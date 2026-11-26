// Scoring for the Nutrition5k truth source. Calories are always grams x reference kcal/g; models never return calories.
export type N5kTruthItem = { name: string; grams: number | null; kcalPerGram?: number };

export type N5kTruth = {
  photoId: string; items: N5kTruthItem[];
  source?: { dataset: string; stratum: string; dishTotals: { calories: number; massGrams: number } };
};

export type N5kResult = {
  photoId: string; arm: string; latencyMs: number | null; rawOutput: string; schemaValid: boolean; error?: string;
};

export type ReferenceIngredient = { name: string; kcalPerGram: number };

type Prediction = { name: string; grams: number | null };

export type Method = "exact" | "alias" | "contains" | "fuzzy";

const STRENGTH: Record<Method, number> = { exact: 4, alias: 3, contains: 2, fuzzy: 1 };

const FUZZY_THRESHOLD = 0.8;

// Words that describe preparation or quantity rather than identity. Cooking words that are part of a
// Nutrition5k ingredient name (fried rice, roasted potatoes, grilled chicken) are kept and handled by aliases/contains.
const DROP_WORDS = new Set([
  "cooked", "raw", "fresh", "sliced", "diced", "chopped", "steamed", "shredded", "piece", "slice", "cube", "cubed",
  "whole", "small", "large", "baked", "sauteed", "of", "and", "with", "a", "the", "some"
]);

// Small synonym table: names a person would accept as the same food. Reviewed by hand; not exhaustive.
const ALIAS_GROUPS = [
  ["potato", "roasted potato", "red potato", "baked potato", "boiled potato", "potato wedge"],
  ["bell pepper", "pepper", "capsicum", "sweet pepper"],
  ["tomato", "cherry tomato", "grape tomato"],
  ["carrot", "baby carrot"],
  ["mixed green", "salad", "garden salad", "lettuce", "salad green", "mixed salad", "spring mix", "romaine lettuce", "romaine", "arugula"],
  ["chicken", "grilled chicken", "chicken breast", "roast chicken", "chicken thigh", "chicken drumstick", "chicken meat"],
  ["beef", "steak", "brisket", "roast beef", "ground beef", "beef steak"],
  ["pork", "roast pork", "pork chop", "rib", "pork loin"],
  ["bacon", "turkey bacon"],
  ["sausage", "chicken apple sausage", "soy sausage"],
  ["white rice", "rice", "steamed rice", "country rice", "plain rice"],
  ["brown rice"],
  ["pasta", "spaghetti", "macaroni", "penne", "noodle", "fettuccine", "orzo"],
  ["bread", "white bread", "wheat bread", "toast", "whole wheat bread", "multigrain bread", "sourdough bread", "rye bread", "roll", "bun", "bagel", "garlic bread", "focaccia", "pita bread", "flatbread"],
  ["french fry", "fry", "potato fry"],
  ["corn", "corn on the cob", "sweet corn", "corn kernel"],
  ["green bean", "string bean"],
  ["mushroom", "button mushroom"],
  ["cucumber"],
  ["avocado", "guacamole"],
  ["oatmeal", "oat", "porridge"],
  ["olive oil", "vegetable oil", "oil", "cooking oil", "dressing oil"],
  ["salad dressing", "ranch dressing", "italian dressing", "french dressing", "caesar dressing", "vinaigrette", "dressing"],
  ["egg", "scrambled egg", "fried egg", "poached egg", "hard boiled egg", "omelet", "boiled egg", "egg white", "egg yolk"],
  ["yogurt", "greek yogurt", "soy yogurt"],
  ["shrimp", "prawn"],
  ["fish", "white fish", "cod", "tilapia", "halibut", "haddock", "snapper", "flounder"],
  ["salmon", "artic char", "trout"],
  ["berry", "mixed berry"],
  ["strawberry"],
  ["hummus", "chickpea dip"],
  ["pea", "green pea", "snow pea"],
  ["onion", "green onion", "red onion"],
  ["bean", "black bean", "kidney bean", "pinto bean", "white bean", "baked bean", "refried bean"],
  ["nut", "mixed nut", "almond", "walnut", "pecan", "cashew", "peanut"],
  ["sauce", "pasta sauce", "gravy", "barbecue sauce", "teriyaki sauce", "pizza sauce"],
  ["cheese", "cheddar cheese", "mozzarella cheese", "parmesan cheese", "swiss cheese", "feta cheese", "american cheese"]
];

