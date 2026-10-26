import { mkdir, readFile, writeFile } from "node:fs/promises";
import { createHash } from "node:crypto";
import { resolve } from "node:path";
import { z } from "zod";
import { discoverLatestRelease, downloadArchive, loadFoods } from "./fndds";
import { selectFoods } from "./select";
import { addStapleAliases, stapleNamesInPriorityOrder, stapleSchema, validateStaples } from "./staples";

const seedFoodSchema = z.object({
  sourceIdentifier: z.string(),
  name: z.string(),
  aliases: z.array(z.string()),
  servingDescription: z.string(),
  gramsPerServing: z.number().nullable(),
  caloriesPerServing: z.number(),
  proteinPerServing: z.number(),
  fatPerServing: z.number(),
  carbsPerServing: z.number(),
  saturatedFatPerServing: z.number().nullable(),
  fiberPerServing: z.number().nullable(),
  sugarsPerServing: z.number().nullable(),
  addedSugarsPerServing: z.number().nullable(),
  sodiumPerServing: z.number().nullable(),
  cholesterolPerServing: z.number().nullable(),
});

const seedFoodListSchema = z.array(seedFoodSchema);

type SeedFood = z.infer<typeof seedFoodSchema>;

const root = resolve(import.meta.dir, "../../..");

const outputDirectory = resolve(root, "cal-macro-tracker/CommonFoods");

const manifestPath = resolve(outputDirectory, "common_foods_manifest.json");

const staplesPath = resolve(import.meta.dir, "../staples.json");

const legacyFoods = z.array(z.object({
  sourceIdentifier: z.string(),
  name: z.string(),
  aliases: z.array(z.string()),
  sourcePrefix: z.string(),
  servingDescription: z.string(),
  gramsPerServing: z.number().nullable(),
  caloriesPerServing: z.number(),
  proteinPerServing: z.number(),
  fatPerServing: z.number(),
  carbsPerServing: z.number(),
  saturatedFatPerServing: z.number().nullable(),
  fiberPerServing: z.number().nullable(),
  sugarsPerServing: z.number().nullable(),
  addedSugarsPerServing: z.number().nullable(),
  sodiumPerServing: z.number().nullable(),
  cholesterolPerServing: z.number().nullable(),
})).parse(JSON.parse(
  await readFile(resolve(import.meta.dir, "../legacy-foods.json"), "utf8"),
));

const buildArguments = process.argv.slice(2);

const releaseArgumentIndex = buildArguments.indexOf("--release");

const requestedRelease = releaseArgumentIndex < 0 ? undefined : buildArguments[releaseArgumentIndex + 1];

if (releaseArgumentIndex >= 0 && (!requestedRelease || buildArguments.indexOf("--release", releaseArgumentIndex + 1) >= 0)) {
  throw new Error("Usage: bun run build -- --release <recorded release name>");
}

const recordedManifestSchema = z.object({
  source: z.string(),
  sourceRelease: z.string(),
  generatedAt: z.string(),
  sourceArchiveSha256: z.string().optional(),
});

const existingManifest = await Bun.file(manifestPath).exists()
  ? recordedManifestSchema.parse(JSON.parse(await readFile(manifestPath, "utf8")))
  : undefined;

const release = requestedRelease
  ? (() => {
      if (existingManifest?.sourceRelease !== requestedRelease || !existingManifest.sourceArchiveSha256) {
        throw new Error(`Release "${requestedRelease}" is not recorded in ${manifestPath}.`);
      }

      return {
        url: existingManifest.source,
        release: existingManifest.sourceRelease,
        date: existingManifest.generatedAt,
      };
    })()
  : await discoverLatestRelease();

const archivePath = await downloadArchive(release);

const sourceArchiveSha256 = createHash("sha256").update(await readFile(archivePath)).digest("hex");

if (requestedRelease && existingManifest?.sourceArchiveSha256 !== sourceArchiveSha256) {
  throw new Error(`Cached archive for ${requestedRelease} does not match its recorded SHA-256.`);
}

const rawFoods = await loadFoods(archivePath);

const selectedFoods = selectFoods(rawFoods);

