import { createHash } from "node:crypto";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { spawnSync } from "node:child_process";

const calibrationSchemaVersion = 2;

type TeachingGasRow = {
  path: string;
  category: string;
  course_type_gas: number;
  research_setup_gas: number;
  research_mutation_gas: number;
  lesson_gas: number;
  claim_gas: number;
  valid_lesson: boolean;
  revenue_weight_bps: number;
};

type FollowupGasRow = {
  path: string;
  category: string;
  gas: number;
  measurement_context: string;
};

type ResearchGasRow = {
  path: string;
  gas: number;
};

type Scenario = {
  name: string;
  ordinaryMix: Record<"NR" | "ZS" | "RB" | "WM" | "ML", number>;
};

type CoordinatorCase = {
  name: string;
  pFV: number;
  pCF: number;
  pTF: number;
};

type FeeAssumptions = {
  referenceUsdPerGas: number;
  source: string;
  measurementWindow: string;
  unit: string;
};

type SummaryRow = {
  window: string;
  coordinatorCase: string;
  feeMultiplier: number;
  pFV: number;
  pCF: number;
  pTF: number;
  ordinaryResearchMutationGas: number;
  ordinaryLessonGas: number;
  ordinaryClaimGas: number;
  forcedValidResearchMutationGas: number;
  forcedValidLessonGas: number;
  forcedValidClaimGas: number;
  customerFaultResearchMutationGas: number;
  customerFaultLessonGas: number;
  customerFaultClaimGas: number;
  teacherFaultResearchMutationGas: number;
  teacherFaultLessonGas: number;
  teacherFaultClaimGas: number;
  expectedResearchMutationGas: number;
  expectedLessonGas: number;
  expectedClaimGas: number;
  expectedManagementGas: number;
  expectedCoupledGas: number;
  revenueWeight: number;
  lessonLifecycleCostPerAttemptedLesson: number;
  claimCostPerAttemptedLesson: number;
  costPerAttemptedLesson: number;
  coupledCostPerAttemptedLesson: number;
  shares: number[];
  coupledShares: number[];
};

const root = process.cwd();
const gasCsvPath = join(root, "teaching_gas_calibration.csv");
const followupGasCsvPath = join(root, "teaching_followup_gas_calibration.csv");
const researchGasCsvPath = join(root, "research_gas_calibration.csv");
const feeAssumptionsPath = join(root, "simulation_inputs", "fee_assumptions.json");
const outDir = join(root, "simulation_outputs");
const expectedRemedialWageContext = "same-test-warm-call";
const sourceFilePaths = [
  "test/TeachingGasCalibration.t.sol",
  "test/ResearchGasCalibration.t.sol",
  "client/scripts/simulateTeachingCost.ts",
  "foundry.toml",
  "package.json",
  "package-lock.json",
];

const scenarios: Scenario[] = [
  {
    name: "Demand-first",
    ordinaryMix: { NR: 0.7, ZS: 0.2, RB: 0.1, WM: 0, ML: 0 },
  },
  {
    name: "Supply-first",
    ordinaryMix: { NR: 0.45, ZS: 0.25, RB: 0.2, WM: 0.1, ML: 0 },
  },
  {
    name: "Synchronised",
    ordinaryMix: { NR: 0.3, ZS: 0.2, RB: 0.25, WM: 0.2, ML: 0.05 },
  },
];

const coordinatorCases: CoordinatorCase[] = [
  { name: "No coordinator", pFV: 0, pCF: 0, pTF: 0 },
  { name: "Low coordinator", pFV: 0.01, pCF: 0.003, pTF: 0.002 },
  { name: "Elevated coordinator", pFV: 0.05, pCF: 0.02, pTF: 0.01 },
  { name: "Coordinator stress", pFV: 0.1, pCF: 0.05, pTF: 0.03 },
];

const revenues = [50, 100, 150];
const feeMultipliers = [1, 5, 10];

function parseCsv(path: string): Record<string, string>[] {
  const text = readFileSync(path, "utf8").trim();
  if (!text) throw new Error(`Empty CSV: ${path}`);
  const [headerLine, ...lines] = text.split(/\r?\n/);
  const headers = headerLine.split(",");
  return lines.map((line) => {
    const cells = line.split(",");
    if (cells.length !== headers.length) {
      throw new Error(`CSV column mismatch in ${path}: ${line}`);
    }
    return Object.fromEntries(headers.map((header, index) => [header, cells[index]]));
  });
}

function numberCell(row: Record<string, string>, key: string, path: string): number {
  const value = Number(row[key]);
  if (!Number.isFinite(value)) {
    throw new Error(`Invalid numeric value for ${key} in ${path}`);
  }
  return value;
}