function singular(word: string): string {
  if (word.length > 4 && word.endsWith("ies")) return `${word.slice(0, -3)}y`;

  if (word.length > 4 && /(ches|shes|sses|xes|oes)$/.test(word)) return word.slice(0, -2);

  if (word.length > 3 && word.endsWith("s") && !word.endsWith("ss")) return word.slice(0, -1);

  return word;
}

export function tokens(name: string): string[] {
  return name.toLowerCase().replace(/[^a-z0-9]+/g, " ").trim().split(" ").filter(Boolean)
    .map(singular).filter((word) => !DROP_WORDS.has(word));
}

const canonical = (name: string) => tokens(name).join(" ");

const groupOf = new Map<string, number>();

ALIAS_GROUPS.forEach((group, index) => group.forEach((name) => {
  if (!groupOf.has(canonical(name))) groupOf.set(canonical(name), index);
}));

function similarity(left: string, right: string): number {
  if (left === right) return 1;

  if (!left || !right) return 0;
  const previous = Array.from({ length: right.length + 1 }, (_, index) => index);

  for (let row = 1; row <= left.length; row += 1) {
    let diagonal = previous[0]!;
    previous[0] = row;

    for (let column = 1; column <= right.length; column += 1) {
      const above = previous[column]!;
      previous[column] = Math.min(previous[column]! + 1, previous[column - 1]! + 1, diagonal + (left[row - 1] === right[column - 1] ? 0 : 1));
      diagonal = above;
    }
  }

  return 1 - previous[right.length]! / Math.max(left.length, right.length);
}

export function matchMethod(left: string, right: string): Method | null {
  const a = canonical(left);
  const b = canonical(right);

  if (!a || !b) return null;

  if (a === b) return "exact";
  const groupA = groupOf.get(a);

  if (groupA !== undefined && groupA === groupOf.get(b)) return "alias";
  const [short, long] = a.split(" ").length <= b.split(" ").length ? [a.split(" "), b.split(" ")] : [b.split(" "), a.split(" ")];

  if (short.every((word) => long.includes(word))) return "contains";

  return similarity(a, b) >= FUZZY_THRESHOLD ? "fuzzy" : null;
}

type Pair = { truth: number; prediction: number; method: Method };

function bestPairs(truth: N5kTruthItem[], predictions: Prediction[]): Pair[] {
  const candidates: Pair[] = [];
  truth.forEach((item, truthIndex) => predictions.forEach((prediction, predictionIndex) => {
    const method = matchMethod(item.name, prediction.name);

    if (method) candidates.push({ truth: truthIndex, prediction: predictionIndex, method });
  }));
  candidates.sort((x, y) => STRENGTH[y.method] - STRENGTH[x.method]);
  const usedTruth = new Set<number>();
  const usedPrediction = new Set<number>();

  return candidates.filter((pair) => {
    if (usedTruth.has(pair.truth) || usedPrediction.has(pair.prediction)) return false;
    usedTruth.add(pair.truth);
    usedPrediction.add(pair.prediction);

    return true;
  });
}

function referenceKcalPerGram(name: string, reference: ReferenceIngredient[]): number | null {
  let best: { strength: number; kcal: number } | null = null;

  for (const entry of reference) {
    const method = matchMethod(entry.name, name);

    if (method && (!best || STRENGTH[method] > best.strength)) best = { strength: STRENGTH[method], kcal: entry.kcalPerGram };
  }

  return best?.kcal ?? null;
}

const positive = (value: number | null | undefined): value is number => value != null && Number.isFinite(value) && value > 0;

const sum = (values: number[]) => values.reduce((total, value) => total + value, 0);

export function median(values: number[]): number | null {
  if (!values.length) return null;
  const sorted = [...values].sort((a, b) => a - b);
  const middle = Math.floor(sorted.length / 2);

  return sorted.length % 2 ? sorted[middle]! : (sorted[middle - 1]! + sorted[middle]!) / 2;
}

export function percentile(values: number[], fraction: number): number | null {
  if (!values.length) return null;
  const sorted = [...values].sort((a, b) => a - b);

  return sorted[Math.ceil(fraction * sorted.length) - 1]!;
}

const mean = (values: number[]) => values.length ? sum(values) / values.length : null;

