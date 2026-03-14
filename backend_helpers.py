from __future__ import annotations

import re
from datetime import datetime, timezone
from pathlib import Path

IMAGE_EXTENSIONS = {
    ".bmp",
    ".gif",
    ".jpeg",
    ".jpg",
    ".png",
    ".tif",
    ".tiff",
    ".webp",
}


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def resolve_dataset_path(dataset_root: Path, dataset_subpath: str) -> Path:
    normalized = (dataset_subpath or ".").strip() or "."
    candidate = (dataset_root / normalized).resolve()
    root = dataset_root.resolve()
    if not candidate.is_relative_to(root):
        raise ValueError("dataset_subpath must stay within DATASET_ROOT")
    if not candidate.exists() or not candidate.is_dir():
        raise FileNotFoundError(f"Dataset path does not exist: {candidate}")
    return candidate


def count_dataset_images(dataset_path: Path) -> int:
    total = 0
    for path in dataset_path.rglob("*"):
        if not path.is_file():
            continue
        if any(part.startswith(".") for part in path.relative_to(dataset_path).parts):
            continue
        if path.suffix.lower() in IMAGE_EXTENSIONS:
            total += 1
    return total


def compute_split_counts(total_images: int) -> tuple[int, int, int]:
    train_images = int(0.70 * total_images)
    val_images = int(0.15 * total_images)
    test_images = total_images - train_images - val_images
    return train_images, val_images, test_images


def parse_summary_text(text: str) -> dict[str, float | int]:
    patterns: dict[str, tuple[str, type[int] | type[float]]] = {
        "dataset_total_images": (r"\| Dataset \| (\d+) images", int),
        "train_images": (r"train=(\d+)", int),
        "val_images": (r"val=(\d+)", int),
        "test_images": (r"test=(\d+)", int),
        "best_val_accuracy": (r"\| Best val accuracy \| ([0-9.]+) \(round (\d+)\)", float),
        "test_accuracy": (r"\| Test accuracy \| ([0-9.]+)", float),
        "total_training_seconds": (r"\| Total training time \| ([0-9.]+)s", float),
    }
    parsed: dict[str, float | int] = {}

    match = re.search(patterns["best_val_accuracy"][0], text)
    if match:
        parsed["best_val_accuracy"] = float(match.group(1))
        parsed["best_round"] = int(match.group(2))

    for key, (pattern, caster) in patterns.items():
        if key == "best_val_accuracy":
            continue
        match = re.search(pattern, text)
        if match:
            parsed[key] = caster(match.group(1))

    return parsed