function booleanCell(row: Record<string, string>, key: string, path: string): boolean {
  const value = row[key];
  if (value === "true") return true;
  if (value === "false") return false;
  throw new Error(`Invalid boolean value for ${key} in ${path}`);
}

function parseTeachingCsv(path: string): TeachingGasRow[] {
  return parseCsv(path).map((row) => ({
    path: row.path,
    category: row.category,
    course_type_gas: numberCell(row, "course_type_gas", row.path),
    research_setup_gas: numberCell(row, "research_setup_gas", row.path),
    research_mutation_gas: numberCell(row, "research_mutation_gas", row.path),
    lesson_gas: numberCell(row, "lesson_gas", row.path),
    claim_gas: numberCell(row, "claim_gas", row.path),
    valid_lesson: booleanCell(row, "valid_lesson", row.path),
    revenue_weight_bps: numberCell(row, "revenue_weight_bps", row.path),
  }));
}

function parseFollowupCsv(path: string): FollowupGasRow[] {
  return parseCsv(path).map((row) => ({
    path: row.path,
    category: row.category,
    gas: numberCell(row, "gas", row.path),
    measurement_context: row.measurement_context,
  }));
}

function parseResearchCsv(path: string): ResearchGasRow[] {
  return parseCsv(path).map((row) => ({
    path: row.path,
    gas: numberCell(row, "gas", row.path),
  }));
}

function parseFeeAssumptions(path: string): FeeAssumptions {
  const assumptions = JSON.parse(readFileSync(path, "utf8")) as FeeAssumptions;
  if (
    !Number.isFinite(assumptions.referenceUsdPerGas)
    || assumptions.referenceUsdPerGas <= 0
  ) {
    throw new Error("Invalid referenceUsdPerGas in fee assumptions");
  }
  if (!assumptions.source || !assumptions.measurementWindow || !assumptions.unit) {
    throw new Error("Incomplete fee assumptions");
  }
  return assumptions;
}

function assertPositiveGas(value: number, label: string) {
  if (!Number.isFinite(value) || value <= 0) {
    throw new Error(`${label} must be positive gas`);
  }
}

function assertScenarioWeights() {
  for (const scenario of scenarios) {
    const weight = Object.values(scenario.ordinaryMix).reduce((sum, value) => sum + value, 0);
    if (Math.abs(weight - 1) > 1e-12) {
      throw new Error(`Scenario weights must sum to 1 for ${scenario.name}`);
    }
  }
}

function validateTeachingRows(rows: TeachingGasRow[]) {
  if (rows.length !== 20) {
    throw new Error(`Expected 20 teaching calibration rows, got ${rows.length}`);
  }
  const seen = new Set<string>();
  for (const row of rows) {
    if (seen.has(row.path)) throw new Error(`Duplicate teaching calibration path: ${row.path}`);
    seen.add(row.path);
    assertPositiveGas(row.course_type_gas, `${row.path}.course_type_gas`);
    assertPositiveGas(row.lesson_gas, `${row.path}.lesson_gas`);
    if (row.research_setup_gas < 0 || row.research_mutation_gas < 0 || row.claim_gas < 0) {
      throw new Error(`Negative gas field in ${row.path}`);
    }
    if (row.path.endsWith("_ML")) {
      assertPositiveGas(row.research_mutation_gas, `${row.path}.research_mutation_gas`);
    } else if (row.research_mutation_gas !== 0) {
      throw new Error(`Non-ML path must not carry research mutation gas: ${row.path}`);
    }
    if (row.revenue_weight_bps !== 10_000 && row.revenue_weight_bps !== 5_000) {
      throw new Error(`Unexpected revenue weight for ${row.path}`);
    }
  }
  for (const prefix of ["ORD", "FV", "CF", "TF"]) {
    for (const kind of ["NR", "ZS", "RB", "WM", "ML"]) {
      const path = `${prefix}_${kind}`;
      if (!seen.has(path)) throw new Error(`Missing teaching calibration path: ${path}`);
    }
  }
}

function validateFollowupRows(rows: FollowupGasRow[]) {
  if (rows.length !== 1) {
    throw new Error(`Expected exactly 1 teaching follow-up primitive, got ${rows.length}`);
  }
  const remedial = rows.find((row) => row.path === "TF_REMEDIAL_WAGE_CLOSE");
  if (!remedial) throw new Error("Missing TF_REMEDIAL_WAGE_CLOSE follow-up primitive");
  if (remedial.category !== "remedial_wage") {
    throw new Error("TF_REMEDIAL_WAGE_CLOSE category must be remedial_wage");
  }
  if (remedial.measurement_context !== expectedRemedialWageContext) {
    throw new Error(
      `TF_REMEDIAL_WAGE_CLOSE measurement_context must be ${expectedRemedialWageContext}`,
    );
  }
  assertPositiveGas(remedial.gas, "TF_REMEDIAL_WAGE_CLOSE.gas");
}

