# SharedComputing

SharedComputing is a local distributed training project.
The goal is simple: use multiple devices on the same LAN as one training team.

## What is implemented

1. A single-machine baseline trainer for CIFAR-10 (`ml/train_cifar10.py`)
2. A LAN-ready master-worker distributed MVP (`ml/distributed/*`)
3. FastAPI-based control plane with polling workers
4. Round checkpoints and training status endpoint

## Project structure

```text
SharedComputing/
├── ml/
│   ├── train_cifar10.py
│   └── distributed/
│       ├── __init__.py
│       ├── config.py
│       ├── master.py
│       ├── worker.py
│       ├── run_master.py
│       └── run_worker.py
├── docs/
│   └── distributed-training-guide.md
├── requirements.txt
└── README.md
```

## Environment setup

```bash
python3.11 -m venv .venv
source .venv/bin/activate
python -m pip install -U pip
pip install -r requirements.txt
```

## Baseline training (single machine)

```bash
python ml/train_cifar10.py
```

Output model:

`ml/saved_model.pt`

## Distributed training (master-worker over HTTP)

### Start master

```bash
python -m ml.distributed.run_master --port 8000 --num-workers 2 --rounds 3
```

### Start workers

```bash
python -m ml.distributed.run_worker --master-url http://localhost:8000 --name w1
python -m ml.distributed.run_worker --master-url http://localhost:8000 --name w2
```

### Check status

```bash
curl http://localhost:8000/status
```

### Checkpoints

Checkpoints are saved in:

`ml/distributed/checkpoints/`

You will see:

1. `global_round_*.pt`
2. `best_global.pt`

## LAN usage (real devices)

1. Run master on one machine:
   `python -m ml.distributed.run_master --host 0.0.0.0 --port 8000 --num-workers 2`
2. Find master LAN IP (example `192.168.1.100`)
3. On each worker machine:
   `python -m ml.distributed.run_worker --master-url http://192.168.1.100:8000 --name worker-X`

Only the `--master-url` value changes when you move from localhost to real devices.

## More guidance

For a practical, human-friendly walkthrough, read:

[`docs/distributed-training-guide.md`](docs/distributed-training-guide.md)
