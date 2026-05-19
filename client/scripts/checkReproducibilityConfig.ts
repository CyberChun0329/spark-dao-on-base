import { readFileSync } from "node:fs";

function requireText(path: string): string {
  return readFileSync(path, "utf8");
}

function assertIncludes(text: string, needle: string, label: string) {
  if (!text.includes(needle)) {
    throw new Error(`${label} is missing ${needle}`);
  }
}

const envExample = requireText(".env.example");
for (const key of [
  "BASE_CHAIN",
  "RESEARCH_REGISTRY",
  "TEACHING_REGISTRY",
  "TEACHING_REWARD_DISTRIBUTOR",
  "DAO_TREASURY",
]) {
  assertIncludes(envExample, `${key}=`, ".env.example");
}

assertIncludes(
  requireText("script/DeployRegistry.s.sol"),
  "setTeachingRewardDistributor",
  "DeployRegistry.s.sol",
);

const packageJson = JSON.parse(requireText("package.json")) as {
  scripts?: Record<string, string>;
};
if (packageJson.scripts?.["simulate:teaching-cost"] !== "tsx client/scripts/simulateTeachingCost.ts") {
  throw new Error("package.json is missing simulate:teaching-cost");
}

assertIncludes(
  requireText("script/DemoResearch.s.sol"),
  "researchToken.lockMinter();",
  "DemoResearch.s.sol",
);
assertIncludes(
  requireText("script/DemoTeaching.s.sol"),
  "researchToken.lockMinter();",
  "DemoTeaching.s.sol",
);
assertIncludes(
  requireText("script/DemoTeaching.s.sol"),
  "teachingToken.lockMinter();",
  "DemoTeaching.s.sol",
);

console.log("Reproducibility config checks passed");
