import io
import time
from typing import Any

import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader, Subset
from torchvision import datasets, models, transforms

NUM_CLASSES = 10
ROUNDS = 5
LOCAL_EPOCHS = 1
BATCH_SIZE = 128
LR = 1e-3
IMG_SIZE = 224


def default_device() -> str:
    if torch.backends.mps.is_available():
        return "mps"
    if torch.cuda.is_available():
        return "cuda"
    return "cpu"


def get_train_transform() -> transforms.Compose:
    return transforms.Compose(
        [
            transforms.Resize(IMG_SIZE),
            transforms.RandomHorizontalFlip(),
            transforms.ToTensor(),
            transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225]),
        ]
    )


def get_test_transform() -> transforms.Compose:
    return transforms.Compose(
        [
            transforms.Resize(IMG_SIZE),
            transforms.ToTensor(),
            transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225]),
        ]
    )


def build_model(
    num_classes: int = NUM_CLASSES,
    pretrained: bool = True,
) -> nn.Module:
    weights = models.ResNet18_Weights.DEFAULT if pretrained else None
    model = models.resnet18(weights=weights)
    model.fc = nn.Linear(model.fc.in_features, num_classes)
    return model


def state_dict_to_cpu(state_dict: dict[str, torch.Tensor]) -> dict[str, torch.Tensor]:
    return {name: tensor.detach().cpu().clone() for name, tensor in state_dict.items()}


def serialize_state_dict(state_dict: dict[str, torch.Tensor]) -> bytes:
    buffer = io.BytesIO()
    torch.save(state_dict_to_cpu(state_dict), buffer)
    return buffer.getvalue()


def deserialize_state_dict(blob: bytes) -> dict[str, torch.Tensor]:
    buffer = io.BytesIO(blob)
    return torch.load(buffer, map_location="cpu")


def _build_train_loader(
    indices: list[int],
    dataset_root: str,
    batch_size: int,
) -> DataLoader:
    train_ds = datasets.CIFAR10(
        root=dataset_root,
        train=True,
        download=True,
        transform=get_train_transform(),
    )
    subset = Subset(train_ds, indices)
    return DataLoader(subset, batch_size=batch_size, shuffle=True)


def train_on_subset(
    indices: list[int],
    dataset_root: str,
    init_weights: dict[str, torch.Tensor] | None,
    device: str,
    local_epochs: int = LOCAL_EPOCHS,
    batch_size: int = BATCH_SIZE,
    lr: float = LR,
) -> tuple[dict[str, torch.Tensor], int, float]:
    sample_count = len(indices)
    if sample_count == 0:
        if init_weights is None:
            fallback = state_dict_to_cpu(build_model(pretrained=False).state_dict())
            return fallback, 0, 0.0
        return state_dict_to_cpu(init_weights), 0, 0.0

    model = build_model(pretrained=False)
    if init_weights is not None:
        model.load_state_dict(init_weights)
    model = model.to(device)

    loader = _build_train_loader(indices=indices, dataset_root=dataset_root, batch_size=batch_size)
    optimizer = optim.Adam(model.parameters(), lr=lr)
    criterion = nn.CrossEntropyLoss()

    started_at = time.time()
    model.train()
    for _ in range(local_epochs):
        for x, y in loader:
            x, y = x.to(device), y.to(device)
            optimizer.zero_grad()
            out = model(x)
            loss = criterion(out, y)
            loss.backward()
            optimizer.step()
    elapsed = time.time() - started_at

    return state_dict_to_cpu(model.state_dict()), sample_count, elapsed


def evaluate(
    weights: dict[str, torch.Tensor],
    dataset_root: str,
    device: str,
    batch_size: int = BATCH_SIZE,
) -> dict[str, Any]:
    test_ds = datasets.CIFAR10(
        root=dataset_root,
        train=False,
        download=True,
        transform=get_test_transform(),
    )
    test_loader = DataLoader(test_ds, batch_size=batch_size, shuffle=False)

    model = build_model(pretrained=False)
    model.load_state_dict(weights)
    model = model.to(device)

    criterion = nn.CrossEntropyLoss()
    model.eval()

    total_loss = 0.0
    total_correct = 0
    total = 0

    with torch.no_grad():
        for x, y in test_loader:
            x, y = x.to(device), y.to(device)
            out = model(x)
            loss = criterion(out, y)
            total_loss += loss.item() * y.size(0)
            total_correct += (out.argmax(1) == y).sum().item()
            total += y.size(0)

    return {
        "loss": total_loss / total,
        "acc": total_correct / total,
    }

