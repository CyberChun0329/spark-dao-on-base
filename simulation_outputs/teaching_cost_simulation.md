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
| ORD_NR | ordinary | 135,600 | 0 | 0 | 525,534 | 0 | 525,534 | 525,534 | 661,134 | 100.000% |
| ORD_ZS | ordinary | 119,802 | 518,306 | 0 | 477,216 | 0 | 477,216 | 477,216 | 1,115,324 | 100.000% |
| ORD_RB | ordinary | 119,805 | 759,511 | 0 | 581,856 | 167,701 | 749,557 | 749,557 | 1,628,873 | 100.000% |
| ORD_WM | ordinary | 119,808 | 953,256 | 0 | 656,628 | 123,319 | 779,947 | 779,947 | 1,853,011 | 100.000% |
| ORD_ML | ordinary | 119,811 | 1,475,618 | 173,452 | 658,654 | 122,284 | 780,938 | 954,390 | 2,549,819 | 100.000% |
| FV_NR | forced_valid | 119,813 | 0 | 0 | 427,773 | 0 | 427,773 | 427,773 | 547,586 | 100.000% |
| FV_ZS | forced_valid | 119,815 | 476,656 | 0 | 472,757 | 0 | 472,757 | 472,757 | 1,069,228 | 100.000% |
| FV_RB | forced_valid | 119,817 | 737,661 | 0 | 571,596 | 121,901 | 693,497 | 693,497 | 1,550,975 | 100.000% |
| FV_WM | forced_valid | 119,820 | 953,354 | 0 | 651,675 | 123,346 | 775,021 | 775,021 | 1,848,195 | 100.000% |
| FV_ML | forced_valid | 119,823 | 1,431,961 | 173,452 | 653,701 | 122,284 | 775,985 | 949,437 | 2,501,221 | 100.000% |
| CF_NR | customer_fault | 119,825 | 0 | 0 | 489,221 | 0 | 489,221 | 489,221 | 609,046 | 50.000% |
| CF_ZS | customer_fault | 119,827 | 476,705 | 0 | 514,308 | 0 | 514,308 | 514,308 | 1,110,840 | 50.000% |
| CF_RB | customer_fault | 119,830 | 737,824 | 0 | 534,375 | 0 | 534,375 | 534,375 | 1,392,029 | 50.000% |
| CF_WM | customer_fault | 119,832 | 953,453 | 0 | 537,729 | 0 | 537,729 | 537,729 | 1,611,014 | 50.000% |
| CF_ML | customer_fault | 119,835 | 1,432,099 | 173,452 | 537,738 | 0 | 537,738 | 711,190 | 2,263,124 | 50.000% |
| TF_NR | teacher_fault | 119,836 | 0 | 0 | 439,500 | 0 | 439,500 | 439,500 | 559,336 | 50.000% |
| TF_ZS | teacher_fault | 119,839 | 476,753 | 0 | 484,489 | 0 | 484,489 | 484,489 | 1,081,081 | 50.000% |
| TF_RB | teacher_fault | 119,842 | 737,698 | 0 | 583,328 | 121,901 | 705,229 | 705,229 | 1,562,769 | 50.000% |
| TF_WM | teacher_fault | 119,844 | 953,548 | 0 | 663,422 | 123,399 | 786,821 | 786,821 | 1,860,213 | 50.000% |
| TF_ML | teacher_fault | 119,847 | 1,432,241 | 173,452 | 665,447 | 122,284 | 787,731 | 961,183 | 2,513,271 | 50.000% |

## Measured Follow-Up Primitives

| Follow-up path | Category | Gas | Measurement context | Included in scenario expectation |
|---|---|---:|---|---|
| TF_REMEDIAL_WAGE_CLOSE | remedial_wage | 9,999 | same-test-warm-call | no |

## Measured Class-Size Paths

These rows measure ordinary no-research Teaching sessions with all seats paid and majority attendance close.

| Class size | Paid seats | Attendance confirmations | Course type gas | Session lifecycle gas | Session gas / seat | Session cost | Session cost / seat |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 1 | 1 | 136,546 | 518,862 | 518,862 | $0.0078 | $0.0078 |
| 2 | 2 | 2 | 120,751 | 477,836 | 238,918 | $0.0071 | $0.0036 |
| 5 | 5 | 3 | 120,752 | 659,908 | 131,982 | $0.0099 | $0.0020 |
| 20 | 20 | 11 | 121,037 | 1,635,414 | 81,771 | $0.0245 | $0.0012 |
| 50 | 50 | 26 | 121,040 | 3,844,106 | 76,882 | $0.0575 | $0.0012 |
| 100 | 100 | 51 | 121,328 | 8,301,536 | 83,015 | $0.1242 | $0.0012 |

## Coordinator-Extended Scenario Simulation

Values use the reference fee coefficient at `1x`.

