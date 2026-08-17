"""Training CLI for the OCRadar oral-lesion classifier.

Usage::

    python -m ocradar_ml.train --data data --labels labels.example.yaml \
        --epochs 40 --out runs/exp

Writes into ``--out``:

* ``classes.json`` — the ImageFolder class order. This order is load-bearing:
  it becomes the label order embedded in the exported Core ML model.
* ``best.pt`` — checkpoint with the best validation macro recall.
* ``last.pt`` — checkpoint from the most recent epoch.
* ``history.json`` — per-epoch metrics including per-class recall and the
  confusion matrix.

Model selection uses macro recall rather than accuracy because a screening
model must not buy overall accuracy by ignoring rare, high-risk classes.
"""

from __future__ import annotations

import argparse
import json
import math
import os
import random
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Sequence

import numpy as np
import torch
from torch import nn
from torch.utils.data import DataLoader
from tqdm import tqdm

from ocradar_ml.data import DatasetBundle, build_datasets, class_weights
from ocradar_ml.labels import load_class_metadata, require_metadata
from ocradar_ml.model import SUPPORTED_ARCHS, build_model

#: Fraction of total steps used for linear learning-rate warmup.
_WARMUP_FRACTION: float = 0.05


@dataclass(frozen=True)
class TrainConfig:
    """Everything a training run needs, resolved from the CLI."""

    data: Path
    labels: Path | None
    arch: str
    pretrained: bool
    epochs: int
    batch_size: int
    lr: float
    weight_decay: float
    val_split: float
    seed: int
    out: Path


@dataclass(frozen=True)
class EvalMetrics:
    """Validation metrics for one epoch."""

    loss: float
    accuracy: float
    macro_recall: float
    per_class_recall: list[float]
    confusion_matrix: list[list[int]]


def parse_args(argv: Sequence[str] | None = None) -> TrainConfig:
    """Parses CLI arguments into a :class:`TrainConfig`."""
    parser = argparse.ArgumentParser(
        prog="ocradar-train",
        description="Train the OCRadar oral-lesion classifier.",
    )
    parser.add_argument(
        "--data",
        type=Path,
        default=Path("data"),
        help="Dataset root containing train/ (and optionally val/). Default: data",
    )
    parser.add_argument(
        "--labels",
        type=Path,
        default=None,
        help=(
            "Class-metadata YAML (see labels.example.yaml). When given, every "
            "discovered class is checked for metadata up front so export cannot "
            "fail after hours of training."
        ),
    )
    parser.add_argument(
        "--arch",
        choices=SUPPORTED_ARCHS,
        default="oralnet",
        help="Model architecture. Default: oralnet",
    )
    parser.add_argument(
        "--pretrained",
        action="store_true",
        help="Start from ImageNet weights (mobilenet_v3_small only).",
    )
    parser.add_argument("--epochs", type=int, default=40, help="Training epochs. Default: 40")
    parser.add_argument("--batch-size", type=int, default=32, help="Batch size. Default: 32")
    parser.add_argument("--lr", type=float, default=3e-4, help="Peak learning rate. Default: 3e-4")
    parser.add_argument(
        "--weight-decay", type=float, default=0.01, help="AdamW weight decay. Default: 0.01"
    )
    parser.add_argument(
        "--val-split",
        type=float,
        default=0.15,
        help="Validation fraction when data/val is absent. Default: 0.15",
    )
    parser.add_argument("--seed", type=int, default=42, help="Random seed. Default: 42")
    parser.add_argument(
        "--out",
        type=Path,
        default=Path("runs/exp"),
        help="Output directory for checkpoints and metrics. Default: runs/exp",
    )
    args = parser.parse_args(argv)
    return TrainConfig(
        data=args.data,
        labels=args.labels,
        arch=args.arch,
        pretrained=args.pretrained,
        epochs=args.epochs,
        batch_size=args.batch_size,
        lr=args.lr,
        weight_decay=args.weight_decay,
        val_split=args.val_split,
        seed=args.seed,
        out=args.out,
    )


def seed_everything(seed: int) -> None:
    """Seeds Python, NumPy, and torch RNGs for reproducible runs."""
    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)