function weightedGas(
  gasByPath: Map<string, TeachingGasRow>,
  prefix: "ORD" | "FV" | "CF" | "TF",
  mix: Scenario["ordinaryMix"],
  metric:
    | "research_mutation_gas"
    | "lesson_gas"
    | "claim_gas"
    | "management_gas"
    | "coupled_gas",
): number {
  let total = 0;
  for (const [kind, weight] of Object.entries(mix)) {
    const row = gasByPath.get(`${prefix}_${kind}`);
    if (!row) throw new Error(`Missing gas row for ${prefix}_${kind}`);
    const managementGas = row.lesson_gas + row.claim_gas;
    const coupledGas = row.research_mutation_gas + managementGas;
    const gas =
      metric === "management_gas"
        ? managementGas
        : metric === "coupled_gas"
          ? coupledGas
          : row[metric];
    total += weight * gas;
  }
  return total;
}

function fmtMoney(value: number): string {
  return `$${value.toFixed(4)}`;
}

function fmtMoney2(value: number): string {
  return `$${value.toFixed(2)}`;
}

function fmtPct(value: number): string {
  return `${value.toFixed(3)}%`;
}

function fmtSharePct(value: number): string {
  return value < 0.01 ? `${value.toFixed(4)}%` : fmtPct(value);
}

function fmtGas(value: number): string {
  return Math.round(value).toLocaleString("en-US");
}

function sha256(path: string): string {
  return createHash("sha256").update(readFileSync(path)).digest("hex");
}

function commandOutput(command: string, args: string[]): string {
  const result = spawnSync(command, args, {
    cwd: root,
    encoding: "utf8",
  });
  if (result.status !== 0) return "unavailable";
  return result.stdout.trim();
}

function buildManifest(inputFiles: string[]) {
  const forgeVersion = commandOutput("forge", ["--version"]);
  const npmVersion = commandOutput("npm", ["--version"]);
  return {
    calibrationSchemaVersion,
    implementationRoot: ".",
    toolVersions: {
      node: process.version,
      npm: npmVersion,
      forge: forgeVersion,
    },
    solcVersion: "0.8.26",
    inputFiles: inputFiles.map((path) => ({
      path,
      sha256: sha256(join(root, path)),
    })),
    sourceFiles: sourceFilePaths.map((path) => ({
      path,
      sha256: sha256(join(root, path)),
    })),
  };
}

const gasRows = parseTeachingCsv(gasCsvPath);
const followupGasRows = parseFollowupCsv(followupGasCsvPath);
const researchGasRows = parseResearchCsv(researchGasCsvPath);
const gasByPath = new Map(gasRows.map((row) => [row.path, row]));
const researchGasByPath = new Map(researchGasRows.map((row) => [row.path, row.gas]));
const feeAssumptions = parseFeeAssumptions(feeAssumptionsPath);
const referenceUsdPerGas = feeAssumptions.referenceUsdPerGas;

assertScenarioWeights();
validateTeachingRows(gasRows);
validateFollowupRows(followupGasRows);

const simulationRows: string[] = [
  [
    "window",
    "coordinator_case",
    "fee_multiplier",
    "p_forced_valid",
    "p_customer_fault",
    "p_teacher_fault",
    "ordinary_expected_research_mutation_gas",
    "ordinary_expected_lesson_gas",
    "ordinary_expected_claim_gas",
    "forced_valid_expected_research_mutation_gas",
    "forced_valid_expected_lesson_gas",
    "forced_valid_expected_claim_gas",
    "customer_fault_expected_research_mutation_gas",
    "customer_fault_expected_lesson_gas",
    "customer_fault_expected_claim_gas",
    "teacher_fault_expected_research_mutation_gas",
    "teacher_fault_expected_lesson_gas",
    "teacher_fault_expected_claim_gas",
    "expected_research_mutation_gas_per_attempted_lesson",
    "expected_lesson_gas_per_attempted_lesson",
    "expected_claim_gas_per_attempted_lesson",
    "expected_management_gas_per_attempted_lesson",
    "expected_coupled_gas_per_attempted_lesson",
    "revenue_weight",
    "lesson_lifecycle_cost_per_attempted_lesson",
    "claim_cost_per_attempted_lesson",
    "claim_inclusive_cost_per_attempted_lesson",
    "coupled_cost_per_attempted_lesson",
    "cost_share_at_50",
    "cost_share_at_100",
    "cost_share_at_150",
    "coupled_cost_share_at_50",
    "coupled_cost_share_at_100",
    "coupled_cost_share_at_150",
  ].join(","),
];

