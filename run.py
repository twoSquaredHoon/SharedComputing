import sys
from pathlib import Path

# ── Validate data folder before doing anything ────────────────────────────────
DATA_DIR = Path(__file__).parent / "data"

if not DATA_DIR.exists():
    print("\n  ✗ No 'data/' folder found.")
    print("  Create it and add your images like this:\n")
    print("    data/")
    print("    ├── class_a/")
    print("    │   ├── image1.jpg")
    print("    │   └── image2.jpg")
    print("    └── class_b/")
    print("        ├── image1.jpg")
    print("        └── image2.jpg\n")
    sys.exit(1)

classes = [d for d in DATA_DIR.iterdir() if d.is_dir()]
if len(classes) < 2:
    print(f"\n  ✗ Found {len(classes)} class folder(s) in data/ — need at least 2.")
    print("  Each subfolder = one class. Folder name = class label.\n")
    sys.exit(1)

print(f"\n  ✓ Found {len(classes)} classes: {[c.name for c in sorted(classes)]}")

if __name__ == "__main__":
    # ── Phase 1: Single machine training ─────────────────────────────────────
    print("\n  ► Phase 1: Single machine training\n")
    from train import train
    train()

    # ── Phase 2: Distributed training ────────────────────────────────────────
    print("\n  ► Phase 2: Distributed training\n")
    import torch.multiprocessing as mp
    mp.set_start_method("spawn", force=True)
    from train_dist import master
    master()

    print("\n  ✓ All done.")
    print("  Results:")
    print("    models/best_model.pth       ← single machine")
    print("    models/best_model_dist.pth  ← distributed")
    print("    summary.md")
    print("    summary_dist.md\n")
