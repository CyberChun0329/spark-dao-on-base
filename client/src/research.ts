import type { Address, Hex } from "viem";
import type { SparkDaoClientConfig } from "./config.js";
import { createSparkDaoClient } from "./createSparkDaoClient.js";

export function createResearchClient(config: SparkDaoClientConfig, privateKey?: Hex) {
  return createSparkDaoClient({
    rpcUrl: config.rpcUrl,
    chain: config.chain,
    addresses: config.addresses,
    privateKey,
  });
}

export async function getDaoState(config: SparkDaoClientConfig) {
  const client = createResearchClient(config);
  return client.publicClient.readContract({
    ...client.contracts.researchRegistry,
    functionName: "getDaoState",
  });
}

export async function getResearchAsset(
  config: SparkDaoClientConfig,
  assetId: bigint,
) {
  const client = createResearchClient(config);
  return client.publicClient.readContract({
    ...client.contracts.researchRegistry,
    functionName: "getResearchAsset",
    args: [assetId],
  });
}

export async function getResearchPosition(
  config: SparkDaoClientConfig,
  assetId: bigint,
  positionId: bigint,
) {
  const client = createResearchClient(config);
  return client.publicClient.readContract({
    ...client.contracts.researchRegistry,
    functionName: "getResearchPosition",
    args: [assetId, positionId],
  });
}

export async function createResearchAsset(
  config: SparkDaoClientConfig,
  privateKey: Hex,
  title: string,
  metadataUri: string,
) {
  const client = createResearchClient(config, privateKey);
  if (!client.walletClient || !client.account) {
    throw new Error("Wallet client not configured");
  }
  return client.walletClient.writeContract({
    ...client.contracts.researchRegistry,
    account: client.account,
    chain: config.chain,
    functionName: "createResearchAsset",
    args: [title, metadataUri],
  });
}

export async function transferResearchPosition(
  config: SparkDaoClientConfig,
  privateKey: Hex,
  assetId: bigint,
  positionId: bigint,
  newHolder: Address,
) {
  const client = createResearchClient(config, privateKey);
  if (!client.walletClient || !client.account) {
    throw new Error("Wallet client not configured");
  }
  return client.walletClient.writeContract({
    ...client.contracts.researchRegistry,
    account: client.account,
    chain: config.chain,
    functionName: "transferResearchPosition",
    args: [assetId, positionId, newHolder],
  });
}

export async function claimRevenue(
  config: SparkDaoClientConfig,
  privateKey: Hex,
  assetId: bigint,
  positionId: bigint,
  revenueId: bigint,
) {
  const client = createResearchClient(config, privateKey);
  if (!client.walletClient || !client.account) {
    throw new Error("Wallet client not configured");
  }
  return client.walletClient.writeContract({
    ...client.contracts.researchRegistry,
    account: client.account,
    chain: config.chain,
    functionName: "claimRevenue",
    args: [assetId, positionId, revenueId],
  });
}
