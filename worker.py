import os
import ssl
import certifi

os.environ.setdefault("SSL_CERT_FILE", certifi.where())
ssl._create_default_https_context = ssl.create_default_context

import time
import threading
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader, Subset
from torchvision import datasets, transforms, models
from pathlib import Path
import requests
import socket
import psutil

# ── Config ────────────────────────────────────────────────────────────────────
master_ip   = input("  Enter master IP address: ").strip()
MASTER_URL  = f"http://{master_ip}:8000"
WORKER_ID   = socket.gethostname()
DATASET_DIR = Path(__file__).parent / "data"
SEED        = 42

UPLOAD_RETRIES    = 5
UPLOAD_RETRY_DELAY = 3

DEVICE = (
    "mps"  if torch.backends.mps.is_available() else
    "cuda" if torch.cuda.is_available() else
    "cpu"
)

def build_model(num_classes):
    model = models.resnet18(weights=None)
    for param in model.parameters():
        param.requires_grad = False
    model.fc = nn.Linear(model.fc.in_features, num_classes)
    return model

def dict_to_state(d, reference_state=None):
    result = {}
    for k, v in d.items():
        t = torch.tensor(v)
        if reference_state is not None and k in reference_state:
            t = t.to(dtype=reference_state[k].dtype)
        result[k] = t
    return result

def model_to_dict(model):
    return {k: v.cpu().tolist() for k, v in model.state_dict().items()}

def get_train_loader(train_indices, batch_size, img_size):
    train_transform = transforms.Compose([
        transforms.Resize((img_size, img_size)),
        transforms.RandomHorizontalFlip(),
        transforms.RandomRotation(15),
        transforms.ColorJitter(brightness=0.3, contrast=0.3, saturation=0.2),
        transforms.ToTensor(),
        transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
    ])
    dataset = datasets.ImageFolder(str(DATASET_DIR), transform=train_transform)
    return DataLoader(Subset(dataset, train_indices),
                      batch_size=batch_size, shuffle=True, num_workers=0)

def fetch_my_indices():
    """For split mode: fetch this worker's assigned indices from master."""
    while True:
        try:
            r = requests.get(f"{MASTER_URL}/my_indices/{WORKER_ID}", timeout=10)
            if r.status_code == 200:
                return r.json()["train_indices"]
            # 404 means indices not assigned yet — wait for training to start
        except Exception as e:
            print(f"  ⚠ Could not fetch indices: {e}")
        time.sleep(2)

def upload_weights_with_retry(worker_id, weights):
    for attempt in range(1, UPLOAD_RETRIES + 1):
        try:
            resp = requests.post(f"{MASTER_URL}/update", json={
                "worker_id": worker_id,
                "weights":   weights,
            }, timeout=30)
            resp.raise_for_status()
            return True
        except Exception as e:
            print(f"  ⚠ Upload attempt {attempt}/{UPLOAD_RETRIES} failed: {e}")
            if attempt < UPLOAD_RETRIES:
                time.sleep(UPLOAD_RETRY_DELAY)
    print("  ✗ All upload attempts failed — master may have timed out this round.")
    return False

def collect_metrics():
    cpu = psutil.cpu_percent(interval=0)
    mem = psutil.virtual_memory()
    temps = psutil.sensors_temperatures() if hasattr(psutil, "sensors_temperatures") else {}
    cpu_temp = None
    if temps:
        for name, entries in temps.items():
            if entries:
                cpu_temp = entries[0].current
                break
    return {
        "cpu": cpu,
        "ram_used": round(mem.used / (1024**3), 2),
        "ram_total": round(mem.total / (1024**3), 2),
        "gpu": None,
        "temp": cpu_temp,
    }

def metrics_reporter(master_url, worker_id):
    psutil.cpu_percent(interval=None)
    while True:
        try:
            data = collect_metrics()
            data["worker_id"] = worker_id
            requests.post(f"{master_url}/worker_metrics", json=data, timeout=5)
        except Exception:
            pass
        time.sleep(2)

