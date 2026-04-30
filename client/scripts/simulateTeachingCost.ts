import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

type GasRow = {
  path: string;
  category: string;
  total_gas: number;
  setup_gas: number;
  lesson_gas: number;
  valid_lesson: boolean;
  revenue_weight_bps: number;
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

const root = process.cwd();
const gasCsvPath = join(root, "teaching_gas_calibration.csv");
const researchGasCsvPath = join(root, "research_gas_calibration.csv");
const outDir = join(root, "simulation_outputs");

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

// Same reference translation used in the manuscript's no-research anchor.
const referenceNoResearchUsd = 0.0133;
const referenceNoResearchGas = 889_005;
const referenceUsdPerGas = referenceNoResearchUsd / referenceNoResearchGas;

function parseCsv(path: string): GasRow[] {
  const [headerLine, ...lines] = readFileSync(path, "utf8").trim().split(/\r?\n/);
  const headers = headerLine.split(",");
  return lines.map((line) => {
    const cells = line.split(",");
    const row = Object.fromEntries(headers.map((header, index) => [header, cells[index]]));
    return {
      path: row.path,
      category: row.category,
      total_gas: Number(row.total_gas),
      setup_gas: Number(row.setup_gas),
      lesson_gas: Number(row.lesson_gas),
      valid_lesson: row.valid_lesson === "true",
      revenue_weight_bps: Number(row.revenue_weight_bps),
    };
  });
}

function parseResearchCsv(path: string): ResearchGasRow[] {
  const [headerLine, ...lines] = readFileSync(path, "utf8").trim().split(/\r?\n/);
  const headers = headerLine.split(",");
  return lines.map((line) => {
    const cells = line.split(",");
    const row = Object.fromEntries(headers.map((header, index) => [header, cells[index]]));
    return {
      path: row.path,
      gas: Number(row.gas),
    };
  });
}

function weightedGas(
  gasByPath: Map<string, GasRow>,
  prefix: "ORD" | "FV" | "CF" | "TF",
  mix: Scenario["ordinaryMix"],
): number {
  let total = 0;
  for (const [kind, weight] of Object.entries(mix)) {
    const row = gasByPath.get(`${prefix}_${kind}`);
    if (!row) throw new Error(`Missing gas row for ${prefix}_${kind}`);
    total += weight * row.lesson_gas;
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

const gasRows = parseCsv(gasCsvPath);
const gasByPath = new Map(gasRows.map((row) => [row.path, row]));
const researchGasRows = parseResearchCsv(researchGasCsvPath);
const researchGasByPath = new Map(researchGasRows.map((row) => [row.path, row.gas]));

const simulationRows: string[] = [
  [
    "window",
    "coordinator_case",
    "fee_multiplier",
    "p_forced_valid",
    "p_customer_fault",
    "p_teacher_fault",
    "ordinary_expected_lesson_gas",
    "forced_valid_expected_lesson_gas",
    "customer_fault_expected_lesson_gas",
    "teacher_fault_expected_lesson_gas",
    "expected_gas_per_attempted_lesson",
    "revenue_weight",
    "cost_per_attempted_lesson",
    "cost_share_at_50",
    "cost_share_at_100",
    "cost_share_at_150",
  ].join(","),
];

type SummaryRow = {
  window: string;
  coordinatorCase: string;
  feeMultiplier: number;
  pFV: number;
  pCF: number;
  pTF: number;
  ordinaryGas: number;
  forcedValidGas: number;
  customerFaultGas: number;
  teacherFaultGas: number;
  expectedGas: number;
  revenueWeight: number;
  costPerAttemptedLesson: number;
  shares: number[];
};

const summaries: SummaryRow[] = [];

for (const scenario of scenarios) {
  const ordinaryGas = weightedGas(gasByPath, "ORD", scenario.ordinaryMix);
  const forcedValidGas = weightedGas(gasByPath, "FV", scenario.ordinaryMix);
  const customerFaultGas = weightedGas(gasByPath, "CF", scenario.ordinaryMix);
  const teacherFaultGas = weightedGas(gasByPath, "TF", scenario.ordinaryMix);

  for (const coordinatorCase of coordinatorCases) {
    if (coordinatorCase.pFV + coordinatorCase.pCF + coordinatorCase.pTF >= 1) {
      throw new Error(`Invalid coordinator probabilities for ${coordinatorCase.name}`);
    }
    const expectedGas =
      (1 - coordinatorCase.pFV - coordinatorCase.pCF - coordinatorCase.pTF) * ordinaryGas
      + coordinatorCase.pFV * forcedValidGas
      + coordinatorCase.pCF * customerFaultGas
      + coordinatorCase.pTF * teacherFaultGas;
    const revenueWeight = 1 - 0.5 * (coordinatorCase.pCF + coordinatorCase.pTF);

    for (const feeMultiplier of feeMultipliers) {
      const costPerAttemptedLesson = expectedGas * referenceUsdPerGas * feeMultiplier;
      const shares = revenues.map(
        (revenue) => (100 * costPerAttemptedLesson) / (revenue * revenueWeight),
      );

      summaries.push({
        window: scenario.name,
        coordinatorCase: coordinatorCase.name,
        feeMultiplier,
        pFV: coordinatorCase.pFV,
        pCF: coordinatorCase.pCF,
        pTF: coordinatorCase.pTF,
        ordinaryGas,
        forcedValidGas,
        customerFaultGas,
        teacherFaultGas,
        expectedGas,
        revenueWeight,
        costPerAttemptedLesson,
        shares,
      });

      simulationRows.push(
        [
          scenario.name,
          coordinatorCase.name,
          feeMultiplier,
          coordinatorCase.pFV,
          coordinatorCase.pCF,
          coordinatorCase.pTF,
          Math.round(ordinaryGas),
          Math.round(forcedValidGas),
          Math.round(customerFaultGas),
          Math.round(teacherFaultGas),
          Math.round(expectedGas),
          revenueWeight.toFixed(3),
          costPerAttemptedLesson.toFixed(8),
          shares[0].toFixed(6),
          shares[1].toFixed(6),
          shares[2].toFixed(6),
        ].join(","),
      );
    }
  }
}

const pathTable = [
  "| Path | Category | Setup gas | Lesson gas | Total gas | Revenue weight |",
  "|---|---|---:|---:|---:|---|",
  ...gasRows.map((row) =>
    [
      row.path,
      row.category,
      fmtGas(row.setup_gas),
      fmtGas(row.lesson_gas),
      fmtGas(row.total_gas),
      fmtPct(row.revenue_weight_bps / 100),
    ].join(" | "),
  ).map((line) => `| ${line} |`),
];

const k1Rows = summaries.filter((row) => row.feeMultiplier === 1);
const scenarioTable = [
  "| Window | Coordinator case | p(FV) | p(CF) | p(TF) | Expected gas / attempted lesson | Revenue weight | Cost / attempted lesson | Share at $50 | Share at $100 | Share at $150 |",
  "|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|",
  ...k1Rows.map((row) =>
    [
      row.window,
      row.coordinatorCase,
      fmtPct(100 * row.pFV),
      fmtPct(100 * row.pCF),
      fmtPct(100 * row.pTF),
      fmtGas(row.expectedGas),
      fmtPct(100 * row.revenueWeight),
      fmtMoney(row.costPerAttemptedLesson),
      fmtPct(row.shares[0]),
      fmtPct(row.shares[1]),
      fmtPct(row.shares[2]),
    ].join(" | "),
  ).map((line) => `| ${line} |`),
];

const stressRows = summaries.filter(
  (row) => row.coordinatorCase === "Coordinator stress" && [1, 10].includes(row.feeMultiplier),
);
const stressTable = [
  "| Window | Fee multiplier | Expected gas / attempted lesson | Cost / attempted lesson | Share at $50 | Share at $100 | Share at $150 |",
  "|---|---:|---:|---:|---:|---:|---:|",
  ...stressRows.map((row) =>
    [
      row.window,
      `${row.feeMultiplier}x`,
      fmtGas(row.expectedGas),
      fmtMoney(row.costPerAttemptedLesson),
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
    ? "| Teachers | Active students | Main research NFTs | Realised lessons / month | Throughput bottleneck | Estimated lesson-driven cost / month |"
    : "| Teachers | Active students | Realised lessons / month | Throughput bottleneck | Estimated lesson-driven cost / month |";
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

const newMainGas = researchGas("createResearchAsset") + researchGas("createPatchPosition_current");
const updateGas =
  researchGas("sealLayer_current")
  + researchGas("createPatchPosition_prepared")
  + researchGas("sealLayer_prepared")
  + researchGas("approveEarlyDecay")
  + researchGas("advanceLayer");
const extraPreparedPositionGas = researchGas("createPatchPosition_prepared");
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
  monthlyMaintenanceCostLow: number;
  monthlyMaintenanceCostHigh: number;
  fixedMixCostLow: number;
  fixedMixCostHigh: number;
  upliftLow: number;
  upliftHigh: number;
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
      + params.newMainResearchNftsPerCycle * newMainGas
      + params.extraPreparedPositionsPerCycle * extraPreparedPositionGas)
    / params.cadenceMonths;
  const monthlyMaintenanceCost = monthlyMaintenanceGas * referenceUsdPerGas;
  const baseCost = synchronisedBaseMonthlyCost;
  return {
    teachers: 120,
    students: 600,
    existingMainResearchNfts: params.existingMainResearchNfts,
    newMainResearchNfts: params.newMainResearchNftsLabel,
    updateCadence: params.updateCadence,
    extraStructure: params.extraStructure,
    monthlyMaintenanceCostLow: monthlyMaintenanceCost,
    monthlyMaintenanceCostHigh: monthlyMaintenanceCost,
    fixedMixCostLow: baseCost + monthlyMaintenanceCost,
    fixedMixCostHigh: baseCost + monthlyMaintenanceCost,
    upliftLow: (100 * monthlyMaintenanceCost) / baseCost,
    upliftHigh: (100 * monthlyMaintenanceCost) / baseCost,
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
  "| Teachers | Active students | Existing main research NFTs | New main research NFTs | Update cadence | Extra structure per update | Estimated research-maintenance cost / month | Estimated fixed-mix cost / month | Uplift vs fixed-mix lesson baseline |",
  "|---:|---:|---:|---:|---|---|---:|---:|---:|",
  ...researchMaintenanceSummaries.map((row) =>
    [
      row.teachers,
      row.students,
      row.existingMainResearchNfts,
      row.newMainResearchNfts,
      row.updateCadence,
      row.extraStructure,
      fmtMoney2(row.monthlyMaintenanceCostLow),
      fmtMoney2(row.fixedMixCostLow),
      fmtPct(row.upliftLow),
    ].join(" | "),
  ).map((line) => `| ${line} |`),
];

const ordinaryNoCoordinatorRows = summaries.filter(
  (row) => row.coordinatorCase === "No coordinator" && row.feeMultiplier === 1,
);
const ordinaryMinCost = Math.min(...ordinaryNoCoordinatorRows.map((row) => row.costPerAttemptedLesson));
const ordinaryMaxCost = Math.max(...ordinaryNoCoordinatorRows.map((row) => row.costPerAttemptedLesson));
const costShareTable = [
  "| Revenue / lesson | Window-specific on-chain cost / lesson | Lesson-driven cost share of revenue |",
  "|---:|---:|---:|",
  ...revenues.map((revenue) =>
    `| $${revenue} | ${fmtMoney(ordinaryMinCost)}-${fmtMoney(ordinaryMaxCost)} | ${
      fmtSharePct((100 * ordinaryMinCost) / revenue)
    }-${fmtSharePct((100 * ordinaryMaxCost) / revenue)} |`,
  ),
];

const markdown = `# Teaching Cost Simulation

Generated from \`teaching_gas_calibration.csv\`.

Reference translation coefficient:

\`\`\`text
referenceUsdPerGas = ${referenceUsdPerGas}
source = ${referenceNoResearchUsd} / ${referenceNoResearchGas}
\`\`\`

The simulation uses \`lesson_gas\` for lesson-driven cost. \`setup_gas\` is reported separately because research setup and catalogue maintenance are low-frequency components in the model. Research maintenance rows are generated from \`research_gas_calibration.csv\`.

## Measured Contract Paths

${pathTable.join("\n")}

## Coordinator-Extended Scenario Simulation

These values use the reference fee coefficient at \`1x\`. Customer-fault and teacher-fault resolutions carry half-price revenue, so the denominator uses \`revenueWeight = 1 - 0.5 * (p(CF) + p(TF))\`.

${scenarioTable.join("\n")}

## Coordinator Stress With Fee Multiplier

${stressTable.join("\n")}

## Chapter Scale Tables

### Demand-first expansion

${makeScaleTable("Demand-first", false).join("\n")}

### Supply-first product expansion

${makeScaleTable("Supply-first", true).join("\n")}

### Synchronised expansion

${makeScaleTable("Synchronised", true).join("\n")}

### Research maintenance

Research gas source:

| Component | Gas |
|---|---:|
| New main research NFT bootstrap | ${fmtGas(newMainGas)} |
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
      gasRows,
      researchGasRows,
      summaries,
      chapterScaleSummaries,
      researchMaintenanceSummaries,
      ordinaryCostRange: {
        min: ordinaryMinCost,
        max: ordinaryMaxCost,
      },
    },
    null,
    2,
  ),
);
writeFileSync(join(outDir, "teaching_cost_simulation.md"), markdown);

console.log(`Wrote ${join(outDir, "teaching_cost_simulation.csv")}`);
console.log(`Wrote ${join(outDir, "teaching_cost_simulation.json")}`);
console.log(`Wrote ${join(outDir, "teaching_cost_simulation.md")}`);
