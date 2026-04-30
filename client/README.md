# Client

这里是 Base 版最小 `viem` 客户端层。

当前提供：

- ABI 自动读取
- `BASE_RPC_URL` + 地址环境变量加载
- `ResearchRegistry` / `TeachingRegistry` 的最小读写 helper
- teaching fault-settlement 读取与 coordinator resolution helper
- 一个 `inspect.ts` 示例脚本，方便直接读取 DAO / research / teaching 状态

推荐顺序：

1. 先跑合约测试
2. 再部署或跑 demo
3. 最后用 `client/scripts/inspect.ts` 读取链上状态

当前还不是完整前端，只是一个足够稳的 SDK 骨架。
