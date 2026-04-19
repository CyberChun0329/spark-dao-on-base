# Spark DAO on Base

This directory contains the Base version of the Spark DAO protocol.

The codebase is a protocol-focused migration from the earlier Solana implementation. It keeps the economic logic that matters for the paper while expressing the system in an EVM-native form suitable for Base.

## Scope

The snapshot includes three protocol layers:

- `src/`: core contracts
- `test/`: Foundry test suites used for behavioural and gas validation
- `script/`: deployment and demo scripts

The main contracts are:

- `ResearchRegistry.sol`
- `TeachingRegistry.sol`
- `TeachingRewardRegistry.sol`
- `ResearchPositionToken.sol`
- `TeachingNftToken.sol`

## Reproducibility

The protocol can be rebuilt and tested with Foundry:

```bash
forge build
forge test -vvv
forge test --gas-report
```

The gas report is the basis for the representative execution paths cited in the paper chapter on protocol cost scalability.

## Deployment

The deployment flow is split into three scripts:

1. `DeployTokens.s.sol`
2. `DeployRegistry.s.sol`
3. `SetTokenMinters.s.sol`

Local end-to-end demonstrations are available through:

- `DemoResearch.s.sol`
- `DemoTeaching.s.sol`

## Configuration

Environment variables are documented in `.env.example`.

The Foundry project configuration is stored in `foundry.toml`.

## Snapshot Use

This Base version is intended to serve as the protocol snapshot for supplementary material. Build artefacts, caches, and package dependencies should not be included in the archival upload.
