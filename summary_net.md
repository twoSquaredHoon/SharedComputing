# Training Summary — Network Distributed

## Run info
| | |
|--|--|
| Date | 2026-03-16 15:57:58 |
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
| Batch size | 5 |
| Rounds | 3 |
| Local epochs per round | 2 |
| Learning rate | 0.001 |
| Aggregation | FedAvg |
| Round timeout | 120s |

## Results
| Metric | Value |
|--------|-------|
| Best val accuracy | 1.000 (round 3) |
| Test accuracy | 0.979 |
| Total training time | 630.1s |

## Per-round log
| Round | Val Loss | Val Acc | Time | Workers | Saved |
|------:|---------:|--------:|-----:|--------:|:-----:|
|     1 | 0.2515 | 0.978 | 212.4s | 1/1 | ✓ |
|     2 | 0.1174 | 0.978 | 216.5s | 1/1 |  |
|     3 | 0.0630 | 1.000 | 201.0s | 1/1 | ✓ |
