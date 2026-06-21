# Teaching Cost Simulation

Generated from `teaching_gas_calibration.csv`, `teaching_followup_gas_calibration.csv`, and `research_gas_calibration.csv`.

Reference translation coefficient:

```text
referenceUsdPerGas = 1.4960545778707655e-8
source = trailing-twelve-month Base fee translation coefficient
measurementWindow = trailing twelve months at calibration time
unit = dollars per gas unit
```

Calibration schema version 2 separates one-time course-type creation, research setup, research mutation, lesson lifecycle, and distributor claim gas. Here, `lesson_gas` covers session creation, confirmations, approvals, collateral locks, resolution, and redeem. The recurring management coefficient remains `lesson_gas + claim_gas`. `coupled_gas` is reported as `research_mutation_gas + lesson_gas + claim_gas` for cases where the model wants to inspect cross-module research churn. The teacher-fault remedial wage close primitive is displayed separately and is not automatically included in teacher-fault scenario expectations.

## Calibration Manifest

```json
{
  "calibrationSchemaVersion": 2,
  "implementationRoot": ".",
  "manifestMode": "public-safe",
  "toolVersions": {
    "node": "v24.12.0",
    "npm": "11.6.2",
    "forge": "forge Version: 1.5.1-stable\nCommit SHA: b0a9dd9ceda36f63e2326ce530c10e6916f4b8a2\nBuild Timestamp: 2025-12-22T11:41:09.812070000Z (1766403669)\nBuild Profile: maxperf"
  },
  "solcVersion": "0.8.26",
  "inputFiles": [
    {
      "path": "teaching_gas_calibration.csv",
      "sha256": "bf90e12c4ac429d43f66be047bbcc15b151040bbd4cd8bd2452cdf128786b4e7"
    },
    {
      "path": "teaching_followup_gas_calibration.csv",
      "sha256": "cf31b1a53be6c37aa262a7b3e27254b4bdee949c0df14d0b7e5b6cf65d9a653a"
    },
    {
      "path": "research_gas_calibration.csv",
      "sha256": "8e654a6a3cf92eff4d420db3389f58944c787d7a6e1512699860c95ba47097ef"
    },
    {
      "path": "simulation_inputs/fee_assumptions.json",
      "sha256": "e391a58918b019b2519fe1f9fdbac2d15dad97f6400a527ec6e89464ae21379a"
    }
  ],
  "sourceFiles": [
    {
      "path": "test/TeachingGasCalibration.t.sol",
      "sha256": "7b49d5284d96b0561aa1ed93e58dc648331a2f9f124d9dec9f98de1c98050948"
    },
    {
      "path": "test/ResearchGasCalibration.t.sol",
      "sha256": "6e8eba412528e4345f508803b1b92e6928a608b71ded745188fb7e37517823dc"
    },
    {
      "path": "client/scripts/simulateTeachingCost.ts",
      "sha256": "91fcdad23a396aa8e7bd46b6e53f4278c79c2e94c80a88b5688234b536d2f021"
    },
    {
      "path": "foundry.toml",
      "sha256": "c205596ce02a92f74f76d1e3246b1dbd324db092bb76c04852e2d40dc7265173"
    },
    {
      "path": "package.json",
      "sha256": "daa3a24f4535a4932ba46fb312aa6fdb613dc5a99e9cdef90d76a24ba072f6c9"
    },
    {
      "path": "package-lock.json",
      "sha256": "32650fa9dfe590e2ec8c23d1e92d98603b170d19c964c4697431af1cd68b1814"
    }
  ]
}
```

## Measured Contract Paths

