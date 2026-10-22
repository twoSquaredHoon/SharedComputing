import ast
import os
import re
import ssl
import subprocess
import certifi

os.environ.setdefault("SSL_CERT_FILE", certifi.where())
ssl._create_default_https_context = ssl.create_default_context

import torch
import torch.nn as nn
from torchvision import models, transforms
from PIL import Image
import sys
from pathlib import Path

from sharedcomputing.core.paths import CHECKPOINT_BEST_NET, REPO_ROOT, SUMMARY_NET

# ── Config ────────────────────────────────────────────────────────────────────
CKPT_PATH = CHECKPOINT_BEST_NET
IMG_SIZE = 224
TEST_INPUT_DIR = REPO_ROOT / "test_input"


def load_classes_from_summary() -> list[str]:
    """Read class labels from the latest network training summary."""
    summary_path = SUMMARY_NET if SUMMARY_NET.is_file() else None
    if summary_path is None:
        return ["cat", "dog", "fox"]

    text = summary_path.read_text(encoding="utf-8")
    match = re.search(r"\| Classes \| (\[.+\])", text)
    if not match:
        return ["cat", "dog", "fox"]
    try:
        classes = ast.literal_eval(match.group(1))
    except (SyntaxError, ValueError):
        return ["cat", "dog", "fox"]
    if not isinstance(classes, list) or not classes:
        return ["cat", "dog", "fox"]
    return [str(c) for c in classes]


CLASSES = load_classes_from_summary()

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

def _copy_via_sips(src: Path, dst: Path) -> Path:
    """macOS can block direct reads from Trash; sips can still access the file."""
    TEST_INPUT_DIR.mkdir(exist_ok=True)
    dst.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["sips", "-s", "format", "png", str(src), "--out", str(dst)],
        check=True,
        capture_output=True,
        text=True,
    )
    return dst


def resolve_image_path(image_path: str | Path) -> Path:
    path = Path(image_path).expanduser()
    if path.is_file():
        return path

    trash_path = Path.home() / ".Trash" / path.name
    if trash_path.is_file():
        print(f"  ↳ Found in Trash, copying via sips...")
        dst = TEST_INPUT_DIR / path.name
        return _copy_via_sips(trash_path, dst)

    raise FileNotFoundError(
        f"Image not found: {path}\n"
        f"  Put test images in: {TEST_INPUT_DIR}/"
    )


def open_image(image_path: str | Path) -> Image.Image:
    path = resolve_image_path(image_path)
    try:
        return Image.open(path).convert("RGB")
    except PermissionError:
        if ".Trash" in str(path):
            print(f"  ↳ macOS blocked Trash read, copying via sips...")
            dst = TEST_INPUT_DIR / path.name
            path = _copy_via_sips(path, dst)
            return Image.open(path).convert("RGB")
        raise PermissionError(
            f"macOS blocked access to: {path}\n"
            f"  Try: python3 predict.py \"{TEST_INPUT_DIR}/{path.name}\""
        ) from None


PREDICT_PORT = int(os.environ.get("PREDICT_PORT", "8091"))


def run_inference(model, image_path: str | Path) -> list[tuple[str, float]]:
    img = open_image(image_path)
    tensor = transform(img).unsqueeze(0).to(DEVICE)
    with torch.no_grad():
        probs = torch.softmax(model(tensor), dim=1)[0]
    return sorted(zip(CLASSES, probs.tolist()), key=lambda x: x[1], reverse=True)


def print_results(image_path: str | Path, results: list[tuple[str, float]]) -> str:
    print(f"\n  Image : {image_path}")
    print(f"  {'─'*30}")
    for cls, prob in results:
        bar = "█" * int(prob * 20)
        print(f"  {cls:<10} {prob*100:5.1f}%  {bar}")
    label = results[0][0].upper()
    print(f"\n  → Prediction: {label}\n")
    return results[0][0]


def predict(model, image_path: str | Path) -> str:
    return print_results(image_path, run_inference(model, image_path))


def _predict_remote(image_path: str | Path) -> bool:
    import json
    import urllib.error
    import urllib.request

    resolved = str(resolve_image_path(image_path))
    body = json.dumps({"path": resolved}).encode()
    req = urllib.request.Request(
        f"http://127.0.0.1:{PREDICT_PORT}/predict",
        data=body,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=5) as resp:
            data = json.loads(resp.read().decode())
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError, KeyError):
        return False

    results = [(row["class"], row["prob"]) for row in data["results"]]
    print_results(image_path, results)
    return True


def serve() -> None:
    import json
    from http.server import BaseHTTPRequestHandler, HTTPServer

    if not CKPT_PATH.is_file():
        print(f"\n  ✗ No trained model at {CKPT_PATH}\n")
        sys.exit(1)

    print(f"  Loading model from {CKPT_PATH}...", flush=True)
    model = load_model()
    print(f"  Ready on http://127.0.0.1:{PREDICT_PORT}")
    print(f"  Classes: {CLASSES}  |  Device: {DEVICE}")
    print("  Predict fast: python3 predict.py path/to/image.jpg\n", flush=True)

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *_args) -> None:
            return

        def do_POST(self) -> None:
            if self.path != "/predict":
                self.send_error(404)
                return
            length = int(self.headers.get("Content-Length", 0))
            try:
                payload = json.loads(self.rfile.read(length).decode())
                image_path = payload["path"]
                results = run_inference(model, image_path)
                body = json.dumps({
                    "path": str(image_path),
                    "prediction": results[0][0],
                    "results": [{"class": c, "prob": p} for c, p in results],
                }).encode()
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)
            except (FileNotFoundError, PermissionError, KeyError, json.JSONDecodeError) as exc:
                body = json.dumps({"error": str(exc)}).encode()
                self.send_response(400)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)

        def do_GET(self) -> None:
            if self.path == "/health":
                body = b'{"status":"ok"}'
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)
            else:
                self.send_error(404)

    HTTPServer(("127.0.0.1", PREDICT_PORT), Handler).serve_forever()


# ── Main ──────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    TEST_INPUT_DIR.mkdir(exist_ok=True)

    if len(sys.argv) >= 2 and sys.argv[1] in ("--serve", "serve"):
        serve()

    if len(sys.argv) < 2:
        print("\n  Usage:")
        print("    python3 predict.py --serve          # keep model loaded (fast)")
        print("    python3 predict.py path/to/image.jpg")
        print(f"  Drop images into: {TEST_INPUT_DIR}/\n")
        sys.exit(1)

    if not CKPT_PATH.is_file():
        print(f"\n  ✗ No trained model at {CKPT_PATH}")
        print("  Run a training session first.\n")
        sys.exit(1)

    model = None
    for image_path in sys.argv[1:]:
        try:
            if _predict_remote(image_path):
                continue
            if model is None:
                print("  (no predict server — loading model, this takes ~1 min)", flush=True)
                model = load_model()
                print(f"  Model loaded from {CKPT_PATH}")
                print(f"  Classes: {CLASSES}")
                print(f"  Device: {DEVICE}")
            predict(model, image_path)
        except (FileNotFoundError, PermissionError) as exc:
            print(f"\n  ✗ {exc}\n")
            sys.exit(1)