const summaries: SummaryRow[] = [];

for (const scenario of scenarios) {
  const ordinaryResearchMutationGas = weightedGas(
    gasByPath,
    "ORD",
    scenario.ordinaryMix,
    "research_mutation_gas",
  );
  const forcedValidResearchMutationGas = weightedGas(
    gasByPath,
    "FV",
    scenario.ordinaryMix,
    "research_mutation_gas",
  );
  const customerFaultResearchMutationGas = weightedGas(
    gasByPath,
    "CF",
    scenario.ordinaryMix,
    "research_mutation_gas",
  );
  const teacherFaultResearchMutationGas = weightedGas(
    gasByPath,
    "TF",
    scenario.ordinaryMix,
    "research_mutation_gas",
  );
  const ordinaryLessonGas = weightedGas(gasByPath, "ORD", scenario.ordinaryMix, "lesson_gas");
  const forcedValidLessonGas = weightedGas(gasByPath, "FV", scenario.ordinaryMix, "lesson_gas");
  const customerFaultLessonGas = weightedGas(gasByPath, "CF", scenario.ordinaryMix, "lesson_gas");
  const teacherFaultLessonGas = weightedGas(gasByPath, "TF", scenario.ordinaryMix, "lesson_gas");
  const ordinaryClaimGas = weightedGas(gasByPath, "ORD", scenario.ordinaryMix, "claim_gas");
  const forcedValidClaimGas = weightedGas(gasByPath, "FV", scenario.ordinaryMix, "claim_gas");
  const customerFaultClaimGas = weightedGas(gasByPath, "CF", scenario.ordinaryMix, "claim_gas");
  const teacherFaultClaimGas = weightedGas(gasByPath, "TF", scenario.ordinaryMix, "claim_gas");

  for (const coordinatorCase of coordinatorCases) {
    const ordinaryShare = 1 - coordinatorCase.pFV - coordinatorCase.pCF - coordinatorCase.pTF;
    if (ordinaryShare < 0) {
      throw new Error(`Invalid coordinator probabilities for ${coordinatorCase.name}`);
    }
    const expectedResearchMutationGas =
      ordinaryShare * ordinaryResearchMutationGas
      + coordinatorCase.pFV * forcedValidResearchMutationGas
      + coordinatorCase.pCF * customerFaultResearchMutationGas
      + coordinatorCase.pTF * teacherFaultResearchMutationGas;
    const expectedLessonGas =
      ordinaryShare * ordinaryLessonGas
      + coordinatorCase.pFV * forcedValidLessonGas
      + coordinatorCase.pCF * customerFaultLessonGas
      + coordinatorCase.pTF * teacherFaultLessonGas;
    const expectedClaimGas =
      ordinaryShare * ordinaryClaimGas
      + coordinatorCase.pFV * forcedValidClaimGas
      + coordinatorCase.pCF * customerFaultClaimGas
      + coordinatorCase.pTF * teacherFaultClaimGas;
    const expectedManagementGas = expectedLessonGas + expectedClaimGas;
    const expectedCoupledGas = expectedResearchMutationGas + expectedManagementGas;
    const revenueWeight = 1 - 0.5 * (coordinatorCase.pCF + coordinatorCase.pTF);

    for (const feeMultiplier of feeMultipliers) {
      const lessonLifecycleCostPerAttemptedLesson =
        expectedLessonGas * referenceUsdPerGas * feeMultiplier;
      const claimCostPerAttemptedLesson =
        expectedClaimGas * referenceUsdPerGas * feeMultiplier;
      const costPerAttemptedLesson =
        expectedManagementGas * referenceUsdPerGas * feeMultiplier;
      const coupledCostPerAttemptedLesson =
        expectedCoupledGas * referenceUsdPerGas * feeMultiplier;
      const shares = revenues.map(
        (revenue) => (100 * costPerAttemptedLesson) / (revenue * revenueWeight),
      );
      const coupledShares = revenues.map(
        (revenue) => (100 * coupledCostPerAttemptedLesson) / (revenue * revenueWeight),
      );

      summaries.push({
        window: scenario.name,
        coordinatorCase: coordinatorCase.name,
        feeMultiplier,
        pFV: coordinatorCase.pFV,
        pCF: coordinatorCase.pCF,
        pTF: coordinatorCase.pTF,
        ordinaryResearchMutationGas,
        ordinaryLessonGas,
        ordinaryClaimGas,
        forcedValidResearchMutationGas,
        forcedValidLessonGas,
        forcedValidClaimGas,
        customerFaultResearchMutationGas,
        customerFaultLessonGas,
        customerFaultClaimGas,
        teacherFaultResearchMutationGas,
        teacherFaultLessonGas,
        teacherFaultClaimGas,
        expectedResearchMutationGas,
        expectedLessonGas,
        expectedClaimGas,
        expectedManagementGas,
        expectedCoupledGas,
        revenueWeight,
        lessonLifecycleCostPerAttemptedLesson,
        claimCostPerAttemptedLesson,
        costPerAttemptedLesson,
        coupledCostPerAttemptedLesson,
        shares,
        coupledShares,
      });

      simulationRows.push(
        [
          scenario.name,
          coordinatorCase.name,
          feeMultiplier,
          coordinatorCase.pFV,
          coordinatorCase.pCF,
          coordinatorCase.pTF,
          Math.round(ordinaryResearchMutationGas),
          Math.round(ordinaryLessonGas),
          Math.round(ordinaryClaimGas),
          Math.round(forcedValidResearchMutationGas),
          Math.round(forcedValidLessonGas),
          Math.round(forcedValidClaimGas),
          Math.round(customerFaultResearchMutationGas),
          Math.round(customerFaultLessonGas),
          Math.round(customerFaultClaimGas),
          Math.round(teacherFaultResearchMutationGas),
          Math.round(teacherFaultLessonGas),
          Math.round(teacherFaultClaimGas),
          Math.round(expectedResearchMutationGas),
          Math.round(expectedLessonGas),
          Math.round(expectedClaimGas),
          Math.round(expectedManagementGas),
          Math.round(expectedCoupledGas),
          revenueWeight.toFixed(3),
          lessonLifecycleCostPerAttemptedLesson.toFixed(8),
          claimCostPerAttemptedLesson.toFixed(8),
          costPerAttemptedLesson.toFixed(8),
          coupledCostPerAttemptedLesson.toFixed(8),
          shares[0].toFixed(6),
          shares[1].toFixed(6),
          shares[2].toFixed(6),
          coupledShares[0].toFixed(6),
          coupledShares[1].toFixed(6),
          coupledShares[2].toFixed(6),
        ].join(","),
      );
    }
  }
}

