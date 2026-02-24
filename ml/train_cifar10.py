import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader
from torchvision import datasets, transforms, models
from tqdm import tqdm

def main():
    device = "mps" if torch.backends.mps.is_available() else "cpu"
    print("device =", device)

    tf_train = transforms.Compose([
        transforms.Resize(224),
        transforms.RandomHorizontalFlip(),
        transforms.ToTensor(),
        transforms.Normalize([0.485,0.456,0.406],[0.229,0.224,0.225]),
    ])
    tf_test = transforms.Compose([
        transforms.Resize(224),
        transforms.ToTensor(),
        transforms.Normalize([0.485,0.456,0.406],[0.229,0.224,0.225]),
    ])

    train_ds = datasets.CIFAR10(root="ml/data", train=True, download=True, transform=tf_train)
    test_ds  = datasets.CIFAR10(root="ml/data", train=False, download=True, transform=tf_test)

    train_loader = DataLoader(train_ds, batch_size=128, shuffle=True)
    test_loader  = DataLoader(test_ds, batch_size=128)

    model = models.resnet18(weights=models.ResNet18_Weights.DEFAULT)
    model.fc = nn.Linear(model.fc.in_features, 10)
    model = model.to(device)

    optimizer = optim.Adam(model.parameters(), lr=1e-3)
    criterion = nn.CrossEntropyLoss()

    for epoch in range(1,6):
        model.train()
        correct,total = 0,0

        for x,y in tqdm(train_loader, desc=f"Epoch {epoch}"):
            x,y = x.to(device), y.to(device)
            optimizer.zero_grad()
            out = model(x)
            loss = criterion(out,y)
            loss.backward()
            optimizer.step()

            correct += (out.argmax(1)==y).sum().item()
            total += y.size(0)

        train_acc = correct/total

        model.eval()
        correct,total = 0,0
        with torch.no_grad():
            for x,y in test_loader:
                x,y = x.to(device), y.to(device)
                correct += (model(x).argmax(1)==y).sum().item()
                total += y.size(0)

        test_acc = correct/total
        print(f"train_acc={train_acc:.3f} test_acc={test_acc:.3f}")

    torch.save(model.state_dict(),"ml/saved_model.pt")
    print("Saved -> ml/saved_model.pt")

if __name__ == "__main__":
    main()