def select_device() -> torch.device:
    """Picks the best available device: CUDA, then Apple MPS, then CPU."""
    if torch.cuda.is_available():
        return torch.device("cuda")
    if torch.backends.mps.is_available():
        return torch.device("mps")
    return torch.device("cpu")


def cosine_with_warmup(warmup_steps: int, total_steps: int) -> Callable[[int], float]:
    """LR multiplier: linear warmup to 1.0, then cosine decay to 0."""

    def multiplier(step: int) -> float:
        if step < warmup_steps:
            return (step + 1) / warmup_steps
        progress = (step - warmup_steps) / max(1, total_steps - warmup_steps)
        return 0.5 * (1.0 + math.cos(math.pi * min(1.0, progress)))

    return multiplier


def evaluate(
    model: nn.Module,
    loader: DataLoader,
    criterion: nn.Module,
    device: torch.device,
    num_classes: int,
) -> EvalMetrics:
    """Runs a full validation pass and computes accuracy, recall, and confusion."""
    model.eval()
    confusion = np.zeros((num_classes, num_classes), dtype=np.int64)
    total_loss = 0.0
    correct = 0
    total = 0

    with torch.no_grad():
        for images, targets in loader:
            images = images.to(device, non_blocking=True)
            targets = targets.to(device, non_blocking=True)
            logits = model(images)
            loss = criterion(logits, targets)
            predictions = logits.argmax(dim=1)

            total_loss += loss.item() * targets.size(0)
            correct += int((predictions == targets).sum().item())
            total += int(targets.size(0))
            for true_label, predicted in zip(targets.tolist(), predictions.tolist()):
                confusion[true_label, predicted] += 1

    row_sums = confusion.sum(axis=1)
    per_class_recall = [
        float(confusion[i, i] / row_sums[i]) if row_sums[i] > 0 else 0.0
        for i in range(num_classes)
    ]
    supported = [per_class_recall[i] for i in range(num_classes) if row_sums[i] > 0]
    macro_recall = float(sum(supported) / len(supported)) if supported else 0.0

    return EvalMetrics(
        loss=total_loss / max(1, total),
        accuracy=correct / max(1, total),
        macro_recall=macro_recall,
        per_class_recall=per_class_recall,
        confusion_matrix=confusion.tolist(),
    )


def _make_loaders(
    bundle: DatasetBundle, config: TrainConfig, device: torch.device
) -> tuple[DataLoader, DataLoader]:
    """Builds train/val loaders with a seeded shuffle generator."""
    workers = min(8, os.cpu_count() or 0)
    generator = torch.Generator().manual_seed(config.seed)
    train_loader = DataLoader(
        bundle.train,
        batch_size=config.batch_size,
        shuffle=True,
        num_workers=workers,
        pin_memory=device.type == "cuda",
        generator=generator,
    )
    val_loader = DataLoader(
        bundle.val,
        batch_size=config.batch_size,
        shuffle=False,
        num_workers=workers,
        pin_memory=device.type == "cuda",
    )
    return train_loader, val_loader


def _make_checkpoint(
    config: TrainConfig,
    classes: list[str],
    model: nn.Module,
    epoch: int,
    metrics: EvalMetrics,
) -> dict[str, object]:
    """Assembles the checkpoint payload consumed by ``export.py``."""
    return {
        "arch": config.arch,
        "num_classes": len(classes),
        "width_multiplier": 1.0,
        "classes": classes,
        "epoch": epoch,
        "model_state": model.state_dict(),
        "val_accuracy": metrics.accuracy,
        "macro_recall": metrics.macro_recall,
    }


