import assert from "node:assert/strict";
import { mkdtemp, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");

const oxlint = path.join(root, "tools/oxlint/node_modules/oxlint/bin/oxlint");

const scratch = await mkdtemp(path.join(os.tmpdir(), "macros-oxlint-smoke-"));

try {
  const positive = path.join(scratch, "positive.ts");
  const negative = path.join(scratch, "negative.ts");
  const spreadNegative = path.join(scratch, "spread-negative.ts");
  const complexityBoundary = path.join(scratch, "complexity-boundary.ts");
  const missingPluginConfig = path.join(scratch, "missing-plugin.json");
  await writeFile(
    positive,
    "export function total(values: number[]) {\n  let sum = 0;\n\n  for (const value of values) {\n    sum += value;\n  }\n\n  return sum;\n}\n",
  );
  await writeFile(
    negative,
    "export function select(values: number[]) {\n  return values.filter((value) => value > 0).map((value) => value * 2);\n}\n",
  );
  await writeFile(
    spreadNegative,
    "export function append(values: number[], input: number[]) {\n  return input.reduce<number[]>((accumulator, value) => [...accumulator, value], values);\n}\n",
  );
  await writeFile(
    missingPluginConfig,
    JSON.stringify({
      jsPlugins: [{ name: "missing", specifier: "./does-not-exist.ts" }],
      rules: { "missing/missing-rule": "error" },
    }),
  );

  const complexityFunction = (name, branchCount) =>
    `export function ${name}(value: number) {\n${Array.from(
      { length: branchCount },
      (_, index) => `\n  if (value === ${index}) {\n    return ${index};\n  }`,
    ).join("")}\n\n  return -1;\n}\n`;

  await writeFile(
    complexityBoundary,
    `${complexityFunction("atLimit", 19)}\n${complexityFunction("overLimit", 20)}`,
  );

  const run = (target) =>
    spawnSync(oxlint, ["--config", ".oxlintrc.json", "--format", "json", target], {
      cwd: root,
      encoding: "utf8",
    });

  const positiveResult = run(positive);

  assert.equal(positiveResult.status, 0, positiveResult.stderr || positiveResult.stdout);

  const negativeResult = run(negative);
  assert.notEqual(negativeResult.status, 0, "Known anti-slop violation unexpectedly passed");
  const diagnostics = JSON.parse(negativeResult.stdout).diagnostics;
  assert(
    diagnostics.some((diagnostic) => diagnostic.code === "anti-slop(no-array-filter-map)"),
    `Expected anti-slop/no-array-filter-map diagnostic; received ${negativeResult.stdout}`,
  );

  const spreadResult = run(spreadNegative);
  assert.notEqual(spreadResult.status, 0, "Accumulating spread unexpectedly passed");
  assert(
    JSON.parse(spreadResult.stdout).diagnostics.some(
      (diagnostic) => diagnostic.code === "oxc(no-accumulating-spread)",
    ),
    `Expected native oxc/no-accumulating-spread diagnostic; received ${spreadResult.stdout}`,
  );

  const missingPluginResult = spawnSync(
    oxlint,
    ["--config", missingPluginConfig, "--format", "json", positive],
    { cwd: root, encoding: "utf8" },
  );

  assert.notEqual(missingPluginResult.status, 0, "Missing plugin unexpectedly loaded");
  assert(
    /plugin/i.test(missingPluginResult.stderr + missingPluginResult.stdout),
    `Expected a plugin load diagnostic; received ${missingPluginResult.stderr}${missingPluginResult.stdout}`,
  );

  const complexityResult = run(complexityBoundary);
  assert.notEqual(complexityResult.status, 0, "Complexity 21 unexpectedly passed");
  const complexityDiagnostics = JSON.parse(complexityResult.stdout).diagnostics;
  assert(
    complexityDiagnostics.some(
      (diagnostic) =>
        diagnostic.code === "eslint(complexity)" &&
        diagnostic.filename === complexityBoundary &&
        diagnostic.message.includes("21"),
    ),
    `Expected complexity diagnostic on overLimit; received ${complexityResult.stdout}`,
  );
  assert(
    !complexityDiagnostics.some(
      (diagnostic) =>
        diagnostic.code === "eslint(complexity)" &&
        !diagnostic.message.includes("21"),
    ),
    `Complexity 20 should pass; received ${complexityResult.stdout}`,
  );

  process.stdout.write(
    `Oxlint smoke passed: positive accepted; anti-slop and native spread violations rejected; missing plugin rejected; classic complexity 20 accepted and 21 rejected (${complexityDiagnostics.find((diagnostic) => diagnostic.code === "eslint(complexity)")?.message}).\n`,
  );
} finally {
  await rm(scratch, { recursive: true, force: true });
}
