# Supplementary Material Snapshot

This directory is a clean protocol snapshot prepared for archival submission and public release.

## Included material

- `src/`: core Base contracts
- `test/`: Foundry test suites
- `script/`: deployment and demo scripts
- `foundry.toml`: Foundry configuration
- `package.json` and `package-lock.json`: lightweight project metadata
- `.env.example`: example environment variables

## Excluded material

The snapshot intentionally excludes local build artefacts and dependencies such as:

- `node_modules/`
- `out/`
- `cache/`
- generated `.abi` and `.bin` files

## Reproduction

The core protocol results can be reproduced with:

```bash
forge build
forge test -vvv
forge test --gas-report
```

The gas report underlies the representative execution paths cited in the cost-scalability chapter.
