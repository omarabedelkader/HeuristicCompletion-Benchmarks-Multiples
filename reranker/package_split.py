"""Validate the saved Pharo package holdout before any optimization."""
import json
from pathlib import Path


def load_split(path):
    split = json.loads(Path(path).read_text())
    if split.get("schema") != "coo-package-split-v1":
        raise ValueError("Unknown package split schema")
    if type(split.get("seed")) is not int:
        raise ValueError("Selection seed must be an integer")
    for key in ("eligible", "benchmark", "train"):
        names = split.get(key)
        if (not isinstance(names, list) or not names
                or any(not isinstance(p, str) or not p for p in names)
                or len(names) != len(set(names))):
            raise ValueError(f"Invalid or duplicate package names in {key}")
    train, benchmark = set(split["train"]), set(split["benchmark"])
    if train & benchmark:
        raise ValueError("Benchmark packages must never enter training")
    if train | benchmark != set(split["eligible"]):
        raise ValueError("Training must contain every remaining eligible package")
    return split


def validate_training_rows(rows, split):
    allowed = set(split["train"])
    for row in rows:
        if row.get("group") not in allowed:
            raise ValueError(f"Forbidden training package: {row.get('group')!r}")
        if row.get("package", row["group"]) != row["group"]:
            raise ValueError("Training row package and group disagree")
