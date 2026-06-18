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
| ORD_NR | ordinary | 0 | 708,061 | 0 | 708,061 | 708,061 | 100.000% |
| ORD_ZS | ordinary | 521,574 | 678,895 | 0 | 678,895 | 1,200,469 | 100.000% |
| ORD_RB | ordinary | 761,388 | 866,071 | 194,334 | 1,060,405 | 1,821,793 | 100.000% |
| ORD_WM | ordinary | 955,785 | 960,150 | 171,895 | 1,132,045 | 2,087,830 | 100.000% |
| ORD_ML | ordinary | 1,478,484 | 1,139,596 | 170,894 | 1,310,490 | 2,788,974 | 100.000% |
| FV_NR | forced_valid | 0 | 630,326 | 0 | 630,326 | 630,326 | 100.000% |
| FV_ZS | forced_valid | 477,915 | 675,362 | 0 | 675,362 | 1,153,277 | 100.000% |
| FV_RB | forced_valid | 739,544 | 855,237 | 148,534 | 1,003,771 | 1,743,315 | 100.000% |
| FV_WM | forced_valid | 955,868 | 956,623 | 171,918 | 1,128,541 | 2,084,409 | 100.000% |
| FV_ML | forced_valid | 1,434,803 | 1,136,070 | 170,894 | 1,306,964 | 2,741,767 | 100.000% |
| CF_NR | customer_fault | 0 | 719,995 | 0 | 719,995 | 719,995 | 50.000% |
| CF_ZS | customer_fault | 477,958 | 765,034 | 0 | 765,034 | 1,242,992 | 50.000% |
| CF_RB | customer_fault | 739,612 | 824,879 | 0 | 824,879 | 1,564,491 | 50.000% |
| CF_WM | customer_fault | 955,951 | 828,302 | 0 | 828,302 | 1,784,253 | 50.000% |
| CF_ML | customer_fault | 1,434,921 | 1,005,755 | 0 | 1,005,755 | 2,440,676 | 50.000% |
| TF_NR | teacher_fault | 0 | 723,176 | 0 | 723,176 | 723,176 | 50.000% |
| TF_ZS | teacher_fault | 477,998 | 748,317 | 0 | 748,317 | 1,226,315 | 50.000% |
| TF_RB | teacher_fault | 739,646 | 948,087 | 148,534 | 1,096,621 | 1,836,267 | 50.000% |
| TF_WM | teacher_fault | 956,032 | 1,049,485 | 171,963 | 1,221,448 | 2,177,480 | 50.000% |
| TF_ML | teacher_fault | 1,435,041 | 1,228,931 | 170,894 | 1,399,825 | 2,834,866 | 50.000% |

## Measured Reward-Claim Primitives

| Claim path | Category | Claim gas | Claim count | Dust release |
|---|---|---:|---:|---|
| CLAIM_SINGLE_FULL | single_claim | 82,345 | 1 | no |
| CLAIM_BATCH_TWO | batch_claim | 172,002 | 2 | no |
| CLAIM_DUST_RELEASE | dust_release | 44,112 | 1 | yes |

## Coordinator-Extended Scenario Simulation

These values use the reference fee coefficient at `1x`. Customer-fault and teacher-fault resolutions carry half-price revenue, so the denominator uses `revenueWeight = 1 - 0.5 * (p(CF) + p(TF))`.

| Window | Coordinator case | p(FV) | p(CF) | p(TF) | Lesson gas | Claim gas | Claim-inclusive gas | Revenue weight | Claim-inclusive cost / attempted lesson | Claim gas share | Share at $50 | Share at $100 | Share at $150 |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Demand-first | No coordinator | 0.000% | 0.000% | 0.000% | 718,029 | 19,433 | 737,462 | 100.000% | $0.0110 | 2.635% | 0.022% | 0.011% | 0.007% |
| Demand-first | Low coordinator | 1.000% | 0.300% | 0.200% | 717,596 | 19,320 | 736,917 | 99.750% | $0.0110 | 2.622% | 0.022% | 0.011% | 0.007% |
| Demand-first | Elevated coordinator | 5.000% | 2.000% | 1.000% | 715,974 | 18,770 | 734,744 | 98.500% | $0.0110 | 2.555% | 0.022% | 0.011% | 0.007% |
| Demand-first | Coordinator stress | 10.000% | 5.000% | 3.000% | 714,461 | 17,866 | 732,328 | 96.000% | $0.0110 | 2.440% | 0.023% | 0.011% | 0.008% |
| Supply-first | No coordinator | 0.000% | 0.000% | 0.000% | 757,580 | 56,056 | 813,637 | 100.000% | $0.0122 | 6.890% | 0.024% | 0.012% | 0.008% |
| Supply-first | Low coordinator | 1.000% | 0.300% | 0.200% | 757,312 | 55,778 | 813,090 | 99.750% | $0.0122 | 6.860% | 0.024% | 0.012% | 0.008% |
| Supply-first | Elevated coordinator | 5.000% | 2.000% | 1.000% | 756,266 | 54,386 | 810,652 | 98.500% | $0.0121 | 6.709% | 0.025% | 0.012% | 0.008% |
| Supply-first | Coordinator stress | 10.000% | 5.000% | 3.000% | 755,501 | 52,063 | 807,564 | 96.000% | $0.0121 | 6.447% | 0.025% | 0.013% | 0.008% |
| Synchronised | No coordinator | 0.000% | 0.000% | 0.000% | 813,725 | 91,507 | 905,232 | 100.000% | $0.0135 | 10.109% | 0.027% | 0.014% | 0.009% |
| Synchronised | Low coordinator | 1.000% | 0.300% | 0.200% | 813,504 | 91,095 | 904,599 | 99.750% | $0.0135 | 10.070% | 0.027% | 0.014% | 0.009% |
| Synchronised | Elevated coordinator | 5.000% | 2.000% | 1.000% | 812,506 | 88,990 | 901,496 | 98.500% | $0.0135 | 9.871% | 0.027% | 0.014% | 0.009% |
| Synchronised | Coordinator stress | 10.000% | 5.000% | 3.000% | 811,673 | 85,444 | 897,117 | 96.000% | $0.0134 | 9.524% | 0.028% | 0.014% | 0.009% |

