### SharedComputing
#### Overview

SharedComputing is a distributed AI training platform designed to combine the computing power of multiple local devices into a unified system.

This repository currently implements the core machine learning pipeline as a validation phase before building the distributed master–worker architecture.

The current implementation demonstrates:

Computer Vision training workflow

ResNet18 fine-tuning

Model saving

Device auto-detection (CPU / Apple MPS)

#### Project Structure
```
SharedComputing/
│
├── ml/
│   ├── train_cifar10.py
│   ├── saved_model.pt        # Generated after training
│   └── data/                 # CIFAR-10 downloads here
│
├── requirements.txt
└── README.md
```
#### Tech Stack

Python 3.11

PyTorch

Torchvision

NumPy (< 2)

tqdm

Apple Silicon MPS (if available)

#### Setup (Mac)
cd SharedComputing
python3.11 -m venv .venv
source .venv/bin/activate
python -m pip install -U pip
pip install -r requirements.txt
#### Train (CIFAR-10 Validation Phase)
python ml/train_cifar10.py

What happens:

CIFAR-10 downloads automatically into ml/data/

Pretrained ResNet18 loads

Model trains for 5 epochs

Final model saved to:

ml/saved_model.pt
#### Current Status

ML pipeline functional

Model saving functional

Hardware acceleration supported

Repository structured for distributed expansion

#### Roadmap

Next development phases:

Extract training logic into reusable module

Implement Master–Worker architecture

Add weight aggregation

LAN communication layer (FastAPI)

Performance-aware shard allocation

Web demo layer

#### Vision

SharedComputing aims to:

Utilize idle local devices as distributed compute

Automatically allocate workloads based on device performance

Create a lightweight local AI training platform

Move toward a PaaS-style distributed AI system
