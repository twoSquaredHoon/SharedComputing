"""Shim: helpers live in sharedcomputing.utils.backend_helpers."""
from __future__ import annotations

import sys
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parent
_SRC = _REPO_ROOT / "src"
if _SRC.is_dir() and str(_SRC) not in sys.path:
    sys.path.insert(0, str(_SRC))

from sharedcomputing.utils.backend_helpers import *  # noqa: F403
