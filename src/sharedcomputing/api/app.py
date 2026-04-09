from __future__ import annotations

import json
import os
import pty
import shutil
import sqlite3
import ssl
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.request
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Literal

import certifi

os.environ.setdefault("SSL_CERT_FILE", certifi.where())
ssl._create_default_https_context = ssl.create_default_context

from fastapi import FastAPI, HTTPException
from fastapi.responses import PlainTextResponse
from pydantic import BaseModel, Field

from sharedcomputing.core.paths import (
    CHECKPOINT_BEST_NET,
    MASTER_SCRIPT,
    PRETRAINED_MODEL_DIR,
    REPO_ROOT,
    SUMMARY_NET,
)
from sharedcomputing.utils.backend_helpers import (
    compute_split_counts,
    count_dataset_images,
    parse_summary_text,
    resolve_dataset_path,
    utc_now,
)

SUMMARY_SOURCE = SUMMARY_NET
CHECKPOINT_SOURCE = CHECKPOINT_BEST_NET
PRETRAINED_MODEL_ROOT = PRETRAINED_MODEL_DIR

DATASET_ROOT_ENV = os.environ.get("DATASET_ROOT")
ADVERTISED_HOST = os.environ.get("ADVERTISED_HOST")
RESULTS_DB_ENV = os.environ.get("RESULTS_DB")

if not ADVERTISED_HOST:
    raise RuntimeError("ADVERTISED_HOST must be set")

DATASET_ROOT = Path(DATASET_ROOT_ENV).resolve() if DATASET_ROOT_ENV else None
RESULTS_DB = Path(RESULTS_DB_ENV or (REPO_ROOT / "runtime" / "results.db")).resolve()
RUNTIME_ROOT = RESULTS_DB.parent
LOG_ROOT = RUNTIME_ROOT / "logs"
SUMMARY_ROOT = RUNTIME_ROOT / "summaries"
MODEL_ARCHIVE_ROOT = RUNTIME_ROOT / "models"
TORCH_CACHE_DIR = Path.home() / ".cache" / "torch" / "hub" / "checkpoints"
MASTER_PORT = 8000
CONTROL_PORT = int(os.environ.get("CONTROL_PORT", "8080"))
POLL_INTERVAL_SECONDS = 2.0

MODEL_INSTALL_CATALOG: dict[str, dict[str, str]] = {
    "resnet18": {
        "filename": "resnet18-f37072fd.pth",
        "url": "https://download.pytorch.org/models/resnet18-f37072fd.pth",
    },
    "resnet34": {
        "filename": "resnet34-b627a593.pth",
        "url": "https://download.pytorch.org/models/resnet34-b627a593.pth",
    },
    "resnet50": {
        "filename": "resnet50-11ad3fa6.pth",
        "url": "https://download.pytorch.org/models/resnet50-11ad3fa6.pth",
    },
}

MODEL_DOWNLOAD_TIMEOUT_SECONDS = 180
MODEL_DOWNLOAD_MAX_ATTEMPTS = 3

_MODEL_INSTALL_LOCK = threading.Lock()
_MODEL_INSTALL_STATE: dict[str, dict[str, Any]] = {}

for path in (RUNTIME_ROOT, LOG_ROOT, SUMMARY_ROOT, MODEL_ARCHIVE_ROOT, PRETRAINED_MODEL_ROOT, TORCH_CACHE_DIR):
    path.mkdir(parents=True, exist_ok=True)


class CreateRunRequest(BaseModel):
    dataset_subpath: str = Field(default=".")
    rounds: int = Field(gt=0)
    local_epochs: int = Field(gt=0)
    batch_size: int = Field(gt=0)
    learning_rate: float = Field(gt=0)
    round_timeout_sec: int = Field(gt=0)
    connection_type: Literal["LAN", "WiFi"] = "LAN"
    # ── New fields for mode and model selection ────────────────────────────────
    mode: Literal["quality", "speed"] = "quality"
    model: Literal["resnet18", "resnet50", "efficientnet_b0", "efficientnet_b3", "vit"] = "resnet18"


