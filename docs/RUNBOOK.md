# Base Runbook

本手册覆盖两条常见运行路径：本地 `anvil` 和 `Base Sepolia`。

## 1. 本地开发链

建议先用 `anvil`：

```bash
anvil
```

然后把 `.env.example` 复制成你自己的环境文件，至少填这些值：

- `BASE_RPC_URL=http://127.0.0.1:8545`
- `BASE_CHAIN=base-sepolia` 或 `BASE_CHAIN=base`
- 6 个 demo 私钥：
  - `DEMO_AUTHORITY_PRIVATE_KEY`
  - `DEMO_COORDINATOR_PRIVATE_KEY`
  - `DEMO_CONTRIBUTOR_ONE_PRIVATE_KEY`
  - `DEMO_CONTRIBUTOR_TWO_PRIVATE_KEY`
  - `DEMO_TEACHER_PRIVATE_KEY`
  - `DEMO_CUSTOMER_PRIVATE_KEY`

本地演示脚本会自行部署本次 demo 所需合约：

- `DemoResearch.s.sol` 部署 `MockERC20`、`ResearchPositionToken`、`ResearchRegistry`
- `DemoTeaching.s.sol` 部署 `MockERC20`、`ResearchPositionToken`、`TeachingNftToken`、
  `TeachingRegistry`、`TeachingRewardDistributor`

Teaching demo 会把 distributor 接入 registry，并通过 distributor 执行 teaching
reward claim。演示脚本还会把：

- `rewardUnlockSeconds`
- `buybackWaitSeconds`

都设成 `0`，这样一次脚本就能跑完整条 claim / buyback 主线。

## 2. 协议层回归

常用命令：

```bash
npm run build
npm run build:sizes
npm run test
npm run client:typecheck
npm run simulate:teaching-cost
```

其中：

- `build:sizes` 默认带 `--skip script`，只看真正部署到链上的协议合约尺寸
- 直接跑 `forge build --sizes` 会把 `.s.sol` 脚本合约也统计进去，噪音更大

## 3. 正式部署顺序

分三步：

1. 部署 token

```bash
npm run deploy:tokens
```

2. 部署 registry + reward distributor

```bash
npm run deploy:registry
```

`DeployRegistry.s.sol` 会部署 `TeachingRewardDistributor` 并调用
`setTeachingRewardDistributor`。因此广播 signer 必须是 `DAO_AUTHORITY`，或者至少必须
能代表 `DAO_AUTHORITY` 完成这一步。

这一步是 one-time wiring。registry 会检查 distributor 的 `TEACHING_REGISTRY()` 是否
等于自己，能防常见地址填错；但它不能证明 bytecode 没被替换，所以 authority 仍要使用
可信部署产物。

记录输出地址：

- `TEACHING_REGISTRY` = registry address
- `RESEARCH_REGISTRY` = registry address，除非你刻意部署 research-only registry
- `TEACHING_REWARD_DISTRIBUTOR` = reward distributor address

3. 把 token minter 指到 registry 并锁定

```bash
npm run deploy:set-minters
```

对应环境变量见 `.env.example`。

## 4. 本地 demo

Research 主线：

```bash
npm run demo:research
```

Teaching + Research 联动主线：

```bash
npm run demo:teaching
```

如果只是想快速读取链上状态，不发写交易：

```bash
npm run client:inspect
```

可选环境变量：

- `INSPECT_ASSET_ID`
- `INSPECT_POSITION_ID`
- `INSPECT_TEACHING_NFT_ID`

如果同时设置 `INSPECT_TEACHING_NFT_ID`、`INSPECT_ASSET_ID` 和
`INSPECT_POSITION_ID`，inspect 会读取 teaching reward preview；这需要
`TEACHING_REWARD_DISTRIBUTOR`。

## 5. Base Sepolia

如果要上 `Base Sepolia`：

- 把 `BASE_RPC_URL` 改成 Sepolia RPC
- `DAO_AUTHORITY / DAO_COORDINATOR` 改成真实部署地址
- `DAO_TREASURY` 改成真实 treasury 或多签地址
- `TEACHING_REWARD_DISTRIBUTOR` 填入 `DeployRegistry.s.sol` 输出的 distributor 地址
- `REWARD_UNLOCK_SECONDS / BUYBACK_WAIT_SECONDS` 改回正式业务值
- 不要再用 demo 脚本里的零等待参数

本地 teaching demo 会使用未来 `scheduledAt` 并通过 Foundry cheatcode 推进本地时间；
这只是 Anvil 快速演示路径，不代表生产支持 backfilled lesson。

建议顺序：

1. 先本地 `anvil` 跑通
2. 再 Sepolia 部署 token + registry
3. 再单独跑最小 smoke test

## 6. Gas and simulation refresh

Gas and cost numbers are generated, not hand-filled.

```bash
forge test --match-contract TeachingGasCalibrationTest
forge test --match-contract ResearchGasCalibrationTest
npm run simulate:teaching-cost
```

The calibration tests write `teaching_gas_calibration.csv` and
`research_gas_calibration.csv`; the simulation script reads those CSVs plus
`simulation_inputs/fee_assumptions.json` and rewrites `simulation_outputs/`.
