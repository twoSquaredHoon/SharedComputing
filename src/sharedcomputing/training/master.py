import os
import ssl
import certifi

os.environ.setdefault("SSL_CERT_FILE", certifi.where())
ssl._create_default_https_context = ssl.create_default_context

import time
import threading
import curses
import torch
import torch.nn as nn
from torchvision import datasets, models
from torch.utils.data import DataLoader, Subset, random_split
from torchvision import transforms
from pathlib import Path

from sharedcomputing.core.paths import REPO_ROOT
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import uvicorn
import socket

# ── Arrow-key menu selector ───────────────────────────────────────────────────
# Force a known-good TERM so curses works in Ghostty, Terminal.app, iTerm2 etc.
if os.environ.get("TERM", "") not in ("xterm-256color", "xterm", "screen-256color"):
    os.environ["TERM"] = "xterm-256color"

def arrow_select(title, options, default=0):
    """
    options: list of (label, subtitle, enabled) tuples
    Returns index of selected option.
    Falls back to simple numbered input if terminal doesn't support curses.
    """
    def _menu(stdscr, options, default):
        curses.curs_set(0)
        curses.use_default_colors()
        curses.start_color()
        curses.init_pair(1, curses.COLOR_CYAN,  -1)   # selected
        curses.init_pair(2, curses.COLOR_WHITE, -1)   # normal
        curses.init_pair(3, 8, -1)                    # disabled (dark grey)
        idx = default
        while True:
            stdscr.clear()
            h, w = stdscr.getmaxyx()
            stdscr.addstr(0, 2, title, curses.A_BOLD)
            stdscr.addstr(1, 2, "arrow keys to move  Enter to select", curses.A_DIM)
            for i, (label, subtitle, enabled) in enumerate(options):
                y = i + 3
                if y >= h - 1:
                    break
                cursor = "> " if i == idx else "  "
                if i == idx:
                    attr = curses.color_pair(1) | curses.A_BOLD
                elif not enabled:
                    attr = curses.A_DIM
                else:
                    attr = curses.color_pair(2)
                line = f"{cursor}{label:<20} {subtitle}"
                stdscr.addstr(y, 2, line[:w-3], attr)
            stdscr.refresh()
            key = stdscr.getch()
            if key in (curses.KEY_UP, ord('k')) and idx > 0:
                idx -= 1
            elif key in (curses.KEY_DOWN, ord('j')) and idx < len(options) - 1:
                idx += 1
            elif key in (curses.KEY_ENTER, ord('\n'), ord('\r')):
                return idx
    try:
        return curses.wrapper(_menu, options, default)
    except Exception:
        # Fallback for non-interactive terminals (e.g. piped input from Swift app)
        print(f"\n  {title}")
        for i, (label, subtitle, enabled) in enumerate(options):
            status = "" if enabled else " (unavailable)"
            print(f"    {i+1}. {label}{status}")
        while True:
            raw = input(f"  Select (default: {default+1}): ").strip()
            if raw == "": return default
            if raw.isdigit() and 1 <= int(raw) <= len(options):
                return int(raw) - 1

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
BASE     = REPO_ROOT
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
    parser.add_argument("--mode",     type=str,   default=None,
                        choices=["quality", "speed"])
    parser.add_argument("--model",    type=str,   default=None,
                        choices=["resnet18", "resnet50", "efficientnet_b0", "efficientnet_b3", "vit"])
    args = parser.parse_args()

    # If all args provided (e.g. launched from Swift app), skip wizard
    if all(v is not None for v in vars(args).values()):
        dataset_dir = Path(args.dataset)
        if not dataset_dir.is_absolute():
            dataset_dir = BASE / dataset_dir
        return dataset_dir, args.rounds, args.epochs, args.batch, args.lr, args.timeout, args.mode, args.model

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

    # 1. Dataset folder
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

    # 2. Model selection
    AVAILABLE_MODELS = [
        ("resnet18",        "ResNet18",        True),
        ("resnet50",        "ResNet50",        True),
        ("efficientnet_b0", "EfficientNet-B0", False),
        ("efficientnet_b3", "EfficientNet-B3", False),
        ("vit",             "ViT",             False),
    ]

    if args.model:
        selected_model = args.model
        if selected_model not in ("resnet18", "resnet50"):
            print(f"  ⚠ {selected_model} is not yet available — using ResNet18.")
            selected_model = "resnet18"
    else:
        model_options = [
            (label, "✓ available" if available else "unavailable", available)
            for key, label, available in AVAILABLE_MODELS
        ]
        chosen = arrow_select("Model Architecture", model_options, default=0)
        key, label, available = AVAILABLE_MODELS[chosen]
        if not available:
            print(f"  ⚠ {label} is not yet available — using ResNet18.")
            selected_model = "resnet18"
        else:
            selected_model = key
        print(f"  Model: {label}")

    # 3. Mode selection
    if args.mode:
        mode = args.mode
    else:
        mode_options = [
            ("Quality", "each worker trains on full dataset — better accuracy", True),
            ("Speed",   "dataset divided between workers — faster rounds",      True),
        ]
        chosen = arrow_select("Training Mode", mode_options, default=0)
        mode = ["quality", "speed"][chosen]
        print(f"  Mode: {mode.capitalize()}")

    # 4. Hyperparameters
    print()
    rounds       = args.rounds   or prompt("Rounds",                  15,    int)
    local_epochs = args.epochs   or prompt("Local epochs per round",   2,    int)
    batch_size   = args.batch    or prompt("Batch size",               8,    int)
    lr           = args.lr       or prompt("Learning rate",            1e-3, float)
    timeout      = args.timeout  or prompt("Round timeout (seconds)", 120,   int)

    print()
    return dataset_dir, rounds, local_epochs, batch_size, lr, timeout, mode, selected_model