const retainedFoods = legacyFoods.map((legacyFood) => {
  const sourceRow = rawFoods
    .filter(({ description }) =>
      description.toLowerCase().startsWith(legacyFood.sourcePrefix)
      && !/\b(?:nfs|ns as to)\b/i.test(description)
    )[0];

  const matching = sourceRow ? selectFoods([sourceRow], 0)[0] : undefined;

  if (!matching) throw new Error(`Could not find source record for legacy food: ${legacyFood.name}`);

  return {
    ...matching,
    sourceIdentifier: legacyFood.sourceIdentifier,
    name: String(legacyFood.name),
    aliases: [...new Set([...matching.aliases, ...legacyFood.aliases])],
    servingDescription: legacyFood.servingDescription,
    gramsPerServing: legacyFood.gramsPerServing,
    caloriesPerServing: legacyFood.caloriesPerServing,
    proteinPerServing: legacyFood.proteinPerServing,
    fatPerServing: legacyFood.fatPerServing,
    carbsPerServing: legacyFood.carbsPerServing,
    saturatedFatPerServing: legacyFood.saturatedFatPerServing,
    fiberPerServing: legacyFood.fiberPerServing,
    sugarsPerServing: legacyFood.sugarsPerServing,
    addedSugarsPerServing: legacyFood.addedSugarsPerServing,
    sodiumPerServing: legacyFood.sodiumPerServing,
    cholesterolPerServing: legacyFood.cholesterolPerServing,
  };
});

const retainedIDs = new Set(retainedFoods.flatMap(({ fdcId }) => fdcId === undefined ? [] : [fdcId]));

const retainedNames = new Set(retainedFoods.map(({ name }) => String(name).toLowerCase()));

const remainingFoods = selectedFoods.filter(({ fdcId, name }) =>
  !retainedIDs.has(fdcId) && !retainedNames.has(name.toLowerCase()),
);

const foods = [...retainedFoods, ...remainingFoods.slice(0, 3300 - retainedFoods.length)];

const jsonFoods: SeedFood[] = seedFoodListSchema.parse(foods.map(({ fdcId: _fdcId, ...food }) => food));

if (new Set(jsonFoods.map(({ sourceIdentifier }) => sourceIdentifier)).size !== jsonFoods.length) {
  throw new Error("Generated common foods must have unique source identifiers.");
}

if (jsonFoods.some(({ sourceIdentifier, name }) =>
  !(sourceIdentifier.startsWith("legacy:")
    ? /^legacy:[a-z0-9-]+$/.test(sourceIdentifier)
    : /^fndds:\d{8}$/.test(sourceIdentifier))
  || name.length > 60
  || name.split(",").length > 4
)) {
  throw new Error("Generated common foods must have valid identifiers and display names of at most four segments and 60 characters.");
}

if (new Set(jsonFoods.map(({ name }) => name.normalize("NFKC").toLowerCase())).size !== jsonFoods.length) {
  throw new Error("Generated common foods must have unique display names.");
}

const staples = validateStaples(
  z.array(stapleSchema).parse(JSON.parse(await readFile(staplesPath, "utf8"))),
  jsonFoods,
);

const foodsWithStapleAliases = addStapleAliases(staples, jsonFoods);

const json = `${JSON.stringify(foodsWithStapleAliases, null, 2)}\n`;

if (Buffer.byteLength(json) >= 2_000_000) throw new Error("Generated common foods JSON exceeds 2 MB.");

if (foods.length < 2500 || foods.length > 3500) throw new Error(`Generated ${foods.length} foods, expected 2,500–3,500.`);

if (jsonFoods.some(({ caloriesPerServing, proteinPerServing, fatPerServing, carbsPerServing }) =>
  caloriesPerServing === null || proteinPerServing === null || fatPerServing === null || carbsPerServing === null
)) {
  throw new Error("FNDDS has a missing required macro. Do not produce a seed that fails app decoding.");
}

const manifest = {
  version: `fndds-${release.date}-${createHash("sha256").update(json).update(JSON.stringify(staples)).digest("hex").slice(0, 12)}`,
  source: release.url,
  sourceRelease: release.release,
  sourceArchiveSha256,
  count: foods.length,
  generatedAt: release.date,
  staples: stapleNamesInPriorityOrder(staples),
};

await mkdir(outputDirectory, { recursive: true });

await writeFile(resolve(outputDirectory, "common_foods.json"), json);

await writeFile(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);

const fallbackPortionCount = selectedFoods.filter(({ usedFallbackPortion }) => usedFallbackPortion).length;

console.info(
  `Wrote ${foods.length} foods (${Buffer.byteLength(json)} bytes) from ${release.release}; `
  + `${fallbackPortionCount} use the 100 g fallback.`,
);
