import os
import ssl
import certifi

os.environ.setdefault("SSL_CERT_FILE", certifi.where())
ssl._create_default_https_context = ssl.create_default_context

import io
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
import numpy as np
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
BASE        = Path(__file__).parent
DATASET_DIR = BASE / "data"
CKPT_DIR    = BASE / "models"
CKPT_PATH   = CKPT_DIR / "best_model_net.pth"
SUMMARY     = BASE / "summary_net.md"

# ── Config ────────────────────────────────────────────────────────────────────
IMG_SIZE     = 224
BATCH_SIZE   = 8
ROUNDS       = 15
LOCAL_EPOCHS = 2
LR           = 1e-3
SEED         = 42
MASTER_HOST  = "0.0.0.0"
MASTER_PORT  = 8000

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
    "global_weights": None,      # current global model weights (serialized)
    "worker_updates": {},         # worker_id -> updated weights
    "registered_workers": set(),  # worker IDs that have registered
    "round": 0,
    "rounds_total": ROUNDS,
    "round_ready": threading.Event(),
    "num_classes": None,
    "classes": None,
}

# ── Pydantic models ───────────────────────────────────────────────────────────
class RegisterRequest(BaseModel):
    worker_id: str

class WeightsUpdate(BaseModel):
    worker_id: str
    weights: dict  # key -> list (tensor serialized as nested list)

# ── Helpers ───────────────────────────────────────────────────────────────────
def model_to_dict(model):
    return {k: v.cpu().tolist() for k, v in model.state_dict().items()}

def dict_to_state(d):
    return {k: torch.tensor(v) for k, v in d.items()}

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
        "status": "ok",
        "num_classes": state["num_classes"],
        "classes": state["classes"],
        "rounds": ROUNDS,
        "local_epochs": LOCAL_EPOCHS,
        "batch_size": BATCH_SIZE,
        "img_size": IMG_SIZE,
        "lr": LR,
    }

@app.get("/weights")
def get_weights():
    if state["global_weights"] is None:
        raise HTTPException(status_code=503, detail="Weights not ready yet")
    return {"round": state["round"], "weights": state["global_weights"]}

@app.post("/update")
def receive_update(update: WeightsUpdate):
    state["worker_updates"][update.worker_id] = update.weights
    print(f"  ← Received update from {update.worker_id}  "
          f"({len(state['worker_updates'])}/{len(state['registered_workers'])} workers done)")
    if len(state["worker_updates"]) >= len(state["registered_workers"]):
        state["round_ready"].set()
    return {"status": "ok"}

@app.get("/status")
def status():
    return {
        "round": state["round"],
        "rounds_total": ROUNDS,
        "registered_workers": list(state["registered_workers"]),
        "updates_received": list(state["worker_updates"].keys()),
    }

# ── Training orchestration (runs in background thread) ────────────────────────
def run_master():
    torch.manual_seed(SEED)

    full_dataset = datasets.ImageFolder(str(DATASET_DIR))
    num_classes  = len(full_dataset.classes)
    state["num_classes"] = num_classes
    state["classes"]     = full_dataset.classes

    total   = len(full_dataset)
    n_train = int(0.70 * total)
    n_val   = int(0.15 * total)
    n_test  = total - n_train - n_val

    _, val_set, test_set = random_split(
        full_dataset, [n_train, n_val, n_test],
        generator=torch.Generator().manual_seed(SEED)
    )

    eval_dataset = datasets.ImageFolder(str(DATASET_DIR), transform=val_transform)
    val_loader   = DataLoader(Subset(eval_dataset, list(val_set.indices)),
                              batch_size=BATCH_SIZE, shuffle=False, num_workers=0)
    test_loader  = DataLoader(Subset(eval_dataset, list(test_set.indices)),
                              batch_size=BATCH_SIZE, shuffle=False, num_workers=0)

    # Global model — download pretrained weights once
    global_model = models.resnet18(weights=models.ResNet18_Weights.DEFAULT)
    for param in global_model.parameters():
        param.requires_grad = False
    global_model.fc = nn.Linear(global_model.fc.in_features, num_classes)
    global_model    = global_model.to(MASTER_DEVICE)

    print(f"\n{'='*55}")
    print(f"  NETWORK DISTRIBUTED TRAINING (MASTER)")
    print(f"{'='*55}")
    print(f"  Device   : {MASTER_DEVICE}")
    print(f"  Classes  : {full_dataset.classes}")
    print(f"  Dataset  : {total} images")
    print(f"  Rounds   : {ROUNDS}  ×  {LOCAL_EPOCHS} local epoch(s)")
    print(f"\n  Waiting for workers to connect at http://{LOCAL_IP}:{MASTER_PORT}")
    print(f"  Workers can join by running: python3 worker.py")
    print(f"  Press Ctrl+C to start training once workers are ready.\n")

    # Wait for user to signal workers are connected
    try:
        input("  → Press Enter when all workers are connected...\n")
    except EOFError:
        pass

    print(f"  Starting training with {len(state['registered_workers'])} worker(s)\n")

    CKPT_DIR.mkdir(exist_ok=True)  # creates models/ if it doesn't exist
    best_val_acc = 0.0
    history      = []
    train_start  = time.time()

    for rnd in range(1, ROUNDS + 1):
        t0 = time.time()
        state["round"]         = rnd
        state["worker_updates"] = {}
        state["round_ready"].clear()

        # Broadcast current weights (workers will poll /weights)
        state["global_weights"] = model_to_dict(global_model)

        print(f"  Round {rnd}/{ROUNDS} — waiting for {len(state['registered_workers'])} worker(s)...")

        # Wait until all workers have submitted updates
        state["round_ready"].wait()

        # FedAvg
        worker_states = [dict_to_state(w) for w in state["worker_updates"].values()]
        avg_state = {
            key: torch.stack([ws[key].float() for ws in worker_states]).mean(dim=0)
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
                            elapsed=elapsed, saved=saved))

        print(f"  Round {rnd:>3}/{ROUNDS}  "
              f"val_loss={val_loss:.4f}  val_acc={val_acc:.3f}  "
              f"({elapsed:.1f}s){'  ← saved' if saved else ''}")

    total_time = time.time() - train_start

    global_model.load_state_dict(torch.load(CKPT_PATH, map_location=MASTER_DEVICE))
    test_loss, test_acc = evaluate(global_model, test_loader)

    print(f"\n  Test  loss={test_loss:.4f}  acc={test_acc:.3f}")
    print(f"  Saved → {CKPT_PATH}\n")

    best = max(history, key=lambda r: r["val_acc"])
    rows = "\n".join(
        f"| {r['round']:>5} | {r['val_loss']:.4f} | {r['val_acc']:.3f} "
        f"| {r['elapsed']:.1f}s | {'✓' if r['saved'] else ''} |"
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
| Dataset | {total} images |
| Classes | {full_dataset.classes} |

## Results
| Metric | Value |
|--------|-------|
| Best val accuracy | {best['val_acc']:.3f} (round {best['round']}) |
| Test accuracy | {test_acc:.3f} |
| Total training time | {total_time:.1f}s |

## Per-round log
| Round | Val Loss | Val Acc | Time | Saved |
|------:|---------:|--------:|-----:|:-----:|
{rows}
""")
    print(f"  Summary → {SUMMARY}")


if __name__ == "__main__":
    # Start training loop in background thread
    t = threading.Thread(target=run_master, daemon=True)
    t.start()
    # Start FastAPI server
    uvicorn.run(app, host=MASTER_HOST, port=MASTER_PORT)
