# Teaching Cost Simulation

Generated from Teaching lifecycle calibration CSVs and `research_gas_calibration.csv`.

Reference translation coefficient:

```text
referenceUsdPerGas = 1.4960545778707655e-8
source = trailing-twelve-month Base fee translation coefficient
measurementWindow = trailing twelve months at calibration time
unit = dollars per gas unit
```

Generated from Teaching lifecycle calibration. Management gas is `lesson_gas + claim_gas`.

## Measured Contract Paths

| Path | Category | Course type gas | Research setup gas | Research mutation gas | Lesson lifecycle gas | Distributor claim gas | Management gas | Coupled gas | Full fixture gas | Revenue weight |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| ORD_NR | ordinary | 157,006 | 0 | 0 | 595,521 | 0 | 595,521 | 595,521 | 752,527 | 100.000% |
| ORD_ZS | ordinary | 141,208 | 519,587 | 0 | 547,194 | 0 | 547,194 | 547,194 | 1,207,989 | 100.000% |
| ORD_RB | ordinary | 141,211 | 761,400 | 0 | 732,961 | 194,318 | 927,279 | 927,279 | 1,829,890 | 100.000% |
| ORD_WM | ordinary | 141,213 | 955,816 | 0 | 829,221 | 171,855 | 1,001,076 | 1,001,076 | 2,098,105 | 100.000% |
| ORD_ML | ordinary | 141,217 | 1,478,547 | 177,418 | 831,223 | 170,878 | 1,002,101 | 1,179,519 | 2,799,283 | 100.000% |
| FV_NR | forced_valid | 141,219 | 0 | 0 | 497,348 | 0 | 497,348 | 497,348 | 638,567 | 100.000% |
| FV_ZS | forced_valid | 141,221 | 477,937 | 0 | 542,323 | 0 | 542,323 | 542,323 | 1,161,481 | 100.000% |
| FV_RB | forced_valid | 141,223 | 739,557 | 0 | 722,289 | 148,518 | 870,807 | 870,807 | 1,751,587 | 100.000% |
| FV_WM | forced_valid | 141,226 | 955,915 | 0 | 823,856 | 171,882 | 995,738 | 995,738 | 2,092,879 | 100.000% |
| FV_ML | forced_valid | 141,229 | 1,434,890 | 177,418 | 825,857 | 170,878 | 996,735 | 1,174,153 | 2,750,272 | 100.000% |
| CF_NR | customer_fault | 141,230 | 0 | 0 | 534,782 | 0 | 534,782 | 534,782 | 676,012 | 50.000% |
| CF_ZS | customer_fault | 141,233 | 477,985 | 0 | 559,860 | 0 | 559,860 | 559,860 | 1,179,078 | 50.000% |
| CF_RB | customer_fault | 141,235 | 739,659 | 0 | 599,826 | 0 | 599,826 | 599,826 | 1,480,720 | 50.000% |
| CF_WM | customer_fault | 141,238 | 956,013 | 0 | 603,191 | 0 | 603,191 | 603,191 | 1,700,442 | 50.000% |
| CF_ML | customer_fault | 141,241 | 1,435,028 | 177,418 | 603,201 | 0 | 603,201 | 780,619 | 2,356,888 | 50.000% |
| TF_NR | teacher_fault | 141,242 | 0 | 0 | 510,690 | 0 | 510,690 | 510,690 | 651,932 | 50.000% |
| TF_ZS | teacher_fault | 141,245 | 478,033 | 0 | 555,671 | 0 | 555,671 | 555,671 | 1,174,949 | 50.000% |
| TF_RB | teacher_fault | 141,248 | 739,774 | 0 | 735,636 | 148,518 | 884,154 | 884,154 | 1,765,176 | 50.000% |
| TF_WM | teacher_fault | 141,250 | 956,109 | 0 | 837,218 | 171,935 | 1,009,153 | 1,009,153 | 2,106,512 | 50.000% |
| TF_ML | teacher_fault | 141,253 | 1,435,169 | 177,418 | 839,220 | 170,878 | 1,010,098 | 1,187,516 | 2,763,938 | 50.000% |

## Measured Follow-Up Primitives

| Follow-up path | Category | Gas | Measurement context | Included in scenario expectation |
|---|---|---:|---|---|
| TF_REMEDIAL_WAGE_CLOSE | remedial_wage | 10,080 | same-test-warm-call | no |

## Coordinator-Extended Scenario Simulation

Values use the reference fee coefficient at `1x`.

