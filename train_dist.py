import os
import ssl
import certifi

os.environ.setdefault("SSL_CERT_FILE", certifi.where())
ssl._create_default_https_context = ssl.create_default_context

import time
import torch
import torch.nn as nn
import torch.optim as optim
import torch.multiprocessing as mp
from torch.utils.data import DataLoader, Subset, random_split
from torchvision import datasets, transforms, models
from pathlib import Path

# ── Paths ─────────────────────────────────────────────────────────────────────
BASE        = Path(__file__).parent
DATASET_DIR = BASE / "data"
CKPT_DIR    = BASE / "checkpoints"
CKPT_PATH   = CKPT_DIR / "best_model_dist.pth"
SUMMARY     = BASE / "summary_dist.md"

# ── Config ────────────────────────────────────────────────────────────────────
IMG_SIZE     = 224
BATCH_SIZE   = 8
NUM_WORKERS  = 2
ROUNDS       = 15
LOCAL_EPOCHS = 2
LR           = 1e-3
SEED         = 42

# MPS is not safe across multiple processes — workers run on CPU
WORKER_DEVICE = "cpu"
MASTER_DEVICE = (
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

def build_model(num_classes):
    model = models.resnet18(weights=None)
    for param in model.parameters():
        param.requires_grad = False
    model.fc = nn.Linear(model.fc.in_features, num_classes)
    return model

# ── Worker ────────────────────────────────────────────────────────────────────
def worker_fn(worker_id, dataset_dir, indices, num_classes, task_queue, result_queue):
    local_dataset = datasets.ImageFolder(str(dataset_dir), transform=train_transform)
    local_loader  = DataLoader(Subset(local_dataset, indices),
                               batch_size=BATCH_SIZE, shuffle=True, num_workers=0)
    model     = build_model(num_classes).to(WORKER_DEVICE)
    criterion = nn.CrossEntropyLoss()

    while True:
        msg = task_queue.get()
        if msg == "done":
            break
        model.load_state_dict(msg)
        optimizer = optim.Adam(model.fc.parameters(), lr=LR)
        model.train()
        for _ in range(LOCAL_EPOCHS):
            for imgs, labels in local_loader:
                imgs, labels = imgs.to(WORKER_DEVICE), labels.to(WORKER_DEVICE)
                loss = criterion(model(imgs), labels)
                optimizer.zero_grad()
                loss.backward()
                optimizer.step()
        result_queue.put({k: v.cpu().clone() for k, v in model.state_dict().items()})

# ── Evaluate ──────────────────────────────────────────────────────────────────
def evaluate(model, loader, device):
    criterion = nn.CrossEntropyLoss()
    model.eval()
    total_loss, correct = 0.0, 0
    with torch.no_grad():
        for imgs, labels in loader:
            imgs, labels = imgs.to(device), labels.to(device)
            outputs     = model(imgs)
            total_loss += criterion(outputs, labels).item() * imgs.size(0)
            correct    += (outputs.argmax(1) == labels).sum().item()
    n = len(loader.dataset)
    return total_loss / n, correct / n

# ── Master ────────────────────────────────────────────────────────────────────
def master():
    torch.manual_seed(SEED)

    # ── Auto-detect classes from data folder
    full_dataset = datasets.ImageFolder(str(DATASET_DIR))
    num_classes  = len(full_dataset.classes)

    total   = len(full_dataset)
    n_train = int(0.70 * total)
    n_val   = int(0.15 * total)
    n_test  = total - n_train - n_val

    train_set, val_set, test_set = random_split(full_dataset, [n_train, n_val, n_test])

    train_indices  = list(train_set.indices)
    split          = len(train_indices) // NUM_WORKERS
    worker_indices = [train_indices[i * split:(i + 1) * split] for i in range(NUM_WORKERS)]
    worker_indices[-1].extend(train_indices[NUM_WORKERS * split:])

    eval_dataset = datasets.ImageFolder(str(DATASET_DIR), transform=val_transform)
    val_loader   = DataLoader(Subset(eval_dataset, list(val_set.indices)),
                              batch_size=BATCH_SIZE, shuffle=False, num_workers=0)
    test_loader  = DataLoader(Subset(eval_dataset, list(test_set.indices)),
                              batch_size=BATCH_SIZE, shuffle=False, num_workers=0)

    print(f"\n{'='*55}")
    print(f"  DISTRIBUTED TRAINING")
    print(f"{'='*55}")
    print(f"  Master device  : {MASTER_DEVICE}")
    print(f"  Worker device  : {WORKER_DEVICE}")
    print(f"  Classes        : {full_dataset.classes}")
    print(f"  Dataset        : {total} images  (train={n_train} val={n_val} test={n_test})")
    print(f"  Workers        : {NUM_WORKERS}  |  Rounds: {ROUNDS}  |  Local epochs: {LOCAL_EPOCHS}")
    print(f"{'='*55}\n")

    # ── Global model (pretrained weights downloaded once on master)
    global_model = models.resnet18(weights=models.ResNet18_Weights.DEFAULT)
    for param in global_model.parameters():
        param.requires_grad = False
    global_model.fc = nn.Linear(global_model.fc.in_features, num_classes)
    global_model    = global_model.to(MASTER_DEVICE)

    # ── Spawn workers
    task_queues   = [mp.Queue() for _ in range(NUM_WORKERS)]
    result_queues = [mp.Queue() for _ in range(NUM_WORKERS)]
    processes     = []

    for wid in range(NUM_WORKERS):
        p = mp.Process(target=worker_fn,
                       args=(wid, DATASET_DIR, worker_indices[wid],
                             num_classes, task_queues[wid], result_queues[wid]))
        p.start()
        processes.append(p)
        print(f"  Worker {wid} started (PID {p.pid}, {len(worker_indices[wid])} images)")
    print()

    CKPT_DIR.mkdir(exist_ok=True)
    best_val_acc = 0.0
    history      = []
    train_start  = time.time()

    for rnd in range(1, ROUNDS + 1):
        t0 = time.time()

        # Broadcast → collect → FedAvg
        global_state = {k: v.cpu() for k, v in global_model.state_dict().items()}
        for q in task_queues:
            q.put(global_state)

        worker_states = [result_queues[wid].get() for wid in range(NUM_WORKERS)]

        avg_state = {
            key: torch.stack([ws[key].float() for ws in worker_states]).mean(dim=0)
            for key in worker_states[0]
        }
        global_model.load_state_dict(avg_state)

        val_loss, val_acc = evaluate(global_model, val_loader, MASTER_DEVICE)
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

    # Shut down workers
    for q in task_queues:
        q.put("done")
    for p in processes:
        p.join()

    # Final test
    global_model.load_state_dict(torch.load(CKPT_PATH, map_location=MASTER_DEVICE))
    test_loss, test_acc = evaluate(global_model, test_loader, MASTER_DEVICE)
    print(f"\n  Test  loss={test_loss:.4f}  acc={test_acc:.3f}")
    print(f"  Saved → {CKPT_PATH}\n")

    # ── Write summary_dist.md
    best = max(history, key=lambda r: r["val_acc"])
    rows = "\n".join(
        f"| {r['round']:>5} | {r['val_loss']:.4f} | {r['val_acc']:.3f} "
        f"| {r['elapsed']:.1f}s | {'✓' if r['saved'] else ''} |"
        for r in history
    )
    with open(SUMMARY, "w") as f:
        f.write(f"""# Training Summary — Distributed (Master + {NUM_WORKERS} Workers)

## Run info
| | |
|--|--|
| Date | {time.strftime('%Y-%m-%d %H:%M:%S')} |
| Master device | {MASTER_DEVICE} |
| Worker device | {WORKER_DEVICE} |
| Workers | {NUM_WORKERS} |
| Dataset | {total} images (train={n_train}, val={n_val}, test={n_test}) |
| Classes | {full_dataset.classes} |
| Checkpoint | `checkpoints/best_model_dist.pth` |

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

    print(f"  Summary written to: {SUMMARY}")


if __name__ == "__main__":
    mp.set_start_method("spawn", force=True)
    master()