@dataclass
class ActiveRun:
    run_id: int
    dataset_subpath: str
    dataset_path: Path
    train_images: int
    val_images: int
    test_images: int
    connection_type: str
    process: subprocess.Popen[bytes]
    master_fd: int
    log_path: Path
    summary_archive_path: Path
    checkpoint_archive_path: Path
    started_epoch: float
    stop_event: threading.Event = field(default_factory=threading.Event)
    begin_sent: bool = False
    completion_reason: str | None = None
    output_buffer: str = ""


class SQLiteStore:
    def __init__(self, db_path: Path) -> None:
        self.db_path = db_path
        self._lock = threading.Lock()
        self._conn = sqlite3.connect(db_path, check_same_thread=False)
        self._conn.row_factory = sqlite3.Row
        self._conn.execute("PRAGMA foreign_keys = ON")
        self._create_schema()

    def _create_schema(self) -> None:
        with self._lock:
            self._conn.executescript(
                """
                CREATE TABLE IF NOT EXISTS runs (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    status TEXT NOT NULL,
                    started_at TEXT NOT NULL,
                    finished_at TEXT,
                    dataset_subpath TEXT NOT NULL,
                    dataset_total_images INTEGER NOT NULL,
                    train_images INTEGER NOT NULL,
                    val_images INTEGER NOT NULL,
                    test_images INTEGER NOT NULL,
                    model_name TEXT NOT NULL,
                    training_mode TEXT NOT NULL DEFAULT 'quality',
                    connection_type TEXT NOT NULL,
                    rounds INTEGER NOT NULL,
                    local_epochs INTEGER NOT NULL,
                    batch_size INTEGER NOT NULL,
                    learning_rate REAL NOT NULL,
                    round_timeout_sec INTEGER NOT NULL,
                    advertised_host TEXT NOT NULL,
                    master_port INTEGER NOT NULL,
                    registered_worker_count INTEGER NOT NULL DEFAULT 0,
                    best_val_accuracy REAL,
                    best_round INTEGER,
                    test_accuracy REAL,
                    total_training_seconds REAL,
                    summary_path TEXT,
                    checkpoint_path TEXT,
                    error_message TEXT
                );

                CREATE TABLE IF NOT EXISTS workers (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    run_id INTEGER NOT NULL REFERENCES runs(id) ON DELETE CASCADE,
                    worker_id TEXT NOT NULL,
                    first_seen_at TEXT NOT NULL,
                    last_seen_at TEXT NOT NULL,
                    state TEXT NOT NULL,
                    connection_type TEXT NOT NULL,
                    worker_train_images INTEGER NOT NULL,
                    ram_total_gb REAL,
                    last_cpu_pct REAL,
                    last_ram_used_gb REAL,
                    last_gpu_pct REAL,
                    last_temp_c REAL,
                    UNIQUE(run_id, worker_id)
                );
                """
            )
            self._conn.commit()

    def create_run(self, request: CreateRunRequest, dataset_total: int, splits: tuple[int, int, int]) -> int:
        started_at = utc_now()
        train_images, val_images, test_images = splits
        with self._lock:
            cursor = self._conn.execute(
                """
                INSERT INTO runs (
                    status, started_at, dataset_subpath, dataset_total_images,
                    train_images, val_images, test_images, model_name, training_mode,
                    connection_type, rounds, local_epochs, batch_size,
                    learning_rate, round_timeout_sec, advertised_host, master_port
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    "waiting_workers",
                    started_at,
                    request.dataset_subpath,
                    dataset_total,
                    train_images,
                    val_images,
                    test_images,
                    request.model,
                    request.mode,
                    request.connection_type,
                    request.rounds,
                    request.local_epochs,
                    request.batch_size,
                    request.learning_rate,
                    request.round_timeout_sec,
                    ADVERTISED_HOST,
                    MASTER_PORT,
                ),
            )
            self._conn.commit()
            return int(cursor.lastrowid)

    def get_active_run(self) -> dict[str, Any] | None:
        return self._fetch_one(
            """
            SELECT * FROM runs
            WHERE status IN ('waiting_workers', 'running')
            ORDER BY id DESC LIMIT 1
            """
        )

    def list_runs(self) -> list[dict[str, Any]]:
        return self._fetch_all("SELECT * FROM runs ORDER BY id DESC")

    def get_run(self, run_id: int) -> dict[str, Any] | None:
        return self._fetch_one("SELECT * FROM runs WHERE id = ?", (run_id,))

    def update_run(self, run_id: int, **fields: Any) -> None:
        if not fields:
            return
        columns = ", ".join(f"{name} = ?" for name in fields)
        values = list(fields.values()) + [run_id]
        with self._lock:
            self._conn.execute(f"UPDATE runs SET {columns} WHERE id = ?", values)
            self._conn.commit()

    def ensure_worker(self, run_id: int, worker_id: str, connection_type: str, worker_train_images: int) -> None:
        now = utc_now()
        with self._lock:
            self._conn.execute(
                """
                INSERT INTO workers (
                    run_id, worker_id, first_seen_at, last_seen_at, state,
                    connection_type, worker_train_images
                ) VALUES (?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(run_id, worker_id) DO UPDATE SET
                    last_seen_at = excluded.last_seen_at,
                    connection_type = excluded.connection_type,
                    worker_train_images = excluded.worker_train_images
                """,
                (
                    run_id,
                    worker_id,
                    now,
                    now,
                    "registered",
                    connection_type,
                    worker_train_images,
                ),
            )
            self._conn.commit()

    def update_worker_metrics(
        self,
        run_id: int,
        worker_id: str,
        *,
        state: str,
        ram_total_gb: float | None,
        last_cpu_pct: float | None,
        last_ram_used_gb: float | None,
        last_gpu_pct: float | None,
        last_temp_c: float | None,
    ) -> None:
        with self._lock:
            self._conn.execute(
                """
                UPDATE workers
                SET last_seen_at = ?,
                    state = ?,
                    ram_total_gb = ?,
                    last_cpu_pct = ?,
                    last_ram_used_gb = ?,
                    last_gpu_pct = ?,
                    last_temp_c = ?
                WHERE run_id = ? AND worker_id = ?
                """,
                (
                    utc_now(),
                    state,
                    ram_total_gb,
                    last_cpu_pct,
                    last_ram_used_gb,
                    last_gpu_pct,
                    last_temp_c,
                    run_id,
                    worker_id,
                ),
            )
            self._conn.commit()

    def set_all_workers_state(self, run_id: int, state: str) -> None:
        with self._lock:
            self._conn.execute("UPDATE workers SET state = ? WHERE run_id = ?", (state, run_id))
            self._conn.commit()

    def count_workers(self, run_id: int) -> int:
        row = self._fetch_one("SELECT COUNT(*) AS count FROM workers WHERE run_id = ?", (run_id,))
        return int(row["count"]) if row else 0

    def get_workers(self, run_id: int) -> list[dict[str, Any]]:
        return self._fetch_all(
            "SELECT * FROM workers WHERE run_id = ? ORDER BY worker_id ASC",
            (run_id,),
        )

    def _fetch_one(self, query: str, params: tuple[Any, ...] = ()) -> dict[str, Any] | None:
        with self._lock:
            row = self._conn.execute(query, params).fetchone()
        return dict(row) if row else None

    def _fetch_all(self, query: str, params: tuple[Any, ...] = ()) -> list[dict[str, Any]]:
        with self._lock:
            rows = self._conn.execute(query, params).fetchall()
        return [dict(row) for row in rows]


class RunManager:
    def __init__(self, store: SQLiteStore) -> None:
        self.store = store
        self._lock = threading.Lock()
        self.active_run: ActiveRun | None = None

    def start_run(self, request: CreateRunRequest) -> dict[str, Any]:
        with self._lock:
            if self.active_run or self.store.get_active_run():
                raise HTTPException(status_code=409, detail="Only one active run is supported")

            if DATASET_ROOT is None:
                raise HTTPException(status_code=400, detail="DATASET_ROOT must be set before creating runs")

            dataset_path = resolve_dataset_path(DATASET_ROOT, request.dataset_subpath)
            dataset_total = count_dataset_images(dataset_path)
            if dataset_total <= 0:
                raise HTTPException(status_code=400, detail="Dataset folder contains no supported image files")

            splits = compute_split_counts(dataset_total)
            run_id = self.store.create_run(request, dataset_total, splits)

            log_path = LOG_ROOT / f"run-{run_id}.log"
            summary_archive_path = SUMMARY_ROOT / f"run-{run_id}.md"
            checkpoint_archive_path = MODEL_ARCHIVE_ROOT / f"run-{run_id}-best_model_net.pth"
            process, master_fd = self._spawn_master(request, dataset_path)

            active_run = ActiveRun(
                run_id=run_id,
                dataset_subpath=request.dataset_subpath,
                dataset_path=dataset_path,
                train_images=splits[0],
                val_images=splits[1],
                test_images=splits[2],
                connection_type=request.connection_type,
                process=process,
                master_fd=master_fd,
                log_path=log_path,
                summary_archive_path=summary_archive_path,
                checkpoint_archive_path=checkpoint_archive_path,
                started_epoch=time.time(),
            )
            self.active_run = active_run

            threading.Thread(target=self._capture_output, args=(active_run,), daemon=True).start()
            threading.Thread(target=self._poll_master, args=(active_run,), daemon=True).start()

            return {
                "run_id": run_id,
                "status": "waiting_workers",
                "advertised_host": ADVERTISED_HOST,
                "master_port": MASTER_PORT,
                "control_port": CONTROL_PORT,
            }

    def begin_run(self, run_id: int) -> dict[str, Any]:
        with self._lock:
            active = self._require_active_run(run_id)
            if active.begin_sent:
                return {"run_id": run_id, "status": "running"}
            if self.store.count_workers(run_id) < 1:
                raise HTTPException(status_code=409, detail="At least one worker must register before begin")

            os.write(active.master_fd, b"\n")
            active.begin_sent = True
            self.store.update_run(run_id, status="running")
            return {"run_id": run_id, "status": "running"}

    def stop_run(self, run_id: int) -> dict[str, Any]:
        with self._lock:
            active = self._require_active_run(run_id)
        self._finalize_run(active, status="stopped", error_message="Stopped by API request")
        return {"run_id": run_id, "status": "stopped"}

    def list_runs(self) -> list[dict[str, Any]]:
        return self.store.list_runs()

    def get_run(self, run_id: int) -> dict[str, Any]:
        row = self.store.get_run(run_id)
        if not row:
            raise HTTPException(status_code=404, detail="Run not found")
        return row

    def get_workers(self, run_id: int) -> list[dict[str, Any]]:
        self.get_run(run_id)
        return self.store.get_workers(run_id)

    def read_logs(self, run_id: int) -> str:
        self.get_run(run_id)
        log_path = LOG_ROOT / f"run-{run_id}.log"
        if not log_path.exists():
            raise HTTPException(status_code=404, detail="Log file not found")
        return log_path.read_text(encoding="utf-8")

    def _spawn_master(self, request: CreateRunRequest, dataset_path: Path) -> tuple[subprocess.Popen[bytes], int]:
        master_fd, slave_fd = pty.openpty()
        env = os.environ.copy()
        env["PYTHONUNBUFFERED"] = "1"
        process = subprocess.Popen(
            [
                sys.executable,
                str(MASTER_SCRIPT),
                "--dataset", str(dataset_path),
                "--rounds",  str(request.rounds),
                "--epochs",  str(request.local_epochs),
                "--batch",   str(request.batch_size),
                "--lr",      str(request.learning_rate),
                "--timeout", str(request.round_timeout_sec),
                "--mode",    request.mode,
                "--model",   request.model,
            ],
            cwd=REPO_ROOT,
            stdin=slave_fd,
            stdout=slave_fd,
            stderr=slave_fd,
            env=env,
        )
        os.close(slave_fd)
        return process, master_fd

    def _capture_output(self, active: ActiveRun) -> None:
        with active.log_path.open("a", encoding="utf-8") as log_file:
            while not active.stop_event.is_set():
                try:
                    chunk = os.read(active.master_fd, 4096)
                except OSError:
                    break
                if not chunk:
                    break

                text = chunk.decode("utf-8", errors="replace")
                active.output_buffer += text

                while "\n" in active.output_buffer:
                    line, active.output_buffer = active.output_buffer.split("\n", 1)
                    full_line = f"{line}\n"
                    log_file.write(full_line)
                    log_file.flush()
                    self._handle_log_line(active, full_line)

            if active.output_buffer:
                log_file.write(active.output_buffer)
                log_file.flush()

    def _handle_log_line(self, active: ActiveRun, line: str) -> None:
        if "Summary →" in line:
            self._finalize_run(active, status="succeeded", error_message=None)

    def _poll_master(self, active: ActiveRun) -> None:
        while not active.stop_event.is_set():
            self._poll_status(active)
            self._poll_worker_metrics(active)

            if active.process.poll() is not None:
                if active.completion_reason is None:
                    error_message = f"master.py exited with code {active.process.returncode}"
                    self._finalize_run(active, status="failed", error_message=error_message)
                break

            time.sleep(POLL_INTERVAL_SECONDS)

    def _poll_status(self, active: ActiveRun) -> None:
        data = self._http_json("/status")
        if not data:
            return
        registered_workers = data.get("registered_workers") or []
        for worker_id in registered_workers:
            self.store.ensure_worker(
                active.run_id,
                worker_id,
                active.connection_type,
                active.train_images,
            )
        self.store.update_run(active.run_id, registered_worker_count=len(registered_workers))

    def _poll_worker_metrics(self, active: ActiveRun) -> None:
        data = self._http_json("/workers/metrics")
        if not isinstance(data, dict):
            return

        for worker_id, metrics in data.items():
            if not isinstance(metrics, dict):
                continue
            self.store.ensure_worker(
                active.run_id,
                worker_id,
                active.connection_type,
                active.train_images,
            )
            state = "stale" if metrics.get("stale") else "active"
            self.store.update_worker_metrics(
                active.run_id,
                worker_id,
                state=state,
                ram_total_gb=_as_float(metrics.get("ram_total")),
                last_cpu_pct=_as_float(metrics.get("cpu")),
                last_ram_used_gb=_as_float(metrics.get("ram_used")),
                last_gpu_pct=_as_float(metrics.get("gpu")),
                last_temp_c=_as_float(metrics.get("temp")),
            )

    def _http_json(self, endpoint: str) -> Any | None:
        url = f"http://127.0.0.1:{MASTER_PORT}{endpoint}"
        try:
            with urllib.request.urlopen(url, timeout=2) as response:
                if response.status != 200:
                    return None
                return json.loads(response.read().decode("utf-8"))
        except (urllib.error.URLError, TimeoutError, ValueError):
            return None

    def _finalize_run(self, active: ActiveRun, *, status: str, error_message: str | None) -> None:
        with self._lock:
            if self.active_run is not active:
                return
            if active.completion_reason is not None:
                return
            active.completion_reason = status
            active.stop_event.set()

        summary_path = None
        checkpoint_path = None
        extra_fields: dict[str, Any] = {}

        if status == "succeeded":
            time.sleep(0.5)
            if not SUMMARY_SOURCE.exists():
                status = "failed"
                error_message = "summary_net.md was not produced"
            elif SUMMARY_SOURCE.stat().st_mtime < active.started_epoch:
                status = "failed"
                error_message = "summary_net.md was not refreshed for this run"
            else:
                shutil.copy2(SUMMARY_SOURCE, active.summary_archive_path)
                summary_path = str(active.summary_archive_path)
                parsed = parse_summary_text(active.summary_archive_path.read_text(encoding="utf-8"))
                if not parsed:
                    status = "failed"
                    error_message = "summary_net.md could not be parsed"
                else:
                    extra_fields.update(parsed)
                    if CHECKPOINT_SOURCE.exists() and CHECKPOINT_SOURCE.stat().st_mtime >= active.started_epoch:
                        shutil.copy2(CHECKPOINT_SOURCE, active.checkpoint_archive_path)
                        checkpoint_path = str(active.checkpoint_archive_path)

        self._terminate_process(active.process)
        try:
            os.close(active.master_fd)
        except OSError:
            pass

        self.store.set_all_workers_state(active.run_id, "completed")
        self.store.update_run(
            active.run_id,
            status=status,
            finished_at=utc_now(),
            summary_path=summary_path,
            checkpoint_path=checkpoint_path,
            error_message=error_message,
            registered_worker_count=self.store.count_workers(active.run_id),
            **extra_fields,
        )

        with self._lock:
            self.active_run = None

    def _terminate_process(self, process: subprocess.Popen[bytes]) -> None:
        if process.poll() is not None:
            return
        process.terminate()
        try:
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)

    def _require_active_run(self, run_id: int) -> ActiveRun:
        if not self.active_run or self.active_run.run_id != run_id:
            raise HTTPException(status_code=404, detail="Active run not found")
        return self.active_run


def _as_float(value: Any) -> float | None:
    if value is None:
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _new_install_state(model_name: str) -> dict[str, Any]:
    return {
        "model": model_name,
        "status": "idle",
        "progress": 0.0,
        "error": None,
        "path": None,
    }


def _set_install_state(model_name: str, **fields: Any) -> dict[str, Any]:
    with _MODEL_INSTALL_LOCK:
        state = _MODEL_INSTALL_STATE.get(model_name)
        if state is None:
            state = _new_install_state(model_name)
            _MODEL_INSTALL_STATE[model_name] = state
        state.update(fields)
        return dict(state)


def _get_install_state(model_name: str) -> dict[str, Any]:
    with _MODEL_INSTALL_LOCK:
        state = _MODEL_INSTALL_STATE.get(model_name)
        if state is None:
            state = _new_install_state(model_name)
            _MODEL_INSTALL_STATE[model_name] = state
        return dict(state)


def _weight_candidates(model_name: str) -> list[str]:
    entry = MODEL_INSTALL_CATALOG.get(model_name)
    if not entry:
        return [f"{model_name}.pth"]
    primary = entry["filename"]
    alt = f"{model_name}.pth"
    return [primary, alt] if primary != alt else [primary]


def _find_installed_path(model_name: str) -> str | None:
    for filename in _weight_candidates(model_name):
        local = PRETRAINED_MODEL_ROOT / filename
        if local.exists():
            return str(local)
        cache = TORCH_CACHE_DIR / filename
        if cache.exists():
            return str(cache)
    return None


def _copy_if_missing(src: Path, dst: Path) -> None:
    if src.exists() and not dst.exists():
        shutil.copy2(src, dst)


def _download_model_with_progress(model_name: str) -> None:
    entry = MODEL_INSTALL_CATALOG[model_name]
    filename = entry["filename"]
    url = entry["url"]
    cache_path = TORCH_CACHE_DIR / filename
    local_path = PRETRAINED_MODEL_ROOT / filename
    tmp_path = TORCH_CACHE_DIR / f".{filename}.part"

    if cache_path.exists() or local_path.exists():
        _copy_if_missing(cache_path, local_path)
        _copy_if_missing(local_path, cache_path)
        installed_path = str(local_path if local_path.exists() else cache_path)
        _set_install_state(model_name, status="installed", progress=100.0, path=installed_path, error=None)
        return

    last_error: str | None = None
    for attempt in range(1, MODEL_DOWNLOAD_MAX_ATTEMPTS + 1):
        try:
            _set_install_state(model_name, status="downloading", progress=0.0, error=None, path=None)

            downloaded = 0
            total = 0
            req = urllib.request.Request(url, headers={"User-Agent": "SharedComputing/1.0"})
            with urllib.request.urlopen(req, timeout=MODEL_DOWNLOAD_TIMEOUT_SECONDS) as response:
                content_len = response.headers.get("Content-Length")
                if content_len and content_len.isdigit():
                    total = int(content_len)

                with tmp_path.open("wb") as out:
                    while True:
                        chunk = response.read(1024 * 256)
                        if not chunk:
                            break
                        out.write(chunk)
                        downloaded += len(chunk)
                        if total > 0:
                            pct = min(99.0, (downloaded * 100.0) / total)
                            _set_install_state(model_name, status="downloading", progress=round(pct, 1))

            tmp_path.replace(cache_path)
            shutil.copy2(cache_path, local_path)
            _set_install_state(model_name, status="installed", progress=100.0, path=str(local_path), error=None)
            return
        except Exception as exc:
            last_error = str(exc)
            try:
                if tmp_path.exists():
                    tmp_path.unlink()
            except OSError:
                pass

            if attempt < MODEL_DOWNLOAD_MAX_ATTEMPTS:
                time.sleep(1.5 * attempt)

    _set_install_state(model_name, status="failed", progress=0.0, error=last_error or "download failed")


def _start_model_install(model_name: str) -> dict[str, Any]:
    existing = _find_installed_path(model_name)
    if existing:
        return _set_install_state(model_name, status="installed", progress=100.0, path=existing, error=None)

    state = _get_install_state(model_name)
    if state["status"] == "downloading":
        return state

    _set_install_state(model_name, status="downloading", progress=0.0, error=None, path=None)
    threading.Thread(target=_download_model_with_progress, args=(model_name,), daemon=True).start()
    return _get_install_state(model_name)


app = FastAPI(title="SharedComputing Backend Wrapper")
store = SQLiteStore(RESULTS_DB)
manager = RunManager(store)


@app.get("/health")
def health() -> dict[str, Any]:
    active = store.get_active_run()
    return {
        "status": "ok",
        "db_path": str(RESULTS_DB),
        "active_run_id": active["id"] if active else None,
        "advertised_host": ADVERTISED_HOST,
        "master_port": MASTER_PORT,
        "control_port": CONTROL_PORT,
    }


@app.post("/models/install/{model_name}")
def install_model(model_name: str) -> dict[str, Any]:
    model = model_name.lower().strip()
    if model not in MODEL_INSTALL_CATALOG:
        raise HTTPException(status_code=400, detail=f"Unsupported install target: {model}")
    return _start_model_install(model)


@app.get("/models/install/{model_name}")
def get_model_install_status(model_name: str) -> dict[str, Any]:
    model = model_name.lower().strip()
    if model not in MODEL_INSTALL_CATALOG:
        raise HTTPException(status_code=400, detail=f"Unsupported install target: {model}")

    existing = _find_installed_path(model)
    if existing:
        return _set_install_state(model, status="installed", progress=100.0, path=existing, error=None)
    return _get_install_state(model)


@app.post("/runs")
def create_run(request: CreateRunRequest) -> dict[str, Any]:
    return manager.start_run(request)


@app.post("/runs/{run_id}/begin")
def begin_run(run_id: int) -> dict[str, Any]:
    return manager.begin_run(run_id)


@app.post("/runs/{run_id}/stop")
def stop_run(run_id: int) -> dict[str, Any]:
    return manager.stop_run(run_id)


@app.get("/runs")
def list_runs() -> list[dict[str, Any]]:
    return manager.list_runs()


@app.get("/runs/{run_id}")
def get_run(run_id: int) -> dict[str, Any]:
    return manager.get_run(run_id)


@app.get("/runs/{run_id}/workers")
def get_workers(run_id: int) -> list[dict[str, Any]]:
    return manager.get_workers(run_id)


@app.get("/runs/{run_id}/logs", response_class=PlainTextResponse)
def get_logs(run_id: int) -> str:
    return manager.read_logs(run_id)


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=CONTROL_PORT)