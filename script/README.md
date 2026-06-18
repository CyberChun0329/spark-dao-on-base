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

`DeployRegistry.s.sol` deploys `TeachingPolicyGuard`, `TeachingEconomicsPolicyV1`,
`TeachingFaultPolicyV1`, `ResearchRegistry`, `TeachingRegistry`, and
`TeachingRewardDistributor`. It wires `ResearchRegistry` to the teaching registry and
wires the distributor into the teaching registry. The broadcast signer must be
`DAO_AUTHORITY` for both wiring calls. The teaching registry verifies that the candidate
distributor points back to the new teaching and research registries; the research
registry verifies that the teaching registry points back to it. These checks prevent
common address mismatches but do not replace trusted deployment of the intended bytecode.

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
contract addresses. The registries reject EOA placeholders before storing them.

Usage:

```bash
forge script script/DeployRegistry.s.sol:DeployRegistry --rpc-url <BASE_RPC> --broadcast
```

After this script, record the first returned address as `RESEARCH_REGISTRY`, the second
as `TEACHING_REGISTRY`, the third as `TEACHING_REWARD_DISTRIBUTOR`, the fourth as
`TEACHING_POLICY_GUARD`, the fifth as `TEACHING_ECONOMICS_POLICY`, and the sixth as
`TEACHING_FAULT_POLICY`.

If research and teaching should remain under the same admin/default settings, run
`npm run check:registry-admin-state` after deployment and after later admin rotations.
Run `npm run check:module-compatibility` after recording the distributor and policy
addresses to verify registry/distributor/policy wiring and policy versions. For bytecode
checks, copy `client/module-compatibility.example.json`, fill the deployed addresses and
optional deployed bytecode hashes, then set `MODULE_COMPATIBILITY_MANIFEST`.

`SetTokenMinters.s.sol` expects:

- `RESEARCH_REGISTRY`
- `TEACHING_REGISTRY`
- `TEACHING_REWARD_DISTRIBUTOR` is not used by this script, but should be recorded in
  client/runtime configuration after `DeployRegistry.s.sol`
- `TEACHING_POLICY_GUARD` is not used by this script, but should be recorded in
  client/runtime configuration after `DeployRegistry.s.sol`
- `TEACHING_ECONOMICS_POLICY` is not used by this script, but should be recorded in
  client/runtime configuration after `DeployRegistry.s.sol`
- `TEACHING_FAULT_POLICY` is not used by this script, but should be recorded in
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
`TeachingNftToken`, `TeachingPolicyGuard`, `TeachingEconomicsPolicyV1`,
`TeachingFaultPolicyV1`, `ResearchRegistry`, `TeachingRegistry`, and
`TeachingRewardDistributor`. It wires research to teaching, wires the distributor into
the teaching registry, then claims teaching rewards through the distributor rather than
through `TeachingRegistry`.

Both demo scripts set `rewardUnlockSeconds` and `buybackWaitSeconds` to `0` so the full
demo path runs in one local pass. Production deployments should set non-zero governance
waiting periods in the environment before running the deployment scripts; v1 treats these
windows as configured deployment parameters rather than hard-coded protocol minimums.

Additional environment variables:

- `DEMO_AUTHORITY_PRIVATE_KEY`
- `DEMO_COORDINATOR_PRIVATE_KEY`
- `DEMO_CONTRIBUTOR_ONE_PRIVATE_KEY`
- `DEMO_CONTRIBUTOR_TWO_PRIVATE_KEY`
- `DEMO_TEACHER_PRIVATE_KEY` for the teaching demo
- `DEMO_CUSTOMER_PRIVATE_KEY` for the teaching demo
