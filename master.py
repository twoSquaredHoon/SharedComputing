import os
import ssl
import certifi

os.environ.setdefault("SSL_CERT_FILE", certifi.where())
ssl._create_default_https_context = ssl.create_default_context

import time
import threading
import torch
import torch.nn as nn
from torchvision import datasets, models
from torch.utils.data import DataLoader, Subset, random_split
from torchvision import transforms
from pathlib import Path
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import uvicorn
import socket

def get_local_ip():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "localhost"

LOCAL_IP = get_local_ip()

# ── Paths ─────────────────────────────────────────────────────────────────────
BASE     = Path(__file__).parent
CKPT_DIR = BASE / "models"
SUMMARY  = BASE / "summary_net.md"

# ── Fixed settings ─────────────────────────────────────────────────────────────
IMG_SIZE    = 224
SEED        = 42
TRAIN_SPLIT = 0.70
VAL_SPLIT   = 0.15
MASTER_HOST = "0.0.0.0"
MASTER_PORT = 8000

# ── Argument parsing (supports both CLI args and interactive wizard) ───────────
import argparse

def run_setup():
    parser = argparse.ArgumentParser(description="SharedComputing Master Node")
    parser.add_argument("--dataset",  type=str,   default=None)
    parser.add_argument("--rounds",   type=int,   default=None)
    parser.add_argument("--epochs",   type=int,   default=None)
    parser.add_argument("--batch",    type=int,   default=None)
    parser.add_argument("--lr",       type=float, default=None)
    parser.add_argument("--timeout",  type=int,   default=None)
    args = parser.parse_args()

    # If all args provided (e.g. launched from Swift app), skip wizard
    if all(v is not None for v in vars(args).values()):
        dataset_dir = Path(args.dataset)
        if not dataset_dir.is_absolute():
            dataset_dir = BASE / dataset_dir
        return dataset_dir, args.rounds, args.epochs, args.batch, args.lr, args.timeout

    # Otherwise run interactive wizard for any missing values
    print(f"\n{'='*55}")
    print(f"  FEDERATED TRAINING — SETUP")
    print(f"{'='*55}")
    print(f"  Press Enter to accept defaults.\n")

    def prompt(label, default, cast=str):
        raw = input(f"  {label} (default: {default}): ").strip()
        if raw == "": return cast(default)
        try: return cast(raw)
        except ValueError:
            print(f"  ⚠ Invalid input, using default: {default}")
            return cast(default)

    if args.dataset:
        dataset_dir = Path(args.dataset)
    else:
        while True:
            raw = input(f"  Dataset folder (default: ./data): ").strip()
            dataset_dir = Path(raw) if raw else BASE / "data"
            if not dataset_dir.is_absolute():
                dataset_dir = BASE / dataset_dir
            if dataset_dir.exists(): break
            print(f"  ⚠ Folder not found: {dataset_dir}  — please try again.")

    rounds       = args.rounds   or prompt("Rounds",                  15,    int)
    local_epochs = args.epochs   or prompt("Local epochs per round",   2,    int)
    batch_size   = args.batch    or prompt("Batch size",               8,    int)
    lr           = args.lr       or prompt("Learning rate",            1e-3, float)
    timeout      = args.timeout  or prompt("Round timeout (seconds)", 120,   int)
    print()
    return dataset_dir, rounds, local_epochs, batch_size, lr, timeout

DATASET_DIR, ROUNDS, LOCAL_EPOCHS, BATCH_SIZE, LR, ROUND_TIMEOUT = run_setup()
CKPT_PATH = CKPT_DIR / "best_model_net.pth"

MASTER_DEVICE = (
    "mps"  if torch.backends.mps.is_available() else
    "cuda" if torch.cuda.is_available() else
    "cpu"
)

val_transform = transforms.Compose([
    transforms.Resize((IMG_SIZE, IMG_SIZE)),
    transforms.ToTensor(),
    transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
])

# ── App state ─────────────────────────────────────────────────────────────────
app = FastAPI()

state = {
    "global_weights":     None,
    "start_event":        threading.Event(),
    "worker_updates":     {},
    "registered_workers": set(),
    "round":              0,
    "round_ready":        threading.Event(),
    "num_classes":        None,
    "classes":            None,
    "train_indices":      None,
    "config":             {"rounds": ROUNDS},
}

# ── Pydantic models ───────────────────────────────────────────────────────────
class RegisterRequest(BaseModel):
    worker_id: str

class WeightsUpdate(BaseModel):
    worker_id: str
    weights: dict

# ── Helpers ───────────────────────────────────────────────────────────────────
def model_to_dict(model):
    return {k: v.cpu().tolist() for k, v in model.state_dict().items()}

# FIX: preserve original tensor dtypes to avoid crash on integer buffers
# (e.g. ResNet18's num_batches_tracked is a LongTensor, not float)
def dict_to_state(d, reference_state=None):
    result = {}
    for k, v in d.items():
        t = torch.tensor(v)
        if reference_state is not None and k in reference_state:
            t = t.to(dtype=reference_state[k].dtype)
        result[k] = t
    return result

