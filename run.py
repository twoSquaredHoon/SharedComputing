#!/usr/bin/env python3
"""Shim: full local pipeline lives in scripts/run_local.py."""
from __future__ import annotations

import runpy
import sys
from pathlib import Path

_scripts = Path(__file__).resolve().parent / "scripts" / "run_local.py"
sys.argv[0] = str(_scripts)
runpy.run_path(str(_scripts), run_name="__main__")
