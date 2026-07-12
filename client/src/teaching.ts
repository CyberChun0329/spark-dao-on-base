import type { Address, Hex } from "viem";
import type {
  SparkDaoClient,
  SparkDaoContractDescriptor,
} from "./createSparkDaoClient.js";
import type { SparkDaoClientConfig } from "./config.js";
import { createSparkDaoClient } from "./createSparkDaoClient.js";

export type CreateTeachingArgs = {
  courseTypeId: bigint;
  teacher: Address;
  students: Address[];
  scheduledAt: bigint;
  customerDiscountBps?: number;
  linkedResearchAssetIds: bigint[];
  linkedResearchWeightBps: number[];
};

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

export async function getTeachingModuleState(config: SparkDaoClientConfig) {
  const client = createTeachingClient(config);
  return client.publicClient.readContract({
    ...requireTeachingRegistry(client),
    functionName: "getTeachingModuleState",
  });
}

export async function getTeachingDaoState(config: SparkDaoClientConfig) {
  const client = createTeachingClient(config);
  return client.publicClient.readContract({
    ...requireTeachingRegistry(client),
    functionName: "getDaoState",
  });
}

export async function getTeachingSessionState(
  config: SparkDaoClientConfig,
  teachingNftId: bigint,
) {
  const client = createTeachingClient(config);
  return client.publicClient.readContract({
    ...requireTeachingRegistry(client),
    functionName: "getTeachingSessionState",
    args: [teachingNftId],
  });
}

export async function getTeachingSeat(
  config: SparkDaoClientConfig,
  teachingNftId: bigint,
  seatIndex: number,
) {
  const client = createTeachingClient(config);
  return client.publicClient.readContract({
    ...requireTeachingRegistry(client),
    functionName: "getTeachingSeat",
    args: [teachingNftId, seatIndex],
  });
}

export async function getTeachingScheduleState(
  config: SparkDaoClientConfig,
  teachingNftId: bigint,
) {
  const client = createTeachingClient(config);
  return client.publicClient.readContract({
    ...requireTeachingRegistry(client),
    functionName: "getTeachingScheduleState",
    args: [teachingNftId],
  });
}

export async function getTeachingProgressState(
  config: SparkDaoClientConfig,
  teachingNftId: bigint,
) {
  const client = createTeachingClient(config);
  return client.publicClient.readContract({
    ...requireTeachingRegistry(client),
    functionName: "getTeachingProgressState",
    args: [teachingNftId],
  });
}

export async function createTeachingCourseType(
  config: SparkDaoClientConfig,
  privateKey: Hex,
  name: string,
  baseSeatPriceUnits: bigint,
  baseTeacherSalaryUnits: bigint,
  researchShareBps: number,
) {
  const client = requireWallet(createTeachingClient(config, privateKey));
  return client.walletClient.writeContract({
    ...requireTeachingRegistry(client),
    account: client.account,
    chain: config.chain,
    functionName: "createTeachingCourseType",
    args: [name, baseSeatPriceUnits, baseTeacherSalaryUnits, researchShareBps],
  });
}

export async function createTeachingSession(
  config: SparkDaoClientConfig,
  privateKey: Hex,
  args: CreateTeachingArgs,
) {
  const client = requireWallet(createTeachingClient(config, privateKey));
  return client.walletClient.writeContract({
    ...requireTeachingRegistry(client),
    account: client.account,
    chain: config.chain,
    functionName: "createTeachingSession",
    args: [{ ...args, customerDiscountBps: args.customerDiscountBps ?? 10_000 }],
  });
}

export async function confirmTeachingSchedule(
  config: SparkDaoClientConfig,
  privateKey: Hex,
  teachingNftId: bigint,
  teacherSide: boolean,
) {
  const client = requireWallet(createTeachingClient(config, privateKey));
  return client.walletClient.writeContract({
    ...requireTeachingRegistry(client),
    account: client.account,
    chain: config.chain,
    functionName: "confirmTeachingSchedule",
    args: [teachingNftId, teacherSide],
  });
}