def run(config: TrainConfig) -> None:
    """Executes one full training run."""
    seed_everything(config.seed)
    device = select_device()
    print(f"device: {device.type}")

    bundle = build_datasets(config.data, val_split=config.val_split, seed=config.seed)
    classes = bundle.classes
    print(f"classes ({len(classes)}): {', '.join(classes)}")
    print(f"train samples: {len(bundle.train_targets)}")

    if config.labels is not None:
        metadata = load_class_metadata(config.labels)
        require_metadata(metadata, classes, config.labels)
        print(f"label metadata verified against {config.labels}")

    weights = class_weights(bundle.train_targets, len(classes))
    train_loader, val_loader = _make_loaders(bundle, config, device)

    model = build_model(config.arch, num_classes=len(classes), pretrained=config.pretrained)
    model = model.to(device)
    criterion = nn.CrossEntropyLoss(weight=weights.to(device))
    optimizer = torch.optim.AdamW(
        model.parameters(), lr=config.lr, weight_decay=config.weight_decay
    )

    steps_per_epoch = max(1, len(train_loader))
    total_steps = steps_per_epoch * config.epochs
    warmup_steps = max(1, int(total_steps * _WARMUP_FRACTION))
    scheduler = torch.optim.lr_scheduler.LambdaLR(
        optimizer, cosine_with_warmup(warmup_steps, total_steps)
    )

    # Mixed precision on CUDA and MPS; loss scaling is CUDA-only (and a no-op
    # elsewhere, where fp16 gradients do not underflow the same way).
    amp_enabled = device.type in {"cuda", "mps"}
    scaler = torch.amp.GradScaler("cuda", enabled=device.type == "cuda")

    config.out.mkdir(parents=True, exist_ok=True)
    classes_path = config.out / "classes.json"
    classes_path.write_text(json.dumps(classes, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {classes_path}")

    history: list[dict[str, object]] = []
    best_macro_recall = -1.0

    for epoch in range(1, config.epochs + 1):
        model.train()
        running_loss = 0.0
        seen = 0
        progress = tqdm(train_loader, desc=f"epoch {epoch}/{config.epochs}", unit="batch")
        for images, targets in progress:
            images = images.to(device, non_blocking=True)
            targets = targets.to(device, non_blocking=True)

            optimizer.zero_grad(set_to_none=True)
            with torch.autocast(device_type=device.type, dtype=torch.float16, enabled=amp_enabled):
                logits = model(images)
                loss = criterion(logits, targets)
            scaler.scale(loss).backward()
            scaler.step(optimizer)
            scaler.update()
            scheduler.step()

            running_loss += loss.item() * targets.size(0)
            seen += int(targets.size(0))
            progress.set_postfix(loss=f"{running_loss / max(1, seen):.4f}")

        train_loss = running_loss / max(1, seen)
        metrics = evaluate(model, val_loader, criterion, device, len(classes))

        print(
            f"epoch {epoch}: train_loss={train_loss:.4f} val_loss={metrics.loss:.4f} "
            f"val_acc={metrics.accuracy:.4f} macro_recall={metrics.macro_recall:.4f}"
        )
        for name, recall in zip(classes, metrics.per_class_recall):
            print(f"  recall[{name}] = {recall:.4f}")
        print("  confusion matrix (rows = true, cols = predicted):")
        for name, row in zip(classes, metrics.confusion_matrix):
            print(f"    {name:>16} {row}")

        history.append(
            {
                "epoch": epoch,
                "train_loss": train_loss,
                "val_loss": metrics.loss,
                "val_accuracy": metrics.accuracy,
                "macro_recall": metrics.macro_recall,
                "per_class_recall": dict(zip(classes, metrics.per_class_recall)),
                "confusion_matrix": metrics.confusion_matrix,
                "learning_rate": scheduler.get_last_lr()[0],
            }
        )
        (config.out / "history.json").write_text(
            json.dumps(history, indent=2) + "\n", encoding="utf-8"
        )

        checkpoint = _make_checkpoint(config, classes, model, epoch, metrics)
        torch.save(checkpoint, config.out / "last.pt")
        if metrics.macro_recall > best_macro_recall:
            best_macro_recall = metrics.macro_recall
            torch.save(checkpoint, config.out / "best.pt")
            print(f"  new best macro recall {best_macro_recall:.4f}; saved best.pt")

    print(
        f"done. best macro recall {best_macro_recall:.4f}; "
        f"checkpoints and metrics in {config.out}"
    )


def main(argv: Sequence[str] | None = None) -> None:
    """CLI entry point."""
    run(parse_args(argv))


if __name__ == "__main__":
    main()
