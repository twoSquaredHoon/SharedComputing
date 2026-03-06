# Training Summary — Network Distributed

## Run info
| | |
|--|--|
| Date | 2026-03-06 01:42:03 |
| Master | 10.141.100.235:8000 |
| Workers | ['shs-MacBook-Pro.local'] |
| Dataset | 606 images (train=424, val=90, test=92) |
| Classes | ['cats', 'dogs', 'horses'] |

## Hyperparameters
| Param | Value |
|-------|-------|
| Architecture | ResNet18 (transfer learning, frozen backbone) |
| Image size | 224×224 |
| Batch size | 5 |
| Rounds | 5 |
| Local epochs per round | 2 |
| Learning rate | 0.001 |
| Aggregation | FedAvg |
| Round timeout | 60s |

## Results
| Metric | Value |
|--------|-------|
| Best val accuracy | 0.411 (round 5) |
| Test accuracy | 0.337 |
| Total training time | 334.9s |

## Per-round log
| Round | Val Loss | Val Acc | Time | Workers | Saved |
|------:|---------:|--------:|-----:|--------:|:-----:|
|     2 | 4.3492 | 0.356 | 35.4s | 1/1 | ✓ |
|     3 | 4.3770 | 0.356 | 78.1s | 1/1 |  |
|     4 | 7.6987 | 0.367 | 79.4s | 1/1 | ✓ |
|     5 | 7.3831 | 0.411 | 80.1s | 1/1 | ✓ |
