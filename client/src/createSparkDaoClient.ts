import {
  createPublicClient,
  createWalletClient,
  http,
  type Address,
  type Chain,
  type Hex,
} from "viem";
import { privateKeyToAccount } from "viem/accounts";
import {
  teachingPricingPolicyArtifact,
  teachingRegistryArtifact,
  teachingRewardDistributorArtifact,
  researchPositionTokenArtifact,
  researchRegistryArtifact,
  teachingNftTokenArtifact,
} from "./artifacts.js";
import type { SparkDaoAddresses } from "./config.js";

export type SparkDaoContractDescriptor = {
  address: Address;
  abi: readonly unknown[];
};

type ReadContractParams = SparkDaoContractDescriptor & {
  functionName: string;
  args?: readonly unknown[];
};

type WriteContractParams = ReadContractParams & {
  account: Address;
  chain: Chain;
};

export type SparkDaoPublicClient = {
  readContract(params: ReadContractParams): Promise<unknown>;
  getBytecode(params: { address: Address }): Promise<Hex | undefined>;
};

export type SparkDaoWalletClient = {
  writeContract(params: WriteContractParams): Promise<Hex>;
};

export type SparkDaoContracts = {
  researchRegistry: SparkDaoContractDescriptor;
  teachingRegistry: SparkDaoContractDescriptor;
  teachingRewardDistributor: SparkDaoContractDescriptor;
  teachingPricingPolicy: SparkDaoContractDescriptor;
  teachingNftToken?: SparkDaoContractDescriptor;
  researchPositionToken?: SparkDaoContractDescriptor;
};

export type SparkDaoClient = {
  publicClient: SparkDaoPublicClient;
  walletClient?: SparkDaoWalletClient;
  account?: Address;
  contracts: SparkDaoContracts;
};

type CreateSparkDaoClientParams = {
  rpcUrl: string;
  chain: Chain;
  addresses: SparkDaoAddresses;
  privateKey?: Hex;
};

export function createSparkDaoClient(
  params: CreateSparkDaoClientParams,
): SparkDaoClient {
  const publicClient = createPublicClient({
    chain: params.chain,
    transport: http(params.rpcUrl),
  }) as unknown as SparkDaoPublicClient;

  const account = params.privateKey
    ? privateKeyToAccount(params.privateKey)
    : undefined;

  const walletClient = account
    ? (createWalletClient({
        account,
        chain: params.chain,
        transport: http(params.rpcUrl),
      }) as unknown as SparkDaoWalletClient)
    : undefined;

  const researchRegistry: SparkDaoContractDescriptor = {
    address: params.addresses.researchRegistry,
    abi: researchRegistryArtifact.abi,
  };

  const teachingRegistry: SparkDaoContractDescriptor = {
    address: params.addresses.teachingRegistry,
    abi: teachingRegistryArtifact.abi,
  };

  const teachingRewardDistributor: SparkDaoContractDescriptor = {
    address: params.addresses.teachingRewardDistributor,
    abi: teachingRewardDistributorArtifact.abi,
  };

  const teachingPricingPolicy: SparkDaoContractDescriptor = {
    address: params.addresses.teachingPricingPolicy,
    abi: teachingPricingPolicyArtifact.abi,
  };

  const researchPositionToken = params.addresses.researchPositionToken
    ? ({
        address: params.addresses.researchPositionToken,
        abi: researchPositionTokenArtifact.abi,
      } satisfies SparkDaoContractDescriptor)
    : undefined;
  const teachingNftToken = params.addresses.teachingNftToken
    ? ({
        address: params.addresses.teachingNftToken,
        abi: teachingNftTokenArtifact.abi,
      } satisfies SparkDaoContractDescriptor)
    : undefined;

  return {
    publicClient,
    walletClient,
    account: account?.address,
    contracts: {
      researchRegistry,
      teachingRegistry,
      teachingRewardDistributor,
      teachingPricingPolicy,
      teachingNftToken,
      researchPositionToken,
    },
  };
}
