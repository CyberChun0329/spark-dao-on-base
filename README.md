# Spark DAO on Base

Base/Solidity implementation of the Spark DAO protocol.

This repository contains the EVM-native implementation for research assets,
teaching settlement, claim-pull rewards, multi-stable reserves, deployment scripts,
Foundry tests, and gas simulation.

## Scope

- `src/`: core contracts
- `test/`: Foundry test suites used for behavioural and gas validation
- `script/`: deployment and demo scripts
- `client/`: minimal `viem` client helpers and reproducibility checks
- `simulation_inputs/` and `simulation_outputs/`: fee assumptions and generated cost outputs

The main contracts are:

- `ResearchRegistry.sol`
- `TeachingRegistry.sol`
- `TeachingRewardDistributor.sol`
- `TeachingPolicyGuard.sol`
- `TeachingEconomicsPolicyV1.sol`
- `TeachingFaultPolicyV1.sol`
- `ResearchPositionToken.sol`
- `TeachingNftToken.sol`

## Architecture

At a high level, Spark DAO converts off-chain teaching responsibility into recognised
on-chain state, bounded settlement outcomes, and claimable research reward rights:

![Spark DAO teaching and research contribution-rights architecture](docs/assets/spark_dao_nft_rights_architecture.svg)

The figure is conceptual; detailed contract surfaces are documented under `src/`.

- `ResearchRegistry` records research assets, position ownership, revenue and buyback
  flows, and per-stable reserve accounting.
- `TeachingRegistry` records teaching sessions, frozen settlement inputs, teaching vault
  reserves, and distributor callbacks.
- `TeachingRewardDistributor` handles claim-pull teaching reward pools; policy modules
  quote and validate teaching economics.

## Reproducibility

Build and test with Foundry:

```bash
forge build --sizes --skip script
forge test -vv
npm run client:typecheck
npm run check:reproducibility-config
npm run simulate:teaching-cost
npm run check:calibration
```

Cost outputs are generated from calibration tests and fee inputs. Use
`npm run check:calibration` before relying on reported numbers; do not edit generated
outputs by hand.

## Protocol Notes

- Teaching settlement is claim-pull. Research position holders claim through
  `TeachingRewardDistributor`, and each teaching session can link at most two research
  assets.
- Claim rights follow the current research position holder. DAO buybacks route future
  claims to the treasury holder.
- Stable assets are frozen at object creation. Vault reserves are tracked per stable
  asset, and idle teaching withdrawals cannot use reserved balance.
- Token minters are registry-controlled and can be locked after deployment.
- The teaching registry supports ordinary completion, customer-fault settlement, and
  teacher-fault remediation.

Configured stable assets are expected to be deployed standard ERC-20 tokens.

## Distributor wiring

`TeachingRegistry.setTeachingRewardDistributor` is an authority-only, one-time wiring
step. The registry and research registry perform reciprocal address checks before the
module addresses are stored.

## Deployment

Deployment is split into three scripts:

1. `DeployTokens.s.sol`
2. `DeployRegistry.s.sol` deploys `TeachingPolicyGuard`, `TeachingEconomicsPolicyV1`,
   `TeachingFaultPolicyV1`, `ResearchRegistry`, `TeachingRegistry`, and
   `TeachingRewardDistributor`, then wires research, teaching, and distributor addresses
3. `SetTokenMinters.s.sol` sets and locks the research token minter to `ResearchRegistry`
   and the teaching NFT minter to `TeachingRegistry`

`STABLE_ASSET`, `RESEARCH_POSITION_TOKEN`, `TEACHING_NFT_TOKEN`, and the teaching policy
modules must be deployed contract addresses.

Local end-to-end demos:

- `DemoResearch.s.sol`
- `DemoTeaching.s.sol`

## Configuration

Environment variables are listed in `.env.example`.
Project configuration is in `foundry.toml`.

For full teaching deployments, record the registry, distributor, and policy addresses
emitted by the deployment scripts. Reward preview and claim helpers require
`TEACHING_REWARD_DISTRIBUTOR`.

After deployment, use `npm run check:registry-admin-state` and
`npm run check:module-compatibility` for runtime configuration checks.

Local demos are for end-to-end execution on a local chain. Non-demo networks should set
deployment timing values through the environment.
