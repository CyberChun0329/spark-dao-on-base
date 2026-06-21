# Tests

Foundry tests for the Base implementation.

`TeachingRegistry.t.sol` covers teaching settlement, distributor wiring, claim rights,
reserve boundaries, multi-stable behavior, token minter locking, and selected regression
paths.

`TeachingGasCalibrationTest` writes `teaching_gas_calibration.csv` and
`teaching_followup_gas_calibration.csv`, the teaching gas tables used by the
cost simulation.

`ResearchRegistry.t.sol` covers research assets, positions, layer progression, revenue,
buybacks, reserves, minter locking, and bounded decay.

`ResearchGasCalibration.t.sol` writes `research_gas_calibration.csv`.

Run the behavioural suite with:

```bash
forge test -vv
```

Run gas calibration tests when CSV outputs need to be refreshed. Use
`npm run simulate:teaching-cost` for generated cost outputs and
`npm run check:calibration` for the full calibration check.