const pathTable = [
  "| Path | Category | Course type gas | Research setup gas | Research mutation gas | Lesson lifecycle gas | Distributor claim gas | Management gas | Coupled gas | Full fixture gas | Revenue weight |",
  "|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---|",
  ...gasRows.map((row) => {
    const managementGas = row.lesson_gas + row.claim_gas;
    const coupledGas = row.research_mutation_gas + managementGas;
    const fullFixtureGas = row.course_type_gas + row.research_setup_gas + coupledGas;
    return [
      row.path,
      row.category,
      fmtGas(row.course_type_gas),
      fmtGas(row.research_setup_gas),
      fmtGas(row.research_mutation_gas),
      fmtGas(row.lesson_gas),
      fmtGas(row.claim_gas),
      fmtGas(managementGas),
      fmtGas(coupledGas),
      fmtGas(fullFixtureGas),
      fmtPct(row.revenue_weight_bps / 100),
    ].join(" | ");
  }).map((line) => `| ${line} |`),
];

const followupTable = [
  "| Follow-up path | Category | Gas | Measurement context | Included in scenario expectation |",
  "|---|---|---:|---|---|",
  ...followupGasRows.map((row) =>
    [
      row.path,
      row.category,
      fmtGas(row.gas),
      row.measurement_context,
      row.path === "TF_REMEDIAL_WAGE_CLOSE" ? "no" : "unknown",
    ].join(" | "),
  ).map((line) => `| ${line} |`),
];

const k1Rows = summaries.filter((row) => row.feeMultiplier === 1);
const scenarioTable = [
  "| Window | Coordinator case | p(FV) | p(CF) | p(TF) | Research mutation gas | Lesson gas | Claim gas | Management gas | Coupled gas | Revenue weight | Management cost / attempted lesson | Coupled cost / attempted lesson | Claim gas share | Share at $50 | Share at $100 | Share at $150 |",
  "|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|",
  ...k1Rows.map((row) =>
    [
      row.window,
      row.coordinatorCase,
      fmtPct(100 * row.pFV),
      fmtPct(100 * row.pCF),
      fmtPct(100 * row.pTF),
      fmtGas(row.expectedResearchMutationGas),
      fmtGas(row.expectedLessonGas),
      fmtGas(row.expectedClaimGas),
      fmtGas(row.expectedManagementGas),
      fmtGas(row.expectedCoupledGas),
      fmtPct(100 * row.revenueWeight),
      fmtMoney(row.costPerAttemptedLesson),
      fmtMoney(row.coupledCostPerAttemptedLesson),
      fmtPct((100 * row.expectedClaimGas) / row.expectedManagementGas),
      fmtPct(row.shares[0]),
      fmtPct(row.shares[1]),
      fmtPct(row.shares[2]),
    ].join(" | "),
  ).map((line) => `| ${line} |`),
];

