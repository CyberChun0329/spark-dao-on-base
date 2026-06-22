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
| ORD_NR | ordinary | 135,600 | 0 | 0 | 525,232 | 0 | 525,232 | 525,232 | 660,832 | 100.000% |
| ORD_ZS | ordinary | 119,802 | 518,166 | 0 | 476,914 | 0 | 476,914 | 476,914 | 1,114,882 | 100.000% |
| ORD_RB | ordinary | 119,805 | 759,231 | 0 | 581,554 | 121,083 | 702,637 | 702,637 | 1,581,673 | 100.000% |
| ORD_WM | ordinary | 119,808 | 952,976 | 0 | 656,326 | 76,701 | 733,027 | 733,027 | 1,805,811 | 100.000% |
| ORD_ML | ordinary | 119,811 | 1,475,338 | 173,172 | 658,352 | 75,666 | 734,018 | 907,190 | 2,502,339 | 100.000% |
| FV_NR | forced_valid | 119,813 | 0 | 0 | 427,773 | 0 | 427,773 | 427,773 | 547,586 | 100.000% |
| FV_ZS | forced_valid | 119,815 | 476,516 | 0 | 472,757 | 0 | 472,757 | 472,757 | 1,069,088 | 100.000% |
| FV_RB | forced_valid | 119,817 | 737,381 | 0 | 571,596 | 75,283 | 646,879 | 646,879 | 1,504,077 | 100.000% |
| FV_WM | forced_valid | 119,820 | 953,074 | 0 | 651,675 | 76,728 | 728,403 | 728,403 | 1,801,297 | 100.000% |
| FV_ML | forced_valid | 119,823 | 1,431,681 | 173,172 | 653,701 | 75,666 | 729,367 | 902,539 | 2,454,043 | 100.000% |
| CF_NR | customer_fault | 119,825 | 0 | 0 | 489,221 | 0 | 489,221 | 489,221 | 609,046 | 50.000% |
| CF_ZS | customer_fault | 119,827 | 476,565 | 0 | 514,308 | 0 | 514,308 | 514,308 | 1,110,700 | 50.000% |
| CF_RB | customer_fault | 119,830 | 737,544 | 0 | 534,374 | 0 | 534,374 | 534,374 | 1,391,748 | 50.000% |
| CF_WM | customer_fault | 119,833 | 953,171 | 0 | 537,729 | 0 | 537,729 | 537,729 | 1,610,733 | 50.000% |
| CF_ML | customer_fault | 119,835 | 1,431,819 | 173,172 | 537,738 | 0 | 537,738 | 710,910 | 2,262,564 | 50.000% |
| TF_NR | teacher_fault | 119,837 | 0 | 0 | 439,500 | 0 | 439,500 | 439,500 | 559,337 | 50.000% |
| TF_ZS | teacher_fault | 119,839 | 476,613 | 0 | 484,489 | 0 | 484,489 | 484,489 | 1,080,941 | 50.000% |
| TF_RB | teacher_fault | 119,841 | 737,417 | 0 | 583,327 | 75,283 | 658,610 | 658,610 | 1,515,868 | 50.000% |
| TF_WM | teacher_fault | 119,844 | 953,268 | 0 | 663,422 | 76,781 | 740,203 | 740,203 | 1,813,315 | 50.000% |
| TF_ML | teacher_fault | 119,847 | 1,431,961 | 173,172 | 665,447 | 75,666 | 741,113 | 914,285 | 2,466,093 | 50.000% |

## Measured Follow-Up Primitives

| Follow-up path | Category | Gas | Measurement context | Included in scenario expectation |
|---|---|---:|---|---|
| TF_REMEDIAL_WAGE_CLOSE | remedial_wage | 9,999 | same-test-warm-call | no |

## Measured Class-Size Paths

These rows measure ordinary no-research Teaching sessions with all seats paid and majority attendance close.

| Class size | Paid seats | Attendance confirmations | Course type gas | Session lifecycle gas | Session gas / seat | Session cost | Session cost / seat |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 1 | 1 | 136,546 | 518,560 | 518,560 | $0.0078 | $0.0078 |
| 2 | 2 | 2 | 120,751 | 477,383 | 238,692 | $0.0071 | $0.0036 |
| 5 | 5 | 3 | 120,752 | 659,304 | 131,861 | $0.0099 | $0.0020 |
| 20 | 20 | 11 | 121,037 | 1,633,602 | 81,680 | $0.0244 | $0.0012 |
| 50 | 50 | 26 | 121,040 | 3,840,029 | 76,801 | $0.0574 | $0.0011 |
| 100 | 100 | 51 | 121,328 | 8,293,684 | 82,937 | $0.1241 | $0.0012 |

## Coordinator-Extended Scenario Simulation

Values use the reference fee coefficient at `1x`.

