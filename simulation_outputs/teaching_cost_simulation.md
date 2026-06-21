# Teaching Cost Simulation

Generated from `teaching_gas_calibration.csv`, `teaching_followup_gas_calibration.csv`, and `research_gas_calibration.csv`.

Reference translation coefficient:

```text
referenceUsdPerGas = 1.4960545778707655e-8
source = trailing-twelve-month Base fee translation coefficient
measurementWindow = trailing twelve months at calibration time
unit = dollars per gas unit
```

Generated from calibration CSVs. Management gas is `lesson_gas + claim_gas`.

## Measured Contract Paths

| Path | Category | Course type gas | Research setup gas | Research mutation gas | Lesson lifecycle gas | Distributor claim gas | Management gas | Coupled gas | Full fixture gas | Revenue weight |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| ORD_NR | ordinary | 198,894 | 0 | 0 | 708,420 | 0 | 708,420 | 708,420 | 907,314 | 100.000% |
| ORD_ZS | ordinary | 174,096 | 521,575 | 0 | 679,254 | 0 | 679,254 | 679,254 | 1,374,925 | 100.000% |
| ORD_RB | ordinary | 174,099 | 761,375 | 0 | 866,430 | 194,378 | 1,060,808 | 1,060,808 | 1,996,282 | 100.000% |
| ORD_WM | ordinary | 174,101 | 955,789 | 0 | 960,510 | 171,914 | 1,132,424 | 1,132,424 | 2,262,314 | 100.000% |
| ORD_ML | ordinary | 174,104 | 1,478,491 | 177,426 | 962,510 | 170,938 | 1,133,448 | 1,310,874 | 2,963,469 | 100.000% |
| FV_NR | forced_valid | 174,106 | 0 | 0 | 630,667 | 0 | 630,667 | 630,667 | 804,773 | 100.000% |
| FV_ZS | forced_valid | 174,108 | 477,921 | 0 | 675,704 | 0 | 675,704 | 675,704 | 1,327,733 | 100.000% |
| FV_RB | forced_valid | 174,111 | 739,526 | 0 | 855,580 | 148,578 | 1,004,158 | 1,004,158 | 1,917,795 | 100.000% |
| FV_WM | forced_valid | 174,113 | 955,881 | 0 | 956,968 | 171,939 | 1,128,907 | 1,128,907 | 2,258,901 | 100.000% |
| FV_ML | forced_valid | 174,116 | 1,434,825 | 177,426 | 958,967 | 170,938 | 1,129,905 | 1,307,331 | 2,916,272 | 100.000% |
| CF_NR | customer_fault | 174,117 | 0 | 0 | 720,319 | 0 | 720,319 | 720,319 | 894,436 | 50.000% |
| CF_ZS | customer_fault | 174,120 | 477,966 | 0 | 765,359 | 0 | 765,359 | 765,359 | 1,417,445 | 50.000% |
| CF_RB | customer_fault | 174,122 | 739,623 | 0 | 825,203 | 0 | 825,203 | 825,203 | 1,738,948 | 50.000% |
| CF_WM | customer_fault | 174,124 | 955,972 | 0 | 828,629 | 0 | 828,629 | 828,629 | 1,958,725 | 50.000% |
| CF_ML | customer_fault | 174,127 | 1,434,955 | 177,426 | 828,636 | 0 | 828,636 | 1,006,062 | 2,615,144 | 50.000% |
| TF_NR | teacher_fault | 174,128 | 0 | 0 | 723,493 | 0 | 723,493 | 723,493 | 897,621 | 50.000% |
| TF_ZS | teacher_fault | 174,131 | 478,011 | 0 | 748,635 | 0 | 748,635 | 748,635 | 1,400,777 | 50.000% |
| TF_RB | teacher_fault | 174,133 | 739,735 | 0 | 948,405 | 148,578 | 1,096,983 | 1,096,983 | 2,010,851 | 50.000% |
| TF_WM | teacher_fault | 174,135 | 956,062 | 0 | 1,049,807 | 171,988 | 1,221,795 | 1,221,795 | 2,351,992 | 50.000% |
| TF_ML | teacher_fault | 174,138 | 1,435,087 | 177,426 | 1,051,805 | 170,938 | 1,222,743 | 1,400,169 | 3,009,394 | 50.000% |

## Measured Follow-Up Primitives

| Follow-up path | Category | Gas | Measurement context | Included in scenario expectation |
|---|---|---:|---|---|
| TF_REMEDIAL_WAGE_CLOSE | remedial_wage | 9,814 | same-test-warm-call | no |

## Coordinator-Extended Scenario Simulation

Values use the reference fee coefficient at `1x`.

