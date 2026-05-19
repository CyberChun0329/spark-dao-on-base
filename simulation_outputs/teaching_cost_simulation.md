# Teaching Cost Simulation

Generated from `teaching_gas_calibration.csv`, `teaching_claim_gas_calibration.csv`, and `research_gas_calibration.csv`.

Reference translation coefficient:

```text
referenceUsdPerGas = 1.4960545778707655e-8
source = trailing-twelve-month Base fee translation coefficient
measurementWindow = trailing twelve months at calibration time
unit = dollars per gas unit
```

The simulation uses `lesson_gas + claim_gas` for the recurring teaching-management coefficient. `lesson_gas` measures settlement through `TeachingRegistry`; `claim_gas` measures reward withdrawal through `TeachingRewardDistributor`. `setup_gas` is reported separately because research setup and catalogue maintenance are low-frequency components in the model. Claim primitives below record single-claim, batch-claim, and dust-release paths, while the path table reports the deterministic claim policy used by the calibration test.

## Measured Contract Paths

| Path | Category | Setup gas | Lesson settlement gas | Distributor claim gas | Claim-inclusive management gas | Total gas | Revenue weight |
|---|---|---:|---:|---:|---:|---:|---|
| ORD_NR | ordinary | 0 | 395,687 | 0 | 395,687 | 395,687 | 100.000% |
| ORD_ZS | ordinary | 511,526 | 365,658 | 0 | 365,658 | 877,184 | 100.000% |
| ORD_RB | ordinary | 762,064 | 492,396 | 190,950 | 683,346 | 1,445,410 | 100.000% |
| ORD_WM | ordinary | 956,688 | 584,439 | 170,493 | 754,932 | 1,711,620 | 100.000% |
| ORD_ML | ordinary | 1,480,742 | 764,436 | 169,492 | 933,928 | 2,414,670 | 100.000% |
| FV_NR | forced_valid | 0 | 317,831 | 0 | 317,831 | 317,831 | 100.000% |
| FV_ZS | forced_valid | 478,368 | 362,005 | 0 | 362,005 | 840,373 | 100.000% |
| FV_RB | forced_valid | 740,220 | 481,443 | 147,150 | 628,593 | 1,368,813 | 100.000% |
| FV_WM | forced_valid | 956,772 | 580,791 | 170,516 | 751,307 | 1,708,079 | 100.000% |
| FV_ML | forced_valid | 1,437,063 | 760,790 | 169,492 | 930,282 | 2,367,345 | 100.000% |
| CF_NR | customer_fault | 0 | 381,964 | 0 | 381,964 | 381,964 | 50.000% |
| CF_ZS | customer_fault | 478,409 | 426,140 | 0 | 426,140 | 904,549 | 50.000% |
| CF_RB | customer_fault | 740,289 | 426,179 | 0 | 426,179 | 1,166,468 | 50.000% |
| CF_WM | customer_fault | 956,853 | 428,483 | 0 | 428,483 | 1,385,336 | 50.000% |
| CF_ML | customer_fault | 1,437,180 | 606,488 | 0 | 606,488 | 2,043,668 | 50.000% |
| TF_NR | teacher_fault | 0 | 385,332 | 0 | 385,332 | 385,332 | 50.000% |
| TF_ZS | teacher_fault | 478,449 | 429,509 | 0 | 429,509 | 907,958 | 50.000% |
| TF_RB | teacher_fault | 740,323 | 548,942 | 147,150 | 696,092 | 1,436,415 | 50.000% |
| TF_WM | teacher_fault | 956,935 | 648,303 | 170,561 | 818,864 | 1,775,799 | 50.000% |
| TF_ML | teacher_fault | 1,437,300 | 828,300 | 169,492 | 997,792 | 2,435,092 | 50.000% |

## Measured Reward-Claim Primitives

| Claim path | Category | Claim gas | Claim count | Dust release |
|---|---|---:|---:|---|
| CLAIM_SINGLE_FULL | single_claim | 81,644 | 1 | no |
| CLAIM_BATCH_TWO | batch_claim | 170,600 | 2 | no |
| CLAIM_DUST_RELEASE | dust_release | 43,562 | 1 | yes |

## Coordinator-Extended Scenario Simulation

These values use the reference fee coefficient at `1x`. Customer-fault and teacher-fault resolutions carry half-price revenue, so the denominator uses `revenueWeight = 1 - 0.5 * (p(CF) + p(TF))`.

