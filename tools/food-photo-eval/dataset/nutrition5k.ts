// Builds a deterministic Nutrition5k evaluation subset (photos + truth JSON) from the public GCS bucket.
// Data: https://github.com/google-research-datasets/Nutrition5k (CC BY 4.0, Thames et al., CVPR 2021).
// Usage: bun run dataset/nutrition5k.ts [--out dataset/nutrition5k] [--per-stratum 20] [--seed 5002026]
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";

const BUCKET = "nutrition5k_dataset";

const PREFIX = "nutrition5k_dataset";

const OBJECT_URL = `https://storage.googleapis.com/${BUCKET}/${PREFIX}`;

const LIST_URL = `https://storage.googleapis.com/storage/v1/b/${BUCKET}/o`;

const MIN_MASS = 100;

const MAX_MASS = 800;

const STRATA = [
  { name: "1-2", min: 1, max: 2 },
  { name: "3-5", min: 3, max: 5 },
  { name: "6+", min: 6, max: Infinity }
] as const;

function valueAfter(flag: string): string | undefined {
  const index = Bun.argv.indexOf(flag);

  return index >= 0 ? Bun.argv[index + 1] : undefined;
}

const outDir = resolve(process.cwd(), valueAfter("--out") ?? "dataset/nutrition5k");

const perStratum = Number(valueAfter("--per-stratum") ?? 20);

const seed = Number(valueAfter("--seed") ?? 5002026);

const selectionPath = resolve(import.meta.dir, "nutrition5k.selection.json");

type Ingredient = { id: number; name: string; kcalPerGram: number };

type DishIngredient = { ingredientId: number; name: string; grams: number; calories: number };

type Dish = {
  dishId: string; calories: number; mass: number; fat: number; carb: number; protein: number; ingredients: DishIngredient[];
};

async function cached(relative: string, url: string): Promise<string> {
  const path = join(outDir, "cache", relative);
  const existing = await readFile(path, "utf8").catch(() => null);

  if (existing !== null) return existing;
  const response = await fetch(url);

  if (!response.ok) throw new Error(`GET ${url} -> HTTP ${response.status}`);
  const body = await response.text();
  await mkdir(dirname(path), { recursive: true });
  await writeFile(path, body);

  return body;
}

