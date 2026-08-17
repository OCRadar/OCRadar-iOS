"""Single source of truth for preprocessing constants.

``data.py`` (training transforms) and ``export.py`` (Core ML input
configuration) both import from here so the pixels the model sees at training
time and on-device are normalized identically.

``INPUT_SIZE`` must match ``ModelManifest.inputSize`` consumed by the app; the
exported ``ModelManifest.json`` is generated from this value.
"""

from __future__ import annotations

from typing import Final

#: Square input side length in pixels expected by the model.
INPUT_SIZE: Final[int] = 384

#: ImageNet channel means (RGB), applied after scaling pixels to ``0...1``.
NORM_MEAN: Final[tuple[float, float, float]] = (0.485, 0.456, 0.406)

#: ImageNet channel standard deviations (RGB).
NORM_STD: Final[tuple[float, float, float]] = (0.229, 0.224, 0.225)