| Path | Category | Course type gas | Research setup gas | Research mutation gas | Lesson lifecycle gas | Distributor claim gas | Management gas | Coupled gas | Full fixture gas | Revenue weight |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| ORD_NR | ordinary | 198,872 | 0 | 0 | 708,103 | 0 | 708,103 | 708,103 | 906,975 | 100.000% |
| ORD_ZS | ordinary | 174,074 | 521,575 | 0 | 678,937 | 0 | 678,937 | 678,937 | 1,374,586 | 100.000% |
| ORD_RB | ordinary | 174,077 | 761,375 | 0 | 866,113 | 194,334 | 1,060,447 | 1,060,447 | 1,995,899 | 100.000% |
| ORD_WM | ordinary | 174,079 | 955,789 | 0 | 960,193 | 171,870 | 1,132,063 | 1,132,063 | 2,261,931 | 100.000% |
| ORD_ML | ordinary | 174,082 | 1,478,491 | 177,426 | 962,193 | 170,894 | 1,133,087 | 1,310,513 | 2,963,086 | 100.000% |
| FV_NR | forced_valid | 174,084 | 0 | 0 | 630,372 | 0 | 630,372 | 630,372 | 804,456 | 100.000% |
| FV_ZS | forced_valid | 174,086 | 477,921 | 0 | 675,409 | 0 | 675,409 | 675,409 | 1,327,416 | 100.000% |
| FV_RB | forced_valid | 174,089 | 739,526 | 0 | 855,285 | 148,534 | 1,003,819 | 1,003,819 | 1,917,434 | 100.000% |
| FV_WM | forced_valid | 174,091 | 955,881 | 0 | 956,673 | 171,895 | 1,128,568 | 1,128,568 | 2,258,540 | 100.000% |
| FV_ML | forced_valid | 174,094 | 1,434,825 | 177,426 | 958,672 | 170,894 | 1,129,566 | 1,306,992 | 2,915,911 | 100.000% |
| CF_NR | customer_fault | 174,095 | 0 | 0 | 720,046 | 0 | 720,046 | 720,046 | 894,141 | 50.000% |
| CF_ZS | customer_fault | 174,098 | 477,966 | 0 | 765,086 | 0 | 765,086 | 765,086 | 1,417,150 | 50.000% |
| CF_RB | customer_fault | 174,100 | 739,623 | 0 | 824,930 | 0 | 824,930 | 824,930 | 1,738,653 | 50.000% |
| CF_WM | customer_fault | 174,102 | 955,972 | 0 | 828,356 | 0 | 828,356 | 828,356 | 1,958,430 | 50.000% |
| CF_ML | customer_fault | 174,105 | 1,434,955 | 177,426 | 828,363 | 0 | 828,363 | 1,005,789 | 2,614,849 | 50.000% |
| TF_NR | teacher_fault | 174,106 | 0 | 0 | 723,220 | 0 | 723,220 | 723,220 | 897,326 | 50.000% |
| TF_ZS | teacher_fault | 174,109 | 478,011 | 0 | 748,362 | 0 | 748,362 | 748,362 | 1,400,482 | 50.000% |
| TF_RB | teacher_fault | 174,111 | 739,735 | 0 | 948,132 | 148,534 | 1,096,666 | 1,096,666 | 2,010,512 | 50.000% |
| TF_WM | teacher_fault | 174,113 | 956,062 | 0 | 1,049,534 | 171,944 | 1,221,478 | 1,221,478 | 2,351,653 | 50.000% |
| TF_ML | teacher_fault | 174,116 | 1,435,087 | 177,426 | 1,051,532 | 170,894 | 1,222,426 | 1,399,852 | 3,009,055 | 50.000% |

## Measured Follow-Up Primitives

| Follow-up path | Category | Gas | Measurement context | Included in scenario expectation |
|---|---|---:|---|---|
| TF_REMEDIAL_WAGE_CLOSE | remedial_wage | 9,792 | same-test-warm-call | no |

## Coordinator-Extended Scenario Simulation

These values use the reference fee coefficient at `1x`. Customer-fault and teacher-fault resolutions carry half-price revenue, so the denominator uses `revenueWeight = 1 - 0.5 * (p(CF) + p(TF))`.

| Window | Coordinator case | p(FV) | p(CF) | p(TF) | Research mutation gas | Lesson gas | Claim gas | Management gas | Coupled gas | Revenue weight | Management cost / attempted lesson | Coupled cost / attempted lesson | Claim gas share | Share at $50 | Share at $100 | Share at $150 |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Demand-first | No coordinator | 0.000% | 0.000% | 0.000% | 0 | 718,071 | 19,433 | 737,504 | 737,504 | 100.000% | $0.0110 | $0.0110 | 2.635% | 0.022% | 0.011% | 0.007% |
| Demand-first | Low coordinator | 1.000% | 0.300% | 0.200% | 0 | 717,639 | 19,320 | 736,959 | 736,959 | 99.750% | $0.0110 | $0.0110 | 2.622% | 0.022% | 0.011% | 0.007% |
| Demand-first | Elevated coordinator | 5.000% | 2.000% | 1.000% | 0 | 716,017 | 18,770 | 734,787 | 734,787 | 98.500% | $0.0110 | $0.0110 | 2.554% | 0.022% | 0.011% | 0.007% |
| Demand-first | Coordinator stress | 10.000% | 5.000% | 3.000% | 0 | 714,504 | 17,866 | 732,371 | 732,371 | 96.000% | $0.0110 | $0.0110 | 2.440% | 0.023% | 0.011% | 0.008% |
| Supply-first | No coordinator | 0.000% | 0.000% | 0.000% | 0 | 757,623 | 56,054 | 813,676 | 813,676 | 100.000% | $0.0122 | $0.0122 | 6.889% | 0.024% | 0.012% | 0.008% |
| Supply-first | Low coordinator | 1.000% | 0.300% | 0.200% | 0 | 757,354 | 55,776 | 813,130 | 813,130 | 99.750% | $0.0122 | $0.0122 | 6.859% | 0.024% | 0.012% | 0.008% |
| Supply-first | Elevated coordinator | 5.000% | 2.000% | 1.000% | 0 | 756,308 | 54,383 | 810,692 | 810,692 | 98.500% | $0.0121 | $0.0121 | 6.708% | 0.025% | 0.012% | 0.008% |
| Supply-first | Coordinator stress | 10.000% | 5.000% | 3.000% | 0 | 755,544 | 52,061 | 807,605 | 807,605 | 96.000% | $0.0121 | $0.0121 | 6.446% | 0.025% | 0.013% | 0.008% |
| Synchronised | No coordinator | 0.000% | 0.000% | 0.000% | 8,871 | 804,895 | 91,502 | 896,397 | 905,268 | 100.000% | $0.0134 | $0.0135 | 10.208% | 0.027% | 0.013% | 0.009% |
| Synchronised | Low coordinator | 1.000% | 0.300% | 0.200% | 8,871 | 804,674 | 91,090 | 895,764 | 904,635 | 99.750% | $0.0134 | $0.0135 | 10.169% | 0.027% | 0.013% | 0.009% |
| Synchronised | Elevated coordinator | 5.000% | 2.000% | 1.000% | 8,871 | 803,676 | 88,986 | 892,662 | 901,533 | 98.500% | $0.0134 | $0.0135 | 9.969% | 0.027% | 0.014% | 0.009% |
| Synchronised | Coordinator stress | 10.000% | 5.000% | 3.000% | 8,871 | 802,844 | 85,440 | 888,284 | 897,155 | 96.000% | $0.0133 | $0.0134 | 9.618% | 0.028% | 0.014% | 0.009% |

