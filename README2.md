# SharedComputing

Distributed AI training across your Macs. SharedComputing combines the compute power of multiple devices on your local network into a unified training system using a Master–Worker architecture and FedAvg weight aggregation.

---

## Project Structure

```
SharedComputing/
├── SharedComputingMac/       # Native macOS Swift app (GUI)
├── master.py                 # Orchestrates training, runs FastAPI server
├── worker.py                 # Trains locally, sends weights back to master
├── predict.py                # Run inference on an image using a trained model
├── train.py                  # Single-machine training (standalone)
├── data/                     # Image dataset (ImageFolder format)
└── models/
    └── best_model_net.pth    # Saved after training
```

---

## Roadmap

### Stage 1 — Dataset Setup
- [ ] Finder-based dataset picker in Swift app
- [ ] Automated dataset validation
- [ ] Docker container to replace manual Python setup

### Stage 2 — Model Training
- [x] ResNet18 transfer learning (frozen backbone)
- [x] Quality mode — each worker trains on full dataset, master averages weights (FedAvg)
- [ ] Speed mode — dataset is split between workers
- [ ] Additional architectures: ResNet50, EfficientNet, ViT

### Stage 3 — Device Connection
- [x] LAN communication
- [x] Live device metrics API (CPU, RAM, GPU, temp)
- [ ] Swift app displays connected worker specs in real time
- [ ] WiFi / remote (non-LAN) communication

### Stage 4 — Results
- [x] Per-run summary log (`summary_net.md`)
- [ ] Local database to store run history
- [ ] Records: device specs, model used, dataset size, connection method, duration, accuracy
- [ ] Results viewer in Swift app