export async function payTeachingSeat(
  config: SparkDaoClientConfig,
  privateKey: Hex,
  teachingNftId: bigint,
  seatIndex: number,
) {
  const client = requireWallet(createTeachingClient(config, privateKey));
  return client.walletClient.writeContract({
    ...requireTeachingRegistry(client),
    account: client.account,
    chain: config.chain,
    functionName: "payTeachingSeat",
    args: [teachingNftId, seatIndex],
  });
}

export async function lockTeachingTeacherBond(
  config: SparkDaoClientConfig,
  privateKey: Hex,
  teachingNftId: bigint,
) {
  const client = requireWallet(createTeachingClient(config, privateKey));
  return client.walletClient.writeContract({
    ...requireTeachingRegistry(client),
    account: client.account,
    chain: config.chain,
    functionName: "lockTeachingTeacherBond",
    args: [teachingNftId],
  });
}

export async function confirmTeachingAttendance(
  config: SparkDaoClientConfig,
  privateKey: Hex,
  teachingNftId: bigint,
  seatIndex: number,
) {
  const client = requireWallet(createTeachingClient(config, privateKey));
  return client.walletClient.writeContract({
    ...requireTeachingRegistry(client),
    account: client.account,
    chain: config.chain,
    functionName: "confirmTeachingAttendance",
    args: [teachingNftId, seatIndex],
  });
}

export async function confirmTeachingDelivery(
  config: SparkDaoClientConfig,
  privateKey: Hex,
  teachingNftId: bigint,
) {
  const client = requireWallet(createTeachingClient(config, privateKey));
  return client.walletClient.writeContract({
    ...requireTeachingRegistry(client),
    account: client.account,
    chain: config.chain,
    functionName: "confirmTeachingDelivery",
    args: [teachingNftId],
  });
}

export async function withdrawUnmatchedTeachingSeatPayment(
  config: SparkDaoClientConfig,
  privateKey: Hex,
  teachingNftId: bigint,
  seatIndex: number,
) {
  const client = requireWallet(createTeachingClient(config, privateKey));
  return client.walletClient.writeContract({
    ...requireTeachingRegistry(client),
    account: client.account,
    chain: config.chain,
    functionName: "withdrawUnmatchedTeachingSeatPayment",
    args: [teachingNftId, seatIndex],
  });
}

export async function withdrawUnmatchedTeachingTeacherBond(
  config: SparkDaoClientConfig,
  privateKey: Hex,
  teachingNftId: bigint,
) {
  const client = requireWallet(createTeachingClient(config, privateKey));
  return client.walletClient.writeContract({
    ...requireTeachingRegistry(client),
    account: client.account,
    chain: config.chain,
    functionName: "withdrawUnmatchedTeachingTeacherBond",
    args: [teachingNftId],
  });
}

export async function markTeachingCustomerFault(
  config: SparkDaoClientConfig,
  privateKey: Hex,
  teachingNftId: bigint,
  seatIndex: number,
  reasonCode = 2,
) {
  const client = requireWallet(createTeachingClient(config, privateKey));
  return client.walletClient.writeContract({
    ...requireTeachingRegistry(client),
    account: client.account,
    chain: config.chain,
    functionName: "markTeachingCustomerFault",
    args: [teachingNftId, seatIndex, reasonCode],
  });
}

export async function closeTeachingValid(
  config: SparkDaoClientConfig,
  privateKey: Hex,
  teachingNftId: bigint,
  reasonCode = 1,
) {
  const client = requireWallet(createTeachingClient(config, privateKey));
  return client.walletClient.writeContract({
    ...requireTeachingRegistry(client),
    account: client.account,
    chain: config.chain,
    functionName: "coordinatorCloseTeachingValid",
    args: [teachingNftId, reasonCode],
  });
}

