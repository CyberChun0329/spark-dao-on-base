import type { Hex } from "viem";
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

export async function getTeachingRewardBuckets(
  config: SparkDaoClientConfig,
  assetId: bigint,
  positionId: bigint,
) {
  const client = createTeachingClient(config);
  return client.publicClient.readContract({
    ...client.contracts.teachingRegistry,
    functionName: "getTeachingRewardLedgerBuckets",
    args: [assetId, positionId],
  });
}

export async function claimTeachingReward(
  config: SparkDaoClientConfig,
  privateKey: Hex,
  assetId: bigint,
  positionId: bigint,
) {
  const client = createTeachingClient(config, privateKey);
  if (!client.walletClient || !client.account) {
    throw new Error("Wallet client not configured");
  }
  return client.walletClient.writeContract({
    ...client.contracts.teachingRegistry,
    account: client.account,
    chain: config.chain,
    functionName: "claimTeachingReward",
    args: [assetId, positionId],
  });
}

export async function claimTeachingRewardBatch(
  config: SparkDaoClientConfig,
  privateKey: Hex,
  assetIds: bigint[],
  positionIds: bigint[],
) {
  const client = createTeachingClient(config, privateKey);
  if (!client.walletClient || !client.account) {
    throw new Error("Wallet client not configured");
  }
  return client.walletClient.writeContract({
    ...client.contracts.teachingRegistry,
    account: client.account,
    chain: config.chain,
    functionName: "claimTeachingRewardBatch",
    args: [assetIds, positionIds],
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
