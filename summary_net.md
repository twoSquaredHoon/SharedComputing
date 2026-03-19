# Training Summary — Network Distributed

## Run info
| | |
|--|--|
| Date | 2026-03-16 21:42:22 |
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
| Batch size | 1 |
| Rounds | 1 |
| Local epochs per round | 1 |
| Learning rate | 0.001 |
| Aggregation | FedAvg |
| Round timeout | 120s |

## Results
| Metric | Value |
|--------|-------|
| Best val accuracy | 0.326 (round 1) |
| Test accuracy | 0.362 |
| Total training time | 156.9s |

## Per-round log
| Round | Val Loss | Val Acc | Time | Workers | Saved |
|------:|---------:|--------:|-----:|--------:|:-----:|
|     1 | 1.3943 | 0.326 | 156.8s | 1/1 | ✓ |
