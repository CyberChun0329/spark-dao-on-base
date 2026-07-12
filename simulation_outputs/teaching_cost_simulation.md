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
| ORD_NR | ordinary | 137,352 | 0 | 0 | 530,769 | 0 | 530,769 | 530,769 | 668,121 | 100.000% |
| ORD_ZS | ordinary | 121,554 | 518,199 | 0 | 482,436 | 0 | 482,436 | 482,436 | 1,122,189 | 100.000% |
| ORD_RB | ordinary | 121,557 | 759,335 | 0 | 587,172 | 167,745 | 754,917 | 754,917 | 1,635,809 | 100.000% |
| ORD_WM | ordinary | 121,559 | 953,040 | 0 | 661,811 | 123,363 | 785,174 | 785,174 | 1,859,773 | 100.000% |
| ORD_ML | ordinary | 121,563 | 1,475,255 | 173,410 | 663,837 | 122,328 | 786,165 | 959,575 | 2,556,393 | 100.000% |
| FV_NR | forced_valid | 121,565 | 0 | 0 | 429,498 | 0 | 429,498 | 429,498 | 551,063 | 100.000% |
| FV_ZS | forced_valid | 121,567 | 476,549 | 0 | 474,467 | 0 | 474,467 | 474,467 | 1,072,583 | 100.000% |
| FV_RB | forced_valid | 121,569 | 737,495 | 0 | 573,299 | 121,945 | 695,244 | 695,244 | 1,554,308 | 100.000% |
| FV_WM | forced_valid | 121,572 | 953,139 | 0 | 653,348 | 123,390 | 776,738 | 776,738 | 1,851,449 | 100.000% |
| FV_ML | forced_valid | 121,575 | 1,431,598 | 173,410 | 655,373 | 122,328 | 777,701 | 951,111 | 2,504,284 | 100.000% |
| CF_NR | customer_fault | 121,576 | 0 | 0 | 469,653 | 0 | 469,653 | 469,653 | 591,229 | 50.000% |
| CF_ZS | customer_fault | 121,579 | 476,597 | 0 | 494,725 | 0 | 494,725 | 494,725 | 1,092,901 | 50.000% |
| CF_RB | customer_fault | 121,581 | 737,657 | 0 | 514,791 | 0 | 514,791 | 514,791 | 1,374,029 | 50.000% |
| CF_WM | customer_fault | 121,584 | 953,237 | 0 | 518,131 | 0 | 518,131 | 518,131 | 1,592,952 | 50.000% |
| CF_ML | customer_fault | 121,587 | 1,431,736 | 173,410 | 518,141 | 0 | 518,141 | 691,551 | 2,244,874 | 50.000% |
| TF_NR | teacher_fault | 121,588 | 0 | 0 | 422,498 | 0 | 422,498 | 422,498 | 544,086 | 50.000% |
| TF_ZS | teacher_fault | 121,591 | 476,645 | 0 | 467,473 | 0 | 467,473 | 467,473 | 1,065,709 | 50.000% |
| TF_RB | teacher_fault | 121,594 | 737,530 | 0 | 566,304 | 121,945 | 688,249 | 688,249 | 1,547,373 | 50.000% |
| TF_WM | teacher_fault | 121,596 | 953,333 | 0 | 646,368 | 123,443 | 769,811 | 769,811 | 1,844,740 | 50.000% |
| TF_ML | teacher_fault | 121,599 | 1,431,877 | 173,410 | 648,394 | 122,328 | 770,722 | 944,132 | 2,497,608 | 50.000% |

## Measured Follow-Up Primitives

| Follow-up path | Category | Gas | Measurement context | Included in scenario expectation |
|---|---|---:|---|---|
| TF_REMEDIAL_WAGE_CLOSE | remedial_wage | 9,943 | same-test-warm-call | no |

## Measured Class-Size Paths

These rows measure ordinary no-research Teaching sessions with all seats paid and majority attendance close.

| Class size | Paid seats | Attendance confirmations | Course type gas | Session lifecycle gas | Session gas / seat | Session cost | Session cost / seat |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 1 | 1 | 138,277 | 524,097 | 524,097 | $0.0078 | $0.0078 |
| 2 | 2 | 2 | 122,481 | 484,960 | 242,480 | $0.0073 | $0.0036 |
| 5 | 5 | 3 | 122,483 | 668,764 | 133,753 | $0.0100 | $0.0020 |
| 20 | 20 | 11 | 122,753 | 1,656,343 | 82,817 | $0.0248 | $0.0012 |
| 50 | 50 | 26 | 122,755 | 3,875,085 | 77,502 | $0.0580 | $0.0012 |
| 100 | 100 | 51 | 123,029 | 8,313,263 | 83,133 | $0.1244 | $0.0012 |

## Single-Seat Coordinator-Extended Scenario Simulation

Values use the `classSize = 1` lifecycle calibration and the reference fee coefficient at `1x`. Measured multi-seat scaling is reported in the class-size table above.

