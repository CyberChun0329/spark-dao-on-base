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

The teaching demo wires the distributor into the registry and runs a local claim path.
Use environment timing values for non-demo deployments.

## 2. Protocol Regression Checks

Common checks:

```bash
npm run build
npm run build:sizes
npm run test
npm run client:typecheck
npm run simulate:teaching-cost
npm run check:calibration
```

Notes:

- `build:sizes` reports deployable protocol contract sizes.
- `check:registry-admin-state` and `check:module-compatibility` require a deployed
  environment.
- `check:module-compatibility:example` validates the example manifest format without
  chain access.

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

`DeployRegistry.s.sol` deploys the registries, policy modules, and distributor, then
wires the registry/distributor addresses. The broadcast signer must be `DAO_AUTHORITY`.

Use deployed contract addresses for stable asset and token inputs.

After deployment, record the registry, distributor, and policy addresses.

For manifest-based deployment review:

```bash
npm run check:module-compatibility
```

3. Set and lock token minters:

```bash
npm run deploy:set-minters
```

Set registry minters for both token contracts, then lock them.

Run these checks after deployment:

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

Set inspection IDs in the environment when deeper state reads are needed.

## 5. Base Sepolia

For Base Sepolia:

- set `BASE_RPC_URL` to a Sepolia RPC endpoint
- set `DAO_AUTHORITY` and `DAO_COORDINATOR` to the intended deployment addresses
- set `DAO_TREASURY` to the intended treasury or multisig
- use deployed contract addresses for `STABLE_ASSET`, `RESEARCH_POSITION_TOKEN`, and
  `TEACHING_NFT_TOKEN`
- set the distributor and policy addresses from the registry deployment output
- set production values for `REWARD_UNLOCK_SECONDS` and `BUYBACK_WAIT_SECONDS`

Set deployment timing values explicitly for non-demo networks.

Recommended order:

1. Run the local `anvil` path.
2. Deploy token and registry contracts to Base Sepolia.
3. Run a minimal smoke test and the registry/module compatibility checks.

## 6. Gas And Simulation Refresh

Refresh generated gas and cost outputs:

```bash
forge test --match-contract TeachingGasCalibrationTest
forge test --match-contract ResearchGasCalibrationTest
npm run simulate:teaching-cost
npm run check:calibration
```

The calibration tests write the CSV inputs; the simulation rewrites
`simulation_outputs/`.
