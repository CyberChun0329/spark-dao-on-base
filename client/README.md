# Client

这里是 Base 版最小 `viem` 客户端层。

当前提供：

- ABI 自动读取
- `BASE_RPC_URL` + 地址环境变量加载
- `ResearchRegistry` / `TeachingRegistry` 的最小读写 helper
- `TeachingRewardDistributor` 的 claim-pull teaching reward preview、单笔 claim、批量 claim helper
- 多稳定币 vault reserve 读取、定向 fund / withdraw helper
- teaching fault-settlement 读取与 coordinator resolution helper
- 一个 `inspect.ts` 示例脚本，方便直接读取 DAO / research / teaching 状态

地址配置：

- `RESEARCH_REGISTRY`：research helper 的读取/写入目标。完整 teaching 部署通常填
  `TEACHING_REGISTRY` 的同一个地址，因为 `TeachingRegistry` 继承 research surface。
- `TEACHING_REGISTRY`：teaching lifecycle、settlement state、vault reserve 读取目标。
- `TEACHING_REWARD_DISTRIBUTOR`：teaching reward preview、单笔 claim、批量 claim 必需。
  没有这个地址时，相关 helper 会直接报错，避免误以为 claim 仍在 registry 上。
- `RESEARCH_POSITION_TOKEN` / `TEACHING_NFT_TOKEN`：可选 token 描述符，目前主要用于
  client 合约集合暴露和检查部署配置。

推荐顺序：

1. 先跑合约测试
2. 再部署或跑 demo
3. 最后用 `client/scripts/inspect.ts` 读取链上状态

当前还不是完整前端，只是一个足够稳的 SDK 骨架。