## Coordinator Stress With Fee Multiplier

| Window | Fee multiplier | Lesson gas | Claim gas | Claim-inclusive gas | Claim-inclusive cost / attempted lesson | Share at $50 | Share at $100 | Share at $150 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Demand-first | 1x | 714,461 | 17,866 | 732,328 | $0.0110 | 0.023% | 0.011% | 0.008% |
| Demand-first | 10x | 714,461 | 17,866 | 732,328 | $0.1096 | 0.228% | 0.114% | 0.076% |
| Supply-first | 1x | 755,501 | 52,063 | 807,564 | $0.0121 | 0.025% | 0.013% | 0.008% |
| Supply-first | 10x | 755,501 | 52,063 | 807,564 | $0.1208 | 0.252% | 0.126% | 0.084% |
| Synchronised | 1x | 811,673 | 85,444 | 897,117 | $0.0134 | 0.028% | 0.014% | 0.009% |
| Synchronised | 10x | 811,673 | 85,444 | 897,117 | $0.1342 | 0.280% | 0.140% | 0.093% |

## Chapter Scale Tables

### Demand-first expansion

| Teachers | Active students | Realised lessons / month | Throughput bottleneck | Estimated claim-inclusive management cost / month |
|---:|---:|---:|---|---:|
| 100 | 480 | 2880 | demand side | $31.77 |
| 110 | 545 | 3270 | demand side | $36.08 |
| 125 | 620 | 3720 | demand side, near-balanced | $41.04 |

### Supply-first product expansion

| Teachers | Active students | Main research NFTs | Realised lessons / month | Throughput bottleneck | Estimated claim-inclusive management cost / month |
|---:|---:|---:|---:|---|---:|
| 100 | 500 | 50 | 3000 | balanced | $36.52 |
| 120 | 540 | 80 | 3240 | student side | $39.44 |
| 145 | 600 | 120 | 3600 | student side | $43.82 |

### Synchronised expansion

| Teachers | Active students | Main research NFTs | Realised lessons / month | Throughput bottleneck | Estimated claim-inclusive management cost / month |
|---:|---:|---:|---:|---|---:|
| 100 | 500 | 45 | 3000 | balanced | $40.63 |
| 120 | 600 | 52 | 3600 | balanced | $48.75 |
| 150 | 750 | 62 | 4500 | balanced | $60.94 |

### Research maintenance

Research gas source:

| Component | Gas |
|---|---:|
| New main research NFT bootstrap | 516,870 |
| Periodic update bundle | 354,456 |
| Extra prepared position | 259,467 |

| Teachers | Active students | Existing main research NFTs | New main research NFTs | Update cadence | Extra structure per update | Estimated research-maintenance cost / month | Estimated fixed-mix cost / month | Uplift vs fixed-mix lesson baseline |
|---:|---:|---:|---:|---|---|---:|---:|---:|
| 120 | 600 | 60 | 0 | annual | none | $0.03 | $48.78 | 0.054% |
| 120 | 600 | 60 | 0 | semiannual | none | $0.05 | $48.81 | 0.109% |
| 120 | 600 | 60 | 0 | semiannual | +20 extra prepared positions across the catalogue per cycle | $0.07 | $48.82 | 0.135% |
| 120 | 600 | 60 | 6 per 6 months | semiannual | none | $0.06 | $48.81 | 0.125% |

### Cost share under lesson pricing

| Revenue / lesson | Lesson settlement cost / lesson | Distributor claim cost / lesson | Claim-inclusive on-chain cost / lesson | Claim-inclusive cost share of revenue |
|---:|---:|---:|---:|---:|
| $50 | $0.0107-$0.0122 | $0.0003-$0.0014 | $0.0110-$0.0135 | 0.022%-0.027% |
| $100 | $0.0107-$0.0122 | $0.0003-$0.0014 | $0.0110-$0.0135 | 0.011%-0.014% |
| $150 | $0.0107-$0.0122 | $0.0003-$0.0014 | $0.0110-$0.0135 | 0.0074%-0.0090% |
