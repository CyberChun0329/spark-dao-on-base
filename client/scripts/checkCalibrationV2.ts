import { spawnSync } from "node:child_process";

type Command = {
  label: string;
  command: string;
  args: string[];
};

const commands: Command[] = [
  {
    label: "Write V2 teaching gas CSV",
    command: "forge",
    args: [
      "test",
      "--match-contract",
      "TeachingGasCalibrationV2Test",
      "--match-test",
      "testWriteTeachingGasCalibrationV2Csv",
      "-vv",
    ],
  },
  {
    label: "Write V2 follow-up gas CSV",
    command: "forge",
    args: [
      "test",
      "--match-contract",
      "TeachingGasCalibrationV2Test",
      "--match-test",
      "testWriteTeachingFollowupGasCalibrationV2Csv",
      "-vv",
    ],
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
    label: "Regenerate V2 teaching cost simulation",
    command: "npm",
    args: ["run", "simulate:teaching-cost:v2"],
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

for (const command of commands) {
  run(command);
}

if (isInsideGitWorktree()) {
  run({
    label: "Check no unstaged calibration drift",
    command: "git",
    args: ["diff", "--exit-code"],
  });
} else {
  console.log("\n== Check no unstaged calibration drift ==");
  console.log("Skipped: not inside a Git worktree.");
}

console.log("\nV2 calibration freeze check passed.");