def build_model(num_classes):
    model = models.resnet18(weights=None)
    for param in model.parameters():
        param.requires_grad = False
    model.fc = nn.Linear(model.fc.in_features, num_classes)
    return model

def evaluate(model, loader):
    criterion = nn.CrossEntropyLoss()
    model.eval()
    total_loss, correct = 0.0, 0
    with torch.no_grad():
        for imgs, labels in loader:
            imgs, labels = imgs.to(MASTER_DEVICE), labels.to(MASTER_DEVICE)
            outputs     = model(imgs)
            total_loss += criterion(outputs, labels).item() * imgs.size(0)
            correct    += (outputs.argmax(1) == labels).sum().item()
    n = len(loader.dataset)
    return total_loss / n, correct / n

# ── Routes ────────────────────────────────────────────────────────────────────
@app.post("/register")
def register(req: RegisterRequest):
    state["registered_workers"].add(req.worker_id)
    print(f"  ✓ Worker registered: {req.worker_id}  "
          f"(total: {len(state['registered_workers'])})")
    return {
        "status":        "ok",
        "num_classes":   state["num_classes"],
        "classes":       state["classes"],
        "rounds":        ROUNDS,
        "local_epochs":  LOCAL_EPOCHS,
        "batch_size":    BATCH_SIZE,
        "img_size":      IMG_SIZE,
        "lr":            LR,
        # FIX: send the canonical train indices so all workers use the same split
        "train_indices": state["train_indices"],
    }

@app.get("/weights")
def get_weights():
    if state["global_weights"] is None:
        raise HTTPException(status_code=503, detail="Weights not ready yet")
    return {"round": state["round"], "weights": state["global_weights"], "done": state["round"] > ROUNDS}

@app.post("/update")
def receive_update(update: WeightsUpdate):
    # FIX: ignore duplicate or late submissions from the same worker
    if update.worker_id not in state["registered_workers"]:
        raise HTTPException(status_code=400, detail="Unknown worker — register first")
    if update.worker_id in state["worker_updates"]:
        print(f"  ⚠ Duplicate update ignored from {update.worker_id}")
        return {"status": "duplicate_ignored"}

    state["worker_updates"][update.worker_id] = update.weights
    print(f"  ← Received update from {update.worker_id}  "
          f"({len(state['worker_updates'])}/{len(state['registered_workers'])} workers done)")
    if len(state["worker_updates"]) >= len(state["registered_workers"]):
        state["round_ready"].set()
    return {"status": "ok"}

@app.post("/start")
def start_training():
    state["start_event"].set()
    return {"status": "ok"}

@app.get("/status")
def status():
    return {
        "round":              state["round"],
        "rounds_total":       state["config"]["rounds"],
        "registered_workers": list(state["registered_workers"]),
        "updates_received":   list(state["worker_updates"].keys()),
    }

