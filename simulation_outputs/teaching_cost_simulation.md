# Teaching Cost Simulation

Generated from `teaching_gas_calibration.csv`.

Reference translation coefficient:

```text
referenceUsdPerGas = 1.4960545778707655e-8
source = 0.0133 / 889005
```

The simulation uses `lesson_gas` for lesson-driven cost. `setup_gas` is reported separately because research setup and catalogue maintenance are low-frequency components in the model. Research maintenance rows are generated from `research_gas_calibration.csv`.

## Measured Contract Paths

| Path | Category | Setup gas | Lesson gas | Total gas | Revenue weight |
|---|---|---:|---:|---:|---|
| ORD_NR | ordinary | 0 | 478,069 | 478,069 | 100.000% |
| ORD_ZS | ordinary | 375,030 | 434,716 | 809,746 | 100.000% |
| ORD_RB | ordinary | 581,434 | 607,561 | 1,188,995 | 100.000% |
| ORD_WM | ordinary | 683,687 | 589,640 | 1,273,327 | 100.000% |
| ORD_ML | ordinary | 1,163,387 | 630,366 | 1,793,753 | 100.000% |
| FV_NR | forced_valid | 0 | 367,104 | 367,104 | 100.000% |
| FV_ZS | forced_valid | 341,865 | 411,255 | 753,120 | 100.000% |
| FV_RB | forced_valid | 557,523 | 581,300 | 1,138,823 | 100.000% |
| FV_WM | forced_valid | 683,756 | 586,083 | 1,269,839 | 100.000% |
| FV_ML | forced_valid | 1,119,689 | 626,809 | 1,746,498 | 100.000% |
| CF_NR | customer_fault | 0 | 431,545 | 431,545 | 50.000% |
| CF_ZS | customer_fault | 341,902 | 475,695 | 817,597 | 50.000% |
| CF_RB | customer_fault | 557,571 | 475,701 | 1,033,272 | 50.000% |
| CF_WM | customer_fault | 683,826 | 477,978 | 1,161,804 | 50.000% |
| CF_ML | customer_fault | 1,119,791 | 513,400 | 1,633,191 | 50.000% |
| TF_NR | teacher_fault | 0 | 434,876 | 434,876 | 50.000% |
| TF_ZS | teacher_fault | 341,937 | 479,028 | 820,965 | 50.000% |
| TF_RB | teacher_fault | 557,683 | 649,074 | 1,206,757 | 50.000% |
| TF_WM | teacher_fault | 683,895 | 653,870 | 1,337,765 | 50.000% |
| TF_ML | teacher_fault | 1,119,893 | 694,596 | 1,814,489 | 50.000% |

## Coordinator-Extended Scenario Simulation

These values use the reference fee coefficient at `1x`. Customer-fault and teacher-fault resolutions carry half-price revenue, so the denominator uses `revenueWeight = 1 - 0.5 * (p(CF) + p(TF))`.

| Window | Coordinator case | p(FV) | p(CF) | p(TF) | Expected gas / attempted lesson | Revenue weight | Cost / attempted lesson | Share at $50 | Share at $100 | Share at $150 |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Demand-first | No coordinator | 0.000% | 0.000% | 0.000% | 482,348 | 100.000% | $0.0072 | 0.014% | 0.007% | 0.005% |
| Demand-first | Low coordinator | 1.000% | 0.300% | 0.200% | 481,351 | 99.750% | $0.0072 | 0.014% | 0.007% | 0.005% |
| Demand-first | Elevated coordinator | 5.000% | 2.000% | 1.000% | 477,175 | 98.500% | $0.0071 | 0.014% | 0.007% | 0.005% |
| Demand-first | Coordinator stress | 10.000% | 5.000% | 3.000% | 471,454 | 96.000% | $0.0071 | 0.015% | 0.007% | 0.005% |
| Supply-first | No coordinator | 0.000% | 0.000% | 0.000% | 504,286 | 100.000% | $0.0075 | 0.015% | 0.008% | 0.005% |
| Supply-first | Low coordinator | 1.000% | 0.300% | 0.200% | 503,540 | 99.750% | $0.0075 | 0.015% | 0.008% | 0.005% |
| Supply-first | Elevated coordinator | 5.000% | 2.000% | 1.000% | 500,315 | 98.500% | $0.0075 | 0.015% | 0.008% | 0.005% |
| Supply-first | Coordinator stress | 10.000% | 5.000% | 3.000% | 495,925 | 96.000% | $0.0074 | 0.015% | 0.008% | 0.005% |
| Synchronised | No coordinator | 0.000% | 0.000% | 0.000% | 531,700 | 100.000% | $0.0080 | 0.016% | 0.008% | 0.005% |
| Synchronised | Low coordinator | 1.000% | 0.300% | 0.200% | 531,090 | 99.750% | $0.0079 | 0.016% | 0.008% | 0.005% |
| Synchronised | Elevated coordinator | 5.000% | 2.000% | 1.000% | 528,314 | 98.500% | $0.0079 | 0.016% | 0.008% | 0.005% |
| Synchronised | Coordinator stress | 10.000% | 5.000% | 3.000% | 524,482 | 96.000% | $0.0078 | 0.016% | 0.008% | 0.005% |

