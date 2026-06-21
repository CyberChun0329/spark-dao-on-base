# Tests

Foundry tests for the Base implementation.

`TeachingRegistry.t.sol` covers ordinary teaching completion, coordinator-forced valid
settlement, customer-fault half-price settlement, teacher-fault remedial settlement,
distributor wiring, registry-only reward pool recording, claim-pull teaching rewards,
single and batch claims, transfer/buyback claim-right ownership, authority rotation after
buyback, dust release, settlement scalability, multi-stable teaching reserves, frozen
session stable assets, frozen fault quotes, paired registry admin-state initialisation,
and locked token minters.

`TeachingGasCalibrationTest` writes `teaching_gas_calibration.csv` and
`teaching_followup_gas_calibration.csv`, the current teaching gas tables used by the
schema-version-2 cost simulation. It includes ordinary, forced-valid, customer-fault, and
teacher-fault paths across no-research, zero-share, research-backed, weighted multi-asset,
and multi-layer settings, plus the teacher-fault remedial wage follow-up primitive. The
follow-up CSV includes `measurement_context` so the remedial wage close measurement is
kept separate from scenario-level lesson lifecycle expectations.

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

Run gas calibration tests only when the CSV outputs intentionally need to be refreshed.
The current TypeScript simulation is `npm run simulate:teaching-cost`; it reads the
generated schema-version-2 CSVs rather than hard-coded numbers.
`npm run check:calibration` reruns the teaching writers, the research gas writer,
typecheck, reproducibility checks, simulation, and a Git clean-worktree check when
available.