export type DishScore = {
  photoId: string; stratum: string; outcome: "ok" | "refusal" | "failure"; error?: string;
  truthKcal: number; predictedKcal: number | null; truthMass: number; predictedMass: number | null;
  matches: Array<{ truth: string; prediction: string; method: Method; truthGrams: number; predictedGrams: number | null }>;
  missed: Array<{ name: string; grams: number }>; extra: Array<{ name: string; grams: number | null }>;
  matchedTruthGrams: number; matchedPredictedGrams: number; predictedGramsTotal: number; unpricedGrams: number;
  latencyMs: number | null; predictedFoods: Prediction[];
};

function parseEstimate(result: N5kResult | undefined): { status: string; foods: Prediction[] } | "failure" {
  if (!result || result.error || !result.schemaValid) return "failure";

  try {
    // SAFETY: schemaValid is true, so the runner already checked the output against the shared schema; foods is re-checked below.
    const parsed = JSON.parse(result.rawOutput) as { status: string; foods: Prediction[] };

    return Array.isArray(parsed.foods) ? parsed : "failure";
  } catch {
    return "failure";
  }
}

export function scoreDish(truth: N5kTruth, result: N5kResult | undefined, reference: ReferenceIngredient[]): DishScore {
  const truthKcal = sum(truth.items.map((item) => (item.grams ?? 0) * (item.kcalPerGram ?? 0)));

  const base = {
    photoId: truth.photoId, stratum: truth.source?.stratum ?? "unknown", truthKcal,
    truthMass: sum(truth.items.map((item) => item.grams ?? 0)), latencyMs: result?.latencyMs ?? null,
    matches: [], missed: truth.items.map((item) => ({ name: item.name, grams: item.grams ?? 0 })), extra: [],
    matchedTruthGrams: 0, matchedPredictedGrams: 0, predictedGramsTotal: 0, unpricedGrams: 0, predictedFoods: []
  };

  const estimate = parseEstimate(result);

  if (estimate === "failure") {
    return { ...base, outcome: "failure", error: result?.error ?? (result ? "invalid output" : "no result"), predictedKcal: null, predictedMass: null };
  }

  const foods = estimate.foods.filter((food) => Boolean(food?.name));

  if (estimate.status !== "ok" || !foods.length) return { ...base, outcome: "refusal", predictedKcal: null, predictedMass: null, predictedFoods: foods };
  const pairs = bestPairs(truth.items, foods);
  const priceByPrediction = new Map(pairs.map((pair) => [pair.prediction, truth.items[pair.truth]!.kcalPerGram ?? null]));
  let predictedKcal = 0;
  let unpricedGrams = 0;
  foods.forEach((food, index) => {
    if (!positive(food.grams)) return;
    const price = priceByPrediction.get(index) ?? referenceKcalPerGram(food.name, reference);

    if (price === null) unpricedGrams += food.grams;
    else predictedKcal += food.grams * price;
  });
  const matchedPredictions = new Set(pairs.map((pair) => pair.prediction));
  const matchedTruth = new Set(pairs.map((pair) => pair.truth));

  const matches = pairs.map((pair) => ({
    truth: truth.items[pair.truth]!.name, prediction: foods[pair.prediction]!.name, method: pair.method,
    truthGrams: truth.items[pair.truth]!.grams ?? 0, predictedGrams: positive(foods[pair.prediction]!.grams) ? foods[pair.prediction]!.grams : null
  }));

  const grams = (food: Prediction) => positive(food.grams) ? food.grams : 0;

  return {
    ...base, outcome: "ok", predictedKcal, predictedMass: sum(foods.map(grams)), matches, unpricedGrams, predictedFoods: foods,
    missed: truth.items.filter((_, index) => !matchedTruth.has(index)).map((item) => ({ name: item.name, grams: item.grams ?? 0 })),
    extra: foods.filter((_, index) => !matchedPredictions.has(index)).map((food) => ({ name: food.name, grams: positive(food.grams) ? food.grams : null })),
    matchedTruthGrams: sum(matches.map((match) => match.truthGrams)),
    matchedPredictedGrams: sum(matches.map((match) => match.predictedGrams ?? 0)),
    predictedGramsTotal: sum(foods.map(grams))
  };
}

const ape = (predicted: number, truth: number) => Math.abs(predicted - truth) / truth * 100;