export async function closeTeachingTeacherFault(
  config: SparkDaoClientConfig,
  privateKey: Hex,
  teachingNftId: bigint,
  reasonCode = 4,
) {
  const client = requireWallet(createTeachingClient(config, privateKey));
  return client.walletClient.writeContract({
    ...requireTeachingRegistry(client),
    account: client.account,
    chain: config.chain,
    functionName: "coordinatorCloseTeachingTeacherFault",
    args: [teachingNftId, reasonCode],
  });
}

export async function claimTeachingSeatRefund(
  config: SparkDaoClientConfig,
  privateKey: Hex,
  teachingNftId: bigint,
  seatIndex: number,
) {
  const client = requireWallet(createTeachingClient(config, privateKey));
  return client.walletClient.writeContract({
    ...requireTeachingRegistry(client),
    account: client.account,
    chain: config.chain,
    functionName: "claimTeachingSeatRefund",
    args: [teachingNftId, seatIndex],
  });
}

export async function redeemTeachingTeacherPayout(
  config: SparkDaoClientConfig,
  privateKey: Hex,
  teachingNftId: bigint,
) {
  const client = requireWallet(createTeachingClient(config, privateKey));
  return client.walletClient.writeContract({
    ...requireTeachingRegistry(client),
    account: client.account,
    chain: config.chain,
    functionName: "redeemTeachingTeacherPayout",
    args: [teachingNftId],
  });
}

export async function settleTeachingRemedialWage(
  config: SparkDaoClientConfig,
  privateKey: Hex,
  teachingNftId: bigint,
) {
  const client = requireWallet(createTeachingClient(config, privateKey));
  return client.walletClient.writeContract({
    ...requireTeachingRegistry(client),
    account: client.account,
    chain: config.chain,
    functionName: "coordinatorSettleTeachingRemedialWage",
    args: [teachingNftId],
  });
}

export async function getTeachingRewardPreview(
  config: SparkDaoClientConfig,
  teachingNftId: bigint,
  assetId: bigint,
  positionId: bigint,
) {
  const client = createTeachingClient(config);
  return client.publicClient.readContract({
    ...requireTeachingRewardDistributor(client),
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
  const client = requireWallet(createTeachingClient(config, privateKey));
  return client.walletClient.writeContract({
    ...requireTeachingRewardDistributor(client),
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
  const client = requireWallet(createTeachingClient(config, privateKey));
  return client.walletClient.writeContract({
    ...requireTeachingRewardDistributor(client),
    account: client.account,
    chain: config.chain,
    functionName: "claimTeachingRewardBatch",
    args: [teachingNftIds, assetIds, positionIds],
  });
}

export async function withdrawTeachingIdleFor(
  config: SparkDaoClientConfig,
  privateKey: Hex,
  stableAsset: Address,
  amount: bigint,
) {
  const client = requireWallet(createTeachingClient(config, privateKey));
  return client.walletClient.writeContract({
    ...requireTeachingRegistry(client),
    account: client.account,
    chain: config.chain,
    functionName: "withdrawTeachingIdleFor",
    args: [stableAsset, amount],
  });
}

function requireWallet(
  client: SparkDaoClient,
): SparkDaoClient & { walletClient: NonNullable<SparkDaoClient["walletClient"]>; account: Address } {
  if (!client.walletClient || !client.account) {
    throw new Error("Wallet client not configured");
  }
  return client as SparkDaoClient & {
    walletClient: NonNullable<SparkDaoClient["walletClient"]>;
    account: Address;
  };
}

function requireTeachingRegistry(
  client: SparkDaoClient,
): SparkDaoContractDescriptor {
  const contract = client.contracts.teachingRegistry;
  if (!contract) throw new Error("Teaching registry address is not configured");
  return contract;
}

function requireTeachingRewardDistributor(
  client: SparkDaoClient,
): SparkDaoContractDescriptor {
  const contract = client.contracts.teachingRewardDistributor;
  if (!contract) {
    throw new Error("Teaching reward distributor address is not configured");
  }
  return contract;
}