// 32-bit PRNG so the shuffle is identical across machines and Bun versions.
function mulberry32(initial: number): () => number {
  let state = initial >>> 0;

  return () => {
    state = (state + 0x6d2b79f5) >>> 0;
    let t = state;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);

    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function shuffled<T>(items: T[], random: () => number): T[] {
  const copy = [...items];

  for (let index = copy.length - 1; index > 0; index -= 1) {
    const swap = Math.floor(random() * (index + 1));
    [copy[index], copy[swap]] = [copy[swap]!, copy[index]!];
  }

  return copy;
}

function parseIngredients(csv: string): Ingredient[] {
  return csv.trim().split("\n").slice(1).map((line) => {
    const [name, id, kcal] = line.split(",");

    return { id: Number(id), name: name!.trim(), kcalPerGram: Number(kcal) };
  });
}

function parseDishes(csv: string): Dish[] {
  return csv.trim().split("\n").map((line) => {
    const cells = line.split(",");
    const ingredients: DishIngredient[] = [];

    for (let index = 6; index + 7 <= cells.length; index += 7) {
      ingredients.push({
        ingredientId: Number(cells[index]!.replace("ingr_", "")), name: cells[index + 1]!.trim(),
        grams: Number(cells[index + 2]), calories: Number(cells[index + 3])
      });
    }

    return {
      dishId: cells[0]!, calories: Number(cells[1]), mass: Number(cells[2]),
      fat: Number(cells[3]), carb: Number(cells[4]), protein: Number(cells[5]), ingredients
    };
  });
}

async function dishesWithOverheadRgb(): Promise<Set<string>> {
  const cache = await readFile(join(outDir, "cache/overhead-dishes.json"), "utf8").catch(() => null);

  if (cache) {
    // SAFETY: the cache file is written only by this function as a JSON array of dish id strings.
    return new Set(JSON.parse(cache) as string[]);
  }

  const ids: string[] = [];
  let pageToken: string | undefined;

  do {
    const url = new URL(LIST_URL);
    url.searchParams.set("prefix", `${PREFIX}/imagery/realsense_overhead/`);
    url.searchParams.set("delimiter", "/");
    url.searchParams.set("fields", "prefixes,nextPageToken");

    if (pageToken) url.searchParams.set("pageToken", pageToken);
    // SAFETY: fields=prefixes,nextPageToken restricts the GCS JSON API response to this shape.
    const body = await (await fetch(url)).json() as { prefixes?: string[]; nextPageToken?: string };
    ids.push(...(body.prefixes ?? []).map((prefix) => prefix.split("/").at(-2)!));
    pageToken = body.nextPageToken;
  } while (pageToken);

  await mkdir(join(outDir, "cache"), { recursive: true });
  await writeFile(join(outDir, "cache/overhead-dishes.json"), JSON.stringify(ids));

  return new Set(ids);
}

const ingredients = parseIngredients(await cached("ingredients_metadata.csv", `${OBJECT_URL}/metadata/ingredients_metadata.csv`));

const ingredientById = new Map(ingredients.map((ingredient) => [ingredient.id, ingredient]));

const dishes = [
  ...parseDishes(await cached("dish_metadata_cafe1.csv", `${OBJECT_URL}/metadata/dish_metadata_cafe1.csv`)),
  ...parseDishes(await cached("dish_metadata_cafe2.csv", `${OBJECT_URL}/metadata/dish_metadata_cafe2.csv`))
];

const overhead = await dishesWithOverheadRgb();

// Eligible: overhead RGB exists, 100-800 g, every ingredient has grams and a reference kcal/g,
// the ingredient grams sum to the dish mass, and grams x kcal/g reproduces the published dish calories
// (guards against truncated rows; many Cafe 2 rows carry zero calories).
const eligible = dishes.filter((dish) => {
  const sum = dish.ingredients.reduce((total, item) => total + item.grams, 0);
  const kcal = dish.ingredients.reduce((total, item) => total + item.grams * (ingredientById.get(item.ingredientId)?.kcalPerGram ?? NaN), 0);

  return overhead.has(dish.dishId)
    && dish.calories > 0 && Math.abs(kcal - dish.calories) / dish.calories < 0.02
    && dish.mass >= MIN_MASS && dish.mass <= MAX_MASS
    && dish.ingredients.length > 0
    && Math.abs(sum - dish.mass) / dish.mass < 0.02
    && dish.ingredients.every((item) => item.grams > 0 && ingredientById.has(item.ingredientId) && item.name !== "deprecated");
}).sort((a, b) => a.dishId.localeCompare(b.dishId));

const random = mulberry32(seed);

const selected = STRATA.flatMap((stratum) => {
  const pool = eligible.filter((dish) => dish.ingredients.length >= stratum.min && dish.ingredients.length <= stratum.max);

  if (pool.length < perStratum) throw new Error(`Stratum ${stratum.name} has only ${pool.length} eligible dishes.`);

  return shuffled(pool, random).slice(0, perStratum).map((dish) => ({ dish, stratum: stratum.name }));
});

await mkdir(join(outDir, "photos"), { recursive: true });

await mkdir(join(outDir, "truth"), { recursive: true });

for (const { dish, stratum } of selected) {
  const photoPath = join(outDir, "photos", `${dish.dishId}.png`);

  if (!(await Bun.file(photoPath).exists())) {
    const response = await fetch(`${OBJECT_URL}/imagery/realsense_overhead/${dish.dishId}/rgb.png`);

    if (!response.ok) throw new Error(`rgb.png for ${dish.dishId}: HTTP ${response.status}`);
    await Bun.write(photoPath, response);
  }

  const truth = {
    photoId: dish.dishId,
    portionSize: "not_applicable",
    source: {
      dataset: "Nutrition5k", license: "CC BY 4.0", stratum,
      dishTotals: { calories: dish.calories, massGrams: dish.mass, fatGrams: dish.fat, carbGrams: dish.carb, proteinGrams: dish.protein }
    },
    items: dish.ingredients.map((item) => ({
      name: item.name, grams: item.grams, volumeMl: null, preparation: "", notes: `Nutrition5k ingredient id ${item.ingredientId}`,
      foodKey: null, kcalPerGram: ingredientById.get(item.ingredientId)!.kcalPerGram
    }))
  };

  await writeFile(join(outDir, "truth", `${dish.dishId}.json`), `${JSON.stringify(truth, null, 2)}\n`);
}

// Reference table used by the scorer to price predicted foods: calories are always grams x kcal/g, never model output.
await writeFile(join(outDir, "ingredients.json"), `${JSON.stringify(ingredients)}\n`);

await writeFile(selectionPath, `${JSON.stringify({
  dataset: "Nutrition5k", license: "CC BY 4.0", source: "https://github.com/google-research-datasets/Nutrition5k",
  seed, perStratum, massRangeGrams: [MIN_MASS, MAX_MASS], eligibleDishes: eligible.length,
  dishes: selected.map(({ dish, stratum }) => ({ dishId: dish.dishId, stratum, ingredients: dish.ingredients.length, massGrams: dish.mass }))
}, null, 2)}\n`);

console.log(`Wrote ${selected.length} dishes (${eligible.length} eligible) to ${outDir}`);
