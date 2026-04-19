# Spark DAO on Base

This repository contains the Base protocol snapshot underlying the programmable governance system analysed in *Programmable Governance under Limited Verifiability: Evidence from a Knowledge-Intensive Service Organisation*. It is released as supplementary material for the paper and is intended to make the protocol logic, behavioural tests, and gas-based cost evidence directly inspectable.

The codebase implements a bounded governance architecture for a minimalised education-service organisation. It does not attempt to automate every organisational activity. Instead, it formalises a narrower set of recurrent and rule-bound tasks that are costly to reconstruct ex post: lesson attribution, staged validation, payout release, research linkage, and the intertemporal allocation of downstream value to prior knowledge contributions.

## What this repository contains

The repository has three core layers:

- `src/`: Base smart contracts
- `test/`: Foundry test suites for behavioural validation and gas measurement
- `script/`: deployment and demonstration scripts

The principal contracts are:

- `TeachingRegistry.sol`
- `TeachingRewardRegistry.sol`
- `ResearchRegistry.sol`
- `TeachingNftToken.sol`
- `ResearchPositionToken.sol`

These contracts implement the executable governance layer used in the paper's protocol analysis. The representative gas benchmarks cited in the cost-scalability chapter are drawn from the included tests and gas reports.

## Why the supplementary snapshot is on Base

Earlier protocol work for Spark DAO was developed on Solana. The supplementary snapshot released here is the Base version. The shift was driven by operating-cost structure rather than by any broader claim about chain ideology.

The governance model studied in the paper creates many persistent state objects: teaching records, linked research references, reward ledgers, and research positions that remain relevant across later sessions. Under Solana's account model, especially once rent and storage burdens are taken seriously, that design can make operating cost rise faster than the teaching economy itself would justify. For a system centred on relatively low-value, high-frequency educational sessions, that constraint was material.

The Base implementation does not make execution free, but it avoids that particular source of cost inflation. The main recurring burden falls on transaction execution rather than on an expanding set of rent-sensitive state objects. For the bounded-feasibility question addressed in the paper, Base therefore provides the cleaner operating environment.

## The governance model

The protocol represents a minimal educational organisation in which teaching activity, upstream research contribution, and validation authority must be coordinated without relying on fully discretionary ex post bookkeeping. In practice, the organisation does three things. It records a teaching event as a governance-relevant unit rather than as an informal spreadsheet entry. It validates that event through staged confirmations and, where necessary, coordinator intervention. It allocates value across time by linking current teaching sessions to earlier research assets and distributing the research share through predefined rules.

The system is therefore better understood as a governance architecture than as an NFT project. The tokens serve attribution, validation, and allocation functions in a setting where contributions are only partly verifiable and where downstream value depends on upstream knowledge inputs.

## Teaching-side logic

The Teaching NFT is a non-transferable record of a specific teaching session. It is best understood as a governed execution object rather than as a tradable digital asset.

When a session is created, the protocol records the teacher, learner, course type, scheduled time, and any linked research assets. The session then moves through a staged lifecycle: schedule confirmation, collateral locking, completion confirmation, and, if necessary, coordinator resolution. Once those conditions are satisfied, the session is settled as valid, the teacher-side payout becomes redeemable after the configured delay, and any research-linked share is recorded for downstream distribution.

The Teaching NFT anchors the formal existence of a teaching event, records the validation status of that event, and acts as the key through which teacher compensation can later be released. Because it is non-transferable, it is not designed for secondary-market circulation.

## Research-side logic

The research side of the protocol records upstream knowledge contributions as research assets and tracks downstream entitlements through research positions. This is the layer that supports intertemporal allocation.

A research asset represents an identifiable knowledge contribution that may later be linked to teaching sessions. When a teaching session references one or more research assets, the protocol can reserve a research share of session value and distribute that share across active positions under the linked asset according to layer, weight, and timing rules.

The codebase separates two related objects:

- the research asset, which anchors the upstream contribution
- the research position, which represents a governed claim over future flows associated with that asset

Research positions are not intended for unrestricted peer-to-peer circulation. Transfer and reallocation are channelled through protocol-defined flows. The purpose of the mechanism is controlled governance over who holds future claims and under what conditions those claims decay, roll over, or become redeemable.

## Why this matters for the paper

The paper argues that programmable governance becomes organisationally meaningful only when the execution layer remains workable under growth. This repository supports that claim in two ways. First, it makes the organisational logic concrete: readers can inspect how teaching events are created, validated, settled, and connected to upstream research contributions. Second, it provides the executable basis for the gas and scaling analysis reported in the paper. This is the protocol snapshot from which the paper's bounded-feasibility analysis is derived.

## Reproducibility

The Base implementation can be rebuilt and tested with Foundry:

```bash
forge build
forge test -vvv
forge test --gas-report
```

The repository includes the contract code, behavioural tests, and gas-report workflow used to generate representative execution traces. For deployment and local end-to-end demonstrations, see:

- `script/DeployTokens.s.sol`
- `script/DeployRegistry.s.sol`
- `script/SetTokenMinters.s.sol`
- `script/DemoResearch.s.sol`
- `script/DemoTeaching.s.sol`

Environment variables are documented in `.env.example`, and the core project configuration is stored in `foundry.toml`.