function getNoCoordinatorSummary(window: string): SummaryRow {
  const row = summaries.find(
    (item) =>
      item.window === window
      && item.coordinatorCase === "No coordinator"
      && item.feeMultiplier === 1,
  );
  if (!row) throw new Error(`Missing no-coordinator summary for ${window}`);
  return row;
}

type ChapterScaleRow = {
  window: string;
  teachers: number;
  students: number;
  mainResearchNfts?: number;
  bottleneck: string;
};

const monthlyTeacherLoad = 30;
const monthlyStudentDemand = 6;
const chapterScaleRows: ChapterScaleRow[] = [
  { window: "Demand-first", teachers: 100, students: 480, bottleneck: "demand side" },
  { window: "Demand-first", teachers: 110, students: 545, bottleneck: "demand side" },
  {
    window: "Demand-first",
    teachers: 125,
    students: 620,
    bottleneck: "demand side, near-balanced",
  },
  {
    window: "Supply-first",
    teachers: 100,
    students: 500,
    mainResearchNfts: 50,
    bottleneck: "balanced",
  },
  {
    window: "Supply-first",
    teachers: 120,
    students: 540,
    mainResearchNfts: 80,
    bottleneck: "student side",
  },
  {
    window: "Supply-first",
    teachers: 145,
    students: 600,
    mainResearchNfts: 120,
    bottleneck: "student side",
  },
  {
    window: "Synchronised",
    teachers: 100,
    students: 500,
    mainResearchNfts: 45,
    bottleneck: "balanced",
  },
  {
    window: "Synchronised",
    teachers: 120,
    students: 600,
    mainResearchNfts: 52,
    bottleneck: "balanced",
  },
  {
    window: "Synchronised",
    teachers: 150,
    students: 750,
    mainResearchNfts: 62,
    bottleneck: "balanced",
  },
];

type ChapterScaleSummary = ChapterScaleRow & {
  realisedLessons: number;
  costPerLesson: number;
  monthlyCost: number;
};

const chapterScaleSummaries: ChapterScaleSummary[] = chapterScaleRows.map((row) => {
  const scenarioSummary = getNoCoordinatorSummary(row.window);
  const realisedLessons = Math.min(
    monthlyTeacherLoad * row.teachers,
    monthlyStudentDemand * row.students,
  );
  return {
    ...row,
    realisedLessons,
    costPerLesson: scenarioSummary.costPerAttemptedLesson,
    monthlyCost: realisedLessons * scenarioSummary.costPerAttemptedLesson,
  };
});

function makeScaleTable(window: string, includeMainResearchNfts: boolean): string[] {
  const rows = chapterScaleSummaries.filter((row) => row.window === window);
  const header = includeMainResearchNfts
    ? "| Teachers | Active students | Main research NFTs | Realised lessons / month | Throughput bottleneck | Estimated management cost / month |"
    : "| Teachers | Active students | Realised lessons / month | Throughput bottleneck | Estimated management cost / month |";
  const divider = includeMainResearchNfts
    ? "|---:|---:|---:|---:|---|---:|"
    : "|---:|---:|---:|---|---:|";
  return [
    header,
    divider,
    ...rows.map((row) => {
      const cells = includeMainResearchNfts
        ? [
            row.teachers,
            row.students,
            row.mainResearchNfts ?? "",
            row.realisedLessons,
            row.bottleneck,
            fmtMoney2(row.monthlyCost),
          ]
        : [
            row.teachers,
            row.students,
            row.realisedLessons,
            row.bottleneck,
            fmtMoney2(row.monthlyCost),
          ];
      return `| ${cells.join(" | ")} |`;
    }),
  ];
}

function researchGas(path: string): number {
  const gas = researchGasByPath.get(path);
  if (gas === undefined) throw new Error(`Missing research gas row for ${path}`);
  return gas;
}

const researchAssetBootstrapGas =
  researchGas("createResearchAsset") + researchGas("createPatchPosition_current");
const teachingReadyResearchAssetGas =
  researchAssetBootstrapGas + researchGas("sealLayer_current");
const updateGas =
  researchGas("sealLayer_current")
  + researchGas("createPatchPosition_prepared")
  + researchGas("sealLayer_prepared")
  + researchGas("approveEarlyDecay")
  + researchGas("advanceLayer");
const extraPreparedPositionGas = researchGas("createPatchPosition_prepared");
const researchGasPrimitives = {
  researchAssetBootstrapGas,
  teachingReadyResearchAssetGas,
  periodicUpdateBundleGas: updateGas,
  extraPreparedPositionGas,
};
const synchronisedBaseMonthlyCostRow = chapterScaleSummaries.find(
  (row) => row.window === "Synchronised" && row.teachers === 120 && row.students === 600,
);
if (!synchronisedBaseMonthlyCostRow) throw new Error("Missing synchronised base row");
const synchronisedBaseMonthlyCost = synchronisedBaseMonthlyCostRow.monthlyCost;

