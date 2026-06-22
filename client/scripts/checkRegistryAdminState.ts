import "dotenv/config";
import type { Address } from "viem";
import { loadClientConfigFromEnv } from "../src/config.js";
import { getTeachingDaoState, getTeachingModuleState } from "../src/teaching.js";
import { getResearchDaoState } from "../src/research.js";

type DaoState = {
  authority: Address;
  treasury: Address;
  coordinator: Address;
  stableAsset: Address;
  rewardUnlockSeconds: bigint;
  buybackWaitSeconds: bigint;
};

const comparedFields = [
  "authority",
  "treasury",
  "coordinator",
  "stableAsset",
  "rewardUnlockSeconds",
  "buybackWaitSeconds",
] as const;

function valueToString(value: Address | bigint) {
  return typeof value === "bigint" ? value.toString() : value;
}

function normaliseAddress(value: Address) {
  return value.toLowerCase();
}

function assertAddressMatch(label: string, actual: Address, expected?: Address) {
  if (!expected) return;
  if (normaliseAddress(actual) !== normaliseAddress(expected)) {
    throw new Error(`${label} mismatch: actual=${actual}, expected=${expected}`);
  }
}

async function main() {
  const config = loadClientConfigFromEnv();
  const researchState = (await getResearchDaoState(config)) as unknown as DaoState;
  const teachingState = (await getTeachingDaoState(config)) as unknown as DaoState;

  const mismatches = comparedFields.filter(
    (field) => researchState[field] !== teachingState[field],
  );
  if (mismatches.length !== 0) {
    const details = mismatches.map((field) => {
      return `${field}: research=${valueToString(researchState[field])}, teaching=${valueToString(
        teachingState[field],
      )}`;
    });
    throw new Error(`Registry admin state drift detected:\n${details.join("\n")}`);
  }

  const [researchRegistry, teachingPricingPolicy, teachingRewardDistributor] =
    (await getTeachingModuleState(config)) as unknown as readonly [
    Address,
    Address,
    Address,
  ];

  assertAddressMatch(
    "research registry",
    researchRegistry,
    config.addresses.researchRegistry,
  );
  assertAddressMatch(
    "teaching reward distributor",
    teachingRewardDistributor,
    config.addresses.teachingRewardDistributor,
  );
  assertAddressMatch(
    "teaching pricing policy",
    teachingPricingPolicy,
    config.addresses.teachingPricingPolicy,
  );

  console.log("Registry admin state check passed");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
