"""Core ML export CLI: checkpoint -> OralLesionClassifier.mlpackage + ModelManifest.json.

Usage::

    python -m ocradar_ml.export --checkpoint runs/exp/best.pt \
        --classes runs/exp/classes.json --labels labels.example.yaml \
        --model-version 1.0.0 --out dist

The emitted ``ModelManifest.json`` matches the Codable schema in
``OCRadarKit/Sources/OCRCore/ModelManifest.swift`` exactly::

    {
      "schemaVersion": 1,
      "modelVersion": "<string>",
      "inputSize": <int>,
      "classes": [{"id", "displayName", "riskLevel", "summary"}]
    }

with ``riskLevel`` strictly one of ``low`` | ``moderate`` | ``high``, and the
class order identical to the label order embedded in the Core ML model.
"""

from __future__ import annotations

import argparse
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Sequence

import coremltools as ct
import torch
from torch import Tensor, nn

from ocradar_ml.constants import INPUT_SIZE, NORM_MEAN, NORM_STD
from ocradar_ml.labels import ClassMetadata, load_class_metadata, require_metadata
from ocradar_ml.model import build_model

#: Base name of the model package; the Swift loader expects exactly this name.
MODEL_NAME = "OralLesionClassifier"

#: Manifest file name; the Swift loader expects exactly this name.
MANIFEST_NAME = "ModelManifest.json"


@dataclass(frozen=True)
class ExportConfig:
    """Everything an export run needs, resolved from the CLI."""

    checkpoint: Path
    classes: Path
    labels: Path
    model_version: str
    out: Path


class InferenceWrapper(nn.Module):
    """Finishes preprocessing in-graph and emits probabilities.

    Core ML's ``ImageType`` applies one scalar scale plus a per-channel bias
    (``scale * pixel + bias``), which cannot express per-channel std division
    on its own. The converter input is therefore configured with
    ``scale = 1/255`` and ``bias = -NORM_MEAN``, yielding
    ``pixel/255 - mean``; this wrapper divides by ``NORM_STD`` per channel and
    applies softmax, so the app feeds raw RGB pixels and reads calibrated
    class probabilities directly.
    """

    def __init__(self, backbone: nn.Module) -> None:
        super().__init__()
        self.backbone = backbone
        inv_std = torch.tensor([1.0 / value for value in NORM_STD], dtype=torch.float32)
        self.register_buffer("inv_std", inv_std.view(1, 3, 1, 1))

    def forward(self, x: Tensor) -> Tensor:
        return torch.softmax(self.backbone(x * self.inv_std), dim=1)


def parse_args(argv: Sequence[str] | None = None) -> ExportConfig:
    """Parses CLI arguments into an :class:`ExportConfig`."""
    parser = argparse.ArgumentParser(
        prog="ocradar-export",
        description="Export a trained checkpoint to Core ML plus ModelManifest.json.",
    )
    parser.add_argument(
        "--checkpoint",
        type=Path,
        required=True,
        help="Checkpoint from train.py (typically runs/<exp>/best.pt).",
    )
    parser.add_argument(
        "--classes",
        type=Path,
        required=True,
        help="classes.json written by train.py; defines the embedded label order.",
    )
    parser.add_argument(
        "--labels",
        type=Path,
        required=True,
        help="Class-metadata YAML (see labels.example.yaml).",
    )
    parser.add_argument(
        "--model-version",
        required=True,
        help='Version string stamped into the manifest and model, e.g. "1.0.0".',
    )
    parser.add_argument(
        "--out",
        type=Path,
        default=Path("dist"),
        help="Output directory. Default: dist",
    )
    args = parser.parse_args(argv)
    return ExportConfig(
        checkpoint=args.checkpoint,
        classes=args.classes,
        labels=args.labels,
        model_version=args.model_version,
        out=args.out,
    )


def load_classes(path: Path) -> list[str]:
    """Reads classes.json: a non-empty JSON array of class id strings."""
    data = json.loads(path.read_text(encoding="utf-8"))
    if (
        not isinstance(data, list)
        or not data
        or not all(isinstance(item, str) for item in data)
    ):
        raise ValueError(f"{path}: expected a non-empty JSON array of class id strings")
    return data