| Window | Coordinator case | p(FV) | p(CF) | p(TF) | Research mutation gas | Lesson gas | Claim gas | Management gas | Coupled gas | Revenue weight | Management cost / attempted lesson | Coupled cost / attempted lesson | Claim gas share | Share at $50 | Share at $100 | Share at $150 |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Demand-first | No coordinator | 0.000% | 0.000% | 0.000% | 0 | 718,388 | 19,438 | 737,826 | 737,826 | 100.000% | $0.0110 | $0.0110 | 2.634% | 0.022% | 0.011% | 0.007% |
| Demand-first | Low coordinator | 1.000% | 0.300% | 0.200% | 0 | 717,955 | 19,325 | 737,280 | 737,280 | 99.750% | $0.0110 | $0.0110 | 2.621% | 0.022% | 0.011% | 0.007% |
| Demand-first | Elevated coordinator | 5.000% | 2.000% | 1.000% | 0 | 716,331 | 18,774 | 735,106 | 735,106 | 98.500% | $0.0110 | $0.0110 | 2.554% | 0.022% | 0.011% | 0.007% |
| Demand-first | Coordinator stress | 10.000% | 5.000% | 3.000% | 0 | 714,816 | 17,871 | 732,686 | 732,686 | 96.000% | $0.0110 | $0.0110 | 2.439% | 0.023% | 0.011% | 0.008% |
| Supply-first | No coordinator | 0.000% | 0.000% | 0.000% | 0 | 757,940 | 56,067 | 814,007 | 814,007 | 100.000% | $0.0122 | $0.0122 | 6.888% | 0.024% | 0.012% | 0.008% |
| Supply-first | Low coordinator | 1.000% | 0.300% | 0.200% | 0 | 757,671 | 55,789 | 813,460 | 813,460 | 99.750% | $0.0122 | $0.0122 | 6.858% | 0.024% | 0.012% | 0.008% |
| Supply-first | Elevated coordinator | 5.000% | 2.000% | 1.000% | 0 | 756,623 | 54,396 | 811,019 | 811,019 | 98.500% | $0.0121 | $0.0121 | 6.707% | 0.025% | 0.012% | 0.008% |
| Supply-first | Coordinator stress | 10.000% | 5.000% | 3.000% | 0 | 755,855 | 52,073 | 807,929 | 807,929 | 96.000% | $0.0121 | $0.0121 | 6.445% | 0.025% | 0.013% | 0.008% |
| Synchronised | No coordinator | 0.000% | 0.000% | 0.000% | 8,871 | 805,212 | 91,524 | 896,736 | 905,607 | 100.000% | $0.0134 | $0.0135 | 10.206% | 0.027% | 0.013% | 0.009% |
| Synchronised | Low coordinator | 1.000% | 0.300% | 0.200% | 8,871 | 804,990 | 91,112 | 896,102 | 904,974 | 99.750% | $0.0134 | $0.0135 | 10.168% | 0.027% | 0.013% | 0.009% |
| Synchronised | Elevated coordinator | 5.000% | 2.000% | 1.000% | 8,871 | 803,991 | 89,007 | 892,998 | 901,869 | 98.500% | $0.0134 | $0.0135 | 9.967% | 0.027% | 0.014% | 0.009% |
| Synchronised | Coordinator stress | 10.000% | 5.000% | 3.000% | 8,871 | 803,156 | 85,460 | 888,616 | 897,487 | 96.000% | $0.0133 | $0.0134 | 9.617% | 0.028% | 0.014% | 0.009% |

## Chapter Scale Tables

### Demand-first expansion

| Teachers | Active students | Realised lessons / month | Throughput bottleneck | Estimated management cost / month |
|---:|---:|---:|---|---:|
| 100 | 480 | 2880 | demand side | $31.79 |
| 110 | 545 | 3270 | demand side | $36.10 |
| 125 | 620 | 3720 | demand side, near-balanced | $41.06 |

### Supply-first product expansion

| Teachers | Active students | Main research NFTs | Realised lessons / month | Throughput bottleneck | Estimated management cost / month |
|---:|---:|---:|---:|---|---:|
| 100 | 500 | 50 | 3000 | balanced | $36.53 |
| 120 | 540 | 80 | 3240 | student side | $39.46 |
| 145 | 600 | 120 | 3600 | student side | $43.84 |

### Synchronised expansion

| Teachers | Active students | Main research NFTs | Realised lessons / month | Throughput bottleneck | Estimated management cost / month |
|---:|---:|---:|---:|---|---:|
| 100 | 500 | 45 | 3000 | balanced | $40.25 |
| 120 | 600 | 52 | 3600 | balanced | $48.30 |
| 150 | 750 | 62 | 4500 | balanced | $60.37 |

### Research maintenance

New main research NFTs use the teaching-ready research asset primitive.

Research gas source:

| Component | Gas |
|---|---:|
| Research asset bootstrap | 516,870 |
| Teaching-ready research asset | 520,829 |
| Periodic update bundle | 354,456 |
| Extra prepared position | 259,467 |

| Teachers | Active students | Existing main research NFTs | New main research NFTs | Update cadence | Extra structure per update | Estimated research-maintenance cost / month | Estimated fixed-mix cost / month | Uplift vs fixed-mix lesson cost |
|---:|---:|---:|---:|---|---|---:|---:|---:|
| 120 | 600 | 60 | 0 | annual | none | $0.03 | $48.32 | 0.055% |
| 120 | 600 | 60 | 0 | semiannual | none | $0.05 | $48.35 | 0.110% |
| 120 | 600 | 60 | 0 | semiannual | +20 extra prepared positions across the catalogue per cycle | $0.07 | $48.36 | 0.137% |
| 120 | 600 | 60 | 6 per 6 months | semiannual | none | $0.06 | $48.36 | 0.126% |

### Cost share under lesson pricing

| Revenue / lesson | Lesson lifecycle cost / lesson | Distributor claim cost / lesson | Management cost / lesson | Management cost share of revenue |
|---:|---:|---:|---:|---:|
| $50 | $0.0107-$0.0120 | $0.0003-$0.0014 | $0.0110-$0.0134 | 0.022%-0.027% |
| $100 | $0.0107-$0.0120 | $0.0003-$0.0014 | $0.0110-$0.0134 | 0.011%-0.013% |
| $150 | $0.0107-$0.0120 | $0.0003-$0.0014 | $0.0110-$0.0134 | 0.0074%-0.0089% |
