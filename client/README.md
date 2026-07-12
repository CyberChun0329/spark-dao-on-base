# Client

Minimal `viem` helper layer for deployment checks, inspection, and reward claims.

## Configuration

Required for the teaching stack:

- `BASE_RPC_URL`
- `BASE_CHAIN`
- `RESEARCH_REGISTRY`
- `TEACHING_REGISTRY`
- `TEACHING_REWARD_DISTRIBUTOR`
- `TEACHING_PRICING_POLICY`

Optional module and token addresses:

- `RESEARCH_POSITION_TOKEN`
- `TEACHING_NFT_TOKEN`

## Checks

```bash
npm run client:typecheck
npm run check:registry-admin-state
npm run check:module-compatibility
```

Validate the example manifest without chain access:

```bash
npm run check:module-compatibility:example
```

`check:module-compatibility` checks deployed wiring, token minters and locks, pricing policy
version, and optional bytecode hashes.

## Helpers

- `research.ts`: research registry reads, including per-stable claim totals
- `teaching.ts`: teaching reads, schedule and progress confirmation, seat actions,
  settlement calls, and claims
- `inspect.ts`: read-only environment inspection

## Teaching Compatibility

- classSize = 1 preserves the single-seat economic, reserve, claim, dust, buyback, and stable-asset semantics.
- Schedule confirmation is teacher + coordinator.
- Fault refunds are per-seat claim-pull.
- Customer-fault teacher half wage follows the teacher payout redeem delay.
- Customer fault remains per-seat state inside a valid closed teaching session.
- Clients should read teaching state through `getTeachingSessionState`, `getTeachingProgressState`, `getTeachingSeat`, and teaching reward distributor getters.
- Teaching events are the teaching event surface for demos.

The client layer is intentionally thin. Contract behaviour is defined by the Solidity
sources and tests.
