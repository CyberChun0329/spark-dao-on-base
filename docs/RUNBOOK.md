# Base Runbook

This runbook covers two operating paths for the Base/Solidity implementation:
local `anvil` execution and Base Sepolia deployment.

## 1. Local Development Chain

Start with `anvil` for local checks:

```bash
anvil
```

Create a local environment file from `.env.example`. At minimum, set:

- `BASE_RPC_URL=http://127.0.0.1:8545`
- `BASE_CHAIN=base-sepolia` or `BASE_CHAIN=base`
- demo private keys:
  - `DEMO_AUTHORITY_PRIVATE_KEY`
  - `DEMO_COORDINATOR_PRIVATE_KEY`
  - `DEMO_CONTRIBUTOR_ONE_PRIVATE_KEY`
  - `DEMO_CONTRIBUTOR_TWO_PRIVATE_KEY`
  - `DEMO_TEACHER_PRIVATE_KEY`
  - `DEMO_CUSTOMER_PRIVATE_KEY`

The local demo scripts deploy their own temporary contracts:

- `DemoResearch.s.sol` deploys `MockERC20`, `ResearchPositionToken`, and `ResearchRegistry`.
- `DemoTeaching.s.sol` deploys `MockERC20`, `ResearchPositionToken`,
  `TeachingNftToken`, `TeachingPolicyGuard`, `TeachingEconomicsPolicyV1`,
  `TeachingFaultPolicyV1`, `ResearchRegistry`, `TeachingRegistry`, and
  `TeachingRewardDistributor`.

The teaching demo wires the distributor into the registry and claims teaching rewards
through the distributor. It sets `rewardUnlockSeconds` and `buybackWaitSeconds` to `0`
so the full local claim and buyback path can run in a single pass.

Do not reuse the demo timing values for production deployments. Production operators
should choose non-zero reward and buyback waiting windows in the deployment environment;
v1 treats those windows as configured deployment parameters rather than hard-coded
protocol minimums.

## 2. Protocol Regression Checks

Common checks:

```bash
npm run build
npm run build:sizes
npm run test
npm run client:typecheck
npm run simulate:teaching-cost:v2
npm run check:calibration:v2
```

Notes:

- `build:sizes` uses `--skip script` so the size report focuses on deployable protocol
  contracts rather than script contracts.
- `check:registry-admin-state` requires a deployed environment. It compares research and
  teaching registry authority, coordinator, treasury, stable asset, and timing defaults.
- `check:module-compatibility` requires a deployed environment. It checks registry
  module state, distributor immutables, policy version getters, and policy guard
  validation results.
- `check:module-compatibility:example` validates the example manifest format without
  requiring chain access.

## 3. Deployment Order

Deployment is split into three steps.

1. Deploy tokens:

```bash
npm run deploy:tokens
```

2. Deploy the research registry, teaching registry, policy modules, and reward
   distributor:

```bash
npm run deploy:registry
```

`DeployRegistry.s.sol` deploys `TeachingPolicyGuard`, `TeachingEconomicsPolicyV1`,
`TeachingFaultPolicyV1`, `ResearchRegistry`, `TeachingRegistry`, and
`TeachingRewardDistributor`. It then calls `ResearchRegistry.setTeachingRegistry` and
`TeachingRegistry.setTeachingRewardDistributor`. The broadcast signer must be
`DAO_AUTHORITY`, or otherwise be able to act as `DAO_AUTHORITY` for these one-time
wiring calls.

Stable asset and token inputs are validated as deployed contract addresses. If an EOA or
undeployed address is supplied, deployment reverts before the registry stores it.
Stable assets are expected to be standard ERC-20 tokens without transfer fees, rebasing
balance changes, or transfer callbacks, because registry reserve accounting assumes the
requested transfer amount is the amount that actually moves.

The registry/distributor handshake catches common address and deployment-order mistakes:
the teaching registry checks the distributor's `TEACHING_REGISTRY()` and
`RESEARCH_REGISTRY()` immutables, and the research registry checks that the teaching
registry points back to the expected research registry. These checks do not prove that
the deployed bytecode is benign; deployment operators must still use trusted artifacts.

