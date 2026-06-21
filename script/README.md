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

`DeployRegistry.s.sol` deploys the registries, policy modules, and distributor, then
wires them. The broadcast signer must be `DAO_AUTHORITY`.

It expects:

- `DAO_AUTHORITY`
- `DAO_COORDINATOR`
- `DAO_TREASURY`
- `STABLE_ASSET`
- `RESEARCH_POSITION_TOKEN`
- `TEACHING_NFT_TOKEN`
- `REWARD_UNLOCK_SECONDS`
- `BUYBACK_WAIT_SECONDS`

`STABLE_ASSET`, `RESEARCH_POSITION_TOKEN`, and `TEACHING_NFT_TOKEN` must be deployed
contract addresses.

Usage:

```bash
forge script script/DeployRegistry.s.sol:DeployRegistry --rpc-url <BASE_RPC> --broadcast
```

After this script, record the emitted registry, distributor, and policy addresses.

After deployment, run `npm run check:registry-admin-state` and
`npm run check:module-compatibility`.

`SetTokenMinters.s.sol` expects:

- `RESEARCH_REGISTRY`
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

`DemoResearch.s.sol` deploys its own `MockERC20`, `ResearchPositionToken`, and
`ResearchRegistry`.

`DemoTeaching.s.sol` deploys a local teaching/research stack and runs a reward claim path.

Demo scripts use local timing values. Set deployment timing values through the
environment for non-demo networks.

Additional environment variables:

- `DEMO_AUTHORITY_PRIVATE_KEY`
- `DEMO_COORDINATOR_PRIVATE_KEY`
- `DEMO_CONTRIBUTOR_ONE_PRIVATE_KEY`
- `DEMO_CONTRIBUTOR_TWO_PRIVATE_KEY`
- `DEMO_TEACHER_PRIVATE_KEY` for the teaching demo
- `DEMO_CUSTOMER_PRIVATE_KEY` for the teaching demo
