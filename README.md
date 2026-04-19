# Spark DAO on Base

This repository is the Base protocol snapshot accompanying *Programmable Governance under Limited Verifiability: Evidence from a Knowledge-Intensive Service Organisation*. It provides the executable governance layer used in the paper's protocol analysis, together with the behavioural tests and gas evidence used in the cost-scalability discussion.

The codebase does not try to automate an entire education business. It formalises a narrower set of recurrent, rule-bound activities that are expensive to reconstruct ex post: lesson attribution, staged validation, payout release, research linkage, and the intertemporal allocation of downstream value to prior knowledge contributions. In that sense, the repository is better read as a bounded governance architecture than as an NFT project.

## What the protocol does

The protocol models a minimal educational organisation in which teaching activity, upstream research contribution, and validation authority must be coordinated without relying on fully discretionary bookkeeping.

On the teaching side, each lesson is recorded as a non-transferable Teaching NFT. A session moves through schedule confirmation, collateral locking, completion confirmation, and, when necessary, coordinator resolution. Once a lesson is settled as valid, the teacher-side payout becomes redeemable after the configured delay, and any research-linked share is recorded for downstream distribution.

On the research side, upstream knowledge contributions are represented as research assets, while downstream claims are recorded through research positions. When a teaching session references one or more research assets, the protocol can reserve a research share of lesson value and distribute that share across active positions under the linked asset according to layer, weight, and timing rules. Research positions are therefore governance objects rather than unrestricted speculative tokens.

## Why this snapshot is on Base

Earlier protocol work for Spark DAO was developed on Solana. The snapshot released here is the Base version because the paper's governance model creates many persistent state objects: teaching records, linked research references, reward ledgers, and research positions that remain relevant across later sessions. Under Solana's account model, once rent and storage burdens are taken seriously, that design can make operating cost rise faster than the teaching economy itself would justify. For a system centred on relatively low-value, high-frequency educational sessions, that constraint is material.

The Base implementation does not make execution free, but it avoids that particular source of cost inflation. The main recurring burden falls on transaction execution rather than on an expanding set of rent-sensitive state objects. For the bounded-feasibility question studied in the paper, Base therefore provides the cleaner operating environment.

## Repository structure

- `src/`: Base smart contracts
- `test/`: Foundry test suites for behavioural validation and gas measurement
- `script/`: deployment and demonstration scripts

The principal contracts are `TeachingRegistry.sol`, `TeachingRewardRegistry.sol`, `ResearchRegistry.sol`, `TeachingNftToken.sol`, and `ResearchPositionToken.sol`. These contracts implement the protocol layer analysed in the paper. The representative gas benchmarks cited in the cost-scalability chapter are drawn from the included tests and gas reports.

## Reproducibility

The Base implementation can be rebuilt and tested with Foundry:

```bash
forge build
forge test -vvv
forge test --gas-report
```

For deployment and local end-to-end demonstrations, see `script/DeployTokens.s.sol`, `script/DeployRegistry.s.sol`, `script/SetTokenMinters.s.sol`, `script/DemoResearch.s.sol`, and `script/DemoTeaching.s.sol`. Environment variables are documented in `.env.example`, and core project configuration is stored in `foundry.toml`.

## Why this repository matters for the paper

The paper argues that programmable governance becomes organisationally meaningful only when the execution layer remains workable under growth. This repository makes that claim inspectable. It shows how teaching events are created, validated, settled, and connected to upstream research contributions, and it provides the executable basis for the gas and scaling analysis reported in the paper. This is the protocol snapshot from which the paper's bounded-feasibility analysis is derived.
