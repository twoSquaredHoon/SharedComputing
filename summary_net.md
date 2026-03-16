# Training Summary — Network Distributed

## Run info
| | |
|--|--|
| Date | 2026-03-16 16:50:57 |
| Master | 10.141.67.141:8000 |
| Workers | ['shs-MacBook-Pro.local'] |
| Dataset | 308 images (train=215, val=46, test=47) |
| Classes | ['cat', 'dog', 'fox'] |

## Hyperparameters
| Param | Value |
|-------|-------|
| Architecture | resnet18 (transfer learning, frozen backbone) |
| Training mode | quality |
| Image size | 224×224 |
| Batch size | 8 |
| Rounds | 2 |
| Local epochs per round | 2 |
| Learning rate | 0.001 |
| Aggregation | FedAvg |
| Round timeout | 120s |

## Results
| Metric | Value |
|--------|-------|
| Best val accuracy | 1.000 (round 2) |
| Test accuracy | 0.957 |
| Total training time | 404.7s |

## Per-round log
| Round | Val Loss | Val Acc | Time | Workers | Saved |
|------:|---------:|--------:|-----:|--------:|:-----:|
|     1 | 0.2741 | 0.935 | 206.1s | 1/1 | ✓ |
|     2 | 0.1152 | 1.000 | 198.5s | 1/1 | ✓ |