DATASET_DIR, ROUNDS, LOCAL_EPOCHS, BATCH_SIZE, LR, ROUND_TIMEOUT, TRAINING_MODE, SELECTED_MODEL = run_setup()
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

worker_metrics_store = {}  # {worker_id: {cpu, ram_used, ram_total, gpu, temp, timestamp}}

state = {
    "global_weights":     None,
    "start_event":        threading.Event(),
    "worker_updates":     {},
    "registered_workers": set(),
    "round":              0,
    "round_ready":        threading.Event(),
    "num_classes":        None,
    "classes":            None,
    "train_indices":      None,   # quality mode: full list sent to all workers
    "worker_index_map":   {},     # speed mode: {worker_id: [indices]}
    "worker_heartbeats":  {},     # {worker_id: last_ping_timestamp}
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

def dict_to_state(d, reference_state=None):
    result = {}
    for k, v in d.items():
        t = torch.tensor(v)
        if reference_state is not None and k in reference_state:
            t = t.to(dtype=reference_state[k].dtype)
        result[k] = t
    return result

def build_model(num_classes, model_name="resnet18", pretrained=False):
    if model_name == "resnet18":
        weights = models.ResNet18_Weights.DEFAULT if pretrained else None
        model = models.resnet18(weights=weights)
    elif model_name == "resnet50":
        weights = models.ResNet50_Weights.DEFAULT if pretrained else None
        model = models.resnet50(weights=weights)
    else:
        raise ValueError(f"Unsupported model: {model_name}")

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

def assign_split_indices(train_indices, worker_ids):
    """Divide train_indices evenly across workers for speed mode."""
    n = len(worker_ids)
    chunks = [train_indices[i::n] for i in range(n)]
    return {wid: chunk for wid, chunk in zip(worker_ids, chunks)}

# ── Routes ────────────────────────────────────────────────────────────────────
@app.post("/register")
def register(req: RegisterRequest):
    state["registered_workers"].add(req.worker_id)
    print(f"  ✓ Worker registered: {req.worker_id}  "
          f"(total: {len(state['registered_workers'])})")

    # For speed mode, indices are assigned after all workers connect (at training start).
    # For now send the full list — it will be overridden for speed mode once training begins.
    indices_for_worker = state["train_indices"] or []

    return {
        "status":        "ok",
        "num_classes":   state["num_classes"],
        "classes":       state["classes"],
        "rounds":        ROUNDS,
        "local_epochs":  LOCAL_EPOCHS,
        "batch_size":    BATCH_SIZE,
        "img_size":      IMG_SIZE,
        "lr":            LR,
        "mode":          TRAINING_MODE,
        "model":         SELECTED_MODEL,
        "train_indices": indices_for_worker,
    }

@app.get("/weights")
def get_weights():
    if state["global_weights"] is None:
        raise HTTPException(status_code=503, detail="Weights not ready yet")
    return {"round": state["round"], "weights": state["global_weights"], "done": state["round"] > ROUNDS}

# ── New endpoint: worker fetches its assigned indices for speed mode ───────────
@app.get("/my_indices/{worker_id}")
def get_my_indices(worker_id: str):
    if TRAINING_MODE == "quality":
        return {"train_indices": state["train_indices"]}
    indices = state["worker_index_map"].get(worker_id)
    if indices is None:
        raise HTTPException(status_code=404, detail="No indices assigned yet — wait for training to start")
    return {"train_indices": indices}

@app.post("/update")
def receive_update(update: WeightsUpdate):
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
        "mode":               TRAINING_MODE,
    }

@app.post("/worker_metrics")
def receive_worker_metrics(data: dict):
    worker_id = data.get("worker_id")
    if not worker_id:
        raise HTTPException(status_code=400, detail="worker_id required")
    now = time.time()
    data["timestamp"] = now
    worker_metrics_store[worker_id] = data
    # Reset heartbeat so master knows this worker is still alive
    state["worker_heartbeats"][worker_id] = now
    return {"status": "ok"}

