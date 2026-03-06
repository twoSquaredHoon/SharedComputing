import os
import ssl
import certifi

os.environ.setdefault("SSL_CERT_FILE", certifi.where())
ssl._create_default_https_context = ssl.create_default_context

import torch
import torch.nn as nn
from torchvision import models, transforms
from PIL import Image
from pathlib import Path
import sys

# ── Config ────────────────────────────────────────────────────────────────────
BASE       = Path(__file__).parent
CKPT_PATH  = BASE / "models" / "best_model_net.pth"
IMG_SIZE   = 224
CLASSES    = ['cats', 'dogs', 'horses']  # must match training order

DEVICE = (
    "mps"  if torch.backends.mps.is_available() else
    "cuda" if torch.cuda.is_available() else
    "cpu"
)

# ── Transform ─────────────────────────────────────────────────────────────────
transform = transforms.Compose([
    transforms.Resize((IMG_SIZE, IMG_SIZE)),
    transforms.ToTensor(),
    transforms.Normalize(mean=[0.485, 0.456, 0.406],
                         std=[0.229, 0.224, 0.225]),
])

# ── Load model ────────────────────────────────────────────────────────────────
def load_model():
    model = models.resnet18(weights=None)
    model.fc = nn.Linear(model.fc.in_features, len(CLASSES))
    model.load_state_dict(torch.load(CKPT_PATH, map_location=DEVICE, weights_only=True))
    model.to(DEVICE)
    model.eval()
    return model

# ── Predict ───────────────────────────────────────────────────────────────────
def predict(model, image_path):
    img = Image.open(image_path).convert("RGB")
    tensor = transform(img).unsqueeze(0).to(DEVICE)

    with torch.no_grad():
        outputs = model(tensor)
        probs   = torch.softmax(outputs, dim=1)[0]

    results = sorted(
        zip(CLASSES, probs.tolist()),
        key=lambda x: x[1],
        reverse=True
    )

    print(f"\n  Image : {image_path}")
    print(f"  {'─'*30}")
    for cls, prob in results:
        bar = '█' * int(prob * 20)
        print(f"  {cls:<10} {prob*100:5.1f}%  {bar}")
    print(f"\n  → Prediction: {results[0][0].upper()}\n")
    return results[0][0]

# ── Main ──────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("\n  Usage: python3 predict.py path/to/image.jpg")
        print("  Example: python3 predict.py test.jpg\n")
        sys.exit(1)

    model = load_model()
    print(f"  Model loaded from {CKPT_PATH}")
    print(f"  Device: {DEVICE}")

    for image_path in sys.argv[1:]:
        predict(model, image_path)
