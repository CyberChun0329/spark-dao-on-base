# Contracts

Solidity contracts for the Base version of Spark DAO.

`ResearchRegistry.sol` owns the research side: asset creation, patch positions, layer
seal/advance, decay readiness, direct revenue escrows, position transfers, DAO buybacks,
vault funding, withdrawals, and per-stable reserved-unit accounting. DAO buybacks are
paid from idle vault balance for the position's frozen stable asset; the v1 contracts do
not escrow a separate buyback guarantee.

`TeachingRegistry.sol` is deployed separately from `ResearchRegistry`. It owns the
teaching lifecycle: course types, teaching sessions, first-round freeze, collateral
lock, ordinary completion, coordinator-forced valid settlement, customer-fault
settlement, teacher-fault remedial settlement, scheduled-time snapshot use, teacher
redeem, teaching vault reserve updates, and the distributor-only reward settlement
callback. It reads research readiness and snapshot values through
`IResearchRegistryForTeaching`. `TeachingPolicyGuard.sol`,
`TeachingEconomicsPolicyV1.sol`, and `TeachingFaultPolicyV1.sol` are deployed separately.
Course types freeze the economics and fault policy addresses, sessions freeze the
resulting economics values and fault quotes, and the registry executes those frozen
values during settlement.

Customer fault charges half of the locked lesson price, refunds the other half, returns
the teacher bond, and pays the teacher half of the frozen lesson salary. Teacher fault
charges half of the locked lesson price, refunds the other half, returns the teacher bond,
pays no immediate salary, records one remedial lesson owed, records a half-salary
remedial wage obligation, and can still distribute research-linked rewards for the
affected and remedial lessons. The coordinator can later close the remedial wage
obligation through `coordinatorSettleTeacherFaultRemedialWage`, which pays the reserved
amount to the teacher and releases the matching vault reserve.

Before both teacher and customer collateral are locked, either side can withdraw only its
own unmatched deposit through `withdrawUnmatchedTeachingCollateral`. The session remains
confirmed and can be funded again later. Once both sides are locked, unmatched withdrawal
is unavailable and the normal completion or coordinator-resolution paths must be used.
The ordinary second-round completion path uses two related entrypoints:
`acknowledgeTeachingCompletion` records the first signature without settlement, while
`confirmTeachingCompletion` records a signature and settles when it is the second
signature. A second signer must use `confirmTeachingCompletion`; `acknowledge` reverts
after the counterparty has already signed.
`getTeachingSessionState` reports `researchDistributionRecorded` only for settlement paths
that enter reward-pool recording; customer-fault settlement does not record a research
reward pool and reports `false`.

`TeachingRewardDistributor.sol` is independently deployed. It owns teaching reward pool
storage, claim tracking, claim previews, single and batch reward claims, and dust release.
Only its configured `TEACHING_REGISTRY()` can record pools. During a claim it reads the
current research position holder through `IResearchRegistryForTeaching`; transfer after
settlement sends claim rights to the new holder, and buyback sends claim rights to the
treasury holder.

`TeachingPolicyGuard.sol` is a validation adapter for policy modules. It validates
policy versions and quote invariants, but does not own teaching lifecycle state, reward
pools, reserves, or treasury accounting. `TeachingEconomicsPolicyV1.sol` and
`TeachingFaultPolicyV1.sol` are stateless quote modules; registry-created course types
and teaching sessions freeze their returned values before later settlement.

`TeachingRegistry.setTeachingRewardDistributor` is authority-only and one-time. It
checks the distributor's `TEACHING_REGISTRY()` and `RESEARCH_REGISTRY()` values before
wiring, which prevents common mismatched-address deployment mistakes. `ResearchRegistry`
also has a one-time `setTeachingRegistry` handshake. It is still an operational
requirement to deploy the intended distributor bytecode.

`TeachingRegistry.updateDefaultTeachingEconomicsPolicy` and
`TeachingRegistry.updateDefaultTeachingFaultPolicy` are authority-only. They change
defaults for future course types only; existing course types and teaching sessions keep
their frozen economics values and fault policy. `getTeachingModuleState` exposes the
current module wiring for deployment checks.

The V1 economics policy keeps the static research-share cap as an absolute upper bound,
not as a guarantee that every course can use that full value. Course and session creation
also enforce the teacher-fault solvency rule against the frozen price and salary:
`0.5W + 2 * researchShare * P <= 0.5P`.

`ResearchPositionToken.sol` and `TeachingNftToken.sol` are minimal non-transferable
ERC-721-like tokens. `ResearchRegistry` mints research position tokens, `TeachingRegistry`
mints teaching NFTs, and both token minters should be locked after deployment. The tokens
expose ownership and metadata reads, but user-initiated transfers intentionally revert;
research position movement is mediated by `ResearchRegistry`, and teaching NFTs remain
non-transferable session records.
Registry constructors and stable-asset admin paths require token and policy addresses to
be deployed contracts, not just non-zero addresses, so mistaken EOA placeholders fail
before they can silently break minting, transfers, or reserve accounting.
Configured stable assets are expected to be standard ERC-20 tokens without transfer fees,
rebasing balance changes, or transfer callbacks.
