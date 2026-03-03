import time
from typing import Any

import requests

from .config import (
    BATCH_SIZE,
    LOCAL_EPOCHS,
    LR,
    default_device,
    deserialize_state_dict,
    serialize_state_dict,
    train_on_subset,
)


class WorkerClient:
    def __init__(
        self,
        master_url: str,
        worker_name: str,
        dataset_root: str = "ml/data",
        device: str | None = None,
        poll_interval: float = 2.0,
        request_timeout: int = 120,
    ) -> None:
        self.master_url = master_url.rstrip("/")
        self.worker_name = worker_name
        self.dataset_root = dataset_root
        self.device = device or default_device()
        self.poll_interval = poll_interval
        self.request_timeout = request_timeout
        self.worker_id: str | None = None

    def register(self) -> str:
        response = requests.post(
            f"{self.master_url}/register",
            json={"worker_name": self.worker_name},
            timeout=self.request_timeout,
        )
        response.raise_for_status()
        data = response.json()
        self.worker_id = data["worker_id"]
        self.poll_interval = float(data.get("poll_interval_sec", self.poll_interval))
        print(
            f"[worker:{self.worker_name}] registered worker_id={self.worker_id} "
            f"poll_interval={self.poll_interval}s device={self.device}"
        )
        return self.worker_id

    def run(self) -> None:
        if self.worker_id is None:
            self.register()

        assert self.worker_id is not None

        while True:
            task = self._fetch_task()
            if task is None:
                time.sleep(self.poll_interval)
                continue

            action = task.get("action")
            if action == "wait":
                time.sleep(self.poll_interval)
                continue
            if action == "done":
                print(f"[worker:{self.worker_name}] done at round={task.get('round')}")
                return
            if action != "train":
                print(f"[worker:{self.worker_name}] unknown action={action}, waiting...")
                time.sleep(self.poll_interval)
                continue

            self._train_and_submit(task)

    def _fetch_task(self) -> dict[str, Any] | None:
        assert self.worker_id is not None
        try:
            response = requests.get(
                f"{self.master_url}/task/{self.worker_id}",
                timeout=self.request_timeout,
            )
            response.raise_for_status()
            return response.json()
        except requests.RequestException as exc:
            print(f"[worker:{self.worker_name}] task poll failed: {exc}")
            return None

    def _train_and_submit(self, task: dict[str, Any]) -> None:
        round_num = int(task["round"])
        indices = list(task["indices"])
        local_epochs = int(task.get("local_epochs", LOCAL_EPOCHS))
        batch_size = int(task.get("batch_size", BATCH_SIZE))
        lr = float(task.get("lr", LR))
        weights_url = task["weights_url"]

        print(
            f"[worker:{self.worker_name}] round={round_num} "
            f"received {len(indices)} samples"
        )

        try:
            weights_resp = requests.get(weights_url, timeout=self.request_timeout)
            weights_resp.raise_for_status()
            init_weights = deserialize_state_dict(weights_resp.content)
        except requests.RequestException as exc:
            print(f"[worker:{self.worker_name}] failed to download weights: {exc}")
            time.sleep(self.poll_interval)
            return

        trained_weights, sample_count, train_seconds = train_on_subset(
            indices=indices,
            dataset_root=self.dataset_root,
            init_weights=init_weights,
            device=self.device,
            local_epochs=local_epochs,
            batch_size=batch_size,
            lr=lr,
        )

        payload = {
            "round": str(round_num),
            "sample_count": str(sample_count),
            "train_seconds": f"{train_seconds:.6f}",
        }
        file_bytes = serialize_state_dict(trained_weights)
        files = {
            "weights_file": ("weights.pt", file_bytes, "application/octet-stream"),
        }
        submit_url = f"{self.master_url}/submit/{self.worker_id}"

        for attempt in range(1, 4):
            try:
                response = requests.post(
                    submit_url,
                    data=payload,
                    files=files,
                    timeout=max(self.request_timeout, 300),
                )
                if response.status_code == 409:
                    print(
                        f"[worker:{self.worker_name}] submit rejected "
                        f"(round mismatch or duplicate): {response.text}"
                    )
                    return
                response.raise_for_status()
                print(
                    f"[worker:{self.worker_name}] round={round_num} submitted "
                    f"(samples={sample_count}, train_seconds={train_seconds:.2f})"
                )
                return
            except requests.RequestException as exc:
                print(
                    f"[worker:{self.worker_name}] submit attempt={attempt} failed: {exc}"
                )
                time.sleep(self.poll_interval)

