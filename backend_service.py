"""Compatibility entry point for the control API. Prefer: uvicorn sharedcomputing.api.app:app"""
from __future__ import annotations

import sys
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parent
_SRC = _REPO_ROOT / "src"
if _SRC.is_dir() and str(_SRC) not in sys.path:
    sys.path.insert(0, str(_SRC))

from sharedcomputing.api.app import app

__all__ = ["app"]

if __name__ == "__main__":
    import os

    import uvicorn

    port = int(os.environ.get("CONTROL_PORT", "8080"))
    uvicorn.run(app, host="0.0.0.0", port=port)
