# SharedComputing
Distributed AI training across your Devices. SharedComputing combines the compute power of your multiple devices into a unified training system using a Master–Worker architecture and FedAvg weight aggregation.

---

## Project Structure
```
SharedComputing/
├── SharedComputingMac/       # GUI, macOS Swift app
├── master.py                 # Orchestrates training, runs FastAPI server
├── worker.py                 # Trains locally, sends weights back to master
├── backend_service.py        # FastAPI wrapper on port 8080, manages runs + SQLite DB
├── backend_helpers.py        # Utility functions for backend
├── predict.py                # Run inference on an image using a trained model
├── train.py                  # Single-machine training (standalone)
├── Dockerfile                # Container for backend
├── docker-compose.yml        # Docker Compose config
├── data/                     # Image dataset (ImageFolder format)
└── models/
    └── best_model_net.pth    # Saved after training
```

---

## Roadmap

### Stage 1 — Dataset Setup
- [x] Finder-based dataset picker in Swift app
- [x] Docker container replacing manual Python setup
#### Stage 1.1 - Minor Functions
- [ ] Automated dataset validation

### Stage 2 — Model Training
- [x] ResNet18 transfer learning (frozen backbone)
- [x] Quality mode — each worker trains on full dataset, master averages weights (FedAvg)
- [x] Speed mode — dataset divided between workers for quicker training
#### Stage 2.1 - Minor Functions
- [x] Arrow-key model and mode selection in terminal wizard
- [x] Heartbeat-aware master wait — no more premature timeouts
- [ ] Additional architectures: ResNet50, EfficientNet, ViT

### Stage 3 — Device Connection
- [x] LAN communication
- [x] Live device metrics API (CPU, RAM, GPU, temp) every 2 seconds
- [x] Swift app displays connected worker specs in real time
- [ ] WiFi / remote (non-LAN) communication

### Stage 4 — Results
- [x] Per-run summary log (`summary_net.md`)
- [x] SQLite database recording all run history (`runtime/results.db`)
- [x] Records: device specs, model used, dataset size, training mode, duration, accuracy
- [x] Results viewer in Swift app — history table + detail view per run

---
