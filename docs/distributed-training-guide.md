# Distributed Training Guide (Human-Friendly)

## Why this exists

You want to train one model with several local devices without cloud setup.
This system gives you a practical MVP for that workflow.

## Big picture

There are only two roles:

1. Master: coordinates rounds, sends tasks, aggregates model weights
2. Worker: asks for tasks, trains locally, uploads updated weights

Workers do not host servers. They only poll the master.
This avoids common NAT and firewall issues in local networks.

## How communication works

Each worker follows this loop:

1. Register once (`POST /register`)
2. Poll for work (`GET /task/{worker_id}`)
3. Download current global model (`GET /weights/global`)
4. Train on assigned sample indices
5. Submit updated weights (`POST /submit/{worker_id}`)
6. Repeat until master says `done`

The master waits for all workers each round.
After all submissions arrive, it runs sample-count weighted FedAvg.

## Quick start (10-minute path)

## 1) Install dependencies

```bash
python3.11 -m venv .venv
source .venv/bin/activate
python -m pip install -U pip
pip install -r requirements.txt
```

## 2) Start master

```bash
python -m ml.distributed.run_master --port 8000 --num-workers 2 --rounds 3
```

## 3) Start workers (new terminals)

```bash
python -m ml.distributed.run_worker --master-url http://localhost:8000 --name w1
python -m ml.distributed.run_worker --master-url http://localhost:8000 --name w2
```

## 4) Watch status

```bash
curl http://localhost:8000/status
```

You should see state progress like:
`WAITING -> COLLECTING -> AGGREGATING -> ... -> DONE`

## Moving from localhost to real devices

1. Keep the master command mostly the same, but bind host `0.0.0.0`.
2. Use the master machine LAN IP in worker commands.
3. Make sure all machines can reach `<master-ip>:<port>`.

Example:

```bash
python -m ml.distributed.run_master --host 0.0.0.0 --port 8000 --num-workers 2
python -m ml.distributed.run_worker --master-url http://192.168.1.100:8000 --name worker-1
```

## Files that matter most

1. `ml/distributed/config.py`: shared constants, model builder, train/eval utilities
2. `ml/distributed/master.py`: FastAPI master and round orchestration
3. `ml/distributed/worker.py`: polling worker client
4. `ml/distributed/run_master.py`: master CLI
5. `ml/distributed/run_worker.py`: worker CLI

## What is intentionally simple in this MVP

1. No authentication/TLS
2. No partial-round aggregation (master waits for all workers)
3. No advanced fault recovery
4. CIFAR-10 data is downloaded locally on each machine

This keeps setup fast and makes debugging straightforward.

## Common issues and fixes

1. Worker cannot connect to master  
   Check master IP/port, firewall, and that master is running with `--host 0.0.0.0`.

2. Worker stays in `wait` forever  
   Make sure registered worker count reached `--num-workers`.

3. Missing Python packages  
   Activate your venv and run `pip install -r requirements.txt`.

4. Slow first round  
   First run may download CIFAR-10 and pretrained ResNet18 weights.

## Operational note

Checkpoints are stored in:

`ml/distributed/checkpoints/`

Look for:

1. `global_round_*.pt` for each round
2. `best_global.pt` for the best observed test accuracy
