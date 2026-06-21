import { spawnSync } from "node:child_process";

type Command = {
  label: string;
  command: string;
  args: string[];
};

const commands: Command[] = [
  {
    label: "Write teaching gas CSV",
    command: "forge",
    args: [
      "test",
      "--match-contract",
      "TeachingGasCalibrationTest",
      "--match-test",
      "testWriteTeachingGasCalibrationCsv",
      "-vv",
    ],
  },
  {
    label: "Write teaching follow-up gas CSV",
    command: "forge",
    args: [
      "test",
      "--match-contract",
      "TeachingGasCalibrationTest",
      "--match-test",
      "testWriteTeachingFollowupGasCalibrationCsv",
      "-vv",
    ],
  },
  {
    label: "Write research gas CSV",
    command: "forge",
    args: ["test", "--match-contract", "ResearchGasCalibrationTest", "-vv"],
  },
  {
    label: "Typecheck client scripts",
    command: "npm",
    args: ["run", "client:typecheck"],
  },
  {
    label: "Check reproducibility config",
    command: "npm",
    args: ["run", "check:reproducibility-config"],
  },
  {
    label: "Regenerate teaching cost simulation",
    command: "npm",
    args: ["run", "simulate:teaching-cost"],
  },
];

function run(command: Command) {
  console.log(`\n== ${command.label} ==`);
  const result = spawnSync(command.command, command.args, {
    cwd: process.cwd(),
    stdio: "inherit",
  });
  if (result.error) {
    throw result.error;
  }
  if (result.status !== 0) {
    process.exit(result.status ?? 1);
  }
}

function isInsideGitWorktree(): boolean {
  const result = spawnSync("git", ["rev-parse", "--is-inside-work-tree"], {
    cwd: process.cwd(),
    encoding: "utf8",
  });
  return result.status === 0 && result.stdout.trim() === "true";
}

function assertCleanGitWorktree() {
  const result = spawnSync("git", ["status", "--porcelain"], {
    cwd: process.cwd(),
    encoding: "utf8",
  });
  if (result.error) {
    throw result.error;
  }
  if (result.status !== 0) {
    process.exit(result.status ?? 1);
  }
  const status = result.stdout.trim();
  if (status) {
    console.error("\nCalibration check found Git worktree drift:");
    console.error(status);
    process.exit(1);
  }
}

for (const command of commands) {
  run(command);
}

if (isInsideGitWorktree()) {
  console.log("\n== Check clean Git worktree ==");
  assertCleanGitWorktree();
} else {
  console.log("\n== Check clean Git worktree ==");
  console.log("Skipped: not inside a Git worktree.");
}

console.log("\nCalibration check passed.");
