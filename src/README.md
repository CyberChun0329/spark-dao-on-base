# Contracts

Solidity contracts for the Base version of Spark DAO.

`ResearchRegistry.sol` owns research assets, position movement, research-side revenue,
buybacks, and per-stable reserve accounting.

`TeachingRegistry.sol` owns teaching course types, sessions, settlement, teaching vault
reserves, and distributor callbacks. It reads research state through
`IResearchRegistryForTeaching` and uses separately deployed policy modules for bounded
quotes. Frozen course/session values drive later settlement.

`withdrawTeachingIdleFor` lets the authority withdraw teaching vault balance that is not
reserved for frozen obligations.

Teaching settlement covers ordinary completion, coordinator resolution, fault settlement,
collateral recovery, reward-pool recording, and remedial wage closure.

`TeachingRewardDistributor.sol` owns reward pools, claim tracking, previews, claims, and
dust release. Only its configured teaching registry can record pools.

`TeachingPolicyGuard.sol` validates policy modules. `TeachingEconomicsPolicyV1.sol` and
`TeachingFaultPolicyV1.sol` are stateless quote modules.

`TeachingRegistry.setTeachingRewardDistributor` and
`ResearchRegistry.setTeachingRegistry` are one-time wiring calls.

`TeachingRegistry.updateDefaultTeachingEconomicsPolicy` and
`TeachingRegistry.updateDefaultTeachingFaultPolicy` change defaults for future course
types only. `getTeachingModuleState` exposes module wiring for deployment checks.

Policy modules enforce bounded teaching economics and research-position readiness rules.

`ResearchPositionToken.sol` and `TeachingNftToken.sol` are minimal non-transferable
ERC-721-like tokens. Registry contracts mint them, and both token minters should be
locked after deployment.
Registry constructors and stable-asset admin paths require deployed contract addresses.
Configured stable assets are expected to be standard ERC-20 tokens.
