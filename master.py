#!/usr/bin/env python3
"""Shim: federated master lives in src/sharedcomputing/training/master.py."""
from __future__ import annotations

import runpy
import sys
from pathlib import Path

_REPO = Path(__file__).resolve().parent
_SRC = _REPO / "src"
sys.path.insert(0, str(_SRC))
_main = _SRC / "sharedcomputing" / "training" / "master.py"
sys.argv[0] = str(_main)
runpy.run_path(str(_main), run_name="__main__")
