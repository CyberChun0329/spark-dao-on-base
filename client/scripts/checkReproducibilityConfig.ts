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
  "TEACHING_PRICING_POLICY",
  "TEACHING_NFT_TOKEN",
  "MODULE_COMPATIBILITY_MANIFEST",
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
  requireText("src/ResearchRegistry.sol"),
  "setTeachingRegistry",
  "ResearchRegistry.sol",
);
assertIncludes(
  requireText("src/ResearchRegistry.sol"),
  "recordTeachingRewardClaim",
  "ResearchRegistry.sol",
);
assertIncludes(
  requireText("src/ResearchRegistry.sol"),
  "getTeachingResearchSnapshot",
  "ResearchRegistry.sol",
);
assertIncludes(
  requireText("src/ResearchRegistry.sol"),
  "requireTeachingResearchAssetReady",
  "ResearchRegistry.sol",
);
assertIncludes(
  requireText("src/TeachingRegistry.sol"),
  "coordinatorCloseTeachingTeacherFault",
  "TeachingRegistry.sol",
);
assertIncludes(
  requireText("script/DeployRegistry.s.sol"),
  "ResearchRegistry",
  "DeployRegistry.s.sol",
);
assertIncludes(
  requireText("script/DeployRegistry.s.sol"),
  "TeachingRegistry",
  "DeployRegistry.s.sol",
);
assertIncludes(
  requireText("script/DeployRegistry.s.sol"),
  "TeachingRewardDistributor",
  "DeployRegistry.s.sol",
);
assertIncludes(
  requireText("script/DeployRegistry.s.sol"),
  "TeachingPricingPolicyV1",
  "DeployRegistry.s.sol",
);
assertIncludes(
  requireText("script/DeployRegistry.s.sol"),
  "TEACHING_NFT_TOKEN",
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
if (
  packageJson.scripts?.["check:module-compatibility"]
  !== "tsx client/scripts/checkModuleCompatibility.ts"
) {
  throw new Error("package.json is missing check:module-compatibility");
}
if (
  packageJson.scripts?.["check:module-compatibility:example"]
  !== "MODULE_COMPATIBILITY_VALIDATE_MANIFEST_ONLY=1 MODULE_COMPATIBILITY_MANIFEST=client/module-compatibility.example.json tsx client/scripts/checkModuleCompatibility.ts"
) {
  throw new Error("package.json is missing check:module-compatibility:example");
}
if (
  packageJson.scripts?.["check:teaching-surface"]
  !== "tsx client/scripts/checkTeachingSurface.ts"
) {
  throw new Error("package.json is missing check:teaching-surface");
}
if (packageJson.scripts?.["check:calibration"] !== "tsx client/scripts/checkCalibration.ts") {
  throw new Error("package.json is missing check:calibration");
}
assertIncludes(
  requireText("client/scripts/checkCalibration.ts"),
  "TeachingGasCalibrationTest",
  "checkCalibration.ts",
);
assertIncludes(
  requireText("client/scripts/checkCalibration.ts"),
  "testWriteTeachingSizeGasCalibrationCsv",
  "checkCalibration.ts",
);
assertIncludes(
  requireText("client/scripts/checkCalibration.ts"),
  "testWriteTeachingFaultSizeGasCalibrationCsv",
  "checkCalibration.ts",
);
assertIncludes(
  requireText("client/scripts/simulateTeachingCost.ts"),
  "test/TeachingGasCalibration.t.sol",
  "simulateTeachingCost.ts",
);
if (
  packageJson.scripts?.["demo:teaching"]
  !== "forge script script/DemoTeaching.s.sol:DemoTeaching"
) {
  throw new Error("package.json is missing demo:teaching");
}

assertIncludes(
  requireText("client/module-compatibility.example.json"),
  "spark-dao-module-compatibility/v1",
  "client/module-compatibility.example.json",
);
assertIncludes(
  requireText("client/module-compatibility.example.json"),
  "teachingNftToken",
  "client/module-compatibility.example.json",
);

const moduleCompatibilityChecker = requireText("client/scripts/checkModuleCompatibility.ts");
for (const requiredCheck of [
  "RESEARCH_POSITION_TOKEN",
  "TEACHING_PRICING_POLICY_VERSION",
  "expectedTokenMinterAddress",
  'readAddress(client, token, "minter")',
  'readBool(client, token, "minterLocked")',
]) {
  assertIncludes(
    moduleCompatibilityChecker,
    requiredCheck,
    "checkModuleCompatibility.ts",
  );
}

const foundryToml = requireText("foundry.toml");
for (const outputPath of [
  "./teaching_gas_calibration.csv",
  "./teaching_followup_gas_calibration.csv",
  "./teaching_class_size_gas_calibration.csv",
  "./teaching_fault_size_gas_calibration.csv",
  "./research_gas_calibration.csv",
]) {
  assertIncludes(foundryToml, outputPath, "foundry.toml");
}

assertIncludes(
  requireText("script/DemoResearch.s.sol"),
  "researchToken.lockMinter();",
  "DemoResearch.s.sol",
);
assertIncludes(
  requireText("script/DemoTeaching.s.sol"),
  "researchRegistry.setTeachingRegistry",
  "DemoTeaching.s.sol",
);
assertIncludes(
  requireText("script/DemoTeaching.s.sol"),
  "teaching.setTeachingRewardDistributor",
  "DemoTeaching.s.sol",
);

console.log("Reproducibility config checks passed");
