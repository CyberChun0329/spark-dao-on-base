# Tests

Foundry tests for the Base implementation.

## Behaviour

- `ResearchRegistry.t.sol`: research assets, positions, layer progression, revenue,
  buybacks, reserves, teaching claim writeback, minter locking, and decay.
- `TeachingRegistry.t.sol`: teaching settlement, per-seat accounting, reserve
  conservation, schedule confirmation, attendance-majority auto close, reward claims,
  batch atomicity, dust release, and buyback claim routing.
- `TeachingSingleSeatCompatibility.t.sol`: class-size-1 economic, reserve, claim,
  dust, buyback, and stable-asset invariants.
- `TeachingPricingPolicy.t.sol`: quote-module boundaries.

Teaching compatibility notes:

- classSize = 1 preserves the single-seat economic, reserve, claim, dust, buyback, and stable-asset semantics.
- Schedule confirmation is teacher + coordinator.
- Fault refunds are per-seat claim-pull.
- Customer-fault teacher half wage follows the teacher payout redeem delay.
- Customer fault remains per-seat state inside a valid closed teaching session.
- Clients should read teaching state through `getTeachingSessionState`, `getTeachingSeat`, and teaching reward distributor getters.
- Teaching events are the teaching event surface for demos.

Run:

```bash
forge test -vv
```

## Gas And Calibration

- `TeachingGasCalibration.t.sol` writes the Teaching lifecycle cost inputs:
  - `teaching_gas_calibration.csv`
  - `teaching_followup_gas_calibration.csv`
  - `teaching_class_size_gas_calibration.csv`
- `ResearchGasCalibration.t.sol` writes:
  - `research_gas_calibration.csv`

Refresh generated cost outputs with:

```bash
npm run check:calibration
```

Teaching tests validate the active teaching surface.
