# Teaching Cost Simulation

Generated from `teaching_gas_calibration.csv`, `teaching_claim_gas_calibration.csv`, and `research_gas_calibration.csv`.

Reference translation coefficient:

```text
referenceUsdPerGas = 1.4960545778707655e-8
source = trailing-twelve-month Base fee translation coefficient
measurementWindow = trailing twelve months at calibration time
unit = dollars per gas unit
```

The simulation uses `lesson_gas + claim_gas` for the recurring teaching-management coefficient. `lesson_gas` measures settlement through `TeachingRegistry`, including the deployed `TeachingPolicyGuard` / policy quote path for economics and fault cases; `claim_gas` measures reward withdrawal through `TeachingRewardDistributor`. `setup_gas` is reported separately because research setup and catalogue maintenance are low-frequency components in the model. Claim primitives below record single-claim, batch-claim, and dust-release paths, while the path table reports the deterministic claim policy used by the calibration test.

## Measured Contract Paths

| Path | Category | Setup gas | Lesson settlement gas | Distributor claim gas | Claim-inclusive management gas | Total gas | Revenue weight |
|---|---|---:|---:|---:|---:|---:|---|
| ORD_NR | ordinary | 0 | 708,722 | 0 | 708,722 | 708,722 | 100.000% |
| ORD_ZS | ordinary | 521,574 | 679,556 | 0 | 679,556 | 1,201,130 | 100.000% |
| ORD_RB | ordinary | 761,388 | 866,914 | 194,640 | 1,061,554 | 1,822,942 | 100.000% |
| ORD_WM | ordinary | 955,785 | 961,232 | 172,183 | 1,133,415 | 2,089,200 | 100.000% |
| ORD_ML | ordinary | 1,478,484 | 1,140,678 | 171,182 | 1,311,860 | 2,790,344 | 100.000% |
| FV_NR | forced_valid | 0 | 631,089 | 0 | 631,089 | 631,089 | 100.000% |
| FV_ZS | forced_valid | 477,915 | 676,125 | 0 | 676,125 | 1,154,040 | 100.000% |
| FV_RB | forced_valid | 739,544 | 856,182 | 148,840 | 1,005,022 | 1,744,566 | 100.000% |
| FV_WM | forced_valid | 955,868 | 957,807 | 172,206 | 1,130,013 | 2,085,881 | 100.000% |
| FV_ML | forced_valid | 1,434,803 | 1,137,254 | 171,182 | 1,308,436 | 2,743,239 | 100.000% |
| CF_NR | customer_fault | 0 | 720,589 | 0 | 720,589 | 720,589 | 50.000% |
| CF_ZS | customer_fault | 477,958 | 765,628 | 0 | 765,628 | 1,243,586 | 50.000% |
| CF_RB | customer_fault | 739,612 | 825,473 | 0 | 825,473 | 1,565,085 | 50.000% |
| CF_WM | customer_fault | 955,951 | 828,896 | 0 | 828,896 | 1,784,847 | 50.000% |
| CF_ML | customer_fault | 1,434,921 | 1,006,349 | 0 | 1,006,349 | 2,441,270 | 50.000% |
| TF_NR | teacher_fault | 0 | 723,778 | 0 | 723,778 | 723,778 | 50.000% |
| TF_ZS | teacher_fault | 477,998 | 748,919 | 0 | 748,919 | 1,226,917 | 50.000% |
| TF_RB | teacher_fault | 739,646 | 948,871 | 148,840 | 1,097,711 | 1,837,357 | 50.000% |
| TF_WM | teacher_fault | 956,032 | 1,050,508 | 172,251 | 1,222,759 | 2,178,791 | 50.000% |
| TF_ML | teacher_fault | 1,435,041 | 1,229,954 | 171,182 | 1,401,136 | 2,836,177 | 50.000% |

## Measured Reward-Claim Primitives

| Claim path | Category | Claim gas | Claim count | Dust release |
|---|---|---:|---:|---|
| CLAIM_SINGLE_FULL | single_claim | 82,489 | 1 | no |
| CLAIM_BATCH_TWO | batch_claim | 172,290 | 2 | no |
| CLAIM_DUST_RELEASE | dust_release | 44,481 | 1 | yes |

## Coordinator-Extended Scenario Simulation

These values use the reference fee coefficient at `1x`. Customer-fault and teacher-fault resolutions carry half-price revenue, so the denominator uses `revenueWeight = 1 - 0.5 * (p(CF) + p(TF))`.