def load_backbone(checkpoint_path: Path, classes: Sequence[str]) -> nn.Module:
    """Rebuilds the trained architecture and loads its weights, in eval mode.

    Validates that ``classes`` (from --classes) matches the class list the
    checkpoint was actually trained with: the embedded label order is what maps
    model outputs to lesion ids all the way into the app, so a classes.json
    from a different run must never be exported even if the count happens to
    match.
    """
    num_classes = len(classes)
    payload = torch.load(checkpoint_path, map_location="cpu")
    if not isinstance(payload, dict) or "arch" not in payload or "model_state" not in payload:
        raise ValueError(
            f"{checkpoint_path}: not a train.py checkpoint (missing 'arch'/'model_state')"
        )
    checkpoint_class_list = payload.get("classes")
    if checkpoint_class_list is not None:
        # train.py embeds the exact class list; require identical ids AND order.
        if list(checkpoint_class_list) != list(classes):
            raise ValueError(
                f"{checkpoint_path} was trained with classes "
                f"{list(checkpoint_class_list)} but --classes lists "
                f"{list(classes)}; the files are from different runs, and "
                "exporting them together would map predictions to the wrong "
                "lesion classes"
            )
    # Count check as a fallback for older checkpoints without 'classes'.
    checkpoint_classes = int(payload.get("num_classes", num_classes))
    if checkpoint_classes != num_classes:
        raise ValueError(
            f"{checkpoint_path} was trained with {checkpoint_classes} classes but "
            f"classes.json lists {num_classes}; the files are from different runs"
        )
    model = build_model(
        str(payload["arch"]),
        num_classes=num_classes,
        pretrained=False,
        width_multiplier=float(payload.get("width_multiplier", 1.0)),
    )
    model.load_state_dict(payload["model_state"])
    model.eval()
    return model


def convert_to_coreml(model: nn.Module, classes: Sequence[str]) -> ct.models.MLModel:
    """Traces the wrapped model and converts it to an FP16 ML Program classifier."""
    wrapped = InferenceWrapper(model).eval()
    example_input = torch.rand(1, 3, INPUT_SIZE, INPUT_SIZE)
    with torch.no_grad():
        traced = torch.jit.trace(wrapped, example_input)

    image_input = ct.ImageType(
        name="image",
        shape=(1, 3, INPUT_SIZE, INPUT_SIZE),
        # Applied as scale * pixel + bias; std division happens in-graph
        # (see InferenceWrapper), so the app feeds raw RGB pixels.
        scale=1.0 / 255.0,
        bias=[-mean for mean in NORM_MEAN],
        color_layout=ct.colorlayout.RGB,
    )
    return ct.convert(
        traced,
        inputs=[image_input],
        classifier_config=ct.ClassifierConfig(class_labels=list(classes)),
        convert_to="mlprogram",
        compute_precision=ct.precision.FLOAT16,
        minimum_deployment_target=ct.target.iOS18,
    )


def build_manifest(model_version: str, ordered: Sequence[ClassMetadata]) -> dict[str, object]:
    """Builds the manifest dict in the exact shape OCRCore's Codable decoder expects."""
    return {
        "schemaVersion": 1,
        "modelVersion": model_version,
        "inputSize": INPUT_SIZE,
        "classes": [
            {
                "id": metadata.id,
                "displayName": metadata.display_name,
                "riskLevel": metadata.risk_level,
                "summary": metadata.summary,
            }
            for metadata in ordered
        ],
    }


def run(config: ExportConfig) -> None:
    """Executes one export: validate inputs, convert, and write artifacts."""
    try:
        classes = load_classes(config.classes)
        metadata = load_class_metadata(config.labels)
        ordered = require_metadata(metadata, classes, config.labels)
        model = load_backbone(config.checkpoint, classes)
    except (ValueError, FileNotFoundError, json.JSONDecodeError) as error:
        raise SystemExit(f"error: {error}") from error

    print(f"exporting {config.checkpoint} ({len(classes)} classes) at {INPUT_SIZE}x{INPUT_SIZE}")
    mlmodel = convert_to_coreml(model, classes)
    mlmodel.short_description = (
        "OCRadar oral-lesion screening classifier. Screening aid only - "
        "not a medical device and not a diagnosis."
    )
    mlmodel.version = config.model_version
    mlmodel.user_defined_metadata["modelVersion"] = config.model_version
    mlmodel.user_defined_metadata["inputSize"] = str(INPUT_SIZE)

    config.out.mkdir(parents=True, exist_ok=True)
    package_path = config.out / f"{MODEL_NAME}.mlpackage"
    mlmodel.save(str(package_path))

    manifest_path = config.out / MANIFEST_NAME
    manifest = build_manifest(config.model_version, ordered)
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

    print(
        f"""
wrote:
  {package_path}
  {manifest_path}

install into the app:
  mkdir -p "../OCRadar/Resources/ML"
  cp -R "{package_path}" "../OCRadar/Resources/ML/"
  cp "{manifest_path}" "../OCRadar/Resources/ML/"

(paths relative to ml/; adjust if you run from elsewhere)

The Xcode synchronized folder picks both files up automatically and compiles
the mlpackage into the app bundle. The Swift loader expects exactly these
names: {MODEL_NAME} and {MANIFEST_NAME}.
"""
    )


def main(argv: Sequence[str] | None = None) -> None:
    """CLI entry point."""
    run(parse_args(argv))


if __name__ == "__main__":
    main()
