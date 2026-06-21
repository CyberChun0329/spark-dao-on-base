# Client

This directory contains the minimal `viem` client layer for the Base/Solidity
implementation.

It provides ABI loading, environment-based address configuration, lightweight registry
helpers, reward claim helpers, deployment checks, and read-only inspection scripts.

## Address Configuration

- `RESEARCH_REGISTRY`
- `TEACHING_REGISTRY`
- `TEACHING_REWARD_DISTRIBUTOR`
- `TEACHING_POLICY_GUARD`
- `TEACHING_ECONOMICS_POLICY`
- `TEACHING_FAULT_POLICY`
- `RESEARCH_POSITION_TOKEN`
- `TEACHING_NFT_TOKEN`
- `MODULE_COMPATIBILITY_MANIFEST`
- `EXPECTED_TEACHING_ECONOMICS_POLICY_VERSION`
- `EXPECTED_TEACHING_FAULT_POLICY_VERSION`

## Post-Deployment Checks

```bash
npm run check:registry-admin-state
npm run check:module-compatibility
```

`check:module-compatibility` checks deployed registry, distributor, policy, and token
wiring. A manifest can also include bytecode hashes.

Validate the example manifest format without chain access:

```bash
npm run check:module-compatibility:example
```

Recommended order: test, deploy or run a local demo, then run the registry and module
checks.

This is a minimal SDK and script layer for deployment checks and inspection.

`npm run client:typecheck` checks the client scripts.

Use `getResearchVaultReservedUnits` or `getTeachingVaultReservedUnits` when reading
reserve state from scripts.
