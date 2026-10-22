# Training Summary — Network Distributed

## Run info
| | |
|--|--|
| Date | 2026-06-16 21:28:41 |
| Master | 192.168.0.30:8000 |
| Workers | ['shs-MacBook-Pro.local'] |
| Dataset | 308 images (train=215, val=46, test=47) |
| Classes | ['cat', 'dog', 'fox'] |

## Hyperparameters
| Param | Value |
|-------|-------|
| Architecture | resnet18 (transfer learning, frozen backbone) |
| Training mode | quality |
| Image size | 224×224 |
| Batch size | 1 |
| Rounds | 1 |
| Local epochs per round | 1 |
| Learning rate | 0.001 |
| Aggregation | FedAvg |
| Round timeout | 120s |

## Results
| Metric | Value |
|--------|-------|
| Best val accuracy | 0.239 (round 1) |
| Test accuracy | 0.170 |
| Total training time | 152.1s |

## Per-round log
| Round | Val Loss | Val Acc | Time | Workers | Saved |
|------:|---------:|--------:|-----:|--------:|:-----:|
|     1 | 1.3843 | 0.239 | 152.0s | 1/1 | ✓ |
