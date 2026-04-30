# Base Runbook

本手册覆盖两条常见运行路径：本地 `anvil` 和 `Base Sepolia`。

## 1. 本地开发链

建议先用 `anvil`：

```bash
anvil
```

然后把 `.env.example` 复制成你自己的环境文件，至少填这些值：

- `BASE_RPC_URL=http://127.0.0.1:8545`
- 6 个 demo 私钥：
  - `DEMO_AUTHORITY_PRIVATE_KEY`
  - `DEMO_COORDINATOR_PRIVATE_KEY`
  - `DEMO_CONTRIBUTOR_ONE_PRIVATE_KEY`
  - `DEMO_CONTRIBUTOR_TWO_PRIVATE_KEY`
  - `DEMO_TEACHER_PRIVATE_KEY`
  - `DEMO_CUSTOMER_PRIVATE_KEY`

本地演示脚本会自行部署：

- `MockERC20`
- `ResearchPositionToken`
- `TeachingNftToken`
- `TeachingRegistry`

并且会把：

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

2. 部署 registry

```bash
npm run deploy:registry
```

3. 把 token minter 指到 registry

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

## 5. Base Sepolia

如果要上 `Base Sepolia`：

- 把 `BASE_RPC_URL` 改成 Sepolia RPC
- `DAO_AUTHORITY / DAO_COORDINATOR` 改成真实部署地址
- `REWARD_UNLOCK_SECONDS / BUYBACK_WAIT_SECONDS` 改回正式业务值
- 不要再用 demo 脚本里的零等待参数

建议顺序：

1. 先本地 `anvil` 跑通
2. 再 Sepolia 部署 token + registry
3. 再单独跑最小 smoke test
