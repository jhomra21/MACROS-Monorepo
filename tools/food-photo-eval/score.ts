import { mkdir, readdir, readFile, writeFile } from "node:fs/promises";
import { basename, join, resolve } from "node:path";

type TruthItem = { name: string; grams: number | null; volumeMl: number | null; foodKey: string | null };
type Truth = { photoId: string; portionSize: string; items: TruthItem[] };
type EstimateItem = { name: string; grams: number | null; foodKey: string | null };
type Estimate = { status: string; foods: EstimateItem[] };
type Result = {
  photoId: string; arm: string; model: string; latencyMs: number | null; tokenUsage: { inputTokens: number | null; outputTokens: number | null };
  rawOutput: string; schemaValid: boolean;
};
type CommonFood = {
  sourceIdentifier: string; name: string; aliases: string[]; gramsPerServing: number; caloriesPerServing: number;
};
type Price = { inputPerMillion: number; outputPerMillion: number; source: string };

const root = resolve(import.meta.dir);
const dataset = resolve(process.cwd(), valueAfter("--dataset") ?? "dataset");
const resultsRoot = resolve(process.cwd(), valueAfter("--results") ?? "results");
const commonFoodsPath = resolve(root, "../../cal-macro-tracker/CommonFoods/common_foods.json");
const prices = JSON.parse(await readFile(join(root, "pricing.json"), "utf8")) as Record<string, Price>;
const commonFoods = JSON.parse(await readFile(commonFoodsPath, "utf8")) as CommonFood[];
const foodByKey = new Map(commonFoods.map((food) => [food.sourceIdentifier, food]));

function valueAfter(flag: string): string | undefined {
  const index = Bun.argv.indexOf(flag);
  return index >= 0 ? Bun.argv[index + 1] : undefined;
}

async function jsonFiles(directory: string): Promise<string[]> {
  const entries = await readdir(directory, { withFileTypes: true }).catch(() => []);
  return entries.flatMap((entry) => entry.isDirectory()
    ? [] // Dataset truth is intentionally flat; nested examples are not training/evaluation records.
    : entry.isFile() && entry.name.endsWith(".json") ? [join(directory, entry.name)] : []);
}

function normalize(text: string): string {
  return text.toLowerCase().replace(/[^a-z0-9]+/g, " ").trim();
}

function similarity(left: string, right: string): number {
  const a = normalize(left);
  const b = normalize(right);
  if (a === b) return 1;
  if (!a || !b) return 0;
  const previous = Array.from({ length: b.length + 1 }, (_, index) => index);
  for (let row = 1; row <= a.length; row += 1) {
    let diagonal = previous[0]!;
    previous[0] = row;
    for (let column = 1; column <= b.length; column += 1) {
      const above = previous[column]!;
      previous[column] = Math.min(previous[column]! + 1, previous[column - 1]! + 1, diagonal + (a[row - 1] === b[column - 1] ? 0 : 1));
      diagonal = above;
    }
  }
  return 1 - previous[b.length]! / Math.max(a.length, b.length);
}

function matches(truth: TruthItem, estimate: EstimateItem): boolean {
  if (truth.foodKey && truth.foodKey === estimate.foodKey) return true;
  const names = [truth.name, ...(truth.foodKey ? foodByKey.get(truth.foodKey)?.aliases ?? [] : [])];
  return names.some((name) => similarity(name, estimate.name) >= 0.72);
}

function calorie(foodKey: string | null, name: string, grams: number | null): number | null {
  if (grams === null || grams <= 0) return null;
  const food = (foodKey ? foodByKey.get(foodKey) : undefined)
    ?? commonFoods.find((item) => similarity(item.name, name) >= 0.85 || item.aliases.some((alias) => similarity(alias, name) >= 0.85));
  if (!food || food.gramsPerServing <= 0) return null;
  return grams * food.caloriesPerServing / food.gramsPerServing;
}

function median(values: number[]): number | null {
  if (!values.length) return null;
  const sorted = [...values].sort((a, b) => a - b);
  const middle = Math.floor(sorted.length / 2);
  return sorted.length % 2 ? sorted[middle]! : (sorted[middle - 1]! + sorted[middle]!) / 2;
}

function percentile(values: number[], percentileValue: number): number | null {
  if (!values.length) return null;
  const sorted = [...values].sort((a, b) => a - b);
  return sorted[Math.ceil(percentileValue * sorted.length) - 1]!;
}

const truths = new Map<string, Truth>();
for (const file of await jsonFiles(join(dataset, "truth"))) {
  const truth = JSON.parse(await readFile(file, "utf8")) as Truth;
  truths.set(truth.photoId ?? basename(file, ".json"), truth);
}
const arms = new Map<string, Result[]>();
for (const entry of await readdir(resultsRoot, { withFileTypes: true }).catch(() => [])) {
  if (!entry.isDirectory()) continue;
  for (const file of await jsonFiles(join(resultsRoot, entry.name))) {
    const result = JSON.parse(await readFile(file, "utf8")) as Result;
    const armResults = arms.get(result.arm) ?? [];
    armResults.push(result);
    arms.set(result.arm, armResults);
  }
}

