# SharedComputing

## Overview

SharedComputing is a distributed AI training platform that combines the compute power of multiple local devices into a unified federated learning system.

The platform uses a **Master–Worker architecture** over LAN, where a master node orchestrates training and aggregates model weights from one or more worker nodes using the FedAvg algorithm.

---

## How It Works

```
Master (your Mac)
│
│  1. Setup wizard — choose dataset, rounds, epochs, lr
│  2. Loads pretrained ResNet18, broadcasts global weights
│
└──► Worker (second Mac)
         Receives weights
         Trains on its local data for N epochs
         Sends updated weights back
│
│  3. Master averages the weights (FedAvg)
│  4. Evaluates accuracy on validation set
│  5. Saves if improved
│
│  Repeat for N rounds
│
│  6. Final test evaluation
│  7. Saves best_model_net.pth + summary_net.md
```

---

## Project Structure

```
SharedComputing/
│
├── master.py          # Master node — orchestrates training via FastAPI
├── worker.py          # Worker node — trains locally, sends weights back
├── predict.py         # Run inference on any image
│
├── data/              # Your image dataset (ImageFolder format)
│   ├── class_a/
│   ├── class_b/
│   └── class_c/
│
├── models/
│   └── best_model_net.pth   # Saved after training
│
└── summary_net.md     # Per-round training log (generated after training)
```

---

## Tech Stack

- Python 3.11
- PyTorch + Torchvision
- FastAPI + Uvicorn
- ResNet18 (transfer learning, frozen backbone)
- FedAvg weight aggregation
- Apple Silicon MPS / CUDA / CPU auto-detection
- NumPy < 2

---

## Setup

### Master Mac

> If your project folder path contains spaces (e.g. `2. Area`), create the venv outside it to avoid Python path errors.

```bash
cd SharedComputing
python3.11 -m venv ~/venv_shared
source ~/venv_shared/bin/activate
pip3 install torch torchvision certifi fastapi uvicorn requests
pip3 install "numpy<2"
```

### Worker Mac

```bash
brew install python@3.11
cd SharedComputing
rm -rf .venv
python3.11 -m venv .venv
source .venv/bin/activate
pip3 install torch torchvision certifi requests
pip3 install "numpy<2"
```

> Every new terminal session, re-activate before running anything:
> - Master: `source ~/venv_shared/bin/activate`
> - Worker: `source .venv/bin/activate`

---

## Running

### Order matters — follow these steps exactly

**Step 1 — Start master:**

```bash
source ~/venv_shared/bin/activate
cd ~/Documents/2.Area/SharedComputing
python3 master.py
```

The setup wizard will prompt you:

```
Dataset folder (default: ./data): ./data
Rounds (default: 15): 30
Local epochs per round (default: 2): 5
Batch size (default: 8): 8
Learning rate (default: 0.001): 0.001
Round timeout (seconds) (default: 120): 120
```

Wait for `→ Press Enter when all workers are connected...` — **do not press Enter yet.**

**Step 2 — Start worker (second Mac):**

```bash
source .venv/bin/activate
cd ~/Documents/2.Areas/SharedComputing
python3 worker.py
```

Enter the master IP when prompted — it's printed by the master on startup (e.g. `10.141.100.235`).

**Step 3 — Once worker shows `✓ Registered`, press Enter on master.**

Training begins automatically.

---

## Restarting

If port 8000 is already in use from a previous run:

```bash
kill $(lsof -ti:8000)
```

Then re-run master as normal.

---

## Dataset Format

The `data/` folder must follow PyTorch's ImageFolder format — one subfolder per class:

```
data/
├── cats/
│   ├── cat1.jpg
│   └── cat2.jpg
├── dogs/
│   ├── dog1.jpg
│   └── dog2.jpg
└── horses/
    ├── horse1.jpg
    └── horse2.jpg
```

---

## Inference

```bash
source ~/venv_shared/bin/activate
python3 predict.py /path/to/image.jpg
```

Output:

```
  Image : /path/to/image.jpg
  ──────────────────────────────
  cats        55.8%  ███████████
  dogs        44.2%  ████████
  horses       0.0%
  → Prediction: CATS
```

Drag an image from Finder into the terminal to get its path automatically.

---

## Hyperparameter Guide

| Parameter | What it does | Recommended |
|-----------|-------------|-------------|
| Rounds | How many master–worker cycles to run | 20–30 |
| Local epochs | How many passes through data per round | 3–5 |
| Batch size | Images processed at once | 8 (low memory) |
| Learning rate | Step size for weight updates | 0.001 |
| Round timeout | Seconds master waits per round | 120 |

---

## Current Status

- [x] Master–Worker federated architecture
- [x] FedAvg weight aggregation
- [x] Interactive setup wizard
- [x] ResNet18 transfer learning
- [x] Automatic train/val/test split
- [x] Best model checkpointing
- [x] Per-round training summary
- [x] Image inference script
- [x] Apple Silicon MPS support

---

## Roadmap

- [ ] Support multiple workers simultaneously
- [ ] Web UI for drag-and-drop inference
- [ ] Performance-aware workload allocation
- [ ] Support additional architectures (EfficientNet, ViT)
- [ ] Docker deployment
- [ ] PaaS-style distributed AI platform