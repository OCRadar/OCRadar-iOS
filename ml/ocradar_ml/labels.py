"""Loading and validation of class-metadata YAML files.

The YAML schema (see ``labels.example.yaml``) is a mapping of class id to
``displayName`` / ``riskLevel`` / ``summary``, matching the ``ClassInfo``
shape in ``OCRadarKit/Sources/OCRCore/ModelManifest.swift``.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Mapping, Sequence

import yaml

#: Allowed riskLevel values; must match OCRCore's RiskLevel raw values exactly.
VALID_RISK_LEVELS: tuple[str, ...] = ("low", "moderate", "high")

_REQUIRED_FIELDS: tuple[str, ...] = ("displayName", "riskLevel", "summary")


@dataclass(frozen=True)
class ClassMetadata:
    """Display metadata for one lesion class, as consumed by the app."""

    id: str
    display_name: str
    risk_level: str
    summary: str


def load_class_metadata(path: Path) -> dict[str, ClassMetadata]:
    """Parses a labels YAML file into a mapping of class id to metadata.

    Raises ``ValueError`` on structural problems: non-mapping documents,
    missing fields, or a ``riskLevel`` outside :data:`VALID_RISK_LEVELS`.
    """
    raw = yaml.safe_load(path.read_text(encoding="utf-8"))
    if not isinstance(raw, Mapping):
        raise ValueError(f"{path}: expected a mapping of class id -> metadata")

    metadata: dict[str, ClassMetadata] = {}
    for class_id, fields in raw.items():
        name = str(class_id)
        if not isinstance(fields, Mapping):
            raise ValueError(f"{path}: entry {name!r} must be a mapping of metadata fields")
        missing = [field for field in _REQUIRED_FIELDS if field not in fields]
        if missing:
            raise ValueError(f"{path}: entry {name!r} is missing {', '.join(missing)}")
        risk_level = str(fields["riskLevel"])
        if risk_level not in VALID_RISK_LEVELS:
            raise ValueError(
                f"{path}: entry {name!r} has riskLevel {risk_level!r}; "
                f"expected one of {', '.join(VALID_RISK_LEVELS)}"
            )
        metadata[name] = ClassMetadata(
            id=name,
            display_name=str(fields["displayName"]),
            risk_level=risk_level,
            summary=str(fields["summary"]),
        )

    if not metadata:
        raise ValueError(f"{path}: no class entries found")
    return metadata


def require_metadata(
    metadata: Mapping[str, ClassMetadata],
    class_ids: Sequence[str],
    source: Path,
) -> list[ClassMetadata]:
    """Returns metadata for ``class_ids`` in order, failing if any is missing.

    Raises ``ValueError`` naming every class id that lacks an entry so the
    caller can surface one actionable message.
    """
    missing = [class_id for class_id in class_ids if class_id not in metadata]
    if missing:
        raise ValueError(
            f"{source} lacks metadata for: {', '.join(missing)}. Every trained class "
            "needs displayName, riskLevel, and summary before export."
        )
    return [metadata[class_id] for class_id in class_ids]
