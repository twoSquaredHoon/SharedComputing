import os
import random
import threading
import time
import uuid
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import torch
from fastapi import FastAPI, File, Form, HTTPException, Request, UploadFile
from fastapi.responses import Response

from .config import (
    BATCH_SIZE,
    LOCAL_EPOCHS,
    LR,
    ROUNDS,
    build_model,
    default_device,
    deserialize_state_dict,
    evaluate,
    serialize_state_dict,
    state_dict_to_cpu,
)


@dataclass
class WorkerRecord:
    worker_id: str
    worker_name: str
    registered_at: float


class MasterCoordinator:
    def __init__(
        self,
        required_workers: int,
        rounds: int,
        dataset_root: str,
        checkpoint_dir: str,
        device: str,
        local_epochs: int = LOCAL_EPOCHS,
        batch_size: int = BATCH_SIZE,
        lr: float = LR,
        seed: int = 42,
    ) -> None:
        self.required_workers = required_workers
        self.max_rounds = rounds
        self.dataset_root = dataset_root
        self.checkpoint_dir = checkpoint_dir
        self.device = device
        self.local_epochs = local_epochs
        self.batch_size = batch_size
        self.lr = lr
        self.rng = random.Random(seed)

        self.lock = threading.Lock()
        self.state = "WAITING"
        self.current_round = 0
        self.best_acc = -1.0
        self.history: list[dict[str, Any]] = []

        self.workers: dict[str, WorkerRecord] = {}
        self.worker_order: list[str] = []
        self.round_indices: dict[str, list[int]] = {}
        self.round_submissions: dict[str, dict[str, Any]] = {}

        Path(self.checkpoint_dir).mkdir(parents=True, exist_ok=True)
        self.train_indices = self._load_train_indices()
        self.global_state = state_dict_to_cpu(build_model(pretrained=True).state_dict())
        self._save_checkpoint("global_round_0.pt", self.global_state)

    def _load_train_indices(self) -> list[int]:
        # Import inside the method to keep module import lightweight for CLI help.
        from torchvision import datasets

        train_ds = datasets.CIFAR10(
            root=self.dataset_root,
            train=True,
            download=True,
            transform=None,
        )
        return list(range(len(train_ds)))

    def register_worker(self, worker_name: str) -> dict[str, Any]:
        with self.lock:
            if self.state != "WAITING":
                raise HTTPException(
                    status_code=409,
                    detail="registration_closed_after_training_start",
                )
            worker_id = str(uuid.uuid4())
            record = WorkerRecord(
                worker_id=worker_id,
                worker_name=worker_name,
                registered_at=time.time(),
            )
            self.workers[worker_id] = record
            self.worker_order.append(worker_id)

            if len(self.worker_order) == self.required_workers:
                self._start_next_round_locked()

        return {"worker_id": worker_id, "poll_interval_sec": 2}

    def task_for(self, worker_id: str, base_url: str) -> dict[str, Any]:
        with self.lock:
            self._assert_worker_registered_locked(worker_id)

            if self.state == "DONE":
                return {"action": "done", "round": self.current_round}
            if self.state == "WAITING":
                return {"action": "wait", "round": self.current_round}

            if worker_id in self.round_submissions:
                return {"action": "wait", "round": self.current_round}

            if worker_id not in self.round_indices:
                return {"action": "wait", "round": self.current_round}

            weights_url = f"{base_url.rstrip('/')}/weights/global?round={self.current_round}"
            return {
                "action": "train",
                "round": self.current_round,
                "indices": self.round_indices[worker_id],
                "weights_url": weights_url,
                "local_epochs": self.local_epochs,
                "batch_size": self.batch_size,
                "lr": self.lr,
            }

    def get_global_weights_blob(self, round_num: int) -> bytes:
        with self.lock:
            if round_num != self.current_round:
                raise HTTPException(
                    status_code=409,
                    detail=f"round_mismatch current_round={self.current_round}",
                )
            state = state_dict_to_cpu(self.global_state)
        return serialize_state_dict(state)

    def submit(
        self,
        worker_id: str,
        round_num: int,
        sample_count: int,
        train_seconds: float,
        weights_blob: bytes,
    ) -> dict[str, Any]:
        submitted_weights = deserialize_state_dict(weights_blob)

        with self.lock:
            self._assert_worker_registered_locked(worker_id)
            if self.state not in {"COLLECTING", "AGGREGATING"}:
                raise HTTPException(status_code=409, detail="not_accepting_submissions")
            if round_num != self.current_round:
                raise HTTPException(
                    status_code=409,
                    detail=f"round_mismatch current_round={self.current_round}",
                )
            if worker_id in self.round_submissions:
                raise HTTPException(status_code=409, detail="duplicate_submission")
            if worker_id not in self.round_indices:
                raise HTTPException(status_code=409, detail="worker_has_no_assignment")

            self.round_submissions[worker_id] = {
                "weights": submitted_weights,
                "sample_count": sample_count,
                "train_seconds": train_seconds,
            }
            received_count = len(self.round_submissions)

            if received_count == self.required_workers:
                self._aggregate_and_advance_locked()

            return {
                "accepted": True,
                "submissions_received": received_count,
            }

    def status(self) -> dict[str, Any]:
        with self.lock:
            return {
                "state": self.state,
                "round": self.current_round,
                "num_workers_registered": len(self.workers),
                "num_workers_required": self.required_workers,
                "submissions_received": len(self.round_submissions),
                "best_acc": self.best_acc if self.best_acc >= 0 else None,
                "history": list(self.history),
            }

    def _assert_worker_registered_locked(self, worker_id: str) -> None:
        if worker_id not in self.workers:
            raise HTTPException(status_code=404, detail="worker_not_registered")

    def _start_next_round_locked(self) -> None:
        if self.current_round >= self.max_rounds:
            self.state = "DONE"
            return

        self.state = "DISPATCHING"
        self.current_round += 1
        self.round_submissions = {}

        shuffled = list(self.train_indices)
        self.rng.shuffle(shuffled)

        chunks: list[list[int]] = []
        base = len(shuffled) // self.required_workers
        extra = len(shuffled) % self.required_workers
        start = 0
        for idx in range(self.required_workers):
            take = base + (1 if idx < extra else 0)
            end = start + take
            chunks.append(shuffled[start:end])
            start = end

        self.round_indices = {
            worker_id: chunks[idx] for idx, worker_id in enumerate(self.worker_order)
        }
        self.state = "COLLECTING"

    def _aggregate_and_advance_locked(self) -> None:
        self.state = "AGGREGATING"

        submissions = [self.round_submissions[wid] for wid in self.worker_order]
        sample_counts = [max(0, int(sub["sample_count"])) for sub in submissions]
        sample_total = sum(sample_counts)
        if sample_total <= 0:
            sample_counts = [1 for _ in submissions]
            sample_total = len(submissions)

        first_weights = submissions[0]["weights"]
        averaged: dict[str, torch.Tensor] = {}
        for key in first_weights:
            target_dtype = first_weights[key].dtype
            weighted = None
            for idx, sub in enumerate(submissions):
                part = sub["weights"][key].detach().cpu().float()
                ratio = sample_counts[idx] / sample_total
                contribution = part * ratio
                weighted = contribution if weighted is None else weighted + contribution
            if weighted is None:
                weighted = first_weights[key].detach().cpu().float()

            if target_dtype.is_floating_point:
                averaged[key] = weighted.to(dtype=target_dtype)
            else:
                averaged[key] = weighted.round().to(dtype=target_dtype)

        self.global_state = state_dict_to_cpu(averaged)
        metrics = evaluate(
            weights=self.global_state,
            dataset_root=self.dataset_root,
            device=self.device,
            batch_size=self.batch_size,
        )
        train_time = sum(float(sub["train_seconds"]) for sub in submissions)

        current_ckpt = f"global_round_{self.current_round}.pt"
        self._save_checkpoint(current_ckpt, self.global_state)

        improved = metrics["acc"] > self.best_acc
        if improved:
            self.best_acc = float(metrics["acc"])
            self._save_checkpoint("best_global.pt", self.global_state)

        self.history.append(
            {
                "round": self.current_round,
                "test_loss": round(float(metrics["loss"]), 6),
                "test_acc": round(float(metrics["acc"]), 6),
                "workers": self.required_workers,
                "train_seconds_sum": round(train_time, 3),
                "saved_best": improved,
            }
        )

        if self.current_round >= self.max_rounds:
            self.state = "DONE"
            return

        self._start_next_round_locked()

    def _save_checkpoint(
        self,
        filename: str,
        state_dict: dict[str, torch.Tensor],
    ) -> None:
        path = os.path.join(self.checkpoint_dir, filename)
        torch.save(state_dict_to_cpu(state_dict), path)


