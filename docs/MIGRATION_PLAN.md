# Base Migration Plan

Status: the protocol-layer migration described here is implemented in the current Base
worktree. Keep this file as an orientation note for parity and operating assumptions,
not as a snapshot or review-package checklist.

## 目标

把当前 Solana 版本迁移到 Base，同时保留以下业务语义：

- `research nft` 的 layer / seal / decay / buyback / revenue claim
- `teaching nft` 的双轮确认、保证金、强制裁决、teacher redeem
- teaching 成功后，按 `scheduled_at` snapshot 计算 research 分红
- research 分红采用 claim-pull reward pool，而不是 settlement 时逐个 position fan-out

## 目录职责

- `src/`
  Base 版合约
- `test/`
  Foundry 测试
- `script/`
  部署、初始化、demo 脚本

## 推荐迁移顺序

### 阶段 1：基础模型

- `SparkDaoConfig`
- `ResearchAsset`
- `ResearchPosition`
- `TeachingCourseType`
- `TeachingSession`（Base 版 `TeachingNft`）
- `TeachingPolicyGuard`
- `TeachingEconomicsPolicyV1`
- `TeachingFaultPolicyV1`
- `TeachingRewardDistributor` / `TeachingRewardPool`

### 阶段 2：research 主线

- 创建 root research asset
- 创建 patch / layer position
- seal layer
- mark ready / advance layer
- revenue escrow / claim
- transfer / buyback

### 阶段 3：teaching 主线

- create teaching session
- round-one teacher/customer confirm
- lock collateral
- round-two completion
    - force valid / customer-fault settlement / teacher-fault remedial settlement
- teacher redeem
- vault reserved units tracked per stable asset

### 阶段 4：联动

- teaching success / force-valid / teacher-fault branch -> research snapshot reward-pool recording where applicable
- delayed unlock claim-pull reward pool in `TeachingRewardDistributor`
- batch claim
- claim right follows current research position holder; transfer sends claim right to the
  new holder and buyback sends claim right to treasury
- `TeachingRegistry` reads research snapshots through `ResearchRegistry` rather than
  inheriting it
- teaching sessions freeze the policy-derived fault quotes used by later coordinator
  settlement
- distributor calls back into `TeachingRegistry` for teaching vault release and stable
  transfer; `TeachingRegistry` records claim totals back into `ResearchRegistry`
- interleaved teaching/research stress tests

## Solana 到 Base 的映射原则

### 直接保留

- 一节课一个完整 teaching 记录
- `scheduled_at` snapshot 语义
- claim-pull reward pool
- no-research 快速路径

### 不再保留

- 依赖 PDA 数量控制 fee 的设计
- 依赖 rent 回收的设计
- 依赖 `remaining_accounts` 排布的设计

## 当前操作边界

协议层、测试层、部署脚本、最小 `viem` client、gas calibration 和 cost simulation
已经存在。完整前端 UI 仍不在本仓当前范围内。后续文档校准应以当前合约、测试、
CSV 和 simulation script 为准；不要把旧 snapshot 或 review package 流程混进这个
live worktree 的日常运行说明。
