# Solana -> Base Parity Checklist

这份清单只跟踪 **协议层 / 合约层** 的迁移对等性。

## Research

| Solana 功能 | Base 状态 | 说明 |
|---|---|---|
| `initialize_dao` | `done` | Base 版通过构造函数初始化 `DaoState`，并保留 `updateCoordinator / updateAuthority / updateStableAsset / updateRewardUnlockSeconds / updateBuybackWaitSeconds` |
| `create_research_asset` | `done` | `ResearchRegistry.createResearchAsset` |
| `create_patch_position` | `done` | `ResearchRegistry.createPatchPosition` |
| research position NFT | `done` | Base 版已经补上 `ResearchPositionToken`，并在 create / transfer / buyback 时同步 token owner |
| `seal_layer` | `done` | `ResearchRegistry.sealLayer` |
| `approve_early_decay` | `done` | `ResearchRegistry.approveEarlyDecay` |
| `mark_position_ready` | `done` | `ResearchRegistry.markPositionReady` |
| `advance_layer` | `done` | `ResearchRegistry.advanceLayer` |
| `create_revenue_escrow` | `done` | `ResearchRegistry.createRevenueEscrow` |
| `claim_revenue` | `done` | `ResearchRegistry.claimRevenue` |
| `transfer_research_position` | `done` | `ResearchRegistry.transferResearchPosition` |
| `sell_position_back_to_dao` | `done` | `ResearchRegistry.sellPositionBackToDao` |
| `fund_dao_vault` | `done` | `ResearchRegistry.fundDaoVault` |
| `withdraw_dao_vault` | `done` | `ResearchRegistry.withdrawDaoVault`，保留 reserved funds 保护 |

## Teaching

| Solana 功能 | Base 状态 | 说明 |
|---|---|---|
| `create_teaching_course_type` | `done` | `TeachingRegistry.createTeachingCourseType` |
| `create_teaching_nft` | `done` | `TeachingRegistry.createTeachingSession` + `TeachingNftToken.mint` |
| teaching NFT token 化 | `done` | `TeachingNftToken`，当前仍是 soulbound |
| first round teacher/customer confirm | `done` | `confirmTeachingSchedule(teachingNftId, teacherSide)` |
| `lock_teaching_collateral` | `done` | `lockTeachingCollateral(teachingNftId, teacherSide)` |
| second round full completion | `done` | `confirmTeachingCompletion(teachingNftId, teacherSide)` |
| second round lightweight acknowledge | `done` | `acknowledgeTeachingCompletion(teachingNftId, teacherSide)` |
| no-research fast path | `merged` | Base 版没有单独 public entrypoint，但在 `_requiresResearchDistribution == false` 时走同一结算主线 |
| `coordinator_force_teaching_valid` | `done` | `coordinatorForceTeachingValid` |
| customer-fault coordinator settlement | `done` | `coordinatorResolveCustomerFault` charges half price and pays the teacher for reserved time |
| teacher-fault coordinator settlement | `done` | `coordinatorResolveTeacherFault` charges half price, records one remedial lesson owed, pays no teaching salary, and may distribute research rewards |
| `redeem_teaching_payout` | `done` | `redeemTeachingPayout` |

## Teaching / Research Linkage

| Solana 功能 | Base 状态 | 说明 |
|---|---|---|
| `scheduled_at` snapshot distribution | `done` | `TeachingRewardRegistry` 仍按 `scheduledAt` 计算活跃层和有效份额 |
| multi-asset weighted distribution | `done` | 已实现且有测试 |
| delayed unlock aggregated reward ledger | `done` | `TeachingRewardLedger` |
| single reward claim | `done` | `claimTeachingReward` |
| batch reward claim | `done` | `claimTeachingRewardBatch` |
| transfer after reward -> new holder claim | `done` | 已实现且有测试 |
| buyback after reward -> DAO claim | `done` | 已实现且有测试 |
| zero-share / zero-amount reward skip | `done` | 已实现且有测试 |
| timeout + force-valid snapshot correctness | `done` | 已实现且有测试 |
| teacher-fault research rewards from half-price reserve | `done` | 已实现且有测试，最多两节 research-linked shares funded from retained half price |

## Project Layer

| 项目层能力 | Base 状态 | 说明 |
|---|---|---|
| Foundry tests | `done` | 当前 `forge test` 全绿 |
| deploy script | `done` | 已补 `DeployTokens.s.sol + DeployRegistry.s.sol + SetTokenMinters.s.sol`，可分步部署 token、registry 并设置 minter |
| demo scripts | `done` | 已补 `DemoResearch.s.sol / DemoTeaching.s.sol`，可在本地自带 mock stablecoin 跑端到端演示 |
| frontend/client migration | `in_progress` | 已补最小 `viem` SDK、inspect 脚本和 typecheck，完整前端 UI 仍未开始 |

## Current Confidence

- 协议核心：`high`
- 独立功能：`high`
- teaching/research 联动：`high`
- 项目层收尾：`medium`
