# Client

This directory contains the minimal `viem` client layer for the Base/Solidity
implementation.

It currently provides:

- automatic ABI loading
- `BASE_RPC_URL` and address configuration from environment variables
- minimal read/write helpers for `ResearchRegistry` and `TeachingRegistry`
- claim-pull teaching reward preview, single-claim, and batch-claim helpers for
  `TeachingRewardDistributor`
- optional `TeachingPolicyGuard`, `TeachingEconomicsPolicyV1`, and
  `TeachingFaultPolicyV1` artifact bindings for deployed policy inspection
- research-side multi-stable vault reserve reads and targeted fund/withdraw helpers
- teaching-side DAO state, vault reserve read, and idle withdrawal helpers
- teaching fault-settlement, remedial wage closure, and module wiring read helpers
- unmatched teaching collateral withdrawal helper
- a module compatibility checker for post-deployment registry/distributor/policy wiring
- coordinator fault-resolution helpers
- an `inspect.ts` script for direct DAO, research, and teaching state reads

## Address Configuration

- `RESEARCH_REGISTRY`: target for research helper reads/writes and for teaching
  settlement reads of research readiness, scheduled snapshots, and position holders.
- `TEACHING_REGISTRY`: target for teaching lifecycle, settlement state, and teaching
  vault reserve reads.
- `TEACHING_REWARD_DISTRIBUTOR`: required for teaching reward preview, single claim, and
  batch claim helpers. Reward helpers fail fast when this address is missing so callers
  do not accidentally assume claims still live on the registry.
- `TEACHING_POLICY_GUARD`: optional address for exposing the deployed policy guard.
- `TEACHING_ECONOMICS_POLICY`: optional address for exposing the deployed economics
  policy ABI/address.
- `TEACHING_FAULT_POLICY`: optional address for exposing the deployed fault policy
  ABI/address.
- `RESEARCH_POSITION_TOKEN` and `TEACHING_NFT_TOKEN`: optional token descriptors used
  mainly for client contract exposure and deployment configuration checks.
- `MODULE_COMPATIBILITY_MANIFEST`: optional path to a deployment manifest JSON file. The
  manifest can record chain data, contract names, artifact paths, deployed bytecode
  hashes, and expected registry/distributor wiring.
- `EXPECTED_TEACHING_ECONOMICS_POLICY_VERSION` and
  `EXPECTED_TEACHING_FAULT_POLICY_VERSION`: expected policy versions for the module
  compatibility checker. Both default to `1`.

## Post-Deployment Checks

```bash
npm run check:registry-admin-state
npm run check:module-compatibility
```

`check:module-compatibility` reads `TeachingRegistry.getTeachingModuleState()`,
`TeachingRewardDistributor.TEACHING_REGISTRY()`,
`TeachingRewardDistributor.RESEARCH_REGISTRY()`, policy version getters, and
`TeachingPolicyGuard` validation results. If token addresses are configured in env or
provided by `MODULE_COMPATIBILITY_MANIFEST`, it also checks that the research position
token and teaching NFT token minters are locked. If `MODULE_COMPATIBILITY_MANIFEST` is
provided and contains `deployedBytecodeHash`, the script reads runtime bytecode at the
manifest address and compares hashes. Without bytecode hashes, the manifest can only
prove address, artifact-name, and expected-wiring consistency.

Validate the example manifest format without chain access:

```bash
npm run check:module-compatibility:example
```

Recommended order:

1. Run the contract tests.
2. Deploy or run a local demo.
3. Run registry admin and module compatibility checks.
4. Use `client/scripts/inspect.ts` for read-only chain state inspection.

This is not a full frontend. It is a minimal SDK and script layer for deployment,
inspection, and compatibility checks.

`npm run client:typecheck` uses `tsconfig.typecheck.json`. Runtime scripts still resolve
the real `viem` package through Node/tsx; the typecheck config uses lightweight shims to
avoid pulling the full `viem` advanced type graph into reproducibility checks.

`ResearchRegistry` and `TeachingRegistry` are independent contracts with separate
`DaoState` and reserved-unit accounting. Reserve reads should use
`getResearchVaultReservedUnits` or `getTeachingVaultReservedUnits` to make the target
explicit. `getVaultReservedUnits` remains only as a research helper compatibility alias.