| Window | Coordinator case | p(FV) | p(CF) | p(TF) | Research mutation gas | Lesson gas | Claim gas | Management gas | Coupled gas | Revenue weight | Management cost / attempted lesson | Coupled cost / attempted lesson | Claim gas share | Share at $50 | Share at $100 | Share at $150 |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Demand-first | No coordinator | 0.000% | 0.000% | 0.000% | 0 | 526,743 | 16,775 | 543,517 | 543,517 | 100.000% | $0.0081 | $0.0081 | 3.086% | 0.016% | 0.008% | 0.005% |
| Demand-first | Low coordinator | 1.000% | 0.300% | 0.200% | 0 | 525,700 | 16,669 | 542,369 | 542,369 | 99.750% | $0.0081 | $0.0081 | 3.073% | 0.016% | 0.008% | 0.005% |
| Demand-first | Elevated coordinator | 5.000% | 2.000% | 1.000% | 0 | 521,289 | 16,164 | 537,453 | 537,453 | 98.500% | $0.0080 | $0.0080 | 3.008% | 0.016% | 0.008% | 0.005% |
| Demand-first | Coordinator stress | 10.000% | 5.000% | 3.000% | 0 | 514,551 | 15,340 | 529,892 | 529,892 | 96.000% | $0.0079 | $0.0079 | 2.895% | 0.017% | 0.008% | 0.006% |
| Supply-first | No coordinator | 0.000% | 0.000% | 0.000% | 0 | 543,071 | 45,885 | 588,956 | 588,956 | 100.000% | $0.0088 | $0.0088 | 7.791% | 0.018% | 0.009% | 0.006% |
| Supply-first | Low coordinator | 1.000% | 0.300% | 0.200% | 0 | 542,283 | 45,638 | 587,920 | 587,920 | 99.750% | $0.0088 | $0.0088 | 7.763% | 0.018% | 0.009% | 0.006% |
| Supply-first | Elevated coordinator | 5.000% | 2.000% | 1.000% | 0 | 538,864 | 44,418 | 583,282 | 583,282 | 98.500% | $0.0087 | $0.0087 | 7.615% | 0.018% | 0.009% | 0.006% |
| Supply-first | Coordinator stress | 10.000% | 5.000% | 3.000% | 0 | 533,543 | 42,401 | 575,944 | 575,944 | 96.000% | $0.0086 | $0.0086 | 7.362% | 0.018% | 0.009% | 0.006% |
| Synchronised | No coordinator | 0.000% | 0.000% | 0.000% | 8,671 | 568,065 | 72,725 | 640,790 | 649,461 | 100.000% | $0.0096 | $0.0097 | 11.349% | 0.019% | 0.010% | 0.006% |
| Synchronised | Low coordinator | 1.000% | 0.300% | 0.200% | 8,671 | 567,390 | 72,370 | 639,760 | 648,431 | 99.750% | $0.0096 | $0.0097 | 11.312% | 0.019% | 0.010% | 0.006% |
| Synchronised | Elevated coordinator | 5.000% | 2.000% | 1.000% | 8,671 | 564,342 | 70,584 | 634,926 | 643,596 | 98.500% | $0.0095 | $0.0096 | 11.117% | 0.019% | 0.010% | 0.006% |
| Synchronised | Coordinator stress | 10.000% | 5.000% | 3.000% | 8,671 | 559,473 | 67,602 | 627,074 | 635,745 | 96.000% | $0.0094 | $0.0095 | 10.780% | 0.020% | 0.010% | 0.007% |

## Chapter Scale Tables

### Demand-first expansion

| Teachers | Active students | Realised lessons / month | Throughput bottleneck | Estimated management cost / month |
|---:|---:|---:|---|---:|
| 100 | 480 | 2880 | demand side | $23.42 |
| 110 | 545 | 3270 | demand side | $26.59 |
| 125 | 620 | 3720 | demand side, near-balanced | $30.25 |

### Supply-first product expansion

| Teachers | Active students | Main research NFTs | Realised lessons / month | Throughput bottleneck | Estimated management cost / month |
|---:|---:|---:|---:|---|---:|
| 100 | 500 | 50 | 3000 | balanced | $26.43 |
| 120 | 540 | 80 | 3240 | student side | $28.55 |
| 145 | 600 | 120 | 3600 | student side | $31.72 |

### Synchronised expansion

| Teachers | Active students | Main research NFTs | Realised lessons / month | Throughput bottleneck | Estimated management cost / month |
|---:|---:|---:|---:|---|---:|
| 100 | 500 | 45 | 3000 | balanced | $28.76 |
| 120 | 600 | 52 | 3600 | balanced | $34.51 |
| 150 | 750 | 62 | 4500 | balanced | $43.14 |

### Research maintenance

New main research NFTs use the teaching-ready research asset primitive.

Research gas source:

| Component | Gas |
|---|---:|
| Research asset bootstrap | 513,365 |
| Teaching-ready research asset | 517,306 |
| Periodic update bundle | 351,925 |
| Extra prepared position | 259,130 |

| Teachers | Active students | Existing main research NFTs | New main research NFTs | Update cadence | Extra structure per update | Estimated research-maintenance cost / month | Estimated fixed-mix cost / month | Uplift vs fixed-mix lesson cost |
|---:|---:|---:|---:|---|---|---:|---:|---:|
| 120 | 600 | 60 | 0 | annual | none | $0.03 | $34.54 | 0.076% |
| 120 | 600 | 60 | 0 | semiannual | none | $0.05 | $34.56 | 0.153% |
| 120 | 600 | 60 | 0 | semiannual | +20 extra prepared positions across the catalogue per cycle | $0.07 | $34.58 | 0.190% |
| 120 | 600 | 60 | 6 per 6 months | semiannual | none | $0.06 | $34.57 | 0.175% |

### Cost share under lesson pricing

| Revenue / lesson | Lesson lifecycle cost / lesson | Distributor claim cost / lesson | Management cost / lesson | Management cost share of revenue |
|---:|---:|---:|---:|---:|
| $50 | $0.0079-$0.0085 | $0.0003-$0.0011 | $0.0081-$0.0096 | 0.016%-0.019% |
| $100 | $0.0079-$0.0085 | $0.0003-$0.0011 | $0.0081-$0.0096 | 0.0081%-0.0096% |
| $150 | $0.0079-$0.0085 | $0.0003-$0.0011 | $0.0081-$0.0096 | 0.0054%-0.0064% |
