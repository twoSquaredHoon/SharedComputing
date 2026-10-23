# Training Summary — Network Distributed

## Run info
| | |
|--|--|
| Date | 2026-10-22 02:52:43 |
| Master | 10.141.205.25:8000 |
| Workers | ['LOAN-J1GQM9HV9Y'] |
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
| Best val accuracy | 1.000 (round 1) |
| Test accuracy | 0.979 |
| Total training time | 303.2s |

## Per-round log
| Round | Val Loss | Val Acc | Time | Workers | Saved |
|------:|---------:|--------:|-----:|--------:|:-----:|
|     1 | 0.2164 | 1.000 | 145.6s | 1/1 | ✓ |
|     2 | 0.1076 | 1.000 | 157.5s | 1/1 |  |
