# Scripts

Deployment and demo scripts for the Base implementation.

## Deployment

Main deployment is split into three scripts.

1. `DeployTokens.s.sol`

Deploys the research position token and teaching token.

Required environment:

- `DAO_AUTHORITY`
- `RESEARCH_BASE_URI`
- `TEACHING_BASE_URI`

2. `DeployRegistry.s.sol`

Deploys the research registry, teaching registry, teaching reward distributor, and
teaching pricing policy. The broadcaster must be `DAO_AUTHORITY`.

Required environment:

- `DAO_AUTHORITY`
- `DAO_COORDINATOR`
- `DAO_TREASURY`
- `STABLE_ASSET`
- `RESEARCH_POSITION_TOKEN`
- `TEACHING_NFT_TOKEN`
- `REWARD_UNLOCK_SECONDS`
- `BUYBACK_WAIT_SECONDS`

3. `SetTokenMinters.s.sol`

Sets and locks token minters.

Required environment:

- `RESEARCH_REGISTRY`
- `TEACHING_REGISTRY`
- `RESEARCH_POSITION_TOKEN`
- `TEACHING_NFT_TOKEN`

Run deployment checks after these scripts:

```bash
npm run check:registry-admin-state
npm run check:module-compatibility
```

## Demos

- `DemoResearch.s.sol`: local research registry path
- `DemoTeaching.s.sol`: local teaching and reward claim path

Demo scripts deploy temporary mock stable assets and local protocol contracts. They are
for local execution, not production deployment.

The teaching demo uses the teaching-session path. A single-learner lesson is represented as a
teaching class with one seat.

Required demo keys:

- `DEMO_AUTHORITY_PRIVATE_KEY`
- `DEMO_COORDINATOR_PRIVATE_KEY`
- `DEMO_CONTRIBUTOR_ONE_PRIVATE_KEY`
- `DEMO_CONTRIBUTOR_TWO_PRIVATE_KEY`
- `DEMO_TEACHER_PRIVATE_KEY`
- `DEMO_CUSTOMER_PRIVATE_KEY`