| Window | Coordinator case | p(FV) | p(CF) | p(TF) | Research mutation gas | Lesson gas | Claim gas | Management gas | Coupled gas | Revenue weight | Management cost / attempted lesson | Coupled cost / attempted lesson | Claim gas share | Share at $50 | Share at $100 | Share at $150 |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Demand-first | No coordinator | 0.000% | 0.000% | 0.000% | 0 | 521,201 | 12,108 | 533,309 | 533,309 | 100.000% | $0.0080 | $0.0080 | 2.270% | 0.016% | 0.008% | 0.005% |
| Demand-first | Low coordinator | 1.000% | 0.300% | 0.200% | 0 | 520,316 | 12,017 | 532,333 | 532,333 | 99.750% | $0.0080 | $0.0080 | 2.257% | 0.016% | 0.008% | 0.005% |
| Demand-first | Elevated coordinator | 5.000% | 2.000% | 1.000% | 0 | 516,666 | 11,591 | 528,257 | 528,257 | 98.500% | $0.0079 | $0.0079 | 2.194% | 0.016% | 0.008% | 0.005% |
| Demand-first | Coordinator stress | 10.000% | 5.000% | 3.000% | 0 | 511,324 | 10,907 | 522,231 | 522,231 | 96.000% | $0.0078 | $0.0078 | 2.089% | 0.016% | 0.008% | 0.005% |
| Supply-first | No coordinator | 0.000% | 0.000% | 0.000% | 0 | 537,526 | 31,887 | 569,413 | 569,413 | 100.000% | $0.0085 | $0.0085 | 5.600% | 0.017% | 0.009% | 0.006% |
| Supply-first | Low coordinator | 1.000% | 0.300% | 0.200% | 0 | 536,897 | 31,681 | 568,578 | 568,578 | 99.750% | $0.0085 | $0.0085 | 5.572% | 0.017% | 0.009% | 0.006% |
| Supply-first | Elevated coordinator | 5.000% | 2.000% | 1.000% | 0 | 534,239 | 30,700 | 564,939 | 564,939 | 98.500% | $0.0085 | $0.0085 | 5.434% | 0.017% | 0.009% | 0.006% |
| Supply-first | Coordinator stress | 10.000% | 5.000% | 3.000% | 0 | 530,315 | 29,102 | 559,417 | 559,417 | 96.000% | $0.0084 | $0.0084 | 5.202% | 0.017% | 0.009% | 0.006% |
| Synchronised | No coordinator | 0.000% | 0.000% | 0.000% | 8,659 | 562,524 | 49,394 | 611,918 | 620,577 | 100.000% | $0.0092 | $0.0093 | 8.072% | 0.018% | 0.009% | 0.006% |
| Synchronised | Low coordinator | 1.000% | 0.300% | 0.200% | 8,659 | 562,008 | 49,109 | 611,117 | 619,775 | 99.750% | $0.0091 | $0.0093 | 8.036% | 0.018% | 0.009% | 0.006% |
| Synchronised | Elevated coordinator | 5.000% | 2.000% | 1.000% | 8,659 | 559,720 | 47,720 | 607,440 | 616,099 | 98.500% | $0.0091 | $0.0092 | 7.856% | 0.018% | 0.009% | 0.006% |
| Synchronised | Coordinator stress | 10.000% | 5.000% | 3.000% | 8,659 | 556,248 | 45,437 | 601,686 | 610,344 | 96.000% | $0.0090 | $0.0091 | 7.552% | 0.019% | 0.009% | 0.006% |

## Chapter Scale Tables

### Demand-first expansion

| Teachers | Active students | Realised lessons / month | Throughput bottleneck | Estimated management cost / month |
|---:|---:|---:|---|---:|
| 100 | 480 | 2880 | demand side | $22.98 |
| 110 | 545 | 3270 | demand side | $26.09 |
| 125 | 620 | 3720 | demand side, near-balanced | $29.68 |

### Supply-first product expansion

| Teachers | Active students | Main research NFTs | Realised lessons / month | Throughput bottleneck | Estimated management cost / month |
|---:|---:|---:|---:|---|---:|
| 100 | 500 | 50 | 3000 | balanced | $25.56 |
| 120 | 540 | 80 | 3240 | student side | $27.60 |
| 145 | 600 | 120 | 3600 | student side | $30.67 |

### Synchronised expansion

| Teachers | Active students | Main research NFTs | Realised lessons / month | Throughput bottleneck | Estimated management cost / month |
|---:|---:|---:|---:|---|---:|
| 100 | 500 | 45 | 3000 | balanced | $27.46 |
| 120 | 600 | 52 | 3600 | balanced | $32.96 |
| 150 | 750 | 62 | 4500 | balanced | $41.20 |

### Research maintenance

New main research NFTs use the teaching-ready research asset primitive.

Research gas source:

| Component | Gas |
|---|---:|
| Research asset bootstrap | 513,434 |
| Teaching-ready research asset | 517,393 |
| Periodic update bundle | 352,045 |
| Extra prepared position | 259,267 |

| Teachers | Active students | Existing main research NFTs | New main research NFTs | Update cadence | Extra structure per update | Estimated research-maintenance cost / month | Estimated fixed-mix cost / month | Uplift vs fixed-mix lesson cost |
|---:|---:|---:|---:|---|---|---:|---:|---:|
| 120 | 600 | 60 | 0 | annual | none | $0.03 | $32.98 | 0.080% |
| 120 | 600 | 60 | 0 | semiannual | none | $0.05 | $33.01 | 0.160% |
| 120 | 600 | 60 | 0 | semiannual | +20 extra prepared positions across the catalogue per cycle | $0.07 | $33.02 | 0.199% |
| 120 | 600 | 60 | 6 per 6 months | semiannual | none | $0.06 | $33.02 | 0.183% |

### Cost share under lesson pricing

| Revenue / lesson | Lesson lifecycle cost / lesson | Distributor claim cost / lesson | Management cost / lesson | Management cost share of revenue |
|---:|---:|---:|---:|---:|
| $50 | $0.0078-$0.0084 | $0.0002-$0.0007 | $0.0080-$0.0092 | 0.016%-0.018% |
| $100 | $0.0078-$0.0084 | $0.0002-$0.0007 | $0.0080-$0.0092 | 0.0080%-0.0092% |
| $150 | $0.0078-$0.0084 | $0.0002-$0.0007 | $0.0080-$0.0092 | 0.0053%-0.0061% |
