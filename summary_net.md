# Training Summary — Network Distributed

## Run info
| | |
|--|--|
| Date | 2026-03-06 01:26:31 |
| Master | 10.141.100.235:8000 |
| Workers | ['shs-MacBook-Pro.local'] |
| Dataset | 606 images (train=424, val=90, test=92) |
| Classes | ['cats', 'dogs', 'horses'] |

## Hyperparameters
| Param | Value |
|-------|-------|
| Architecture | ResNet18 (transfer learning, frozen backbone) |
| Image size | 224×224 |
| Batch size | 8 |
| Rounds | 10 |
| Local epochs per round | 2 |
| Learning rate | 0.001 |
| Aggregation | FedAvg |
| Round timeout | 60s |

## Results
| Metric | Value |
|--------|-------|
| Best val accuracy | 0.422 (round 10) |
| Test accuracy | 0.326 |
| Total training time | 463.3s |

## Per-round log
| Round | Val Loss | Val Acc | Time | Workers | Saved |
|------:|---------:|--------:|-----:|--------:|:-----:|
|     2 | 4.3595 | 0.356 | 45.6s | 1/1 | ✓ |
|     4 | 4.2389 | 0.356 | 33.4s | 1/1 |  |
|     6 | 7.4440 | 0.367 | 24.7s | 1/1 | ✓ |
|     8 | 7.0776 | 0.367 | 24.4s | 1/1 |  |
|    10 | 10.0088 | 0.422 | 26.9s | 1/1 | ✓ |
