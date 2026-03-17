# Training Summary — Network Distributed

## Run info
| | |
|--|--|
| Date | 2026-03-16 19:49:43 |
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
| Rounds | 1 |
| Local epochs per round | 1 |
| Learning rate | 0.001 |
| Aggregation | FedAvg |
| Round timeout | 120s |

## Results
| Metric | Value |
|--------|-------|
| Best val accuracy | 0.913 (round 1) |
| Test accuracy | 0.915 |
| Total training time | 144.7s |

## Per-round log
| Round | Val Loss | Val Acc | Time | Workers | Saved |
|------:|---------:|--------:|-----:|--------:|:-----:|
|     1 | 0.4093 | 0.913 | 144.6s | 1/1 | ✓ |
