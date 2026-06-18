import type { Address, Hex } from "viem";
import type { SparkDaoClientConfig } from "./config.js";
import { createSparkDaoClient } from "./createSparkDaoClient.js";

export function createTeachingClient(
  config: SparkDaoClientConfig,
  privateKey?: Hex,
) {
  return createSparkDaoClient({
    rpcUrl: config.rpcUrl,
    chain: config.chain,
    addresses: config.addresses,
    privateKey,
  });
}

export async function getTeachingDaoState(config: SparkDaoClientConfig) {
  const client = createTeachingClient(config);
  return client.publicClient.readContract({
    ...client.contracts.teachingRegistry,
    functionName: "getDaoState",
  });
}

export async function getTeachingVaultReservedUnits(
  config: SparkDaoClientConfig,
  stableAsset: Address,
) {
  const client = createTeachingClient(config);
  return client.publicClient.readContract({
    ...client.contracts.teachingRegistry,
    functionName: "getVaultReservedUnits",
    args: [stableAsset],
  });
}

export async function getTeachingSessionState(
  config: SparkDaoClientConfig,
  teachingNftId: bigint,
) {
  const client = createTeachingClient(config);
  return client.publicClient.readContract({
    ...client.contracts.teachingRegistry,
    functionName: "getTeachingSessionState",
    args: [teachingNftId],
  });
}

export async function getTeachingSessionSettlementLayers(
  config: SparkDaoClientConfig,
  teachingNftId: bigint,
) {
  const client = createTeachingClient(config);
  return client.publicClient.readContract({
    ...client.contracts.teachingRegistry,
    functionName: "getTeachingSessionSettlementResearchLayers",
    args: [teachingNftId],
  });
}

export async function getTeachingFaultSettlement(
  config: SparkDaoClientConfig,
  teachingNftId: bigint,
) {
  const client = createTeachingClient(config);
  return client.publicClient.readContract({
    ...client.contracts.teachingRegistry,
    functionName: "getTeachingFaultSettlement",
    args: [teachingNftId],
  });
}

export async function getTeachingRemedialWageSettlement(
  config: SparkDaoClientConfig,
  teachingNftId: bigint,
) {
  const client = createTeachingClient(config);
  return client.publicClient.readContract({
    ...client.contracts.teachingRegistry,
    functionName: "getTeachingRemedialWageSettlement",
    args: [teachingNftId],
  });
}

export async function getTeachingModuleState(config: SparkDaoClientConfig) {
  const client = createTeachingClient(config);
  return client.publicClient.readContract({
    ...client.contracts.teachingRegistry,
    functionName: "getTeachingModuleState",
  });
}

export async function getTeachingRewardClaimable(
  config: SparkDaoClientConfig,
  teachingNftId: bigint,
  assetId: bigint,
  positionId: bigint,
) {
  return getTeachingRewardPreview(config, teachingNftId, assetId, positionId);
}

export async function getTeachingRewardPreview(
  config: SparkDaoClientConfig,
  teachingNftId: bigint,
  assetId: bigint,
  positionId: bigint,
) {
  const client = createTeachingClient(config);
  const rewardContract = client.contracts.teachingRewardDistributor;
  if (!rewardContract) {
    throw new Error("Teaching reward distributor address is not configured");
  }
  return client.publicClient.readContract({
    ...rewardContract,
    functionName: "getTeachingRewardClaimable",
    args: [teachingNftId, assetId, positionId],
  });
}

export async function claimTeachingReward(
  config: SparkDaoClientConfig,
  privateKey: Hex,
  teachingNftId: bigint,
  assetId: bigint,
  positionId: bigint,
) {
  const client = createTeachingClient(config, privateKey);
  if (!client.walletClient || !client.account) {
    throw new Error("Wallet client not configured");
  }
  const rewardContract = client.contracts.teachingRewardDistributor;
  if (!rewardContract) {
    throw new Error("Teaching reward distributor address is not configured");
  }
  return client.walletClient.writeContract({
    ...rewardContract,
    account: client.account,
    chain: config.chain,
    functionName: "claimTeachingReward",
    args: [teachingNftId, assetId, positionId],
  });
}

export async function claimTeachingRewardBatch(
  config: SparkDaoClientConfig,
  privateKey: Hex,
  teachingNftIds: bigint[],
  assetIds: bigint[],
  positionIds: bigint[],
) {
  const client = createTeachingClient(config, privateKey);
  if (!client.walletClient || !client.account) {
    throw new Error("Wallet client not configured");
  }
  const rewardContract = client.contracts.teachingRewardDistributor;
  if (!rewardContract) {
    throw new Error("Teaching reward distributor address is not configured");
  }
  return client.walletClient.writeContract({
    ...rewardContract,
    account: client.account,
    chain: config.chain,
    functionName: "claimTeachingRewardBatch",
    args: [teachingNftIds, assetIds, positionIds],
  });
}

export async function withdrawUnmatchedTeachingCollateral(
  config: SparkDaoClientConfig,
  privateKey: Hex,
  teachingNftId: bigint,
  teacherSide: boolean,
) {
  const client = createTeachingClient(config, privateKey);
  if (!client.walletClient || !client.account) {
    throw new Error("Wallet client not configured");
  }
  return client.walletClient.writeContract({
    ...client.contracts.teachingRegistry,
    account: client.account,
    chain: config.chain,
    functionName: "withdrawUnmatchedTeachingCollateral",
    args: [teachingNftId, teacherSide],
  });
}

export async function coordinatorResolveCustomerFault(
  config: SparkDaoClientConfig,
  privateKey: Hex,
  teachingNftId: bigint,
  reasonCode = 2,
) {
  const client = createTeachingClient(config, privateKey);
  if (!client.walletClient || !client.account) {
    throw new Error("Wallet client not configured");
  }
  return client.walletClient.writeContract({
    ...client.contracts.teachingRegistry,
    account: client.account,
    chain: config.chain,
    functionName: "coordinatorResolveCustomerFault",
    args: [teachingNftId, reasonCode],
  });
}

export async function coordinatorResolveTeacherFault(
  config: SparkDaoClientConfig,
  privateKey: Hex,
  teachingNftId: bigint,
  reasonCode = 4,
) {
  const client = createTeachingClient(config, privateKey);
  if (!client.walletClient || !client.account) {
    throw new Error("Wallet client not configured");
  }
  return client.walletClient.writeContract({
    ...client.contracts.teachingRegistry,
    account: client.account,
    chain: config.chain,
    functionName: "coordinatorResolveTeacherFault",
    args: [teachingNftId, reasonCode],
  });
}