## Coordinator Stress With Fee Multiplier

| Window | Fee multiplier | Expected gas / attempted lesson | Cost / attempted lesson | Share at $50 | Share at $100 | Share at $150 |
|---|---:|---:|---:|---:|---:|---:|
| Demand-first | 1x | 471,454 | $0.0071 | 0.015% | 0.007% | 0.005% |
| Demand-first | 10x | 471,454 | $0.0705 | 0.147% | 0.073% | 0.049% |
| Supply-first | 1x | 495,925 | $0.0074 | 0.015% | 0.008% | 0.005% |
| Supply-first | 10x | 495,925 | $0.0742 | 0.155% | 0.077% | 0.052% |
| Synchronised | 1x | 524,482 | $0.0078 | 0.016% | 0.008% | 0.005% |
| Synchronised | 10x | 524,482 | $0.0785 | 0.163% | 0.082% | 0.054% |

## Chapter Scale Tables

### Demand-first expansion

| Teachers | Active students | Realised lessons / month | Throughput bottleneck | Estimated lesson-driven cost / month |
|---:|---:|---:|---|---:|
| 100 | 480 | 2880 | demand side | $20.78 |
| 110 | 545 | 3270 | demand side | $23.60 |
| 125 | 620 | 3720 | demand side, near-balanced | $26.84 |

### Supply-first product expansion

| Teachers | Active students | Main research NFTs | Realised lessons / month | Throughput bottleneck | Estimated lesson-driven cost / month |
|---:|---:|---:|---:|---|---:|
| 100 | 500 | 50 | 3000 | balanced | $22.63 |
| 120 | 540 | 80 | 3240 | student side | $24.44 |
| 145 | 600 | 120 | 3600 | student side | $27.16 |

### Synchronised expansion

| Teachers | Active students | Main research NFTs | Realised lessons / month | Throughput bottleneck | Estimated lesson-driven cost / month |
|---:|---:|---:|---:|---|---:|
| 100 | 500 | 45 | 3000 | balanced | $23.86 |
| 120 | 600 | 52 | 3600 | balanced | $28.64 |
| 150 | 750 | 62 | 4500 | balanced | $35.80 |

### Research maintenance

Research gas source:

| Component | Gas |
|---|---:|
| New main research NFT bootstrap | 378,095 |
| Periodic update bundle | 260,324 |
| Extra prepared position | 237,054 |

| Teachers | Active students | Existing main research NFTs | New main research NFTs | Update cadence | Extra structure per update | Estimated research-maintenance cost / month | Estimated fixed-mix cost / month | Uplift vs fixed-mix lesson baseline |
|---:|---:|---:|---:|---|---|---:|---:|---:|
| 120 | 600 | 60 | 0 | annual | none | $0.02 | $28.66 | 0.068% |
| 120 | 600 | 60 | 0 | semiannual | none | $0.04 | $28.68 | 0.136% |
| 120 | 600 | 60 | 0 | semiannual | +20 extra prepared positions across the catalogue per cycle | $0.05 | $28.69 | 0.177% |
| 120 | 600 | 60 | 6 per 6 months | semiannual | none | $0.04 | $28.68 | 0.156% |

### Cost share under lesson pricing

| Revenue / lesson | Window-specific on-chain cost / lesson | Lesson-driven cost share of revenue |
|---:|---:|---:|
| $50 | $0.0072-$0.0080 | 0.014%-0.016% |
| $100 | $0.0072-$0.0080 | 0.0072%-0.0080% |
| $150 | $0.0072-$0.0080 | 0.0048%-0.0053% |
