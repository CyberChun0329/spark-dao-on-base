# Base Runbook

Operational notes for the Base/Solidity implementation.

## Local Setup

Start a local chain:

```bash
anvil
```

Create a local `.env` from `.env.example` and set:

- `BASE_RPC_URL`
- `BASE_CHAIN`
- demo private keys
- deployed addresses when using a persistent environment

Local demo scripts deploy their own temporary contracts.

## Regression Checks

Run these before relying on a local build:

```bash
forge build --sizes --skip script
forge test -vv
npm run client:typecheck
npm run check:reproducibility-config
npm run check:teaching-surface
```

Refresh and verify teaching-cost outputs:

```bash
npm run check:calibration
```

`check:calibration` rewrites the Teaching lifecycle calibration CSVs and
`simulation_outputs/` from the current source.

## Deployment Path

1. Deploy tokens:

```bash
npm run deploy:tokens
```

2. Deploy the research and teaching stack:

```bash
npm run deploy:registry
```

3. Set and lock registry minters:

```bash
npm run deploy:set-minters
```

Then run:

```bash
npm run check:registry-admin-state
npm run check:module-compatibility
```

## Local Demos

Research-only path:

```bash
npm run demo:research
```

Teaching path:

```bash
npm run demo:teaching
```

Single-learner lessons use the teaching path with one seat.
`TeachingRegistry` keeps the Teaching protocol surface while the session API supports
`classSize` and per-seat accounting for fresh deployments.

- classSize = 1 preserves the single-seat economic, reserve, claim, dust, buyback, and stable-asset semantics.
- Schedule confirmation is teacher + coordinator.
- Fault refunds are per-seat claim-pull.
- Customer-fault teacher half wage follows the teacher payout redeem delay.
- Valid close treats paid, unmarked, non-attending seats as completed seats with no refund.
- Attendance auto-close requires paid attendance over half of total `classSize`.
- Attendance auto-close has no upper time window after `scheduledAt`; coordinator fallback starts after the timeout.
- Customer fault remains per-seat state inside a valid closed teaching session. It is coordinator-only, must be marked while the session is open, and requires a paid seat.
- Clients should read teaching state through `getTeachingSessionState`, `getTeachingSeat`, and teaching reward distributor getters.
- Teaching events are the teaching event surface for demos.

Read-only inspection:

```bash
npm run client:inspect
```

## Base Sepolia

For Base Sepolia, set:

- `BASE_RPC_URL`
- `BASE_CHAIN=base-sepolia`
- `DAO_AUTHORITY`
- `DAO_COORDINATOR`
- `DAO_TREASURY`
- `STABLE_ASSET`
- token addresses
- timing values

Use deployed module addresses from the deployment output. Run the registry and module
compatibility checks after deployment.
