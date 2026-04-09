#!/usr/bin/env python3
"""Shim: single-machine training lives in src/sharedcomputing/training/single.py."""
from __future__ import annotations

import sys
from pathlib import Path

_REPO = Path(__file__).resolve().parent
_SRC = _REPO / "src"
sys.path.insert(0, str(_SRC))

from sharedcomputing.training.single import train

if __name__ == "__main__":
    train()
