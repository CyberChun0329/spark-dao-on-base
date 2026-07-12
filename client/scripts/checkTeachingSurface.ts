import { existsSync, readFileSync, readdirSync, statSync } from "node:fs";

function readText(path: string): string {
  return readFileSync(path, "utf8");
}

function assertIncludes(text: string, needle: string, label: string) {
  if (!text.includes(needle)) {
    throw new Error(`${label} is missing ${needle}`);
  }
}

function assertExcludes(text: string, needle: string, label: string) {
  if (text.includes(needle)) {
    throw new Error(`${label} still exposes ${needle}`);
  }
}

function assertMissing(path: string) {
  if (existsSync(path)) {
    throw new Error(`${path} should be removed from the teaching-only surface`);
  }
}

const activeSurfaceFiles = [
  ".env.example",
  "README.md",
  "client/README.md",
  "client/src/artifacts.ts",
  "client/src/config.ts",
  "client/src/index.ts",
  "docs/RUNBOOK.md",
  "script/DeployRegistry.s.sol",
  "script/README.md",
] as const;

const oldTeachingSurfaceMarkers = [
  "DemoClassroom",
  "ClassroomRegistry",
  "ClassroomRewardDistributor",
  "CLASSROOM_REGISTRY",
  "CLASSROOM_REWARD_DISTRIBUTOR",
] as const;

const forbiddenSessionSurfaceMarkers = [
  ...oldTeachingSurfaceMarkers,
  "TeachingClass",
  "CreateTeachingClass",
  "createTeachingClass",
  "getTeachingClassState",
  "TeachingClassCreated",
  "TeachingClassClosed",
  "quoteTeachingClass",
  "classId",
  "classIds",
  "ClassId",
  "CLASS_ID",
  "class is open",
] as const;

const removedTeachingFiles = [
  "src/ClassroomRegistry.sol",
  "src/ClassroomRewardDistributor.sol",
  "src/ClassroomPricingPolicyV1.sol",
  "src/SparkClassroomTypes.sol",
  "src/interfaces/IClassroomPricingPolicy.sol",
  "src/interfaces/IClassroomRegistryForResearch.sol",
  "src/interfaces/IClassroomRewardDistributor.sol",
  "src/interfaces/IClassroomRewardSource.sol",
  "src/interfaces/IResearchRegistryForClassroom.sol",
  "script/DemoClassroom.s.sol",
  "test/ClassroomRegistry.t.sol",
  "test/ClassroomGasCalibration.t.sol",
  "test/ClassroomPricingPolicy.t.sol",
  "test/ClassroomSingleSeatCompatibility.t.sol",
  "client/src/classroom.ts",
  "client/scripts/checkClassroomSurface.ts",
  "src/TeachingEconomicsPolicyV1.sol",
  "src/TeachingFaultPolicyV1.sol",
  "src/TeachingPolicyGuard.sol",
  "src/interfaces/ITeachingEconomicsPolicy.sol",
  "src/interfaces/ITeachingEconomicsPolicyGuard.sol",
  "src/interfaces/ITeachingFaultPolicy.sol",
  "src/interfaces/ITeachingFaultPolicyGuard.sol",
  "test/TeachingEconomicsPolicy.t.sol",
  "test/TeachingFaultPolicy.t.sol",
  "test/mocks/MockTeachingEconomicsPolicy.sol",
  "test/mocks/MockTeachingFaultPolicy.sol",
] as const;

const activeScanRoots = [
  "src",
  "test",
  "script",
  "client/src",
  "client/scripts",
  "docs",
] as const;

const activeStandaloneFiles = [
  ".env.example",
  "README.md",
  "package.json",
  "foundry.toml",
] as const;

function collectFiles(path: string): string[] {
  const stats = statSync(path);
  if (stats.isFile()) {
    return [path];
  }
  if (!stats.isDirectory()) {
    return [];
  }

  return readdirSync(path)
    .flatMap((entry) => collectFiles(`${path}/${entry}`))
    .filter((entry) => /\.(json|md|sol|toml|ts)$/.test(entry))
    .filter((entry) => entry !== "client/scripts/checkTeachingSurface.ts");
}

for (const path of removedTeachingFiles) {
  assertMissing(path);
}

for (const path of activeSurfaceFiles) {
  const text = readText(path);
  for (const marker of oldTeachingSurfaceMarkers) {
    assertExcludes(text, marker, path);
  }
}

for (const path of [...activeStandaloneFiles, ...activeScanRoots.flatMap(collectFiles)]) {
  const text = readText(path);
  for (const marker of forbiddenSessionSurfaceMarkers) {
    assertExcludes(text, marker, path);
  }
}

const packageJson = JSON.parse(readText("package.json")) as {
  scripts?: Record<string, string>;
};
const scripts = packageJson.scripts ?? {};

