#!/usr/bin/env python3
"""Shim: local multiprocess training lives in src/sharedcomputing/training/distributed_local.py."""
from __future__ import annotations

import sys
from pathlib import Path

_REPO = Path(__file__).resolve().parent
_SRC = _REPO / "src"
sys.path.insert(0, str(_SRC))

from sharedcomputing.training.distributed_local import master

if __name__ == "__main__":
    import torch.multiprocessing as mp

    mp.set_start_method("spawn", force=True)
    master()