export type ArmSummary = {
  arm: string; dishes: number; answered: number; failures: number; refusals: number;
  kcalMape: number | null; kcalMedianApe: number | null; kcalMapeFailuresAs100: number | null; kcalSignedBiasPct: number | null; within20: number | null; within20AllDishes: number | null;
  massMape: number | null; massSignedBiasPct: number | null;
  countRecall: number | null; countPrecision: number | null; massRecall: number | null; massPrecision: number | null;
  matchedGramMedianApe: number | null; matchedGramMedianApe10g: number | null; unpricedMassShare: number | null;
  latencyP50: number | null; latencyP95: number | null; methodCounts: Record<Method, number>;
  kcalMapeByStratum: Record<string, { n: number; mape: number | null }>;
  topMissed: Array<{ name: string; count: number; grams: number }>; topExtra: Array<{ name: string; count: number }>;
  failureErrors: string[];
};

function ratio(numerator: number, denominator: number): number | null {
  return denominator > 0 ? numerator / denominator : null;
}

function tally<T>(items: T[], key: (item: T) => string, weight: (item: T) => number): Array<{ name: string; count: number; grams: number }> {
  const totals = new Map<string, { count: number; grams: number }>();

  for (const item of items) {
    const entry = totals.get(key(item)) ?? { count: 0, grams: 0 };
    entry.count += 1;
    entry.grams += weight(item);
    totals.set(key(item), entry);
  }

  return [...totals].map(([name, value]) => ({ name, ...value })).sort((a, b) => b.count - a.count || b.grams - a.grams).slice(0, 10);
}

export function summarizeArm(arm: string, dishes: DishScore[]): ArmSummary {
  const answered = dishes.filter((dish) => dish.outcome === "ok");
  const kcalErrors = answered.map((dish) => ape(dish.predictedKcal!, dish.truthKcal));
  const massErrors = answered.map((dish) => ape(dish.predictedMass!, dish.truthMass));
  const matches = answered.flatMap((dish) => dish.matches);
  const matchedGramErrors = matches.flatMap((match) => match.predictedGrams === null ? [] : [ape(match.predictedGrams, match.truthGrams)]);
  const latencies = answered.flatMap((dish) => dish.latencyMs === null ? [] : [dish.latencyMs]);
  const methodCounts: Record<Method, number> = { exact: 0, alias: 0, contains: 0, fuzzy: 0 };
  matches.forEach((match) => { methodCounts[match.method] += 1; });
  const strata = [...new Set(dishes.map((dish) => dish.stratum))].sort();
  const allKcalErrors = dishes.map((dish) => dish.outcome === "ok" ? ape(dish.predictedKcal!, dish.truthKcal) : 100);

  return {
    arm, dishes: dishes.length, answered: answered.length,
    failures: dishes.filter((dish) => dish.outcome === "failure").length, refusals: dishes.filter((dish) => dish.outcome === "refusal").length,
    kcalMape: mean(kcalErrors), kcalMedianApe: median(kcalErrors), kcalMapeFailuresAs100: mean(allKcalErrors),
    kcalSignedBiasPct: mean(answered.map((dish) => (dish.predictedKcal! - dish.truthKcal) / dish.truthKcal * 100)),
    within20: ratio(kcalErrors.filter((value) => value <= 20).length, kcalErrors.length),
    within20AllDishes: ratio(allKcalErrors.filter((value) => value <= 20).length, allKcalErrors.length),
    massMape: mean(massErrors), massSignedBiasPct: mean(answered.map((dish) => (dish.predictedMass! - dish.truthMass) / dish.truthMass * 100)),
    countRecall: ratio(matches.length, sum(answered.map((dish) => dish.matches.length + dish.missed.length))),
    countPrecision: ratio(matches.length, sum(answered.map((dish) => dish.matches.length + dish.extra.length))),
    massRecall: ratio(sum(answered.map((dish) => dish.matchedTruthGrams)), sum(answered.map((dish) => dish.truthMass))),
    massPrecision: ratio(sum(answered.map((dish) => dish.matchedPredictedGrams)), sum(answered.map((dish) => dish.predictedGramsTotal))),
    matchedGramMedianApe: median(matchedGramErrors),
    matchedGramMedianApe10g: median(matches.flatMap((match) => match.predictedGrams !== null && match.truthGrams >= 10 ? [ape(match.predictedGrams, match.truthGrams)] : [])),
    unpricedMassShare: ratio(sum(answered.map((dish) => dish.unpricedGrams)), sum(answered.map((dish) => dish.predictedGramsTotal))),
    latencyP50: median(latencies), latencyP95: percentile(latencies, 0.95), methodCounts,
    kcalMapeByStratum: Object.fromEntries(strata.map((stratum) => {
      const errors = answered.flatMap((dish) => dish.stratum === stratum ? [ape(dish.predictedKcal!, dish.truthKcal)] : []);

      return [stratum, { n: errors.length, mape: mean(errors) }];
    })),
    topMissed: tally(answered.flatMap((dish) => dish.missed), (item) => item.name, (item) => item.grams),
    topExtra: tally(answered.flatMap((dish) => dish.extra), (item) => canonical(item.name), () => 0).map(({ name, count }) => ({ name, count })),
    failureErrors: [...new Set(dishes.flatMap((dish) => dish.outcome === "failure" ? [(dish.error ?? "").split("\n")[0]!.slice(0, 160)] : []))]
  };
}

