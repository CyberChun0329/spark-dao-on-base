# Teaching Cost Simulation

Generated from `teaching_gas_calibration.csv`.

Reference translation coefficient:

```text
referenceUsdPerGas = 1.4960545778707655e-8
source = trailing-twelve-month Base fee translation coefficient
measurementWindow = trailing twelve months at calibration time
unit = dollars per gas unit
```

The simulation uses `lesson_gas` for lesson-driven cost. `setup_gas` is reported separately because research setup and catalogue maintenance are low-frequency components in the model. Research maintenance rows are generated from `research_gas_calibration.csv`.

## Measured Contract Paths

| Path | Category | Setup gas | Lesson gas | Total gas | Revenue weight |
|---|---|---:|---:|---:|---|
| ORD_NR | ordinary | 0 | 395,611 | 395,611 | 100.000% |
| ORD_ZS | ordinary | 511,525 | 365,597 | 877,122 | 100.000% |
| ORD_RB | ordinary | 763,998 | 492,335 | 1,256,333 | 100.000% |
| ORD_WM | ordinary | 956,677 | 564,524 | 1,521,201 | 100.000% |
| ORD_ML | ordinary | 1,480,721 | 744,436 | 2,225,157 | 100.000% |
| FV_NR | forced_valid | 0 | 297,853 | 297,853 | 100.000% |
| FV_ZS | forced_valid | 478,360 | 342,042 | 820,402 | 100.000% |
| FV_RB | forced_valid | 740,087 | 461,479 | 1,201,566 | 100.000% |
| FV_WM | forced_valid | 956,746 | 560,873 | 1,517,619 | 100.000% |
| FV_ML | forced_valid | 1,437,023 | 740,785 | 2,177,808 | 100.000% |
| CF_NR | customer_fault | 0 | 361,977 | 361,977 | 50.000% |
| CF_ZS | customer_fault | 478,397 | 406,167 | 884,564 | 50.000% |
| CF_RB | customer_fault | 740,135 | 406,205 | 1,146,340 | 50.000% |
| CF_WM | customer_fault | 956,816 | 408,555 | 1,365,371 | 50.000% |
| CF_ML | customer_fault | 1,437,125 | 586,475 | 2,023,600 | 50.000% |
| TF_NR | teacher_fault | 0 | 365,343 | 365,343 | 50.000% |
| TF_ZS | teacher_fault | 478,432 | 409,535 | 887,967 | 50.000% |
| TF_RB | teacher_fault | 740,247 | 528,967 | 1,269,214 | 50.000% |
| TF_WM | teacher_fault | 956,885 | 628,372 | 1,585,257 | 50.000% |
| TF_ML | teacher_fault | 1,437,227 | 808,285 | 2,245,512 | 50.000% |

## Coordinator-Extended Scenario Simulation

These values use the reference fee coefficient at `1x`. Customer-fault and teacher-fault resolutions carry half-price revenue, so the denominator uses `revenueWeight = 1 - 0.5 * (p(CF) + p(TF))`.

| Window | Coordinator case | p(FV) | p(CF) | p(TF) | Expected gas / attempted lesson | Revenue weight | Cost / attempted lesson | Share at $50 | Share at $100 | Share at $150 |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Demand-first | No coordinator | 0.000% | 0.000% | 0.000% | 399,281 | 100.000% | $0.0060 | 0.012% | 0.006% | 0.004% |
| Demand-first | Low coordinator | 1.000% | 0.300% | 0.200% | 398,429 | 99.750% | $0.0060 | 0.012% | 0.006% | 0.004% |
| Demand-first | Elevated coordinator | 5.000% | 2.000% | 1.000% | 394,901 | 98.500% | $0.0059 | 0.012% | 0.006% | 0.004% |
| Demand-first | Coordinator stress | 10.000% | 5.000% | 3.000% | 390,194 | 96.000% | $0.0058 | 0.012% | 0.006% | 0.004% |
| Supply-first | No coordinator | 0.000% | 0.000% | 0.000% | 424,344 | 100.000% | $0.0063 | 0.013% | 0.006% | 0.004% |
| Supply-first | Low coordinator | 1.000% | 0.300% | 0.200% | 423,688 | 99.750% | $0.0063 | 0.013% | 0.006% | 0.004% |
| Supply-first | Elevated coordinator | 5.000% | 2.000% | 1.000% | 420,877 | 98.500% | $0.0063 | 0.013% | 0.006% | 0.004% |
| Supply-first | Coordinator stress | 10.000% | 5.000% | 3.000% | 417,143 | 96.000% | $0.0062 | 0.013% | 0.007% | 0.004% |
| Synchronised | No coordinator | 0.000% | 0.000% | 0.000% | 465,013 | 100.000% | $0.0070 | 0.014% | 0.007% | 0.005% |
| Synchronised | Low coordinator | 1.000% | 0.300% | 0.200% | 464,448 | 99.750% | $0.0069 | 0.014% | 0.007% | 0.005% |
| Synchronised | Elevated coordinator | 5.000% | 2.000% | 1.000% | 461,876 | 98.500% | $0.0069 | 0.014% | 0.007% | 0.005% |
| Synchronised | Coordinator stress | 10.000% | 5.000% | 3.000% | 458,361 | 96.000% | $0.0069 | 0.014% | 0.007% | 0.005% |