| Window | Coordinator case | p(FV) | p(CF) | p(TF) | Lesson gas | Claim gas | Claim-inclusive gas | Revenue weight | Claim-inclusive cost / attempted lesson | Claim gas share | Share at $50 | Share at $100 | Share at $150 |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Demand-first | No coordinator | 0.000% | 0.000% | 0.000% | 718,708 | 19,464 | 738,172 | 100.000% | $0.0110 | 2.637% | 0.022% | 0.011% | 0.007% |
| Demand-first | Low coordinator | 1.000% | 0.300% | 0.200% | 718,276 | 19,351 | 737,627 | 99.750% | $0.0110 | 2.623% | 0.022% | 0.011% | 0.007% |
| Demand-first | Elevated coordinator | 5.000% | 2.000% | 1.000% | 716,656 | 18,800 | 735,456 | 98.500% | $0.0110 | 2.556% | 0.022% | 0.011% | 0.007% |
| Demand-first | Coordinator stress | 10.000% | 5.000% | 3.000% | 715,145 | 17,895 | 733,040 | 96.000% | $0.0110 | 2.441% | 0.023% | 0.011% | 0.008% |
| Supply-first | No coordinator | 0.000% | 0.000% | 0.000% | 758,320 | 56,146 | 814,466 | 100.000% | $0.0122 | 6.894% | 0.024% | 0.012% | 0.008% |
| Supply-first | Low coordinator | 1.000% | 0.300% | 0.200% | 758,052 | 55,868 | 813,920 | 99.750% | $0.0122 | 6.864% | 0.024% | 0.012% | 0.008% |
| Supply-first | Elevated coordinator | 5.000% | 2.000% | 1.000% | 757,007 | 54,474 | 811,481 | 98.500% | $0.0121 | 6.713% | 0.025% | 0.012% | 0.008% |
| Supply-first | Coordinator stress | 10.000% | 5.000% | 3.000% | 756,242 | 52,149 | 808,390 | 96.000% | $0.0121 | 6.451% | 0.025% | 0.013% | 0.008% |
| Synchronised | No coordinator | 0.000% | 0.000% | 0.000% | 814,537 | 91,656 | 906,192 | 100.000% | $0.0136 | 10.114% | 0.027% | 0.014% | 0.009% |
| Synchronised | Low coordinator | 1.000% | 0.300% | 0.200% | 814,316 | 91,243 | 905,559 | 99.750% | $0.0135 | 10.076% | 0.027% | 0.014% | 0.009% |
| Synchronised | Elevated coordinator | 5.000% | 2.000% | 1.000% | 813,317 | 89,136 | 902,453 | 98.500% | $0.0135 | 9.877% | 0.027% | 0.014% | 0.009% |
| Synchronised | Coordinator stress | 10.000% | 5.000% | 3.000% | 812,483 | 85,585 | 898,068 | 96.000% | $0.0134 | 9.530% | 0.028% | 0.014% | 0.009% |

## Coordinator Stress With Fee Multiplier

| Window | Fee multiplier | Lesson gas | Claim gas | Claim-inclusive gas | Claim-inclusive cost / attempted lesson | Share at $50 | Share at $100 | Share at $150 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Demand-first | 1x | 715,145 | 17,895 | 733,040 | $0.0110 | 0.023% | 0.011% | 0.008% |
| Demand-first | 10x | 715,145 | 17,895 | 733,040 | $0.1097 | 0.228% | 0.114% | 0.076% |
| Supply-first | 1x | 756,242 | 52,149 | 808,390 | $0.0121 | 0.025% | 0.013% | 0.008% |
| Supply-first | 10x | 756,242 | 52,149 | 808,390 | $0.1209 | 0.252% | 0.126% | 0.084% |
| Synchronised | 1x | 812,483 | 85,585 | 898,068 | $0.0134 | 0.028% | 0.014% | 0.009% |
| Synchronised | 10x | 812,483 | 85,585 | 898,068 | $0.1344 | 0.280% | 0.140% | 0.093% |

## Chapter Scale Tables

### Demand-first expansion

| Teachers | Active students | Realised lessons / month | Throughput bottleneck | Estimated claim-inclusive management cost / month |
|---:|---:|---:|---|---:|
| 100 | 480 | 2880 | demand side | $31.81 |
| 110 | 545 | 3270 | demand side | $36.11 |
| 125 | 620 | 3720 | demand side, near-balanced | $41.08 |

### Supply-first product expansion

| Teachers | Active students | Main research NFTs | Realised lessons / month | Throughput bottleneck | Estimated claim-inclusive management cost / month |
|---:|---:|---:|---:|---|---:|
| 100 | 500 | 50 | 3000 | balanced | $36.55 |
| 120 | 540 | 80 | 3240 | student side | $39.48 |
| 145 | 600 | 120 | 3600 | student side | $43.87 |

### Synchronised expansion

| Teachers | Active students | Main research NFTs | Realised lessons / month | Throughput bottleneck | Estimated claim-inclusive management cost / month |
|---:|---:|---:|---:|---|---:|
| 100 | 500 | 45 | 3000 | balanced | $40.67 |
| 120 | 600 | 52 | 3600 | balanced | $48.81 |
| 150 | 750 | 62 | 4500 | balanced | $61.01 |

### Research maintenance

Research gas source:

| Component | Gas |
|---|---:|
| New main research NFT bootstrap | 516,870 |
| Periodic update bundle | 354,456 |
| Extra prepared position | 259,467 |

| Teachers | Active students | Existing main research NFTs | New main research NFTs | Update cadence | Extra structure per update | Estimated research-maintenance cost / month | Estimated fixed-mix cost / month | Uplift vs fixed-mix lesson baseline |
|---:|---:|---:|---:|---|---|---:|---:|---:|
| 120 | 600 | 60 | 0 | annual | none | $0.03 | $48.83 | 0.054% |
| 120 | 600 | 60 | 0 | semiannual | none | $0.05 | $48.86 | 0.109% |
| 120 | 600 | 60 | 0 | semiannual | +20 extra prepared positions across the catalogue per cycle | $0.07 | $48.87 | 0.135% |
| 120 | 600 | 60 | 6 per 6 months | semiannual | none | $0.06 | $48.87 | 0.124% |

### Cost share under lesson pricing

| Revenue / lesson | Lesson settlement cost / lesson | Distributor claim cost / lesson | Claim-inclusive on-chain cost / lesson | Claim-inclusive cost share of revenue |
|---:|---:|---:|---:|---:|
| $50 | $0.0108-$0.0122 | $0.0003-$0.0014 | $0.0110-$0.0136 | 0.022%-0.027% |
| $100 | $0.0108-$0.0122 | $0.0003-$0.0014 | $0.0110-$0.0136 | 0.011%-0.014% |
| $150 | $0.0108-$0.0122 | $0.0003-$0.0014 | $0.0110-$0.0136 | 0.0074%-0.0090% |
