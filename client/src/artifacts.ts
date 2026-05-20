import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT_DIR = resolve(dirname(fileURLToPath(import.meta.url)), "../..");

type ArtifactJson = {
  abi: readonly unknown[];
};

function readArtifact(relativePath: string): ArtifactJson {
  const artifactPath = resolve(ROOT_DIR, relativePath);
  return JSON.parse(readFileSync(artifactPath, "utf8")) as ArtifactJson;
}

export const researchRegistryArtifact = readArtifact(
  "out/ResearchRegistry.sol/ResearchRegistry.json",
);
export const teachingRegistryArtifact = readArtifact(
  "out/TeachingRegistry.sol/TeachingRegistry.json",
);
export const teachingRewardDistributorArtifact = readArtifact(
  "out/TeachingRewardDistributor.sol/TeachingRewardDistributor.json",
);
export const teachingEconomicsPolicyArtifact = readArtifact(
  "out/TeachingEconomicsPolicyV1.sol/TeachingEconomicsPolicyV1.json",
);
export const teachingFaultPolicyArtifact = readArtifact(
  "out/TeachingFaultPolicyV1.sol/TeachingFaultPolicyV1.json",
);
export const teachingPolicyGuardArtifact = readArtifact(
  "out/TeachingPolicyGuard.sol/TeachingPolicyGuard.json",
);
export const researchPositionTokenArtifact = readArtifact(
  "out/ResearchPositionToken.sol/ResearchPositionToken.json",
);
export const teachingNftTokenArtifact = readArtifact(
  "out/TeachingNftToken.sol/TeachingNftToken.json",
);
