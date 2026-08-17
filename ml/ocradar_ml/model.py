"""Model architectures for the OCRadar oral-lesion classifier.

Two architectures are supported:

* ``oralnet`` — :class:`OralLesionNet`, a compact from-scratch CNN sized for
  on-device inference (roughly 3M parameters at width 1.0).
* ``mobilenet_v3_small`` — the torchvision baseline, optionally with ImageNet
  pretrained weights, useful as a sanity check or when data is scarce.
"""

from __future__ import annotations

from dataclasses import dataclass

from torch import Tensor, nn

#: Architecture names accepted by :func:`build_model`.
SUPPORTED_ARCHS: tuple[str, ...] = ("oralnet", "mobilenet_v3_small")


def _round_channels(channels: float, divisor: int = 8) -> int:
    """Round a channel count to the nearest multiple of ``divisor`` (min ``divisor``)."""
    return max(divisor, int(channels + divisor / 2) // divisor * divisor)


class SqueezeExcite(nn.Module):
    """Channel attention (Hu et al., Squeeze-and-Excitation Networks).

    Globally pools each channel, passes the summary through a two-layer
    bottleneck, and rescales the input channels by the resulting gate.
    """

    def __init__(self, channels: int, reduction: int = 4) -> None:
        super().__init__()
        reduced = max(8, channels // reduction)
        self.pool = nn.AdaptiveAvgPool2d(1)
        self.fc1 = nn.Conv2d(channels, reduced, kernel_size=1)
        self.act = nn.SiLU(inplace=True)
        self.fc2 = nn.Conv2d(reduced, channels, kernel_size=1)
        self.gate = nn.Sigmoid()

    def forward(self, x: Tensor) -> Tensor:
        scale = self.gate(self.fc2(self.act(self.fc1(self.pool(x)))))
        return x * scale


class ConvBlock(nn.Module):
    """3x3 Conv-BN-SiLU block with squeeze-and-excitation.

    Adds a residual connection when the input and output shapes match
    (stride 1, equal channel counts).
    """

    def __init__(self, in_channels: int, out_channels: int, stride: int = 1) -> None:
        super().__init__()
        self.conv = nn.Conv2d(
            in_channels, out_channels, kernel_size=3, stride=stride, padding=1, bias=False
        )
        self.bn = nn.BatchNorm2d(out_channels)
        self.act = nn.SiLU(inplace=True)
        self.se = SqueezeExcite(out_channels)
        self.use_residual = stride == 1 and in_channels == out_channels

    def forward(self, x: Tensor) -> Tensor:
        out = self.se(self.act(self.bn(self.conv(x))))
        return x + out if self.use_residual else out


@dataclass(frozen=True)
class OralLesionNetConfig:
    """Hyperparameters for :class:`OralLesionNet`.

    ``width_multiplier`` scales every channel count (rounded to multiples of
    8), trading accuracy for size in both directions.
    """

    num_classes: int
    width_multiplier: float = 1.0
    dropout: float = 0.2
    stem_channels: int = 32
    stage_channels: tuple[int, int, int, int] = (48, 96, 192, 384)
    blocks_per_stage: tuple[int, int, int, int] = (2, 2, 3, 2)


class OralLesionNet(nn.Module):
    """Compact from-scratch CNN for oral-lesion classification.

    Layout: a stride-2 conv stem, four downsampling stages of
    ``ConvBlock`` (each stage opens with a stride-2 block), global average
    pooling, dropout, and a linear head. Roughly 3M parameters at the default
    width, comfortably within an on-device budget at 384x384 input.
    """

    def __init__(self, config: OralLesionNetConfig) -> None:
        super().__init__()
        self.config = config

        stem_out = _round_channels(config.stem_channels * config.width_multiplier)
        self.stem = nn.Sequential(
            nn.Conv2d(3, stem_out, kernel_size=3, stride=2, padding=1, bias=False),
            nn.BatchNorm2d(stem_out),
            nn.SiLU(inplace=True),
        )

        stages: list[nn.Module] = []
        in_channels = stem_out
        for channels, block_count in zip(config.stage_channels, config.blocks_per_stage):
            out_channels = _round_channels(channels * config.width_multiplier)
            blocks: list[nn.Module] = [ConvBlock(in_channels, out_channels, stride=2)]
            blocks.extend(
                ConvBlock(out_channels, out_channels, stride=1) for _ in range(block_count - 1)
            )
            stages.append(nn.Sequential(*blocks))
            in_channels = out_channels
        self.stages = nn.Sequential(*stages)

        self.pool = nn.AdaptiveAvgPool2d(1)
        self.dropout = nn.Dropout(config.dropout)
        self.head = nn.Linear(in_channels, config.num_classes)

    def forward(self, x: Tensor) -> Tensor:
        features = self.stages(self.stem(x))
        pooled = self.pool(features).flatten(1)
        return self.head(self.dropout(pooled))


def build_model(
    arch: str,
    num_classes: int,
    pretrained: bool = False,
    width_multiplier: float = 1.0,
) -> nn.Module:
    """Builds a classifier backbone that maps ``(N, 3, H, W)`` to ``(N, num_classes)`` logits.

    ``arch`` must be one of :data:`SUPPORTED_ARCHS`. ``pretrained`` is only
    valid for ``mobilenet_v3_small`` (ImageNet weights, classifier head
    reinitialized). ``width_multiplier`` only applies to ``oralnet``.
    """
    if num_classes < 2:
        raise ValueError(f"num_classes must be >= 2, got {num_classes}")

    if arch == "oralnet":
        if pretrained:
            raise ValueError(
                "oralnet has no pretrained weights; train it from scratch or use "
                "--arch mobilenet_v3_small with --pretrained"
            )
        return OralLesionNet(
            OralLesionNetConfig(num_classes=num_classes, width_multiplier=width_multiplier)
        )

    if arch == "mobilenet_v3_small":
        from torchvision.models import MobileNet_V3_Small_Weights, mobilenet_v3_small

        weights = MobileNet_V3_Small_Weights.DEFAULT if pretrained else None
        model = mobilenet_v3_small(weights=weights)
        in_features = model.classifier[3].in_features
        model.classifier[3] = nn.Linear(in_features, num_classes)
        return model

    raise ValueError(f"Unknown arch {arch!r}; expected one of {', '.join(SUPPORTED_ARCHS)}")
