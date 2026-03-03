import argparse

from .config import default_device
from .worker import WorkerClient


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run SharedComputing worker client.")
    parser.add_argument(
        "--master-url",
        required=True,
        help="Master URL, for example http://192.168.1.100:8000",
    )
    parser.add_argument("--name", required=True, help="Worker display name.")
    parser.add_argument(
        "--dataset-root",
        default="ml/data",
        help="Local dataset path used for worker training.",
    )
    parser.add_argument(
        "--device",
        default=default_device(),
        help="Device for local training (cpu/mps/cuda).",
    )
    parser.add_argument(
        "--poll-interval",
        type=float,
        default=2.0,
        help="Polling interval in seconds when no task is assigned.",
    )
    parser.add_argument(
        "--request-timeout",
        type=int,
        default=120,
        help="HTTP timeout in seconds for task/weights calls.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    client = WorkerClient(
        master_url=args.master_url,
        worker_name=args.name,
        dataset_root=args.dataset_root,
        device=args.device,
        poll_interval=args.poll_interval,
        request_timeout=args.request_timeout,
    )
    client.run()


if __name__ == "__main__":
    main()