## Coordinator Stress With Fee Multiplier

| Window | Fee multiplier | Expected gas / attempted lesson | Cost / attempted lesson | Share at $50 | Share at $100 | Share at $150 |
|---|---:|---:|---:|---:|---:|---:|
| Demand-first | 1x | 390,194 | $0.0058 | 0.012% | 0.006% | 0.004% |
| Demand-first | 10x | 390,194 | $0.0584 | 0.122% | 0.061% | 0.041% |
| Supply-first | 1x | 417,143 | $0.0062 | 0.013% | 0.007% | 0.004% |
| Supply-first | 10x | 417,143 | $0.0624 | 0.130% | 0.065% | 0.043% |
| Synchronised | 1x | 458,361 | $0.0069 | 0.014% | 0.007% | 0.005% |
| Synchronised | 10x | 458,361 | $0.0686 | 0.143% | 0.071% | 0.048% |

## Chapter Scale Tables

### Demand-first expansion

| Teachers | Active students | Realised lessons / month | Throughput bottleneck | Estimated lesson-driven cost / month |
|---:|---:|---:|---|---:|
| 100 | 480 | 2880 | demand side | $17.20 |
| 110 | 545 | 3270 | demand side | $19.53 |
| 125 | 620 | 3720 | demand side, near-balanced | $22.22 |

### Supply-first product expansion

| Teachers | Active students | Main research NFTs | Realised lessons / month | Throughput bottleneck | Estimated lesson-driven cost / month |
|---:|---:|---:|---:|---|---:|
| 100 | 500 | 50 | 3000 | balanced | $19.05 |
| 120 | 540 | 80 | 3240 | student side | $20.57 |
| 145 | 600 | 120 | 3600 | student side | $22.85 |

### Synchronised expansion

| Teachers | Active students | Main research NFTs | Realised lessons / month | Throughput bottleneck | Estimated lesson-driven cost / month |
|---:|---:|---:|---:|---|---:|
| 100 | 500 | 45 | 3000 | balanced | $20.87 |
| 120 | 600 | 52 | 3600 | balanced | $25.04 |
| 150 | 750 | 62 | 4500 | balanced | $31.31 |

### Research maintenance

Research gas source:

| Component | Gas |
|---|---:|
| New main research NFT bootstrap | 516,695 |
| Periodic update bundle | 353,919 |
| Extra prepared position | 259,356 |

| Teachers | Active students | Existing main research NFTs | New main research NFTs | Update cadence | Extra structure per update | Estimated research-maintenance cost / month | Estimated fixed-mix cost / month | Uplift vs fixed-mix lesson baseline |
|---:|---:|---:|---:|---|---|---:|---:|---:|
| 120 | 600 | 60 | 0 | annual | none | $0.03 | $25.07 | 0.106% |
| 120 | 600 | 60 | 0 | semiannual | none | $0.05 | $25.10 | 0.211% |
| 120 | 600 | 60 | 0 | semiannual | +20 extra prepared positions across the catalogue per cycle | $0.07 | $25.11 | 0.263% |
| 120 | 600 | 60 | 6 per 6 months | semiannual | none | $0.06 | $25.11 | 0.242% |

### Cost share under lesson pricing

| Revenue / lesson | Window-specific on-chain cost / lesson | Lesson-driven cost share of revenue |
|---:|---:|---:|
| $50 | $0.0060-$0.0070 | 0.012%-0.014% |
| $100 | $0.0060-$0.0070 | 0.0060%-0.0070% |
| $150 | $0.0060-$0.0070 | 0.0040%-0.0046% |
