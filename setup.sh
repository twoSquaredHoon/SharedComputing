#!/bin/bash
# One-time setup for a new machine (Mac or Linux), master or worker.
# Uses uv to get its own clean Python 3.11, so Homebrew's Python is never touched.
#
#   bash setup.sh
#
# Then run:   .venv/bin/python worker.py     (worker)
#             .venv/bin/python master.py     (master)
set -e
cd "$(dirname "$0")"

# 1. get uv if it's missing
if ! command -v uv >/dev/null 2>&1; then
    echo "==> installing uv"
    if command -v brew >/dev/null 2>&1; then
        brew install uv
    else
        curl -LsSf https://astral.sh/uv/install.sh | sh
        export PATH="$HOME/.local/bin:$PATH"
    fi
    if ! command -v uv >/dev/null 2>&1; then
        echo "Could not install uv. Install it manually (https://docs.astral.sh/uv/) and run this again."
        exit 1
    fi
fi

# 2. fresh venv with Python 3.11 (uv downloads it if needed)
echo "==> creating .venv (Python 3.11)"
rm -rf .venv
uv venv --python 3.11 .venv

# 3. packages for both master and worker
echo "==> installing packages"
uv pip install --python .venv/bin/python \
    torch torchvision "numpy<2" certifi requests psutil fastapi uvicorn pydantic

# 4. quick check
.venv/bin/python -c "import torch, torchvision, fastapi; print('torch', torch.__version__, 'ok')"

echo ""
echo "Done."
echo "  worker:  .venv/bin/python worker.py"
echo "  master:  .venv/bin/python master.py"
if [ ! -d data ]; then
    echo ""
    echo "Note: no data/ folder here yet. Copy the dataset into SharedComputing/data before training."
fi
