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

`DeployRegistry.s.sol` expects:

- `DAO_AUTHORITY`
- `DAO_COORDINATOR`
- `STABLE_ASSET`
- `RESEARCH_POSITION_TOKEN`
- `TEACHING_NFT_TOKEN`
- `REWARD_UNLOCK_SECONDS`
- `BUYBACK_WAIT_SECONDS`

Usage:

```bash
forge script script/DeployRegistry.s.sol:DeployRegistry --rpc-url <BASE_RPC> --broadcast
```

`SetTokenMinters.s.sol` expects:

- `TEACHING_REGISTRY`
- `RESEARCH_POSITION_TOKEN`
- `TEACHING_NFT_TOKEN`

Usage:

```bash
forge script script/SetTokenMinters.s.sol:SetTokenMinters --rpc-url <BASE_RPC> --broadcast
```

## Demo scripts

- `DemoResearch.s.sol`
- `DemoTeaching.s.sol`

Both demo scripts deploy their own `MockERC20`, token contracts, and registry instance. They set `rewardUnlockSeconds` and `buybackWaitSeconds` to `0` so the full path runs in one local pass.

Additional environment variables:

- `DEMO_AUTHORITY_PRIVATE_KEY`
- `DEMO_COORDINATOR_PRIVATE_KEY`
- `DEMO_CONTRIBUTOR_ONE_PRIVATE_KEY`
- `DEMO_CONTRIBUTOR_TWO_PRIVATE_KEY`
- `DEMO_TEACHER_PRIVATE_KEY` for the teaching demo
- `DEMO_CUSTOMER_PRIVATE_KEY` for the teaching demo
