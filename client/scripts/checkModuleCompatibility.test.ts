import assert from "node:assert/strict";
import test from "node:test";
import type { Address } from "viem";
import {
  contractDescriptorFromArtifact,
  expectedAddressByKey,
} from "./checkModuleCompatibility.js";
import type { ModuleCompatibilityManifest } from "./checkModuleCompatibility.js";

const RESEARCH_REGISTRY = "0x00000000000000000000000000000000000000a1" as Address;
const TEACHING_REGISTRY = "0x00000000000000000000000000000000000000a2" as Address;
const MANIFEST_TOKEN = "0x00000000000000000000000000000000000000b1" as Address;
const ENV_TOKEN = "0x00000000000000000000000000000000000000b2" as Address;

const manifest: ModuleCompatibilityManifest = {
  schema: "spark-dao-module-compatibility/v1",
  chain: {
    name: "base-sepolia",
    chainId: 84532,
  },
  contracts: [
    {
      key: "teachingNftToken",
      contractName: "TeachingNftToken",
      address: MANIFEST_TOKEN,
      artifact: "out/TeachingNftToken.sol/TeachingNftToken.json",
    },
  ],
  expectedRelationships: {
    teachingRegistry: {
      researchRegistry: "researchRegistry",
      rewardDistributor: "teachingRewardDistributor",
      policyGuard: "teachingPolicyGuard",
      economicsPolicy: "teachingEconomicsPolicy",
      faultPolicy: "teachingFaultPolicy",
    },
    teachingRewardDistributor: {
      teachingRegistry: "teachingRegistry",
      researchRegistry: "researchRegistry",
    },
    policyVersions: {
      economics: 1,
      fault: 1,
    },
  },
};

test("manifest token address is used when env token address is omitted", () => {
  const config = {
    rpcUrl: "http://127.0.0.1:8545",
    chain: { id: 84532, name: "base-sepolia" },
    addresses: {
      researchRegistry: RESEARCH_REGISTRY,
      teachingRegistry: TEACHING_REGISTRY,
    },
  };

  assert.equal(expectedAddressByKey(config, manifest, "teachingNftToken"), MANIFEST_TOKEN);
});

test("env token address remains authoritative when both env and manifest provide one", () => {
  const config = {
    rpcUrl: "http://127.0.0.1:8545",
    chain: { id: 84532, name: "base-sepolia" },
    addresses: {
      researchRegistry: RESEARCH_REGISTRY,
      teachingRegistry: TEACHING_REGISTRY,
      teachingNftToken: ENV_TOKEN,
    },
  };

  assert.equal(expectedAddressByKey(config, manifest, "teachingNftToken"), ENV_TOKEN);
});

test("manifest entry and artifact ABI can construct a read descriptor", () => {
  const abi = [{ type: "function", name: "minterLocked", stateMutability: "view" }];

  assert.deepEqual(
    contractDescriptorFromArtifact(manifest.contracts[0], { abi }),
    {
      address: MANIFEST_TOKEN,
      abi,
    },
  );
});

test("manifest descriptor construction rejects artifacts without ABI", () => {
  assert.throws(
    () => contractDescriptorFromArtifact(manifest.contracts[0], {}),
    /artifact has no ABI/,
  );
});