## Chapter Scale Tables

### Demand-first expansion

| Teachers | Active students | Realised lessons / month | Throughput bottleneck | Estimated management cost / month |
|---:|---:|---:|---|---:|
| 100 | 480 | 2880 | demand side | $31.78 |
| 110 | 545 | 3270 | demand side | $36.08 |
| 125 | 620 | 3720 | demand side, near-balanced | $41.04 |

### Supply-first product expansion

| Teachers | Active students | Main research NFTs | Realised lessons / month | Throughput bottleneck | Estimated management cost / month |
|---:|---:|---:|---:|---|---:|
| 100 | 500 | 50 | 3000 | balanced | $36.52 |
| 120 | 540 | 80 | 3240 | student side | $39.44 |
| 145 | 600 | 120 | 3600 | student side | $43.82 |

### Synchronised expansion

| Teachers | Active students | Main research NFTs | Realised lessons / month | Throughput bottleneck | Estimated management cost / month |
|---:|---:|---:|---:|---|---:|
| 100 | 500 | 45 | 3000 | balanced | $40.23 |
| 120 | 600 | 52 | 3600 | balanced | $48.28 |
| 150 | 750 | 62 | 4500 | balanced | $60.35 |

### Research maintenance

New main research NFTs in this table use the teaching-ready research asset primitive, meaning the asset has a current patch position and the current layer has been sealed.

Research gas source:

| Component | Gas |
|---|---:|
| Research asset bootstrap | 516,870 |
| Teaching-ready research asset | 520,829 |
| Periodic update bundle | 354,456 |
| Extra prepared position | 259,467 |

| Teachers | Active students | Existing main research NFTs | New main research NFTs | Update cadence | Extra structure per update | Estimated research-maintenance cost / month | Estimated fixed-mix cost / month | Uplift vs fixed-mix lesson baseline |
|---:|---:|---:|---:|---|---|---:|---:|---:|
| 120 | 600 | 60 | 0 | annual | none | $0.03 | $48.30 | 0.055% |
| 120 | 600 | 60 | 0 | semiannual | none | $0.05 | $48.33 | 0.110% |
| 120 | 600 | 60 | 0 | semiannual | +20 extra prepared positions across the catalogue per cycle | $0.07 | $48.34 | 0.137% |
| 120 | 600 | 60 | 6 per 6 months | semiannual | none | $0.06 | $48.34 | 0.126% |

### Cost share under lesson pricing

| Revenue / lesson | Lesson lifecycle cost / lesson | Distributor claim cost / lesson | Management cost / lesson | Management cost share of revenue |
|---:|---:|---:|---:|---:|
| $50 | $0.0107-$0.0120 | $0.0003-$0.0014 | $0.0110-$0.0134 | 0.022%-0.027% |
| $100 | $0.0107-$0.0120 | $0.0003-$0.0014 | $0.0110-$0.0134 | 0.011%-0.013% |
| $150 | $0.0107-$0.0120 | $0.0003-$0.0014 | $0.0110-$0.0134 | 0.0074%-0.0089% |
