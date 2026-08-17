"""Smoke check: build both architectures and run a forward pass.

Needs no dataset and downloads nothing (``pretrained=False`` everywhere).
Run after installing dependencies to confirm the environment works::

    python -m ocradar_ml.selfcheck
"""

from __future__ import annotations

import torch
from torch import nn

from ocradar_ml.constants import INPUT_SIZE
from ocradar_ml.model import SUPPORTED_ARCHS, build_model


def parameter_count(model: nn.Module) -> int:
    """Total number of parameters in ``model``."""
    return sum(parameter.numel() for parameter in model.parameters())


def main() -> None:
    """Builds every supported arch, checks output shapes, prints parameter counts."""
    torch.manual_seed(0)
    num_classes = 5
    batch_size = 2

    for arch in SUPPORTED_ARCHS:
        model = build_model(arch, num_classes=num_classes, pretrained=False)
        model.eval()
        example = torch.randn(batch_size, 3, INPUT_SIZE, INPUT_SIZE)
        with torch.no_grad():
            logits = model(example)

        expected = (batch_size, num_classes)
        actual = tuple(logits.shape)
        assert actual == expected, f"{arch}: expected output shape {expected}, got {actual}"
        assert torch.isfinite(logits).all(), f"{arch}: non-finite values in output"
        print(f"{arch}: output {actual}, {parameter_count(model):,} parameters")

    print("Self-check passed.")


if __name__ == "__main__":
    main()
