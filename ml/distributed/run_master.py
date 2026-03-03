import argparse

import uvicorn

from .config import BATCH_SIZE, LOCAL_EPOCHS, LR, ROUNDS, default_device
from .master import create_app


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run SharedComputing master server.")
    parser.add_argument("--host", default="0.0.0.0", help="Master bind host.")
    parser.add_argument("--port", type=int, default=8000, help="Master bind port.")
    parser.add_argument(
        "--num-workers",
        type=int,
        required=True,
        help="Number of workers required before training starts.",
    )
    parser.add_argument("--rounds", type=int, default=ROUNDS, help="Global rounds.")
    parser.add_argument(
        "--dataset-root",
        default="ml/data",
        help="Local dataset path used by master for indexing/evaluation.",
    )
    parser.add_argument(
        "--checkpoint-dir",
        default="ml/distributed/checkpoints",
        help="Directory to save round checkpoints.",
    )
    parser.add_argument(
        "--device",
        default=default_device(),
        help="Device for master-side evaluation (cpu/mps/cuda).",
    )
    parser.add_argument(
        "--local-epochs",
        type=int,
        default=LOCAL_EPOCHS,
        help="Local epochs to tell workers per round.",
    )
    parser.add_argument(
        "--batch-size",
        type=int,
        default=BATCH_SIZE,
        help="Batch size to tell workers and use for evaluation.",
    )
    parser.add_argument("--lr", type=float, default=LR, help="Learning rate for workers.")
    parser.add_argument("--seed", type=int, default=42, help="Shuffle seed.")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    app = create_app(
        num_workers=args.num_workers,
        rounds=args.rounds,
        dataset_root=args.dataset_root,
        checkpoint_dir=args.checkpoint_dir,
        device=args.device,
        local_epochs=args.local_epochs,
        batch_size=args.batch_size,
        lr=args.lr,
        seed=args.seed,
    )
    uvicorn.run(app, host=args.host, port=args.port, log_level="info")


if __name__ == "__main__":
    main()

