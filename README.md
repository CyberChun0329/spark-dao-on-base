# Spark DAO on Base

Base implementation of the Spark DAO protocol.

This codebase is a protocol-focused migration from the earlier Solana implementation. It preserves the economic logic used in the paper and recasts it in an EVM-native form for Base.

## Scope

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

Build and test with Foundry:

```bash
forge build
forge test -vvv
forge test --gas-report
```

The gas report underpins the representative execution paths used in the protocol cost-scalability chapter.

## Deployment

Deployment is split into three scripts:

1. `DeployTokens.s.sol`
2. `DeployRegistry.s.sol`
3. `SetTokenMinters.s.sol`

Local end-to-end demos:

- `DemoResearch.s.sol`
- `DemoTeaching.s.sol`

## Configuration

Environment variables are listed in `.env.example`.
Project configuration is in `foundry.toml`.

## Snapshot Use

This Base version is intended to serve as the protocol snapshot for supplementary material. Build artefacts, caches, and package dependencies should be excluded from archival uploads.
