# Tests

Foundry tests for the Base implementation.

`TeachingRegistry.t.sol` covers ordinary teaching completion, coordinator-forced valid
settlement, customer-fault half-price settlement, teacher-fault remedial settlement,
distributor wiring, registry-only reward pool recording, claim-pull teaching rewards,
single and batch claims, transfer/buyback claim-right ownership, authority rotation after
buyback, dust release, settlement scalability, multi-stable teaching reserves, frozen
session stable assets, frozen fault quotes, paired registry admin-state initialisation,
and locked token minters.

`TeachingGasCalibration.t.sol` writes `teaching_gas_calibration.csv` and
`teaching_claim_gas_calibration.csv`, the measured settlement and claim gas tables used
by the cost simulation. It includes ordinary, forced-valid, customer-fault, and
teacher-fault paths across no-research, zero-share, research-backed, weighted multi-asset,
and multi-layer settings.

`ResearchRegistry.t.sol` covers research assets, positions, layer progression, revenue
escrows, buybacks, per-stable reserves, minter locking, treasury rotation, stable-asset
freezing for direct revenue escrows, and bounded decay.

`ResearchGasCalibration.t.sol` writes `research_gas_calibration.csv`, the measured
research-maintenance gas table used by the same simulation. It covers main asset
creation, current and prepared patch positions, layer sealing, early-decay approval, and
layer advancement.

Run the behavioural suite with:

```bash
forge test -vv
```

Run gas calibration tests only when the CSV outputs intentionally need to be refreshed;
the TypeScript simulation reads those CSVs rather than hard-coded numbers.