@app.get("/workers/metrics")
def get_worker_metrics():
    now = time.time()
    result = {}
    for wid, m in worker_metrics_store.items():
        m["stale"] = (now - m.get("timestamp", 0)) > 10
        result[wid] = m
    return result

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

    state["train_indices"] = list(train_set.indices)

    eval_dataset = datasets.ImageFolder(str(DATASET_DIR), transform=val_transform)
    val_loader   = DataLoader(Subset(eval_dataset, list(val_set.indices)),
                              batch_size=BATCH_SIZE, shuffle=False, num_workers=0)
    test_loader  = DataLoader(Subset(eval_dataset, list(test_set.indices)),
                              batch_size=BATCH_SIZE, shuffle=False, num_workers=0)

    global_model = build_model(num_classes, model_name=SELECTED_MODEL, pretrained=True)
    global_model    = global_model.to(MASTER_DEVICE)

    print(f"\n{'='*55}")
    print(f"  NETWORK DISTRIBUTED TRAINING (MASTER)")
    print(f"{'='*55}")
    print(f"  Device        : {MASTER_DEVICE}")
    print(f"  Model         : {SELECTED_MODEL}")
    print(f"  Mode          : {TRAINING_MODE.upper()}")
    print(f"  Classes       : {full_dataset.classes}")
    print(f"  Dataset       : {total} images  (train={n_train} val={n_val} test={n_test})")
    print(f"  Rounds        : {ROUNDS}  ×  {LOCAL_EPOCHS} local epoch(s)")
    print(f"  Batch size    : {BATCH_SIZE}")
    print(f"  Learning rate : {LR}")
    print(f"  Round timeout : {ROUND_TIMEOUT}s")
    print(f"\n  Waiting for workers → http://{LOCAL_IP}:{MASTER_PORT}")
    print(f"  Workers run: python3 worker.py  (or: python3 scripts/run_worker.py)\n")

    try:
        input("  → Press Enter when all workers are connected...\n")
    except EOFError:
        pass

    num_workers   = len(state["registered_workers"])
    worker_ids    = sorted(state["registered_workers"])

    # ── Assign indices based on mode ──────────────────────────────────────────
    if TRAINING_MODE == "speed":
        state["worker_index_map"] = assign_split_indices(state["train_indices"], worker_ids)
        print(f"  Speed mode — dataset divided across {num_workers} worker(s):")
        for wid, idxs in state["worker_index_map"].items():
            print(f"    {wid}: {len(idxs)} images")
    else:
        print(f"  Quality mode — all {num_workers} worker(s) train on full dataset ({n_train} images)")

    print(f"\n  Starting training with {num_workers} worker(s)\n")

    CKPT_DIR.mkdir(exist_ok=True)
    best_val_acc = 0.0
    history      = []
    train_start  = time.time()

    reference_state = global_model.state_dict()

    for rnd in range(1, ROUNDS + 1):
        t0 = time.time()
        state["round"]          = rnd
        state["worker_updates"] = {}

        print(f"  Round {rnd}/{ROUNDS} — serializing weights...")
        state["global_weights"] = model_to_dict(global_model)
        state["round_ready"].clear()
        print(f"  Round {rnd}/{ROUNDS} — waiting for {num_workers} worker(s)...")

        # ── Heartbeat-aware wait ─────────────────────────────────────────
        # Instead of a fixed timeout, we keep waiting as long as workers
        # are sending heartbeats (metrics pings every 2s). We only give up
        # if a worker goes silent for longer than ROUND_TIMEOUT seconds.
        print(f"  Round {rnd}/{ROUNDS} — waiting (heartbeat-aware, silence timeout={ROUND_TIMEOUT}s)...")
        while True:
            # Check if all workers have submitted
            if state["round_ready"].is_set():
                break

            now = time.time()
            # Check if any active worker has gone silent
            active_workers = [
                wid for wid in state["registered_workers"]
                if wid not in state["worker_updates"]
            ]
            silent = [
                wid for wid in active_workers
                if now - state["worker_heartbeats"].get(wid, now) > ROUND_TIMEOUT
            ]
            if silent:
                print(f"  ⚠ Workers went silent: {silent} — proceeding with available updates.")
                break

            time.sleep(1)

        received = len(state["worker_updates"])
        if received == 0:
            print(f"  ✗ No updates received for round {rnd} — skipping aggregation.")
            continue
        elif received < num_workers:
            print(f"  ⚠ Only {received}/{num_workers} workers responded — aggregating partial results.")

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

    # Build per-worker index summary for speed mode
    split_info = ""
    if TRAINING_MODE == "speed":
        split_info = "\n## Data Split\n| Worker | Images |\n|--------|-------|\n"
        for wid, idxs in state["worker_index_map"].items():
            split_info += f"| {wid} | {len(idxs)} |\n"

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
| Architecture | {SELECTED_MODEL} (transfer learning, frozen backbone) |
| Training mode | {TRAINING_MODE} |
| Image size | {IMG_SIZE}×{IMG_SIZE} |
| Batch size | {BATCH_SIZE} |
| Rounds | {ROUNDS} |
| Local epochs per round | {LOCAL_EPOCHS} |
| Learning rate | {LR} |
| Aggregation | FedAvg |
| Round timeout | {ROUND_TIMEOUT}s |
{split_info}
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