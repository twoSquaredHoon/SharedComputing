# Docker Backend Wrapper

This setup adds a backend-only wrapper around `master.py` without changing the training code.

## What it does

- Runs `master.py` inside a container and keeps port `8000` available for external workers.
- Exposes a control API on port `8080`.
- Stores run results in `SQLite` at `./runtime/results.db`.
- Saves per-run logs, summary snapshots, and archived checkpoints under `./runtime/`.

## Required environment

Create a local `.env` file:

```env
ADVERTISED_HOST=192.168.1.20
DATASET_ROOT_HOST=/absolute/path/to/your/dataset/root
```

- `ADVERTISED_HOST` must be the LAN IP that worker machines can reach.
- `DATASET_ROOT_HOST` is mounted read-only to `/datasets` inside the container.

## Start the backend

```bash
docker compose up --build
```

The backend API will be available at `http://localhost:8080`.

## Run flow

1. Create a run:

```bash
curl -X POST http://localhost:8080/runs \
  -H "Content-Type: application/json" \
  -d '{
    "dataset_subpath": ".",
    "rounds": 5,
    "local_epochs": 1,
    "batch_size": 8,
    "learning_rate": 0.001,
    "round_timeout_sec": 60,
    "connection_type": "LAN"
  }'
```

2. Start workers on other machines and point them to `ADVERTISED_HOST:8000`.
3. After at least one worker registers, begin training:

```bash
curl -X POST http://localhost:8080/runs/1/begin
```

4. Inspect run status:

```bash
curl http://localhost:8080/runs/1
curl http://localhost:8080/runs/1/workers
curl http://localhost:8080/runs/1/logs
```

## Stored artifacts

- Database: `./runtime/results.db`
- Logs: `./runtime/logs/run-<id>.log`
- Summary snapshots: `./runtime/summaries/run-<id>.md`
- Archived checkpoints: `./runtime/models/run-<id>-best_model_net.pth`

## Current limitations

- Only one active run is supported at a time.
- The backend does not store high-frequency telemetry history; it keeps only the latest worker snapshot.
- Detailed hardware specs are limited to what the existing worker metrics endpoint already reports.
- The Swift macOS app is not integrated with this backend yet.
