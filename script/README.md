# Scripts

Deployment and demo scripts for the Base version of Spark DAO.

## Deployment scripts

- `DeployTokens.s.sol`
- `DeployRegistry.s.sol`
- `SetTokenMinters.s.sol`

`DeployTokens.s.sol` expects:

- `DAO_AUTHORITY`
- `RESEARCH_BASE_URI`
- `TEACHING_BASE_URI`

Usage:

```bash
forge script script/DeployTokens.s.sol:DeployTokens --rpc-url <BASE_RPC> --broadcast
```

`DeployRegistry.s.sol` deploys `TeachingRegistry`, deploys `TeachingRewardDistributor`,
and wires the distributor into the registry. The broadcast signer must be `DAO_AUTHORITY`
for the wiring call. The registry stores the distributor only once and verifies that the
candidate distributor's `TEACHING_REGISTRY()` points back to the new registry. This
prevents common address mismatches but does not replace trusted deployment of the
intended distributor bytecode.

It expects:

- `DAO_AUTHORITY`
- `DAO_COORDINATOR`
- `DAO_TREASURY`
- `STABLE_ASSET`
- `RESEARCH_POSITION_TOKEN`
- `TEACHING_NFT_TOKEN`
- `REWARD_UNLOCK_SECONDS`
- `BUYBACK_WAIT_SECONDS`

Usage:

```bash
forge script script/DeployRegistry.s.sol:DeployRegistry --rpc-url <BASE_RPC> --broadcast
```

After this script, record the returned registry address as `TEACHING_REGISTRY`. In a full
teaching deployment the same address also serves the research surface, so set
`RESEARCH_REGISTRY` to the same address unless you intentionally deployed a separate
research-only registry. Record the second returned address as
`TEACHING_REWARD_DISTRIBUTOR`.

`SetTokenMinters.s.sol` expects:

- `TEACHING_REGISTRY`
- `TEACHING_REWARD_DISTRIBUTOR` is not used by this script, but should be recorded in
  client/runtime configuration after `DeployRegistry.s.sol`
- `RESEARCH_POSITION_TOKEN`
- `TEACHING_NFT_TOKEN`

Usage:

```bash
forge script script/SetTokenMinters.s.sol:SetTokenMinters --rpc-url <BASE_RPC> --broadcast
```

## Demo scripts

- `DemoResearch.s.sol`
- `DemoTeaching.s.sol`

`DemoResearch.s.sol` deploys its own `MockERC20`, `ResearchPositionToken`, and
`ResearchRegistry`.

`DemoTeaching.s.sol` deploys its own `MockERC20`, `ResearchPositionToken`,
`TeachingNftToken`, `TeachingRegistry`, and `TeachingRewardDistributor`. It wires the
distributor into the registry, then claims teaching rewards through the distributor
rather than through `TeachingRegistry`.

Both demo scripts set `rewardUnlockSeconds` and `buybackWaitSeconds` to `0` so the full
demo path runs in one local pass.

Additional environment variables:

- `DEMO_AUTHORITY_PRIVATE_KEY`
- `DEMO_COORDINATOR_PRIVATE_KEY`
- `DEMO_CONTRIBUTOR_ONE_PRIVATE_KEY`
- `DEMO_CONTRIBUTOR_TWO_PRIVATE_KEY`
- `DEMO_TEACHER_PRIVATE_KEY` for the teaching demo
- `DEMO_CUSTOMER_PRIVATE_KEY` for the teaching demo
