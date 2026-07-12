import assert from "node:assert/strict";
import test from "node:test";
import type { Address } from "viem";
import {
  assertTokenMinterState,
  contractDescriptorFromArtifact,
  expectedAddressByKey,
  expectedTokenMinterAddress,
} from "./checkModuleCompatibility.js";
import type { ModuleCompatibilityManifest } from "./checkModuleCompatibility.js";

const RESEARCH_REGISTRY = "0x00000000000000000000000000000000000000a1" as Address;
const TEACHING_REGISTRY = "0x00000000000000000000000000000000000000a2" as Address;
const TEACHING_REWARD_DISTRIBUTOR =
  "0x00000000000000000000000000000000000000a3" as Address;
const TEACHING_PRICING_POLICY = "0x00000000000000000000000000000000000000a4" as Address;
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
      key: "researchPositionToken",
      contractName: "ResearchPositionToken",
      address: MANIFEST_TOKEN,
      artifact: "out/ResearchPositionToken.sol/ResearchPositionToken.json",
    },
  ],
  expectedRelationships: {
    teachingRegistry: {
      researchRegistry: "researchRegistry",
      rewardDistributor: "teachingRewardDistributor",
      pricingPolicy: "teachingPricingPolicy",
    },
    teachingRewardDistributor: {
      teachingRegistry: "teachingRegistry",
      researchRegistry: "researchRegistry",
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
      teachingRewardDistributor: TEACHING_REWARD_DISTRIBUTOR,
      teachingPricingPolicy: TEACHING_PRICING_POLICY,
    },
  };

  assert.equal(expectedAddressByKey(config, manifest, "researchPositionToken"), MANIFEST_TOKEN);
});

test("env token address remains authoritative when both env and manifest provide one", () => {
  const config = {
    rpcUrl: "http://127.0.0.1:8545",
    chain: { id: 84532, name: "base-sepolia" },
    addresses: {
      researchRegistry: RESEARCH_REGISTRY,
      teachingRegistry: TEACHING_REGISTRY,
      teachingRewardDistributor: TEACHING_REWARD_DISTRIBUTOR,
      teachingPricingPolicy: TEACHING_PRICING_POLICY,
      researchPositionToken: ENV_TOKEN,
    },
  };

  assert.equal(expectedAddressByKey(config, manifest, "researchPositionToken"), ENV_TOKEN);
});

test("token minter expectations follow the registry wiring", () => {
  const config = {
    rpcUrl: "http://127.0.0.1:8545",
    chain: { id: 84532, name: "base-sepolia" },
    addresses: {
      researchRegistry: RESEARCH_REGISTRY,
      teachingRegistry: TEACHING_REGISTRY,
      teachingRewardDistributor: TEACHING_REWARD_DISTRIBUTOR,
      teachingPricingPolicy: TEACHING_PRICING_POLICY,
    },
  };

  assert.equal(
    expectedTokenMinterAddress(config, "researchPositionToken"),
    RESEARCH_REGISTRY,
  );
  assert.equal(
    expectedTokenMinterAddress(config, "teachingNftToken"),
    TEACHING_REGISTRY,
  );
});

test("token minter state requires the expected locked minter", () => {
  assert.doesNotThrow(() =>
    assertTokenMinterState(
      "research position token",
      RESEARCH_REGISTRY,
      RESEARCH_REGISTRY,
      true,
    ),
  );
  assert.throws(
    () =>
      assertTokenMinterState(
        "research position token",
        ENV_TOKEN,
        RESEARCH_REGISTRY,
        true,
      ),
    /minter mismatch/,
  );
  assert.throws(
    () =>
      assertTokenMinterState(
        "research position token",
        RESEARCH_REGISTRY,
        RESEARCH_REGISTRY,
        false,
      ),
    /minter is not locked/,
  );
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
