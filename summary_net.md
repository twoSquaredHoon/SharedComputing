# Training Summary — Network Distributed

## Run info
| | |
|--|--|
| Date | 2026-03-16 17:53:45 |
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
| Rounds | 3 |
| Local epochs per round | 2 |
| Learning rate | 0.001 |
| Aggregation | FedAvg |
| Round timeout | 120s |

## Results
| Metric | Value |
|--------|-------|
| Best val accuracy | 1.000 (round 1) |
| Test accuracy | 0.979 |
| Total training time | 666.0s |

## Per-round log
| Round | Val Loss | Val Acc | Time | Workers | Saved |
|------:|---------:|--------:|-----:|--------:|:-----:|
|     1 | 0.2353 | 1.000 | 217.0s | 1/1 | ✓ |
|     2 | 0.1624 | 0.957 | 231.2s | 1/1 |  |
|     3 | 0.1092 | 0.978 | 217.8s | 1/1 |  |
