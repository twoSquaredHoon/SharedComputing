"""Results database: every master run is saved to runs/results.db (SQLite)."""
from __future__ import annotations

import sqlite3
import time

from sharedcomputing.core.paths import REPO_ROOT

RUNS_DIR = REPO_ROOT / "runs"
DB_PATH = RUNS_DIR / "results.db"


def now() -> str:
    return time.strftime("%Y-%m-%d %H:%M:%S")


def connect() -> sqlite3.Connection:
    RUNS_DIR.mkdir(exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS runs (
            id              INTEGER PRIMARY KEY AUTOINCREMENT,
            status          TEXT,       -- running / finished / stopped / error
            started_at      TEXT,
            finished_at     TEXT,
            master_host     TEXT,
            master_device   TEXT,
            model           TEXT,
            mode            TEXT,
            dataset         TEXT,
            classes         TEXT,
            images_total    INTEGER,
            train_images    INTEGER,
            val_images      INTEGER,
            test_images     INTEGER,
            batch_size      INTEGER,
            rounds          INTEGER,
            local_epochs    INTEGER,
            lr              REAL,
            round_timeout   INTEGER,
            num_workers     INTEGER,
            best_val_acc    REAL,
            best_round      INTEGER,
            test_acc        REAL,
            test_loss       REAL,
            total_time_s    REAL,
            avg_round_s     REAL,
            summary_path    TEXT,
            error           TEXT
        )""")
    conn.execute("""
        CREATE TABLE IF NOT EXISTS rounds (
            run_id            INTEGER,
            round             INTEGER,
            val_loss          REAL,
            val_acc           REAL,
            time_s            REAL,
            workers_responded INTEGER,
            saved             INTEGER
        )""")
    conn.execute("""
        CREATE TABLE IF NOT EXISTS workers (
            run_id           INTEGER,
            worker_id        TEXT,
            train_images     INTEGER,
            rounds_responded INTEGER,
            cpu_avg          REAL,
            cpu_max          REAL,
            ram_used_max     REAL,
            ram_total        REAL,
            temp_max         REAL,
            samples          INTEGER
        )""")
    conn.commit()
    return conn


def start_run(info: dict) -> int:
    """info keys = column names of runs. Returns the new run id."""
    info = dict(info, status="running", started_at=now())
    cols = ", ".join(info.keys())
    marks = ", ".join("?" for _ in info)
    conn = connect()
    cur = conn.execute(f"INSERT INTO runs ({cols}) VALUES ({marks})", list(info.values()))
    conn.commit()
    run_id = cur.lastrowid
    conn.close()
    return run_id


def add_round(run_id: int, r: dict) -> None:
    conn = connect()
    conn.execute(
        "INSERT INTO rounds VALUES (?, ?, ?, ?, ?, ?, ?)",
        (run_id, r["round"], r["val_loss"], r["val_acc"], r["elapsed"],
         r["workers_responded"], 1 if r["saved"] else 0),
    )
    conn.commit()
    conn.close()


def save_workers(run_id: int, workers: dict) -> None:
    """workers = {worker_id: {train_images, rounds_responded, cpu: [..], ram_used: [..], ram_total, temp: [..]}}"""
    conn = connect()
    conn.execute("DELETE FROM workers WHERE run_id = ?", (run_id,))
    for wid, w in workers.items():
        cpu = [x for x in w.get("cpu", []) if x is not None]
        ram = [x for x in w.get("ram_used", []) if x is not None]
        temp = [x for x in w.get("temp", []) if x is not None]
        conn.execute(
            "INSERT INTO workers VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (run_id, wid, w.get("train_images"), w.get("rounds_responded", 0),
             round(sum(cpu) / len(cpu), 1) if cpu else None,
             max(cpu) if cpu else None,
             max(ram) if ram else None,
             w.get("ram_total"),
             max(temp) if temp else None,
             len(cpu)),
        )
    conn.commit()
    conn.close()


def finish_run(run_id: int, results: dict) -> None:
    results = dict(results, status="finished", finished_at=now())
    sets = ", ".join(f"{k} = ?" for k in results)
    conn = connect()
    conn.execute(f"UPDATE runs SET {sets} WHERE id = ?", list(results.values()) + [run_id])
    conn.commit()
    conn.close()


def end_run_if_running(run_id: int, status: str, error: str | None = None) -> None:
    """Mark a run stopped/error, only if it never finished."""
    conn = connect()
    conn.execute(
        "UPDATE runs SET status = ?, finished_at = ?, error = ? WHERE id = ? AND status = 'running'",
        (status, now(), error, run_id),
    )
    conn.commit()
    conn.close()