def main():
    print(f"\n{'='*55}")
    print(f"  WORKER: {WORKER_ID}")
    print(f"{'='*55}")
    print(f"  Device    : {DEVICE}")
    print(f"  Master    : {MASTER_URL}")
    print(f"  Dataset   : {DATASET_DIR}\n")

    # ── Register with master ──────────────────────────────────────────────────
    print("  Registering with master...")
    while True:
        try:
            resp = requests.post(f"{MASTER_URL}/register",
                                 json={"worker_id": WORKER_ID}, timeout=10)
            resp.raise_for_status()
            config = resp.json()
            break
        except Exception as e:
            print(f"  Master not reachable yet ({e}), retrying in 3s...")
            time.sleep(3)

    num_classes   = config["num_classes"]
    classes       = config["classes"]
    rounds        = config["rounds"]
    local_epochs  = config["local_epochs"]
    batch_size    = config["batch_size"]
    img_size      = config["img_size"]
    lr            = config["lr"]
    mode          = config.get("mode", "quality")
    train_indices = config["train_indices"]

    print(f"  ✓ Registered — {num_classes} classes: {classes}")
    print(f"  Mode: {mode.upper()}")
    print(f"  Rounds: {rounds}  |  Local epochs: {local_epochs}")

    # ── For split mode, fetch this worker's specific indices ──────────────────
    if mode == "split":
        print(f"  Split mode — fetching assigned indices from master...")
        train_indices = fetch_my_indices()
        print(f"  ✓ Got {len(train_indices)} assigned images for this worker")
    else:
        print(f"  Quality mode — training on full dataset ({len(train_indices)} images)")

    print()

    # Start background metrics reporter
    threading.Thread(target=metrics_reporter, args=(MASTER_URL, WORKER_ID), daemon=True).start()

    train_loader = get_train_loader(train_indices, batch_size, img_size)
    model        = build_model(num_classes).to(DEVICE)
    criterion    = nn.CrossEntropyLoss()
    reference_state = model.state_dict()

    # ── Training rounds ───────────────────────────────────────────────────────
    for rnd in range(1, rounds + 1):
        print(f"  Waiting for round {rnd} weights...")
        weights_resp = None
        while True:
            try:
                r = requests.get(f"{MASTER_URL}/weights", timeout=60)
                if r.status_code == 200:
                    data = r.json()
                    if data.get("done"):
                        print("  Master signalled training complete.")
                        return
                    if data.get("round", -1) >= rnd:
                        weights_resp = data
                        break
            except Exception as e:
                print(f"  ⚠ Poll error: {e}")
            time.sleep(1)

        model.load_state_dict(dict_to_state(weights_resp["weights"], reference_state))
        optimizer = optim.Adam(model.fc.parameters(), lr=lr)

        t0 = time.time()
        model.train()
        for epoch in range(local_epochs):
            total_loss, correct, total = 0.0, 0, 0
            for imgs, labels in train_loader:
                imgs, labels = imgs.to(DEVICE), labels.to(DEVICE)
                outputs = model(imgs)
                loss    = criterion(outputs, labels)
                optimizer.zero_grad()
                loss.backward()
                optimizer.step()
                total_loss += loss.item()
                correct    += (outputs.argmax(1) == labels).sum().item()
                total      += labels.size(0)
            print(f"    Epoch {epoch+1}/{local_epochs}  "
                  f"loss={total_loss/len(train_loader):.4f}  "
                  f"acc={correct/total:.3f}")

        elapsed = time.time() - t0
        success = upload_weights_with_retry(WORKER_ID, model_to_dict(model))
        status  = "weights sent" if success else "upload failed"
        print(f"  → Round {rnd}/{rounds} done ({elapsed:.1f}s) — {status}\n")

    print("  ✓ All rounds complete.")


if __name__ == "__main__":
    main()