# ── Training orchestration ────────────────────────────────────────────────────
def run_master():
    torch.manual_seed(SEED)

    full_dataset = datasets.ImageFolder(str(DATASET_DIR))
    num_classes  = len(full_dataset.classes)
    state["num_classes"] = num_classes
    state["classes"]     = full_dataset.classes

    total   = len(full_dataset)
    n_train = int(TRAIN_SPLIT * total)
    n_val   = int(VAL_SPLIT * total)
    n_test  = total - n_train - n_val

    train_set, val_set, test_set = random_split(
        full_dataset, [n_train, n_val, n_test],
        generator=torch.Generator().manual_seed(SEED)
    )

    # FIX: publish the exact train indices so workers use the same split
    state["train_indices"] = list(train_set.indices)

    eval_dataset = datasets.ImageFolder(str(DATASET_DIR), transform=val_transform)
    val_loader   = DataLoader(Subset(eval_dataset, list(val_set.indices)),
                              batch_size=BATCH_SIZE, shuffle=False, num_workers=0)
    test_loader  = DataLoader(Subset(eval_dataset, list(test_set.indices)),
                              batch_size=BATCH_SIZE, shuffle=False, num_workers=0)

    global_model = models.resnet18(weights=models.ResNet18_Weights.DEFAULT)
    for param in global_model.parameters():
        param.requires_grad = False
    global_model.fc = nn.Linear(global_model.fc.in_features, num_classes)
    global_model    = global_model.to(MASTER_DEVICE)

    print(f"\n{'='*55}")
    print(f"  NETWORK DISTRIBUTED TRAINING (MASTER)")
    print(f"{'='*55}")
    print(f"  Device        : {MASTER_DEVICE}")
    print(f"  Classes       : {full_dataset.classes}")
    print(f"  Dataset       : {total} images  (train={n_train} val={n_val} test={n_test})")
    print(f"  Rounds        : {ROUNDS}  ×  {LOCAL_EPOCHS} local epoch(s)")
    print(f"  Batch size    : {BATCH_SIZE}")
    print(f"  Learning rate : {LR}")
    print(f"  Round timeout : {ROUND_TIMEOUT}s")
    print(f"\n  Waiting for workers → http://{LOCAL_IP}:{MASTER_PORT}")
    print(f"  Workers run: python3 worker.py\n")

    try:
        input("  → Press Enter when all workers are connected...\n")
    except EOFError:
        pass

    num_workers = len(state["registered_workers"])
    print(f"  Starting training with {num_workers} worker(s)\n")

    CKPT_DIR.mkdir(exist_ok=True)
    best_val_acc = 0.0
    history      = []
    train_start  = time.time()

    reference_state = global_model.state_dict()  # used for dtype restoration

    for rnd in range(1, ROUNDS + 1):
        t0 = time.time()
        state["round"]          = rnd
        state["worker_updates"] = {}

        # serialize weights BEFORE clearing event so timeout starts after
        # weights are actually available to workers
        print(f"  Round {rnd}/{ROUNDS} — serializing weights...")
        state["global_weights"] = model_to_dict(global_model)
        state["round_ready"].clear()
        print(f"  Round {rnd}/{ROUNDS} — waiting for {num_workers} worker(s)...")

        finished = state["round_ready"].wait(timeout=ROUND_TIMEOUT)
        if not finished:
            received = len(state["worker_updates"])
            print(f"  ⚠ Timeout! Only {received}/{num_workers} workers responded. "
                  f"Aggregating with available updates...")
            if received == 0:
                print(f"  ✗ No updates received for round {rnd} — skipping aggregation.")
                continue

        # FIX: pass reference_state so integer buffers keep their correct dtype
        worker_states = [
            dict_to_state(w, reference_state)
            for w in state["worker_updates"].values()
        ]
        avg_state = {
            key: torch.stack([ws[key].float() for ws in worker_states]).mean(dim=0).to(
                dtype=reference_state[key].dtype
            )
            for key in worker_states[0]
        }
        global_model.load_state_dict(avg_state)

        val_loss, val_acc = evaluate(global_model, val_loader)
        elapsed = time.time() - t0

        saved = val_acc > best_val_acc
        if saved:
            best_val_acc = val_acc
            torch.save(global_model.state_dict(), CKPT_PATH)

        history.append(dict(round=rnd, val_loss=val_loss, val_acc=val_acc,
                            elapsed=elapsed, saved=saved,
                            workers_responded=len(state["worker_updates"])))

        print(f"  Round {rnd:>3}/{ROUNDS}  "
              f"val_loss={val_loss:.4f}  val_acc={val_acc:.3f}  "
              f"({elapsed:.1f}s){'  ← saved' if saved else ''}")

    total_time = time.time() - train_start

    global_model.load_state_dict(
        torch.load(CKPT_PATH, map_location=MASTER_DEVICE, weights_only=True)
    )
    test_loss, test_acc = evaluate(global_model, test_loader)

    print(f"\n  Test  loss={test_loss:.4f}  acc={test_acc:.3f}")
    print(f"  Saved → {CKPT_PATH}\n")

    best = max(history, key=lambda r: r["val_acc"])
    rows = "\n".join(
        f"| {r['round']:>5} | {r['val_loss']:.4f} | {r['val_acc']:.3f} "
        f"| {r['elapsed']:.1f}s | {r['workers_responded']}/{num_workers} "
        f"| {'✓' if r['saved'] else ''} |"
        for r in history
    )
    with open(SUMMARY, "w") as f:
        f.write(f"""# Training Summary — Network Distributed

## Run info
| | |
|--|--|
| Date | {time.strftime('%Y-%m-%d %H:%M:%S')} |
| Master | {LOCAL_IP}:{MASTER_PORT} |
| Workers | {list(state['registered_workers'])} |
| Dataset | {total} images (train={n_train}, val={n_val}, test={n_test}) |
| Classes | {full_dataset.classes} |

## Hyperparameters
| Param | Value |
|-------|-------|
| Architecture | ResNet18 (transfer learning, frozen backbone) |
| Image size | {IMG_SIZE}×{IMG_SIZE} |
| Batch size | {BATCH_SIZE} |
| Rounds | {ROUNDS} |
| Local epochs per round | {LOCAL_EPOCHS} |
| Learning rate | {LR} |
| Aggregation | FedAvg |
| Round timeout | {ROUND_TIMEOUT}s |

## Results
| Metric | Value |
|--------|-------|
| Best val accuracy | {best['val_acc']:.3f} (round {best['round']}) |
| Test accuracy | {test_acc:.3f} |
| Total training time | {total_time:.1f}s |

## Per-round log
| Round | Val Loss | Val Acc | Time | Workers | Saved |
|------:|---------:|--------:|-----:|--------:|:-----:|
{rows}
""")
    print(f"  Summary → {SUMMARY}")


if __name__ == "__main__":
    t = threading.Thread(target=run_master, daemon=True)
    t.start()
    uvicorn.run(app, host=MASTER_HOST, port=MASTER_PORT)