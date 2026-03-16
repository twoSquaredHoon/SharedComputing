# Training Summary — Network Distributed

## Run info
| | |
|--|--|
| Date | 2026-03-16 15:29:32 |
| Master | 10.141.67.141:8000 |
| Workers | ['shs-MacBook-Pro.local'] |
| Dataset | 308 images (train=215, val=46, test=47) |
| Classes | ['cat', 'dog', 'fox'] |

## Hyperparameters
| Param | Value |
|-------|-------|
| Architecture | ResNet18 (transfer learning, frozen backbone) |
| Training mode | quality |
| Image size | 224×224 |
| Batch size | 5 |
| Rounds | 5 |
| Local epochs per round | 2 |
| Learning rate | 0.001 |
| Aggregation | FedAvg |
| Round timeout | 120s |

## Results
| Metric | Value |
|--------|-------|
| Best val accuracy | 1.000 (round 4) |
| Test accuracy | 0.957 |
| Total training time | 520.9s |

## Per-round log
| Round | Val Loss | Val Acc | Time | Workers | Saved |
|------:|---------:|--------:|-----:|--------:|:-----:|
|     2 | 0.2825 | 0.935 | 95.5s | 1/1 | ✓ |
|     4 | 0.2289 | 1.000 | 58.5s | 1/1 | ✓ |
