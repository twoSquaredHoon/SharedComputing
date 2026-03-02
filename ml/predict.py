import torch
import torch.nn as nn
from torchvision import transforms, models
from PIL import Image
import sys

CLASSES = ['airplane', 'automobile', 'bird', 'cat', 'deer',
           'dog', 'frog', 'horse', 'ship', 'truck']

def load_model(model_path="ml/saved_model.pt"):
    device = "mps" if torch.backends.mps.is_available() else "cpu"
    model = models.resnet18(weights=None)
    model.fc = nn.Linear(model.fc.in_features, 10)
    model.load_state_dict(torch.load(model_path, map_location=device))
    model = model.to(device)
    model.eval()
    return model, device

def predict(image_path, model, device):
    tf = transforms.Compose([
        transforms.Resize(224),
        transforms.ToTensor(),
        transforms.Normalize([0.485, 0.456, 0.406],
                             [0.229, 0.224, 0.225]),
    ])
    img = Image.open(image_path).convert("RGB")
    x = tf(img).unsqueeze(0).to(device)  # add batch dimension

    with torch.no_grad():
        out = model(x)
        probs = torch.softmax(out, dim=1)[0]

    top3 = probs.topk(3)
    print(f"\nImage: {image_path}")
    print("─" * 30)
    for prob, idx in zip(top3.values, top3.indices):
        print(f"  {CLASSES[idx]:<12} {prob.item()*100:.1f}%")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python ml/predict.py <path-to-image>")
        print("Example: python ml/predict.py my_photo.jpg")
        sys.exit(1)

    model, device = load_model()
    predict(sys.argv[1], model, device)