After deployment, record:

- `RESEARCH_REGISTRY`
- `TEACHING_REGISTRY`
- `TEACHING_REWARD_DISTRIBUTOR`
- `TEACHING_POLICY_GUARD`
- `TEACHING_ECONOMICS_POLICY`
- `TEACHING_FAULT_POLICY`

For bytecode-aware deployment review, copy `client/module-compatibility.example.json`,
fill real addresses and optional `deployedBytecodeHash` values, set
`MODULE_COMPATIBILITY_MANIFEST`, and run:

```bash
npm run check:module-compatibility
```

Without recorded bytecode hashes, the manifest check verifies address and wiring
consistency only.

3. Set and lock token minters:

```bash
npm run deploy:set-minters
```

The research position token minter should be set to `ResearchRegistry`, the teaching NFT
token minter should be set to `TeachingRegistry`, and both minters should then be locked.

If research and teaching should stay under the same admin/default settings, run these
checks after deployment and after later admin rotations:

```bash
npm run check:registry-admin-state
npm run check:module-compatibility
```

## 4. Local Demos

Research flow:

```bash
npm run demo:research
```

Teaching plus research-linked reward flow:

```bash
npm run demo:teaching
```

Read-only chain inspection:

```bash
npm run client:inspect
```

Optional inspection variables:

- `INSPECT_ASSET_ID`
- `INSPECT_POSITION_ID`
- `INSPECT_TEACHING_NFT_ID`

If `INSPECT_TEACHING_NFT_ID`, `INSPECT_ASSET_ID`, and `INSPECT_POSITION_ID` are all set,
the inspection script reads teaching reward preview state. That path requires
`TEACHING_REWARD_DISTRIBUTOR`.

## 5. Base Sepolia

For Base Sepolia:

- set `BASE_RPC_URL` to a Sepolia RPC endpoint
- set `DAO_AUTHORITY` and `DAO_COORDINATOR` to the intended deployment addresses
- set `DAO_TREASURY` to the intended treasury or multisig
- use deployed contract addresses for `STABLE_ASSET`, `RESEARCH_POSITION_TOKEN`, and
  `TEACHING_NFT_TOKEN`
- set `TEACHING_REWARD_DISTRIBUTOR` from the `DeployRegistry.s.sol` output
- set `TEACHING_POLICY_GUARD` from the `DeployRegistry.s.sol` output
- set `TEACHING_ECONOMICS_POLICY` from the `DeployRegistry.s.sol` output
- set `TEACHING_FAULT_POLICY` from the `DeployRegistry.s.sol` output
- set production values for `REWARD_UNLOCK_SECONDS` and `BUYBACK_WAIT_SECONDS`

Do not use demo zero-delay parameters for production-like deployments. The local
teaching demo uses a future `scheduledAt` and Foundry time controls only for fast local
execution; it is not a production backfill model.

Recommended order:

1. Run the local `anvil` path.
2. Deploy token and registry contracts to Base Sepolia.
3. Run a minimal smoke test and the registry/module compatibility checks.

## 6. Gas And Simulation Refresh

Gas and cost numbers are generated, not hand-filled:

```bash
forge test --match-contract TeachingGasCalibrationTest
forge test --match-contract TeachingGasCalibrationV2Test
forge test --match-contract ResearchGasCalibrationTest
npm run simulate:teaching-cost:v2
npm run check:calibration:v2
```

The current public cost model is V2. `TeachingGasCalibrationV2Test` writes
`teaching_gas_calibration_v2.csv` and `teaching_followup_gas_calibration_v2.csv`.
`ResearchGasCalibrationTest` writes `research_gas_calibration.csv`. The V2 simulation
script reads those CSVs plus `simulation_inputs/fee_assumptions.json` and rewrites the V2
files under `simulation_outputs/`. The freeze check command reruns the V2 generators and
simulation, then verifies that regeneration leaves no unstaged output drift when it is run
inside a Git worktree.

The V1 teaching calibration CSVs and `npm run simulate:teaching-cost` remain available
only as a historical reproducibility baseline. Do not use them as the current public cost
model.