| Window | Coordinator case | p(FV) | p(CF) | p(TF) | Lesson gas | Claim gas | Claim-inclusive gas | Revenue weight | Claim-inclusive cost / attempted lesson | Claim gas share | Share at $50 | Share at $100 | Share at $150 |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Demand-first | No coordinator | 0.000% | 0.000% | 0.000% | 399,352 | 19,095 | 418,447 | 100.000% | $0.0063 | 4.563% | 0.013% | 0.006% | 0.004% |
| Demand-first | Low coordinator | 1.000% | 0.300% | 0.200% | 398,799 | 18,985 | 417,784 | 99.750% | $0.0063 | 4.544% | 0.013% | 0.006% | 0.004% |
| Demand-first | Elevated coordinator | 5.000% | 2.000% | 1.000% | 396,565 | 18,450 | 415,015 | 98.500% | $0.0062 | 4.446% | 0.013% | 0.006% | 0.004% |
| Demand-first | Coordinator stress | 10.000% | 5.000% | 3.000% | 393,848 | 17,571 | 411,419 | 96.000% | $0.0062 | 4.271% | 0.013% | 0.006% | 0.004% |
| Supply-first | No coordinator | 0.000% | 0.000% | 0.000% | 426,397 | 55,239 | 481,636 | 100.000% | $0.0072 | 11.469% | 0.014% | 0.007% | 0.005% |
| Supply-first | Low coordinator | 1.000% | 0.300% | 0.200% | 426,010 | 54,968 | 480,979 | 99.750% | $0.0072 | 11.428% | 0.014% | 0.007% | 0.005% |
| Supply-first | Elevated coordinator | 5.000% | 2.000% | 1.000% | 424,364 | 53,609 | 477,973 | 98.500% | $0.0072 | 11.216% | 0.015% | 0.007% | 0.005% |
| Supply-first | Coordinator stress | 10.000% | 5.000% | 3.000% | 422,422 | 51,339 | 473,761 | 96.000% | $0.0071 | 10.836% | 0.015% | 0.007% | 0.005% |
| Synchronised | No coordinator | 0.000% | 0.000% | 0.000% | 470,046 | 90,311 | 560,357 | 100.000% | $0.0084 | 16.117% | 0.017% | 0.008% | 0.006% |
| Synchronised | Low coordinator | 1.000% | 0.300% | 0.200% | 469,705 | 89,908 | 559,614 | 99.750% | $0.0084 | 16.066% | 0.017% | 0.008% | 0.006% |
| Synchronised | Elevated coordinator | 5.000% | 2.000% | 1.000% | 468,104 | 87,848 | 555,952 | 98.500% | $0.0083 | 15.801% | 0.017% | 0.008% | 0.006% |
| Synchronised | Coordinator stress | 10.000% | 5.000% | 3.000% | 466,082 | 84,373 | 550,455 | 96.000% | $0.0082 | 15.328% | 0.017% | 0.009% | 0.006% |

## Coordinator Stress With Fee Multiplier

| Window | Fee multiplier | Lesson gas | Claim gas | Claim-inclusive gas | Claim-inclusive cost / attempted lesson | Share at $50 | Share at $100 | Share at $150 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Demand-first | 1x | 393,848 | 17,571 | 411,419 | $0.0062 | 0.013% | 0.006% | 0.004% |
| Demand-first | 10x | 393,848 | 17,571 | 411,419 | $0.0616 | 0.128% | 0.064% | 0.043% |
| Supply-first | 1x | 422,422 | 51,339 | 473,761 | $0.0071 | 0.015% | 0.007% | 0.005% |
| Supply-first | 10x | 422,422 | 51,339 | 473,761 | $0.0709 | 0.148% | 0.074% | 0.049% |
| Synchronised | 1x | 466,082 | 84,373 | 550,455 | $0.0082 | 0.017% | 0.009% | 0.006% |
| Synchronised | 10x | 466,082 | 84,373 | 550,455 | $0.0824 | 0.172% | 0.086% | 0.057% |

## Chapter Scale Tables

### Demand-first expansion

| Teachers | Active students | Realised lessons / month | Throughput bottleneck | Estimated claim-inclusive management cost / month |
|---:|---:|---:|---|---:|
| 100 | 480 | 2880 | demand side | $18.03 |
| 110 | 545 | 3270 | demand side | $20.47 |
| 125 | 620 | 3720 | demand side, near-balanced | $23.29 |

### Supply-first product expansion

| Teachers | Active students | Main research NFTs | Realised lessons / month | Throughput bottleneck | Estimated claim-inclusive management cost / month |
|---:|---:|---:|---:|---|---:|
| 100 | 500 | 50 | 3000 | balanced | $21.62 |
| 120 | 540 | 80 | 3240 | student side | $23.35 |
| 145 | 600 | 120 | 3600 | student side | $25.94 |

### Synchronised expansion

| Teachers | Active students | Main research NFTs | Realised lessons / month | Throughput bottleneck | Estimated claim-inclusive management cost / month |
|---:|---:|---:|---:|---|---:|
| 100 | 500 | 45 | 3000 | balanced | $25.15 |
| 120 | 600 | 52 | 3600 | balanced | $30.18 |
| 150 | 750 | 62 | 4500 | balanced | $37.72 |

### Research maintenance

Research gas source:

| Component | Gas |
|---|---:|
| New main research NFT bootstrap | 516,695 |
| Periodic update bundle | 353,919 |
| Extra prepared position | 259,356 |

| Teachers | Active students | Existing main research NFTs | New main research NFTs | Update cadence | Extra structure per update | Estimated research-maintenance cost / month | Estimated fixed-mix cost / month | Uplift vs fixed-mix lesson baseline |
|---:|---:|---:|---:|---|---|---:|---:|---:|
| 120 | 600 | 60 | 0 | annual | none | $0.03 | $30.21 | 0.088% |
| 120 | 600 | 60 | 0 | semiannual | none | $0.05 | $30.23 | 0.175% |
| 120 | 600 | 60 | 0 | semiannual | +20 extra prepared positions across the catalogue per cycle | $0.07 | $30.25 | 0.218% |
| 120 | 600 | 60 | 6 per 6 months | semiannual | none | $0.06 | $30.24 | 0.201% |

### Cost share under lesson pricing

| Revenue / lesson | Lesson settlement cost / lesson | Distributor claim cost / lesson | Claim-inclusive on-chain cost / lesson | Claim-inclusive cost share of revenue |
|---:|---:|---:|---:|---:|
| $50 | $0.0060-$0.0070 | $0.0003-$0.0014 | $0.0063-$0.0084 | 0.013%-0.017% |
| $100 | $0.0060-$0.0070 | $0.0003-$0.0014 | $0.0063-$0.0084 | 0.0063%-0.0084% |
| $150 | $0.0060-$0.0070 | $0.0003-$0.0014 | $0.0063-$0.0084 | 0.0042%-0.0056% |
