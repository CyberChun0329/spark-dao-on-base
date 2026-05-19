# Contracts

Solidity contracts for the Base version of Spark DAO.

`ResearchRegistry.sol` owns the research side: asset creation, patch positions, layer
seal/advance, decay readiness, direct revenue escrows, position transfers, DAO buybacks,
vault funding, withdrawals, and per-stable reserved-unit accounting.

`TeachingRegistry.sol` inherits `ResearchRegistry` and adds the teaching lifecycle:
course types, teaching sessions, first-round freeze, collateral lock, ordinary
completion, coordinator-forced valid settlement, customer-fault settlement,
teacher-fault remedial settlement, snapshot calculation, teacher redeem, vault reserve
updates, and the stable transfer callback used by reward claims.

Customer fault charges half of the locked lesson price, refunds the other half, returns
the teacher bond, and pays the teacher up to the reserved salary. Teacher fault charges
half of the locked lesson price, refunds the other half, returns the teacher bond, pays
no teaching salary, records one remedial lesson owed, and can still distribute
research-linked rewards for the affected and remedial lessons.

`TeachingRewardDistributor.sol` is independently deployed. It owns teaching reward pool
storage, claim tracking, claim previews, single and batch reward claims, and dust release.
Only its configured `TEACHING_REGISTRY()` can record pools. During a claim it reads the
current research position holder through `ITeachingRewardSource`; transfer after
settlement sends claim rights to the new holder, and buyback sends claim rights to the
treasury holder.

`TeachingRegistry.setTeachingRewardDistributor` is authority-only and one-time. It
checks the distributor's `TEACHING_REGISTRY()` value before wiring, which prevents common
mismatched-address deployment mistakes. It is still an operational requirement to deploy
the intended distributor bytecode.

The hard research-share cap for teaching courses is 25%, which keeps the teacher-fault
branch solvent when two research-linked lesson shares must be funded from a retained
half-price payment.

`ResearchPositionToken.sol` and `TeachingNftToken.sol` are minimal non-transferable
ERC-721-like tokens. The registry mints them and token minters should be locked after
deployment.
