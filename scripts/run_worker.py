"""LAN worker: registers with master and runs local training rounds."""
from __future__ import annotations

import runpy
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "src"
sys.path.insert(0, str(SRC))
main = SRC / "sharedcomputing" / "workers" / "worker.py"
sys.argv[0] = str(main)
runpy.run_path(str(main), run_name="__main__")