const rows = [...arms].sort(([left], [right]) => left.localeCompare(right)).map(([arm, records]) => {
  let truePositives = 0;
  let falsePositives = 0;
  let falseNegatives = 0;
  let largePortionGramErrors: number[] = [];
  const itemPercentErrors: number[] = [];
  const mealCalorieErrors: number[] = [];
  const largeSignedGramBias: number[] = [];
  const latencies = records.map((record) => record.latencyMs).filter((value): value is number => value !== null && Number.isFinite(value));
  const inputTokens = records.reduce((sum, record) => sum + (record.tokenUsage?.inputTokens ?? 0), 0);
  const outputTokens = records.reduce((sum, record) => sum + (record.tokenUsage?.outputTokens ?? 0), 0);
  for (const record of records) {
    const truth = truths.get(record.photoId);
    if (!truth) continue;
    let estimate: Estimate | null = null;
    try { estimate = JSON.parse(record.rawOutput) as Estimate; } catch { /* failed output remains a schema failure */ }
    const predictions = estimate?.foods ?? [];
    const unmatched = new Set(predictions.map((_, index) => index));
    const predictedCalories = predictions.flatMap((item) => {
      const value = calorie(item.foodKey, item.name, item.grams);
      return value === null ? [] : [value];
    });
    const truthCalories: number[] = [];
    for (const item of truth.items) {
      const matchIndex = [...unmatched].find((index) => matches(item, predictions[index]!));
      const knownTruthCalories = calorie(item.foodKey, item.name, item.grams);
      if (knownTruthCalories !== null) truthCalories.push(knownTruthCalories);
      if (matchIndex === undefined) {
        falseNegatives += 1;
        continue;
      }
      unmatched.delete(matchIndex);
      truePositives += 1;
      const prediction = predictions[matchIndex]!;
      if (item.grams !== null && prediction.grams !== null && item.grams > 0) {
        const error = Math.abs(prediction.grams - item.grams) / item.grams * 100;
        itemPercentErrors.push(error);
        if (truth.portionSize === "large") {
          largePortionGramErrors.push(error);
          largeSignedGramBias.push(prediction.grams - item.grams);
        }
      }
    }
    falsePositives += unmatched.size;
    if (truthCalories.length && predictedCalories.length) {
      const truthTotal = truthCalories.reduce((sum, value) => sum + value, 0);
      const predictedTotal = predictedCalories.reduce((sum, value) => sum + value, 0);
      if (truthTotal > 0) mealCalorieErrors.push(Math.abs(predictedTotal - truthTotal) / truthTotal * 100);
    }
  }
  const precision = truePositives + falsePositives ? truePositives / (truePositives + falsePositives) : null;
  const recall = truePositives + falseNegatives ? truePositives / (truePositives + falseNegatives) : null;
  const price = prices[records[0]?.model] ?? prices[arm];
  const costPerThousand = price
    ? ((inputTokens * price.inputPerMillion + outputTokens * price.outputPerMillion) / records.length / 1_000_000) * 1_000
    : null;
  return {
    arm, photos: records.length,
    schemaRate: records.length ? records.filter((record) => record.schemaValid).length / records.length : null,
    precision, recall, medianGramError: median(itemPercentErrors), meanGramError: itemPercentErrors.length ? itemPercentErrors.reduce((sum, value) => sum + value, 0) / itemPercentErrors.length : null,
    medianMealCalorieError: median(mealCalorieErrors), meanMealCalorieError: mealCalorieErrors.length ? mealCalorieErrors.reduce((sum, value) => sum + value, 0) / mealCalorieErrors.length : null,
    calorieWithin20: mealCalorieErrors.length ? mealCalorieErrors.filter((value) => value <= 20).length / mealCalorieErrors.length : null,
    largeSignedGramBias: largeSignedGramBias.length ? largeSignedGramBias.reduce((sum, value) => sum + value, 0) / largeSignedGramBias.length : null,
    medianLargeGramError: median(largePortionGramErrors),
    p50Latency: median(latencies), p95Latency: percentile(latencies, 0.95), costPerThousand
  };
});

const percent = (value: number | null) => value === null ? "n/a" : `${(value * 100).toFixed(1)}%`;
const numeric = (value: number | null, suffix = "") => value === null ? "n/a" : `${value.toFixed(1)}${suffix}`;
const table = [
  "| Arm | Photos | Schema valid | Precision | Recall | Median gram error | Mean gram error | Median meal calorie error | Mean meal calorie error | Within 20% calories | Large signed gram bias | Large median gram error | p50 / p95 ms | Cost / 1k scans |",
  "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|",
  ...rows.map((row) => `| ${row.arm} | ${row.photos} | ${percent(row.schemaRate)} | ${percent(row.precision)} | ${percent(row.recall)} | ${numeric(row.medianGramError, "%")} | ${numeric(row.meanGramError, "%")} | ${numeric(row.medianMealCalorieError, "%")} | ${numeric(row.meanMealCalorieError, "%")} | ${percent(row.calorieWithin20)} | ${numeric(row.largeSignedGramBias, " g")} | ${numeric(row.medianLargeGramError, "%")} | ${numeric(row.p50Latency)} / ${numeric(row.p95Latency)} | ${row.costPerThousand === null ? "n/a" : `$${row.costPerThousand.toFixed(4)}`} |`)
];
const report = `# Food photo evaluation report\n\nGenerated ${new Date().toISOString()}.\n\nMeal calorie metrics include only foods with a CommonFoods match and measured grams. Volume-only items are not converted. Costs use recorded token counts and the price snapshot in \`pricing.json\`; image charges or provider-specific fees not represented by token counts are excluded. Large-portion bias is signed predicted minus true grams across matched items.\n\n${table.join("\n")}\n`;
await mkdir(resultsRoot, { recursive: true });
await writeFile(join(resultsRoot, "report.md"), report);
console.log(report);