type ResearchMaintenanceSummary = {
  teachers: number;
  students: number;
  existingMainResearchNfts: number;
  newMainResearchNfts: string;
  updateCadence: string;
  extraStructure: string;
  monthlyMaintenanceCost: number;
  fixedMixCost: number;
  uplift: number;
};

function researchMaintenanceSummary(params: {
  existingMainResearchNfts: number;
  cadenceMonths: number;
  newMainResearchNftsPerCycle: number;
  extraPreparedPositionsPerCycle: number;
  newMainResearchNftsLabel: string;
  updateCadence: string;
  extraStructure: string;
}): ResearchMaintenanceSummary {
  const monthlyMaintenanceGas =
    (params.existingMainResearchNfts * updateGas
      + params.newMainResearchNftsPerCycle * teachingReadyResearchAssetGas
      + params.extraPreparedPositionsPerCycle * extraPreparedPositionGas)
    / params.cadenceMonths;
  const monthlyMaintenanceCost = monthlyMaintenanceGas * referenceUsdPerGas;
  return {
    teachers: 120,
    students: 600,
    existingMainResearchNfts: params.existingMainResearchNfts,
    newMainResearchNfts: params.newMainResearchNftsLabel,
    updateCadence: params.updateCadence,
    extraStructure: params.extraStructure,
    monthlyMaintenanceCost,
    fixedMixCost: synchronisedBaseMonthlyCost + monthlyMaintenanceCost,
    uplift: (100 * monthlyMaintenanceCost) / synchronisedBaseMonthlyCost,
  };
}

const researchMaintenanceSummaries: ResearchMaintenanceSummary[] = [
  researchMaintenanceSummary({
    existingMainResearchNfts: 60,
    cadenceMonths: 12,
    newMainResearchNftsPerCycle: 0,
    extraPreparedPositionsPerCycle: 0,
    newMainResearchNftsLabel: "0",
    updateCadence: "annual",
    extraStructure: "none",
  }),
  researchMaintenanceSummary({
    existingMainResearchNfts: 60,
    cadenceMonths: 6,
    newMainResearchNftsPerCycle: 0,
    extraPreparedPositionsPerCycle: 0,
    newMainResearchNftsLabel: "0",
    updateCadence: "semiannual",
    extraStructure: "none",
  }),
  researchMaintenanceSummary({
    existingMainResearchNfts: 60,
    cadenceMonths: 6,
    newMainResearchNftsPerCycle: 0,
    extraPreparedPositionsPerCycle: 20,
    newMainResearchNftsLabel: "0",
    updateCadence: "semiannual",
    extraStructure: "+20 extra prepared positions across the catalogue per cycle",
  }),
  researchMaintenanceSummary({
    existingMainResearchNfts: 60,
    cadenceMonths: 6,
    newMainResearchNftsPerCycle: 6,
    extraPreparedPositionsPerCycle: 0,
    newMainResearchNftsLabel: "6 per 6 months",
    updateCadence: "semiannual",
    extraStructure: "none",
  }),
];

const researchMaintenanceTable = [
  "| Teachers | Active students | Existing main research NFTs | New main research NFTs | Update cadence | Extra structure per update | Estimated research-maintenance cost / month | Estimated fixed-mix cost / month | Uplift vs fixed-mix lesson cost |",
  "|---:|---:|---:|---:|---|---|---:|---:|---:|",
  ...researchMaintenanceSummaries.map((row) =>
    [
      row.teachers,
      row.students,
      row.existingMainResearchNfts,
      row.newMainResearchNfts,
      row.updateCadence,
      row.extraStructure,
      fmtMoney2(row.monthlyMaintenanceCost),
      fmtMoney2(row.fixedMixCost),
      fmtPct(row.uplift),
    ].join(" | "),
  ).map((line) => `| ${line} |`),
];

