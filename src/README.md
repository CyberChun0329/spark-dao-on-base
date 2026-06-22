# Contracts

Solidity contracts for the Base implementation.

## Research

`ResearchRegistry` owns research assets, contribution positions, direct revenue escrow,
buybacks, reward-claim accounting, and research-side reserves.

`ResearchPositionToken` is a registry-minted non-transferable position token. User
transfers revert; protocol-mediated movement is handled by the registry.

## Teaching

`TeachingRegistry` owns teaching sessions. Each seat pays independently and may receive
its own refund. Customer fault is per-seat. Teacher fault is session-level.
Schedules are confirmed by the teacher and coordinator. Valid sessions may close by
coordinator fallback after the timeout, or automatically after `scheduledAt` when teacher
delivery and paid attendance over half of `classSize` are recorded. Paid, unmarked,
non-attending seats are completed seats with no refund.

Customer fault is coordinator-only, must be marked while the session is open, and requires a
paid seat.

`TeachingRegistry` keeps the Teaching protocol surface while the session API supports
`classSize` and per-seat accounting for fresh deployments.

`TeachingRewardDistributor` mirrors the claim-pull distributor pattern for teaching
reward pools.

`TeachingPricingPolicyV1` uses a tier table for class sizes `1..100`.

`TeachingNftToken` is used by the teaching protocol. Each teaching session mints one
non-transferable teaching token to the teacher.

A single-learner lesson is represented as a teaching session with one seat. Teaching rewards
extend research wiring through `ResearchRegistry.setTeachingRegistry` and
`recordTeachingRewardClaim`.

## Wiring

One-time wiring calls:

- `ResearchRegistry.setTeachingRegistry`
- `TeachingRegistry.setTeachingRewardDistributor`
- token minters for `ResearchPositionToken` and teaching `TeachingNftToken`

The teaching distributor calls back into `TeachingRegistry` to release reserved units
and record research-position claim totals.

## Stable Assets

Registry constructors and stable-asset admin paths require deployed token contracts.
Configured stable assets are expected to be standard ERC-20 tokens: no transfer fees,
rebasing, or transfer callbacks.

Stable assets are frozen into protocol objects at creation time. Reserve accounting is
per stable asset.
