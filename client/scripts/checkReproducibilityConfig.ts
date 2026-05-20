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
  "TEACHING_POLICY_GUARD",
  "TEACHING_ECONOMICS_POLICY",
  "TEACHING_FAULT_POLICY",
  "DAO_TREASURY",
]) {
  assertIncludes(envExample, `${key}=`, ".env.example");
}

assertIncludes(
  requireText("script/DeployRegistry.s.sol"),
  "setTeachingRegistry",
  "DeployRegistry.s.sol",
);
assertIncludes(
  requireText("script/DeployRegistry.s.sol"),
  "setTeachingRewardDistributor",
  "DeployRegistry.s.sol",
);
assertIncludes(
  requireText("src/TeachingRegistry.sol"),
  "getTeachingModuleState",
  "TeachingRegistry.sol",
);
assertIncludes(
  requireText("src/TeachingRegistry.sol"),
  "coordinatorSettleTeacherFaultRemedialWage",
  "TeachingRegistry.sol",
);
assertIncludes(
  requireText("script/DeployRegistry.s.sol"),
  "ResearchRegistry",
  "DeployRegistry.s.sol",
);
assertIncludes(
  requireText("script/DeployRegistry.s.sol"),
  "TeachingEconomicsPolicyV1",
  "DeployRegistry.s.sol",
);
assertIncludes(
  requireText("script/DeployRegistry.s.sol"),
  "TeachingFaultPolicyV1",
  "DeployRegistry.s.sol",
);
assertIncludes(
  requireText("script/DeployRegistry.s.sol"),
  "TeachingPolicyGuard",
  "DeployRegistry.s.sol",
);

const packageJson = JSON.parse(requireText("package.json")) as {
  scripts?: Record<string, string>;
};
if (packageJson.scripts?.["simulate:teaching-cost"] !== "tsx client/scripts/simulateTeachingCost.ts") {
  throw new Error("package.json is missing simulate:teaching-cost");
}
if (
  packageJson.scripts?.["check:registry-admin-state"]
  !== "tsx client/scripts/checkRegistryAdminState.ts"
) {
  throw new Error("package.json is missing check:registry-admin-state");
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
