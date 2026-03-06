# Training Summary — Network Distributed

## Run info
| | |
|--|--|
| Date | 2026-03-06 00:59:02 |
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
| Rounds | 15 |
| Local epochs per round | 2 |
| Learning rate | 0.001 |
| Aggregation | FedAvg |
| Round timeout | 300s |

## Results
| Metric | Value |
|--------|-------|
| Best val accuracy | 0.456 (round 5) |
| Test accuracy | 0.413 |
| Total training time | 1977.7s |

## Per-round log
| Round | Val Loss | Val Acc | Time | Workers | Saved |
|------:|---------:|--------:|-----:|--------:|:-----:|
|     1 | 4.2413 | 0.344 | 109.3s | 1/1 | ✓ |
|     2 | 7.3328 | 0.367 | 119.2s | 1/1 | ✓ |
|     3 | 10.3875 | 0.389 | 108.5s | 1/1 | ✓ |
|     4 | 10.9530 | 0.444 | 106.1s | 1/1 | ✓ |
|     5 | 11.2274 | 0.456 | 110.1s | 1/1 | ✓ |
|     6 | 11.5692 | 0.411 | 368.2s | 1/1 |  |
|     7 | 11.6588 | 0.411 | 111.0s | 1/1 |  |
|     8 | 11.5948 | 0.411 | 116.3s | 1/1 |  |
|     9 | 11.8287 | 0.422 | 125.6s | 1/1 |  |
|    10 | 11.8580 | 0.422 | 124.7s | 1/1 |  |
|    11 | 12.2377 | 0.444 | 129.7s | 1/1 |  |
|    12 | 11.9865 | 0.433 | 127.5s | 1/1 |  |
|    13 | 11.8866 | 0.400 | 120.3s | 1/1 |  |
|    14 | 12.0408 | 0.433 | 109.3s | 1/1 |  |
|    15 | 12.2338 | 0.356 | 91.7s | 1/1 |  |
