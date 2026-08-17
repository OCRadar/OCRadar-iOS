"""Dataset construction for training.

Expects the standard ImageFolder layout::

    data/
      train/<class_id>/*.jpg
      val/<class_id>/*.jpg     (optional)

When ``data/val`` is absent, a validation set is carved out of ``data/train``
with a seeded random split so runs are reproducible. Validation samples always
receive the deterministic eval transforms, never the training augmentations.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Sequence

import torch
from torch import Tensor
from torch.utils.data import Dataset, Subset
from torchvision import transforms
from torchvision.datasets import ImageFolder

from ocradar_ml.constants import INPUT_SIZE, NORM_MEAN, NORM_STD



def train_transforms() -> transforms.Compose:
    """Augmentation pipeline applied to training images."""
    return transforms.Compose(
        [
            transforms.RandomResizedCrop(INPUT_SIZE, scale=(0.6, 1.0)),
            transforms.RandomHorizontalFlip(),
            transforms.RandomRotation(10),
            transforms.ColorJitter(brightness=0.2, contrast=0.2, saturation=0.15, hue=0.02),
            transforms.ToTensor(),
            transforms.Normalize(NORM_MEAN, NORM_STD),
        ]
    )


def eval_transforms() -> transforms.Compose:
    """Deterministic pipeline applied to validation images.

    Mirrors on-device preprocessing exactly: Vision's
    ``.centerCrop`` (see ``CoreMLLesionClassifier``) scales the largest
    centered square — 100% of the shorter side — to the model input, so eval
    resizes the shorter side to ``INPUT_SIZE`` and center-crops the full
    square rather than using the classic 87.5% crop convention. Validation
    metrics are therefore measured under the same field of view the app
    deploys with.
    """
    return transforms.Compose(
        [
            transforms.Resize(INPUT_SIZE),
            transforms.CenterCrop(INPUT_SIZE),
            transforms.ToTensor(),
            transforms.Normalize(NORM_MEAN, NORM_STD),
        ]
    )


@dataclass(frozen=True)
class DatasetBundle:
    """Train/val datasets plus the class order the model will be trained with.

    ``classes`` is the ImageFolder (alphabetical) class order; it determines
    label indices and is later embedded in the Core ML model, so it is
    load-bearing all the way to the app. ``train_targets`` are the integer
    labels of the training samples, for class-weight computation.
    """

    train: Dataset[tuple[Tensor, int]]
    val: Dataset[tuple[Tensor, int]]
    classes: list[str]
    train_targets: list[int]


def build_datasets(data_dir: Path, val_split: float = 0.15, seed: int = 42) -> DatasetBundle:
    """Builds train/val datasets from ``data_dir``.

    Uses ``data_dir/val`` when it exists; otherwise splits ``data_dir/train``
    with a generator seeded by ``seed``. Raises ``FileNotFoundError`` when the
    train directory is missing and ``ValueError`` on class mismatches or an
    unusable ``val_split``.
    """
    train_dir = data_dir / "train"
    val_dir = data_dir / "val"
    if not train_dir.is_dir():
        raise FileNotFoundError(
            f"Training data not found at {train_dir}. Expected data/train/<class_id>/*.jpg"
        )

    if val_dir.is_dir():
        train_ds = ImageFolder(str(train_dir), transform=train_transforms())
        val_ds = ImageFolder(str(val_dir), transform=eval_transforms())
        if train_ds.classes != val_ds.classes:
            raise ValueError(
                f"Class mismatch between {train_dir} ({train_ds.classes}) and "
                f"{val_dir} ({val_ds.classes}); both must contain the same class directories"
            )
        return DatasetBundle(
            train=train_ds,
            val=val_ds,
            classes=list(train_ds.classes),
            train_targets=list(train_ds.targets),
        )

    if not 0.0 < val_split < 1.0:
        raise ValueError(
            f"{val_dir} does not exist and --val-split is {val_split}; "
            "provide a data/val directory or a --val-split strictly between 0 and 1"
        )

    # Two views of the same directory so the val subset gets eval transforms.
    base_train = ImageFolder(str(train_dir), transform=train_transforms())
    base_val = ImageFolder(str(train_dir), transform=eval_transforms())

    generator = torch.Generator().manual_seed(seed)
    indices = torch.randperm(len(base_train), generator=generator).tolist()
    val_count = max(1, int(len(indices) * val_split))
    if val_count >= len(indices):
        raise ValueError(
            f"--val-split {val_split} leaves no training samples "
            f"({len(indices)} total images found)"
        )
    val_indices = indices[:val_count]
    train_indices = indices[val_count:]

    return DatasetBundle(
        train=Subset(base_train, train_indices),
        val=Subset(base_val, val_indices),
        classes=list(base_train.classes),
        train_targets=[base_train.targets[i] for i in train_indices],
    )


def class_weights(targets: Sequence[int], num_classes: int) -> torch.Tensor:
    """Inverse-frequency class weights for imbalanced datasets.

    Normalized so a perfectly balanced dataset yields all-ones. Raises
    ``ValueError`` when any class has zero training samples, since that class
    could never be learned.
    """
    counts = torch.zeros(num_classes, dtype=torch.float64)
    for target in targets:
        counts[target] += 1

    missing = [index for index in range(num_classes) if counts[index] == 0]
    if missing:
        raise ValueError(
            f"Classes with no training samples (indices {missing}); "
            "every class directory needs at least one training image"
        )

    weights = counts.sum() / (num_classes * counts)
    return weights.to(torch.float32)
