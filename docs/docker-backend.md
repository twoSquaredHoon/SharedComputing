# Backend Startup Guide

## How to Start the Backend

### Prerequisites
- Docker Desktop must be running (open from Applications, wait for whale icon to stop animating)
- A `.env` file must exist in the project root (see below)

### 1. Create the `.env` file (one-time setup)

Create a file called `.env` in the project root (`SharedComputing/.env`):

```
ADVERTISED_HOST=<your Mac's LAN IP>
DATASET_ROOT_HOST=<absolute path to your data/ folder>
```

Example:
```
ADVERTISED_HOST=10.141.134.14
DATASET_ROOT_HOST=/Users/seunghoon/Documents/2.Area/SharedComputing/data
```

To find your current LAN IP:
```bash
ifconfig | grep "inet " | grep -v 127.0.0.1
```

> **Note:** `ADVERTISED_HOST` is the IP that workers on other machines use to reach the backend.
> If your IP changes (e.g. after reconnecting to WiFi), update this value and restart.

### 2. Start the backend

```bash
docker compose up
```

The backend is ready when you see:
```
INFO:     Application startup complete.
INFO:     Uvicorn running on http://0.0.0.0:8080
```

### 3. Stop the backend

```bash
docker compose down
```

Or press `Ctrl+C` in the terminal where it's running.

---

## Ports

| Port | Purpose |
|------|---------|
| 8080 | Control API (workers register here, Mac app polls here) |
| 8000 | Exposed but unused by default |

---

## Known Failure Modes & Fixes

### ❌ `required variable ADVERTISED_HOST is missing a value`
**Cause:** `.env` file doesn't exist or is missing `ADVERTISED_HOST`.
**Fix:** Create `.env` in the project root with `ADVERTISED_HOST=<your LAN IP>` and `DATASET_ROOT_HOST=<path to data>`.

### ❌ `failed to connect to the docker API` / `docker.sock: no such file or directory`
**Cause:** Docker Desktop is not running.
**Fix:** Open Docker Desktop from Applications and wait for it to fully start.

### ❌ `RuntimeError: ADVERTISED_HOST must be set` (when running without Docker)
**Cause:** Running `python3 backend_service.py` without the env var exported.
**Fix:** Use Docker instead, or export the variable first:
```bash
export ADVERTISED_HOST=10.141.134.14
python3 backend_service.py
```

### ❌ `ModuleNotFoundError: No module named 'fastapi'` (when running without Docker)
**Cause:** Dependencies not installed in the active Python environment.
**Fix:** Use Docker instead (it handles all dependencies), or activate the venv:
```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements-backend.txt
```
Note: `source .venv/bin/activate` must be run every time you open a new terminal.

### ❌ Port already in use
**Cause:** A previous backend process didn't shut down cleanly.
**Fix:** Find and kill the process:
```bash
lsof -i :8080
kill -9 <PID>
```

---

## Architecture Notes

- The backend is a FastAPI app (`src/sharedcomputing/api/app.py`) served by uvicorn
- `backend_service.py` in the project root is a compatibility shim — prefer Docker
- `ADVERTISED_HOST` is broadcast to workers so they know where to send results
- `DATASET_ROOT_HOST` maps your local data folder into the container at `/datasets`
- Runtime outputs (logs, models, results.db) are written to `./runtime/` on the host via Docker volume mount
- The `.env` file is gitignored — each machine needs its own copy