const pct = (value: number | null, digits = 1) => value === null ? "n/a" : `${value.toFixed(digits)}%`;

const frac = (value: number | null) => value === null ? "n/a" : `${(value * 100).toFixed(1)}%`;

const ms = (value: number | null) => value === null ? "n/a" : value.toFixed(0);

export function renderReport(summaries: ArmSummary[]): string {
  const head = (title: string, columns: string[]) => [`### ${title}`, "", `| Arm | ${columns.join(" | ")} |`, `|---|${columns.map(() => "---:").join("|")}|`];

  const calorie = [
    ...head("Calories and mass (answered dishes)", ["Dishes", "Answered", "Failed", "Refused/empty", "kcal MAPE", "kcal median APE", "kcal bias", "Within ±20%", "Within ±20% (all dishes)", "Mass MAPE", "Mass bias"]),
    ...summaries.map((s) => `| ${s.arm} | ${s.dishes} | ${s.answered} | ${s.failures} | ${s.refusals} | ${pct(s.kcalMape)} | ${pct(s.kcalMedianApe)} | ${pct(s.kcalSignedBiasPct)} | ${frac(s.within20)} | ${frac(s.within20AllDishes)} | ${pct(s.massMape)} | ${pct(s.massSignedBiasPct)} |`)
  ];

  const recognition = [
    ...head("Recognition and portions (answered dishes)", ["Count recall", "Count precision", "Mass recall", "Mass precision", "Matched-item gram median APE", "…for items ≥ 10 g", "Unpriced predicted mass", "p50 / p95 ms"]),
    ...summaries.map((s) => `| ${s.arm} | ${frac(s.countRecall)} | ${frac(s.countPrecision)} | ${frac(s.massRecall)} | ${frac(s.massPrecision)} | ${pct(s.matchedGramMedianApe)} | ${pct(s.matchedGramMedianApe10g)} | ${frac(s.unpricedMassShare)} | ${ms(s.latencyP50)} / ${ms(s.latencyP95)} |`)
  ];

  const strata = [...new Set(summaries.flatMap((s) => Object.keys(s.kcalMapeByStratum)))].sort();

  const stratified = [
    ...head("kcal MAPE by ingredient count (n answered)", strata),
    ...summaries.map((s) => `| ${s.arm} | ${strata.map((key) => `${pct(s.kcalMapeByStratum[key]?.mape ?? null)} (${s.kcalMapeByStratum[key]?.n ?? 0})`).join(" | ")} |`)
  ];

  const methods = [
    ...head("Name-match methods (matched pairs)", ["exact", "alias", "contains", "fuzzy"]),
    ...summaries.map((s) => `| ${s.arm} | ${s.methodCounts.exact} | ${s.methodCounts.alias} | ${s.methodCounts.contains} | ${s.methodCounts.fuzzy} |`)
  ];

  const lists = summaries.map((s) => [
    `#### ${s.arm}`, "",
    `- Most missed truth ingredients: ${s.topMissed.map((item) => `${item.name} ×${item.count} (${item.grams.toFixed(0)} g)`).join(", ") || "none"}`,
    `- Most frequent unmatched predictions: ${s.topExtra.map((item) => `${item.name} ×${item.count}`).join(", ") || "none"}`,
    ...(s.failureErrors.length ? [`- Failure messages: ${s.failureErrors.map((error) => `\`${error}\``).join("; ")}`] : [])
  ].join("\n"));

  return [`# Nutrition5k scoring\n\nGenerated ${new Date().toISOString()}.`, ...[calorie, recognition, stratified, methods].map((block) => block.join("\n")), "### Failure analysis\n", ...lists].join("\n\n") + "\n";
}