const ordinaryNoCoordinatorRows = summaries.filter(
  (row) => row.coordinatorCase === "No coordinator" && row.feeMultiplier === 1,
);
const ordinaryMinLessonCost = Math.min(
  ...ordinaryNoCoordinatorRows.map((row) => row.lessonLifecycleCostPerAttemptedLesson),
);
const ordinaryMaxLessonCost = Math.max(
  ...ordinaryNoCoordinatorRows.map((row) => row.lessonLifecycleCostPerAttemptedLesson),
);
const ordinaryMinClaimCost = Math.min(
  ...ordinaryNoCoordinatorRows.map((row) => row.claimCostPerAttemptedLesson),
);
const ordinaryMaxClaimCost = Math.max(
  ...ordinaryNoCoordinatorRows.map((row) => row.claimCostPerAttemptedLesson),
);
const ordinaryMinCost = Math.min(
  ...ordinaryNoCoordinatorRows.map((row) => row.costPerAttemptedLesson),
);
const ordinaryMaxCost = Math.max(
  ...ordinaryNoCoordinatorRows.map((row) => row.costPerAttemptedLesson),
);
const costShareTable = [
  "| Revenue / lesson | Lesson lifecycle cost / lesson | Distributor claim cost / lesson | Management cost / lesson | Management cost share of revenue |",
  "|---:|---:|---:|---:|---:|",
  ...revenues.map((revenue) =>
    `| $${revenue} | ${fmtMoney(ordinaryMinLessonCost)}-${fmtMoney(ordinaryMaxLessonCost)} | ${
      fmtMoney(ordinaryMinClaimCost)
    }-${fmtMoney(ordinaryMaxClaimCost)} | ${fmtMoney(ordinaryMinCost)}-${fmtMoney(ordinaryMaxCost)} | ${
      fmtSharePct((100 * ordinaryMinCost) / revenue)
    }-${fmtSharePct((100 * ordinaryMaxCost) / revenue)} |`,
  ),
];

const inputFiles = [
  "teaching_gas_calibration.csv",
  "teaching_followup_gas_calibration.csv",
  "research_gas_calibration.csv",
  "simulation_inputs/fee_assumptions.json",
];
const manifest = buildManifest(inputFiles);

const markdown = `# Teaching Cost Simulation

Generated from Teaching lifecycle calibration CSVs and \`research_gas_calibration.csv\`.

Reference translation coefficient:

\`\`\`text
referenceUsdPerGas = ${referenceUsdPerGas}
source = ${feeAssumptions.source}
measurementWindow = ${feeAssumptions.measurementWindow}
unit = ${feeAssumptions.unit}
\`\`\`

Generated from Teaching lifecycle calibration. Management gas is \`lesson_gas + claim_gas\`.

## Measured Contract Paths

${pathTable.join("\n")}

## Measured Follow-Up Primitives

${followupTable.join("\n")}

## Coordinator-Extended Scenario Simulation

Values use the reference fee coefficient at \`1x\`.

${scenarioTable.join("\n")}

## Chapter Scale Tables

### Demand-first expansion

${makeScaleTable("Demand-first", false).join("\n")}

### Supply-first product expansion

${makeScaleTable("Supply-first", true).join("\n")}

### Synchronised expansion

${makeScaleTable("Synchronised", true).join("\n")}

### Research maintenance

New main research NFTs use the teaching-ready research asset primitive.

Research gas source:

| Component | Gas |
|---|---:|
| Research asset bootstrap | ${fmtGas(researchAssetBootstrapGas)} |
| Teaching-ready research asset | ${fmtGas(teachingReadyResearchAssetGas)} |
| Periodic update bundle | ${fmtGas(updateGas)} |
| Extra prepared position | ${fmtGas(extraPreparedPositionGas)} |

${researchMaintenanceTable.join("\n")}

### Cost share under lesson pricing

${costShareTable.join("\n")}
`;

mkdirSync(outDir, { recursive: true });
writeFileSync(join(outDir, "teaching_cost_simulation.csv"), simulationRows.join("\n"));
writeFileSync(
  join(outDir, "teaching_cost_simulation.json"),
  JSON.stringify(
    {
      calibrationSchemaVersion,
      gasRows,
      followupGasRows,
      researchGasRows,
      feeAssumptions,
      researchGasPrimitives,
      summaries,
      chapterScaleSummaries,
      researchMaintenanceSummaries,
      ordinaryLessonCostRange: {
        min: ordinaryMinLessonCost,
        max: ordinaryMaxLessonCost,
      },
      ordinaryClaimCostRange: {
        min: ordinaryMinClaimCost,
        max: ordinaryMaxClaimCost,
      },
      ordinaryManagementCostRange: {
        min: ordinaryMinCost,
        max: ordinaryMaxCost,
      },
    },
    null,
    2,
  ),
);
writeFileSync(join(outDir, "calibration_manifest.json"), JSON.stringify(manifest, null, 2));
writeFileSync(join(outDir, "teaching_cost_simulation.md"), markdown);

console.log(`Wrote ${join(outDir, "teaching_cost_simulation.csv")}`);
console.log(`Wrote ${join(outDir, "teaching_cost_simulation.json")}`);
console.log(`Wrote ${join(outDir, "calibration_manifest.json")}`);
console.log(`Wrote ${join(outDir, "teaching_cost_simulation.md")}`);