def create_app(
    num_workers: int,
    rounds: int = ROUNDS,
    dataset_root: str = "ml/data",
    checkpoint_dir: str = "ml/distributed/checkpoints",
    device: str | None = None,
    local_epochs: int = LOCAL_EPOCHS,
    batch_size: int = BATCH_SIZE,
    lr: float = LR,
    seed: int = 42,
) -> FastAPI:
    coordinator = MasterCoordinator(
        required_workers=num_workers,
        rounds=rounds,
        dataset_root=dataset_root,
        checkpoint_dir=checkpoint_dir,
        device=device or default_device(),
        local_epochs=local_epochs,
        batch_size=batch_size,
        lr=lr,
        seed=seed,
    )

    app = FastAPI(title="SharedComputing Master Server")

    @app.post("/register")
    def register(payload: dict[str, str]) -> dict[str, Any]:
        worker_name = payload.get("worker_name", "").strip()
        if not worker_name:
            raise HTTPException(status_code=400, detail="worker_name_is_required")
        return coordinator.register_worker(worker_name=worker_name)

    @app.get("/task/{worker_id}")
    def task(worker_id: str, request: Request) -> dict[str, Any]:
        return coordinator.task_for(worker_id=worker_id, base_url=str(request.base_url))

    @app.get("/weights/global")
    def weights_global(round: int) -> Response:  # noqa: A002
        blob = coordinator.get_global_weights_blob(round_num=round)
        return Response(content=blob, media_type="application/octet-stream")

    @app.post("/submit/{worker_id}")
    async def submit(
        worker_id: str,
        round: int = Form(...),  # noqa: A002
        sample_count: int = Form(...),
        train_seconds: float = Form(...),
        weights_file: UploadFile = File(...),
    ) -> dict[str, Any]:
        blob = await weights_file.read()
        return coordinator.submit(
            worker_id=worker_id,
            round_num=round,
            sample_count=sample_count,
            train_seconds=train_seconds,
            weights_blob=blob,
        )

    @app.get("/status")
    def status() -> dict[str, Any]:
        return coordinator.status()

    return app