assertIncludes(
  scripts["deploy:registry"] ?? "",
  "DeployRegistry.s.sol:DeployRegistry",
  "package.json deploy:registry",
);
assertIncludes(
  scripts["demo:teaching"] ?? "",
  "DemoTeaching.s.sol:DemoTeaching",
  "package.json demo:teaching",
);
assertIncludes(
  scripts["check:teaching-surface"] ?? "",
  "checkTeachingSurface.ts",
  "package.json check:teaching-surface",
);

for (const [name, command] of Object.entries(scripts)) {
  assertExcludes(name, "demo:classroom", "package.json scripts");
  assertExcludes(command, "DemoClassroom", `package.json script ${name}`);
  assertExcludes(command, "ClassroomRegistry", `package.json script ${name}`);
  assertExcludes(command, "ClassroomRewardDistributor", `package.json script ${name}`);
}

const deployRegistry = readText("script/DeployRegistry.s.sol");
assertIncludes(deployRegistry, "TeachingRegistry", "DeployRegistry.s.sol");
assertIncludes(deployRegistry, "TeachingRewardDistributor", "DeployRegistry.s.sol");
assertIncludes(deployRegistry, "TeachingPricingPolicyV1", "DeployRegistry.s.sol");
assertIncludes(deployRegistry, "TEACHING_NFT_TOKEN", "DeployRegistry.s.sol");

const compatibilityTests = readText("test/TeachingSingleSeatCompatibility.t.sol");
for (const testName of [
  "testClassSizeOneQuoteKeepsSingleSeatEconomics",
  "testClassSizeOneMintsTeachingNftToTeacher",
  "testClassSizeOneNormalCloseFinalBalancesAndIdleReserve",
  "testClassSizeOneDiscountedCloseKeepsFrozenSalaryAndDiscountedSeatPrice",
  "testClassSizeOneTeacherUnmatchedWithdrawalRestoresTeacherBond",
  "testClassSizeOneStudentUnmatchedWithdrawalRestoresSeatPayment",
  "testClassSizeOneCustomerFaultKeepsPerSeatRefundAndDelayedHalfWage",
  "testClassSizeOneTeacherFaultUsesRefundAndRemedialWage",
  "testClassSizeOneCurrentHolderCanClaimResearchReward",
  "testClassSizeOneBoughtBackRewardRoutesToTreasury",
  "testClassSizeOneRepeatRewardClaimReverts",
  "testClassSizeOneRewardBatchAtomicityPreservesFirstClaimOnLaterFailure",
  "testClassSizeOneRewardDustReleasesOnceAfterAllSharesClaim",
  "testClassSizeOneReleasedIdleCanBeWithdrawn",
  "testClassSizeOneUnauthorizedRewardCallbackReverts",
  "testClassSizeOneStableAssetFreezeUsesCourseTypeStableAsset",
  "testClassSizeOneAttendanceAndDeliveryAutoCloseWithoutCoordinator",
] as const) {
  assertIncludes(compatibilityTests, testName, "TeachingSingleSeatCompatibility.t.sol");
}

const calibrationCheck = readText("client/scripts/checkCalibration.ts");
assertIncludes(calibrationCheck, "TeachingGasCalibrationTest", "checkCalibration.ts");
assertExcludes(calibrationCheck, "ClassroomGasCalibrationTest", "checkCalibration.ts");

const teachingCompatibilityNeedles = [
  "classSize = 1 preserves the single-seat economic, reserve, claim, dust, buyback, and stable-asset semantics.",
  "Schedule confirmation is teacher + coordinator.",
  "Fault refunds are per-seat claim-pull.",
  "Customer-fault teacher half wage follows the teacher payout redeem delay.",
  "Customer fault remains per-seat state inside a valid closed teaching session.",
  "Clients should read teaching state through `getTeachingSessionState`, `getTeachingProgressState`, `getTeachingSeat`, and teaching reward distributor getters.",
  "Teaching events are the teaching event surface for demos.",
] as const;

for (const path of ["docs/RUNBOOK.md", "client/README.md", "test/README.md"] as const) {
  const text = readText(path);
  for (const needle of teachingCompatibilityNeedles) {
    assertIncludes(text, needle, path);
  }
}

const teachingApiUpgradeNeedle =
  "`TeachingRegistry` keeps the Teaching protocol surface while the session API supports";
for (const path of ["docs/RUNBOOK.md", "src/README.md"] as const) {
  assertIncludes(readText(path), teachingApiUpgradeNeedle, path);
}

const teachingRegistry = readText("src/TeachingRegistry.sol");
for (const needle of [
  "function getTeachingProgressState",
  "event TeachingAttendanceConfirmed",
  "event TeachingDeliveryConfirmed",
] as const) {
  assertIncludes(teachingRegistry, needle, "TeachingRegistry.sol");
}

const teachingClient = readText("client/src/teaching.ts");
for (const needle of [
  "function getTeachingProgressState",
  "function lockTeachingTeacherBond",
  "function confirmTeachingAttendance",
  "function confirmTeachingDelivery",
] as const) {
  assertIncludes(teachingClient, needle, "client/src/teaching.ts");
}

console.log("Teaching surface check passed");
