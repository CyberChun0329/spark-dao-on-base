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

## Teaching fault settlement

The Base teaching registry uses a fault-contingent settlement rule for lessons that cannot be closed by ordinary two-sided completion:

- customer fault keeps half of the locked lesson price, refunds the other half, and pays the teacher `min(teacher salary, half price)` together with the returned teacher bond;
- teacher fault keeps half of the locked lesson price, refunds the other half, returns the teacher bond, pays no teaching salary, and records one remedial lesson owed on the same teaching record;
- research-linked rewards are not inferred from customer fault, but teacher fault can still fund research/IP rewards for the affected lesson and the remedial lesson from the retained half-price amount;
- teaching research share is capped at 25% on-chain so the teacher-fault branch remains solvent. The intended operating cap can be lower.

Remaining retained funds are left in the registry as service-guarantee reserve, not booked as a teacher or customer payout.

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
