# Client

这里是 Base 版最小 `viem` 客户端层。

当前提供：

- ABI 自动读取
- `BASE_RPC_URL` + 地址环境变量加载
- `ResearchRegistry` / `TeachingRegistry` 的最小读写 helper
- `TeachingRewardDistributor` 的 claim-pull teaching reward preview、单笔 claim、批量 claim helper
- optional `TeachingPolicyGuard` / `TeachingEconomicsPolicyV1` / `TeachingFaultPolicyV1` artifact bindings for deployed policy inspection
- research-side 多稳定币 vault reserve 读取、定向 fund / withdraw helper
- teaching-side DAO state 与 vault reserve 读取 helper
- teaching fault-settlement、remedial wage closure state、module wiring 读取 helper
- coordinator fault-resolution helper
- 一个 `inspect.ts` 示例脚本，方便直接读取 DAO / research / teaching 状态

地址配置：

- `RESEARCH_REGISTRY`：research helper 的读取/写入目标，也是 teaching settlement
  读取 research readiness、snapshot 和 position holder 的目标。
- `TEACHING_REGISTRY`：teaching lifecycle、settlement state、vault reserve 读取目标。
- `TEACHING_REWARD_DISTRIBUTOR`：teaching reward preview、单笔 claim、批量 claim 必需。
  没有这个地址时，相关 helper 会直接报错，避免误以为 claim 仍在 registry 上。
- `TEACHING_POLICY_GUARD`：可选，用于 client 侧暴露已部署 policy guard。
- `TEACHING_ECONOMICS_POLICY`：可选，用于 client 侧暴露已部署 economics policy 的 ABI/address。
- `TEACHING_FAULT_POLICY`：可选，用于 client 侧暴露已部署 fault policy 的 ABI/address。
- `RESEARCH_POSITION_TOKEN` / `TEACHING_NFT_TOKEN`：可选 token 描述符，目前主要用于
  client 合约集合暴露和检查部署配置。

推荐顺序：

1. 先跑合约测试
2. 再部署或跑 demo
3. 最后用 `client/scripts/inspect.ts` 读取链上状态

当前还不是完整前端，只是一个足够稳的 SDK 骨架。

`npm run client:typecheck` 使用 `tsconfig.typecheck.json`。运行时脚本仍按普通
Node/tsx 解析真实 `viem` 包；typecheck 配置只用轻量 shim 避免把完整 `viem`
高阶类型图拖进可复现检查。

注意：`ResearchRegistry` 和 `TeachingRegistry` 是两个独立合约，各自有
`DaoState` 和 reserved-unit accounting。读取 reserve 时应使用
`getResearchVaultReservedUnits` 或 `getTeachingVaultReservedUnits` 明确目标；旧的
`getVaultReservedUnits` 只是 research helper 的兼容 alias。