| Window | Coordinator case | p(FV) | p(CF) | p(TF) | Research mutation gas | Lesson gas | Claim gas | Management gas | Coupled gas | Revenue weight | Management cost / attempted lesson | Coupled cost / attempted lesson | Claim gas share | Share at $50 | Share at $100 | Share at $150 |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Demand-first | No coordinator | 0.000% | 0.000% | 0.000% | 0 | 599,600 | 19,432 | 619,031 | 619,031 | 100.000% | $0.0093 | $0.0093 | 3.139% | 0.019% | 0.009% | 0.006% |
| Demand-first | Low coordinator | 1.000% | 0.300% | 0.200% | 0 | 598,617 | 19,319 | 617,936 | 617,936 | 99.750% | $0.0092 | $0.0092 | 3.126% | 0.019% | 0.009% | 0.006% |
| Demand-first | Elevated coordinator | 5.000% | 2.000% | 1.000% | 0 | 594,421 | 18,768 | 613,190 | 613,190 | 98.500% | $0.0092 | $0.0092 | 3.061% | 0.019% | 0.009% | 0.006% |
| Demand-first | Coordinator stress | 10.000% | 5.000% | 3.000% | 0 | 588,136 | 17,865 | 606,001 | 606,001 | 96.000% | $0.0091 | $0.0091 | 2.948% | 0.019% | 0.009% | 0.006% |
| Supply-first | No coordinator | 0.000% | 0.000% | 0.000% | 0 | 634,297 | 56,049 | 690,346 | 690,346 | 100.000% | $0.0103 | $0.0103 | 8.119% | 0.021% | 0.010% | 0.007% |
| Supply-first | Low coordinator | 1.000% | 0.300% | 0.200% | 0 | 633,527 | 55,771 | 689,298 | 689,298 | 99.750% | $0.0103 | $0.0103 | 8.091% | 0.021% | 0.010% | 0.007% |
| Supply-first | Elevated coordinator | 5.000% | 2.000% | 1.000% | 0 | 630,079 | 54,379 | 684,458 | 684,458 | 98.500% | $0.0102 | $0.0102 | 7.945% | 0.021% | 0.010% | 0.007% |
| Supply-first | Coordinator stress | 10.000% | 5.000% | 3.000% | 0 | 624,779 | 52,056 | 676,836 | 676,836 | 96.000% | $0.0101 | $0.0101 | 7.691% | 0.021% | 0.011% | 0.007% |
| Synchronised | No coordinator | 0.000% | 0.000% | 0.000% | 8,871 | 678,741 | 91,494 | 770,235 | 779,106 | 100.000% | $0.0115 | $0.0117 | 11.879% | 0.023% | 0.012% | 0.008% |
| Synchronised | Low coordinator | 1.000% | 0.300% | 0.200% | 8,871 | 678,037 | 91,083 | 769,120 | 777,991 | 99.750% | $0.0115 | $0.0116 | 11.842% | 0.023% | 0.012% | 0.008% |
| Synchronised | Elevated coordinator | 5.000% | 2.000% | 1.000% | 8,871 | 674,696 | 88,978 | 763,674 | 772,545 | 98.500% | $0.0114 | $0.0116 | 11.651% | 0.023% | 0.012% | 0.008% |
| Synchronised | Coordinator stress | 10.000% | 5.000% | 3.000% | 8,871 | 669,386 | 85,432 | 754,818 | 763,689 | 96.000% | $0.0113 | $0.0114 | 11.318% | 0.024% | 0.012% | 0.008% |

## Chapter Scale Tables

### Demand-first expansion

| Teachers | Active students | Realised lessons / month | Throughput bottleneck | Estimated management cost / month |
|---:|---:|---:|---|---:|
| 100 | 480 | 2880 | demand side | $26.67 |
| 110 | 545 | 3270 | demand side | $30.28 |
| 125 | 620 | 3720 | demand side, near-balanced | $34.45 |

### Supply-first product expansion

| Teachers | Active students | Main research NFTs | Realised lessons / month | Throughput bottleneck | Estimated management cost / month |
|---:|---:|---:|---:|---|---:|
| 100 | 500 | 50 | 3000 | balanced | $30.98 |
| 120 | 540 | 80 | 3240 | student side | $33.46 |
| 145 | 600 | 120 | 3600 | student side | $37.18 |

### Synchronised expansion

| Teachers | Active students | Main research NFTs | Realised lessons / month | Throughput bottleneck | Estimated management cost / month |
|---:|---:|---:|---:|---|---:|
| 100 | 500 | 45 | 3000 | balanced | $34.57 |
| 120 | 600 | 52 | 3600 | balanced | $41.48 |
| 150 | 750 | 62 | 4500 | balanced | $51.85 |

### Research maintenance

New main research NFTs use the teaching-ready research asset primitive.

Research gas source:

| Component | Gas |
|---|---:|
| Research asset bootstrap | 514,882 |
| Teaching-ready research asset | 518,841 |
| Periodic update bundle | 354,468 |
| Extra prepared position | 259,479 |

| Teachers | Active students | Existing main research NFTs | New main research NFTs | Update cadence | Extra structure per update | Estimated research-maintenance cost / month | Estimated fixed-mix cost / month | Uplift vs fixed-mix lesson cost |
|---:|---:|---:|---:|---|---|---:|---:|---:|
| 120 | 600 | 60 | 0 | annual | none | $0.03 | $41.51 | 0.064% |
| 120 | 600 | 60 | 0 | semiannual | none | $0.05 | $41.54 | 0.128% |
| 120 | 600 | 60 | 0 | semiannual | +20 extra prepared positions across the catalogue per cycle | $0.07 | $41.55 | 0.159% |
| 120 | 600 | 60 | 6 per 6 months | semiannual | none | $0.06 | $41.54 | 0.147% |

### Cost share under lesson pricing

| Revenue / lesson | Lesson lifecycle cost / lesson | Distributor claim cost / lesson | Management cost / lesson | Management cost share of revenue |
|---:|---:|---:|---:|---:|
| $50 | $0.0090-$0.0102 | $0.0003-$0.0014 | $0.0093-$0.0115 | 0.019%-0.023% |
| $100 | $0.0090-$0.0102 | $0.0003-$0.0014 | $0.0093-$0.0115 | 0.0093%-0.012% |
| $150 | $0.0090-$0.0102 | $0.0003-$0.0014 | $0.0093-$0.0115 | 0.0062%-0.0077% |
