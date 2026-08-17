"""Training and Core ML export pipeline for the OCRadar oral-lesion classifier.

Kept intentionally light so importing the package never drags in torch;
submodules (:mod:`ocradar_ml.train`, :mod:`ocradar_ml.export`, ...) import
their heavy dependencies themselves.
"""

from ocradar_ml.constants import INPUT_SIZE, NORM_MEAN, NORM_STD

__version__ = "0.1.0"

__all__ = ["INPUT_SIZE", "NORM_MEAN", "NORM_STD", "__version__"]
