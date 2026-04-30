import type { Address, Chain } from "viem";
import { base, baseSepolia } from "viem/chains";

export type SparkDaoAddresses = {
  researchRegistry: Address;
  teachingRegistry: Address;
  researchPositionToken?: Address;
  teachingNftToken?: Address;
};

export type SparkDaoClientConfig = {
  rpcUrl: string;
  chain: Chain;
  addresses: SparkDaoAddresses;
};

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

function optionalAddress(name: string): Address | undefined {
  const value = process.env[name];
  return value ? (value as Address) : undefined;
}

export function resolveBaseChain(): Chain {
  const chainName = process.env.BASE_CHAIN?.toLowerCase();
  if (chainName === "base") return base;
  return baseSepolia;
}

export function loadClientConfigFromEnv(): SparkDaoClientConfig {
  return {
    rpcUrl: requireEnv("BASE_RPC_URL"),
    chain: resolveBaseChain(),
    addresses: {
      researchRegistry: requireEnv("RESEARCH_REGISTRY") as Address,
      teachingRegistry: requireEnv("TEACHING_REGISTRY") as Address,
      researchPositionToken: optionalAddress("RESEARCH_POSITION_TOKEN"),
      teachingNftToken: optionalAddress("TEACHING_NFT_TOKEN"),
    },
  };
}
