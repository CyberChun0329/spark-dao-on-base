import {
  createPublicClient,
  createWalletClient,
  http,
  type Abi,
  type Address,
  type Chain,
  type Hex,
  type PublicClient,
  type WalletClient,
} from "viem";
import { privateKeyToAccount } from "viem/accounts";
import {
  researchPositionTokenArtifact,
  researchRegistryArtifact,
  teachingNftTokenArtifact,
  teachingRegistryArtifact,
} from "./artifacts.js";
import type { SparkDaoAddresses } from "./config.js";

export type SparkDaoContractDescriptor = {
  address: Address;
  abi: Abi;
};

export type SparkDaoContracts = {
  researchRegistry: SparkDaoContractDescriptor;
  teachingRegistry: SparkDaoContractDescriptor;
  researchPositionToken?: SparkDaoContractDescriptor;
  teachingNftToken?: SparkDaoContractDescriptor;
};

export type SparkDaoClient = {
  publicClient: PublicClient;
  walletClient?: WalletClient;
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
  });

  const account = params.privateKey
    ? privateKeyToAccount(params.privateKey)
    : undefined;

  const walletClient = account
    ? createWalletClient({
        account,
        chain: params.chain,
        transport: http(params.rpcUrl),
      })
    : undefined;

  const researchRegistry: SparkDaoContractDescriptor = {
    address: params.addresses.researchRegistry,
    abi: researchRegistryArtifact.abi,
  };

  const teachingRegistry: SparkDaoContractDescriptor = {
    address: params.addresses.teachingRegistry,
    abi: teachingRegistryArtifact.abi,
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
      researchPositionToken,
      teachingNftToken,
    },
  };
}