| Window | Coordinator case | p(FV) | p(CF) | p(TF) | Research mutation gas | Lesson gas | Claim gas | Management gas | Coupled gas | Revenue weight | Management cost / attempted lesson | Coupled cost / attempted lesson | Claim gas share | Share at $50 | Share at $100 | Share at $150 |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Demand-first | No coordinator | 0.000% | 0.000% | 0.000% | 0 | 521,503 | 16,770 | 538,273 | 538,273 | 100.000% | $0.0081 | $0.0081 | 3.116% | 0.016% | 0.008% | 0.005% |
| Demand-first | Low coordinator | 1.000% | 0.300% | 0.200% | 0 | 520,614 | 16,665 | 537,278 | 537,278 | 99.750% | $0.0080 | $0.0080 | 3.102% | 0.016% | 0.008% | 0.005% |
| Demand-first | Elevated coordinator | 5.000% | 2.000% | 1.000% | 0 | 516,944 | 16,160 | 533,104 | 533,104 | 98.500% | $0.0080 | $0.0080 | 3.031% | 0.016% | 0.008% | 0.005% |
| Demand-first | Coordinator stress | 10.000% | 5.000% | 3.000% | 0 | 511,571 | 15,336 | 526,908 | 526,908 | 96.000% | $0.0079 | $0.0079 | 2.911% | 0.016% | 0.008% | 0.005% |
| Supply-first | No coordinator | 0.000% | 0.000% | 0.000% | 0 | 537,828 | 45,872 | 583,700 | 583,700 | 100.000% | $0.0087 | $0.0087 | 7.859% | 0.017% | 0.009% | 0.006% |
| Supply-first | Low coordinator | 1.000% | 0.300% | 0.200% | 0 | 537,195 | 45,625 | 582,819 | 582,819 | 99.750% | $0.0087 | $0.0087 | 7.828% | 0.017% | 0.009% | 0.006% |
| Supply-first | Elevated coordinator | 5.000% | 2.000% | 1.000% | 0 | 534,517 | 44,405 | 578,923 | 578,923 | 98.500% | $0.0087 | $0.0087 | 7.670% | 0.018% | 0.009% | 0.006% |
| Supply-first | Coordinator stress | 10.000% | 5.000% | 3.000% | 0 | 530,562 | 42,388 | 572,951 | 572,951 | 96.000% | $0.0086 | $0.0086 | 7.398% | 0.018% | 0.009% | 0.006% |
| Synchronised | No coordinator | 0.000% | 0.000% | 0.000% | 8,673 | 562,826 | 72,703 | 635,529 | 644,202 | 100.000% | $0.0095 | $0.0096 | 11.440% | 0.019% | 0.010% | 0.006% |
| Synchronised | Low coordinator | 1.000% | 0.300% | 0.200% | 8,673 | 562,305 | 72,348 | 634,653 | 643,326 | 99.750% | $0.0095 | $0.0096 | 11.400% | 0.019% | 0.010% | 0.006% |
| Synchronised | Elevated coordinator | 5.000% | 2.000% | 1.000% | 8,673 | 559,998 | 70,563 | 630,561 | 639,233 | 98.500% | $0.0094 | $0.0096 | 11.190% | 0.019% | 0.010% | 0.006% |
| Synchronised | Coordinator stress | 10.000% | 5.000% | 3.000% | 8,673 | 556,496 | 67,581 | 624,077 | 632,749 | 96.000% | $0.0093 | $0.0095 | 10.829% | 0.019% | 0.010% | 0.006% |

## Chapter Scale Tables

### Demand-first expansion

| Teachers | Active students | Realised lessons / month | Throughput bottleneck | Estimated management cost / month |
|---:|---:|---:|---|---:|
| 100 | 480 | 2880 | demand side | $23.19 |
| 110 | 545 | 3270 | demand side | $26.33 |
| 125 | 620 | 3720 | demand side, near-balanced | $29.96 |

### Supply-first product expansion

| Teachers | Active students | Main research NFTs | Realised lessons / month | Throughput bottleneck | Estimated management cost / month |
|---:|---:|---:|---:|---|---:|
| 100 | 500 | 50 | 3000 | balanced | $26.20 |
| 120 | 540 | 80 | 3240 | student side | $28.29 |
| 145 | 600 | 120 | 3600 | student side | $31.44 |

### Synchronised expansion

| Teachers | Active students | Main research NFTs | Realised lessons / month | Throughput bottleneck | Estimated management cost / month |
|---:|---:|---:|---:|---|---:|
| 100 | 500 | 45 | 3000 | balanced | $28.52 |
| 120 | 600 | 52 | 3600 | balanced | $34.23 |
| 150 | 750 | 62 | 4500 | balanced | $42.79 |

### Research maintenance

New main research NFTs use the teaching-ready research asset primitive.

Research gas source:

| Component | Gas |
|---|---:|
| Research asset bootstrap | 513,574 |
| Teaching-ready research asset | 517,533 |
| Periodic update bundle | 352,185 |
| Extra prepared position | 259,267 |

| Teachers | Active students | Existing main research NFTs | New main research NFTs | Update cadence | Extra structure per update | Estimated research-maintenance cost / month | Estimated fixed-mix cost / month | Uplift vs fixed-mix lesson cost |
|---:|---:|---:|---:|---|---|---:|---:|---:|
| 120 | 600 | 60 | 0 | annual | none | $0.03 | $34.25 | 0.077% |
| 120 | 600 | 60 | 0 | semiannual | none | $0.05 | $34.28 | 0.154% |
| 120 | 600 | 60 | 0 | semiannual | +20 extra prepared positions across the catalogue per cycle | $0.07 | $34.29 | 0.192% |
| 120 | 600 | 60 | 6 per 6 months | semiannual | none | $0.06 | $34.29 | 0.177% |

### Cost share under lesson pricing

| Revenue / lesson | Lesson lifecycle cost / lesson | Distributor claim cost / lesson | Management cost / lesson | Management cost share of revenue |
|---:|---:|---:|---:|---:|
| $50 | $0.0078-$0.0084 | $0.0003-$0.0011 | $0.0081-$0.0095 | 0.016%-0.019% |
| $100 | $0.0078-$0.0084 | $0.0003-$0.0011 | $0.0081-$0.0095 | 0.0081%-0.0095% |
| $150 | $0.0078-$0.0084 | $0.0003-$0.0011 | $0.0081-$0.0095 | 0.0054%-0.0063% |
