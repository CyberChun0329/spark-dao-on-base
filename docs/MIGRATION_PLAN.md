# Base Migration Plan

## 目标

把当前 Solana 版本迁移到 Base，同时保留以下业务语义：

- `research nft` 的 layer / seal / decay / buyback / revenue claim
- `teaching nft` 的双轮确认、保证金、强制裁决、teacher redeem
- teaching 成功后，按 `scheduled_at` snapshot 计算 research 分红
- research 分红继续采用聚合 reward ledger，而不是“一课一户”

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
- `TeachingRewardLedger`

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

### 阶段 4：联动

- teaching success -> research snapshot distribution
- delayed unlock reward ledger
- batch claim
- interleaved teaching/research stress tests

## Solana 到 Base 的映射原则

### 直接保留

- 一节课一个完整 teaching 记录
- `scheduled_at` snapshot 语义
- research 聚合账本
- no-research 快速路径

### 不再保留

- 依赖 PDA 数量控制 fee 的设计
- 依赖 rent 回收的设计
- 依赖 `remaining_accounts` 排布的设计

## 当前建议

先不要急着迁 UI。

先把协议层和测试层迁过去，直到：

- research 主线可跑
- teaching 主线可跑
- teaching/research snapshot 联动可跑

然后再决定是否复用现有 demo 脚本思路。
