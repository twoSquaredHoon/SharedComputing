import os
import ssl
import certifi

os.environ.setdefault("SSL_CERT_FILE", certifi.where())
ssl._create_default_https_context = ssl.create_default_context

import time
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader, random_split
from torchvision import datasets, transforms, models
from pathlib import Path

from sharedcomputing.core.paths import REPO_ROOT

# ── Paths ─────────────────────────────────────────────────────────────────────
BASE        = REPO_ROOT
DATASET_DIR = BASE / "data"
CKPT_DIR    = BASE / "models"
CKPT_PATH   = CKPT_DIR / "best_model.pth"
SUMMARY     = BASE / "summary.md"

# ── Config ────────────────────────────────────────────────────────────────────
IMG_SIZE   = 224
BATCH_SIZE = 16
EPOCHS     = 20
LR         = 1e-3
SEED       = 42

DEVICE = (
    "mps"  if torch.backends.mps.is_available() else
    "cuda" if torch.cuda.is_available() else
    "cpu"
)

# ── Transforms ────────────────────────────────────────────────────────────────
train_transform = transforms.Compose([
    transforms.Resize((IMG_SIZE, IMG_SIZE)),
    transforms.RandomHorizontalFlip(),
    transforms.RandomRotation(15),
    transforms.ColorJitter(brightness=0.3, contrast=0.3, saturation=0.2),
    transforms.ToTensor(),
    transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
])

val_transform = transforms.Compose([
    transforms.Resize((IMG_SIZE, IMG_SIZE)),
    transforms.ToTensor(),
    transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
])

class TransformSubset(torch.utils.data.Dataset):
    def __init__(self, subset, transform):
        self.subset    = subset
        self.transform = transform
    def __len__(self):
        return len(self.subset)
    def __getitem__(self, idx):
        img, label = self.subset[idx]
        return self.transform(img), label

def run_epoch(model, loader, criterion, optimizer, training, device):
    model.train(training)
    total_loss, correct = 0.0, 0
    with torch.set_grad_enabled(training):
        for imgs, labels in loader:
            imgs, labels = imgs.to(device), labels.to(device)
            outputs = model(imgs)
            loss    = criterion(outputs, labels)
            if training:
                optimizer.zero_grad()
                loss.backward()
                optimizer.step()
            total_loss += loss.item() * imgs.size(0)
            correct    += (outputs.argmax(1) == labels).sum().item()
    n = len(loader.dataset)
    return total_loss / n, correct / n


def train():
    torch.manual_seed(SEED)

    # ── Auto-detect classes from data folder
    full_dataset = datasets.ImageFolder(DATASET_DIR)
    num_classes  = len(full_dataset.classes)

    total   = len(full_dataset)
    n_train = int(0.70 * total)
    n_val   = int(0.15 * total)
    n_test  = total - n_train - n_val

    train_set, val_set, test_set = random_split(full_dataset, [n_train, n_val, n_test])

    train_loader = DataLoader(TransformSubset(train_set, train_transform),
                              batch_size=BATCH_SIZE, shuffle=True,  num_workers=0)
    val_loader   = DataLoader(TransformSubset(val_set,   val_transform),
                              batch_size=BATCH_SIZE, shuffle=False, num_workers=0)
    test_loader  = DataLoader(TransformSubset(test_set,  val_transform),
                              batch_size=BATCH_SIZE, shuffle=False, num_workers=0)

    print(f"\n{'='*55}")
    print(f"  SINGLE MACHINE TRAINING")
    print(f"{'='*55}")
    print(f"  Device   : {DEVICE}")
    print(f"  Classes  : {full_dataset.classes}")
    print(f"  Dataset  : {total} images  (train={n_train} val={n_val} test={n_test})")
    print(f"  Epochs   : {EPOCHS}")
    print(f"{'='*55}\n")

    # ── Model
    model = models.resnet18(weights=models.ResNet18_Weights.DEFAULT)
    for param in model.parameters():
        param.requires_grad = False
    model.fc = nn.Linear(model.fc.in_features, num_classes)
    model    = model.to(DEVICE)

    criterion = nn.CrossEntropyLoss()
    optimizer = optim.Adam(model.fc.parameters(), lr=LR)

    CKPT_DIR.mkdir(exist_ok=True)  # creates models/ if it doesn't exist
    best_val_acc = 0.0
    history      = []
    train_start  = time.time()

    for epoch in range(1, EPOCHS + 1):
        t0 = time.time()
        train_loss, train_acc = run_epoch(model, train_loader, criterion, optimizer, True,  DEVICE)
        val_loss,   val_acc   = run_epoch(model, val_loader,   criterion, None,      False, DEVICE)
        elapsed = time.time() - t0

        saved = val_acc > best_val_acc
        if saved:
            best_val_acc = val_acc
            torch.save(model.state_dict(), CKPT_PATH)

        history.append(dict(epoch=epoch, train_loss=train_loss, train_acc=train_acc,
                            val_loss=val_loss, val_acc=val_acc, elapsed=elapsed, saved=saved))

        print(f"  Epoch {epoch:>3}/{EPOCHS}  "
              f"train_loss={train_loss:.4f}  train_acc={train_acc:.3f}  "
              f"val_loss={val_loss:.4f}  val_acc={val_acc:.3f}  "
              f"({elapsed:.1f}s){'  ← saved' if saved else ''}")

    total_time = time.time() - train_start

    model.load_state_dict(torch.load(CKPT_PATH, map_location=DEVICE))
    test_loss, test_acc = run_epoch(model, test_loader, criterion, None, False, DEVICE)

    print(f"\n  Test  loss={test_loss:.4f}  acc={test_acc:.3f}")
    print(f"  Saved → {CKPT_PATH}\n")

    # ── Write summary.md
    best = max(history, key=lambda r: r["val_acc"])
    rows = "\n".join(
        f"| {r['epoch']:>5} | {r['train_loss']:.4f} | {r['train_acc']:.3f} "
        f"| {r['val_loss']:.4f} | {r['val_acc']:.3f} | {r['elapsed']:.1f}s | {'✓' if r['saved'] else ''} |"
        for r in history
    )
    with open(SUMMARY, "w") as f:
        f.write(f"""# Training Summary — Single Machine

## Run info
| | |
|--|--|
| Date | {time.strftime('%Y-%m-%d %H:%M:%S')} |
| Device | {DEVICE} |
| Dataset | {total} images (train={n_train}, val={n_val}, test={n_test}) |
| Classes | {full_dataset.classes} |
| Checkpoint | `checkpoints/best_model.pth` |

## Hyperparameters
| Param | Value |
|-------|-------|
| Architecture | ResNet18 (transfer learning, frozen backbone) |
| Image size | {IMG_SIZE}×{IMG_SIZE} |
| Batch size | {BATCH_SIZE} |
| Epochs | {EPOCHS} |
| Learning rate | {LR} |

## Results
| Metric | Value |
|--------|-------|
| Best val accuracy | {best['val_acc']:.3f} (epoch {best['epoch']}) |
| Test accuracy | {test_acc:.3f} |
| Total training time | {total_time:.1f}s |

## Per-epoch log
| Epoch | Train Loss | Train Acc | Val Loss | Val Acc | Time | Saved |
|------:|----------:|----------:|---------:|--------:|-----:|:-----:|
{rows}
""")

    return num_classes, full_dataset.classes


if __name__ == "__main__":
    train()
