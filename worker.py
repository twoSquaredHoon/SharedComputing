import os
import ssl
import certifi

os.environ.setdefault("SSL_CERT_FILE", certifi.where())
ssl._create_default_https_context = ssl.create_default_context

import time
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader, Subset
from torchvision import datasets, transforms, models
from pathlib import Path
import requests
import socket

# ── Config ────────────────────────────────────────────────────────────────────
MASTER_URL  = "http://10.140.74.23:8000"   # your master Mac's IP
WORKER_ID   = socket.gethostname()          # uses this Mac's hostname automatically
DATASET_DIR = Path(__file__).parent / "data"
SEED        = 42

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

def dict_to_state(d):
    return {k: torch.tensor(v) for k, v in d.items()}

def model_to_dict(model):
    return {k: v.cpu().tolist() for k, v in model.state_dict().items()}

def get_train_loader(num_classes, classes, batch_size, img_size, local_epochs):
    train_transform = transforms.Compose([
        transforms.Resize((img_size, img_size)),
        transforms.RandomHorizontalFlip(),
        transforms.RandomRotation(15),
        transforms.ColorJitter(brightness=0.3, contrast=0.3, saturation=0.2),
        transforms.ToTensor(),
        transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
    ])
    dataset = datasets.ImageFolder(str(DATASET_DIR), transform=train_transform)

    # Use 70% of data for training (same split logic as master)
    total   = len(dataset)
    n_train = int(0.70 * total)
    indices = list(range(n_train))  # worker uses training portion

    return DataLoader(Subset(dataset, indices),
                      batch_size=batch_size, shuffle=True, num_workers=0)


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
                                 json={"worker_id": WORKER_ID})
            config = resp.json()
            break
        except Exception:
            print("  Master not reachable yet, retrying in 3s...")
            time.sleep(3)

    num_classes  = config["num_classes"]
    classes      = config["classes"]
    rounds       = config["rounds"]
    local_epochs = config["local_epochs"]
    batch_size   = config["batch_size"]
    img_size     = config["img_size"]
    lr           = config["lr"]

    print(f"  ✓ Registered — {num_classes} classes: {classes}")
    print(f"  Rounds: {rounds}  |  Local epochs: {local_epochs}\n")

    train_loader = get_train_loader(num_classes, classes, batch_size, img_size, local_epochs)
    model        = build_model(num_classes).to(DEVICE)
    criterion    = nn.CrossEntropyLoss()

    last_round = 0

    # ── Training rounds ───────────────────────────────────────────────────────
    for rnd in range(1, rounds + 1):
        # Poll master for new weights
        print(f"  Waiting for round {rnd} weights...")
        while True:
            try:
                resp = requests.get(f"{MASTER_URL}/weights").json()
                if resp["round"] == rnd:
                    break
            except Exception:
                pass
            time.sleep(1)

        # Load global weights
        model.load_state_dict(dict_to_state(resp["weights"]))
        optimizer = optim.Adam(model.fc.parameters(), lr=lr)

        # Train locally
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

        # Send updated weights to master
        requests.post(f"{MASTER_URL}/update", json={
            "worker_id": WORKER_ID,
            "weights":   model_to_dict(model)
        })
        print(f"  → Round {rnd}/{rounds} done ({elapsed:.1f}s) — weights sent to master\n")

    print("  ✓ All rounds complete.")


if __name__ == "__main__":
    main()
