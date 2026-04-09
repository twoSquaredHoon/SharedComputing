from __future__ import annotations

from pathlib import Path


def _repo_root() -> Path:
    # src/sharedcomputing/core/paths.py -> parents[3] == repository root
    return Path(__file__).resolve().parents[3]


REPO_ROOT = _repo_root()

# Root shims (master.py, worker.py, …) stay at repo root for subprocess / UX compatibility.
MASTER_SCRIPT = REPO_ROOT / "master.py"
SUMMARY_NET = REPO_ROOT / "summary_net.md"
MODELS_DIR = REPO_ROOT / "models"
CHECKPOINT_BEST_NET = MODELS_DIR / "best_model_net.pth"
PRETRAINED_MODEL_DIR = MODELS_DIR / "pretrained"
DATA_DIR = REPO_ROOT / "data"
RUNTIME_DIR = REPO_ROOT / "runtime"
