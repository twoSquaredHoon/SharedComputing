# Training Summary — Network Distributed

## Run info
| | |
|--|--|
| Date | 2026-03-06 02:05:05 |
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
| Local epochs per round | 1 |
| Learning rate | 0.001 |
| Aggregation | FedAvg |
| Round timeout | 60s |

## Results
| Metric | Value |
|--------|-------|
| Best val accuracy | 0.333 (round 5) |
| Test accuracy | 0.272 |
| Total training time | 271.9s |

## Per-round log
| Round | Val Loss | Val Acc | Time | Workers | Saved |
|------:|---------:|--------:|-----:|--------:|:-----:|
|     2 | 4.1764 | 0.300 | 42.1s | 1/1 | ✓ |
|     4 | 4.0864 | 0.300 | 64.9s | 1/1 |  |
|     5 | 6.8856 | 0.333 | 39.4s | 1/1 | ✓ |
