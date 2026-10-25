import { mkdirSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { parse } from "csv-parse";
import yauzl from "yauzl";
import { z } from "zod";
import type { FoodRow } from "./select";

export const downloadPageUrl = "https://fdc.nal.usda.gov/download-datasets";

export type FNDDSRelease = {
  url: string;
  release: string;
  date: string;
};

const csvRowSchema = z.record(z.string(), z.string());

type CSVRow = z.infer<typeof csvRowSchema>;

export async function discoverLatestRelease(): Promise<FNDDSRelease> {
  const response = await fetch(downloadPageUrl);

  if (!response.ok) throw new Error(`Could not verify latest USDA FNDDS download: ${response.status}`);
  const html = await response.text();

  const releases = Array.from(
    html.matchAll(/<a\b[^>]*href="([^"]*FoodData_Central_survey_food_csv_(\d{4}-\d{2}-\d{2})\.zip)"[^>]*>([\s\S]*?)<\/a>/gi),
    ([, path, date, label]) => ({ path, date, label }),
  );

  const latest = releases[0];

  if (!latest?.path || !latest.date || !latest.label) {
    throw new Error(`USDA download page does not list an FNDDS CSV release: ${downloadPageUrl}`);
  }

  const releaseLabel = latest.label.replace(/<[^>]*>/g, " ").replace(/\s+/g, " ").trim();
  const years = releaseLabel.match(/FNDDS\s+(\d{4})-(\d{4})/i);

  if (!years) throw new Error(`Could not read FNDDS cycle from USDA release label: ${releaseLabel}`);
  const month = new Date(`${latest.date}T00:00:00Z`).toLocaleString("en-US", { month: "long", timeZone: "UTC" });

  return {
    url: new URL(latest.path, "https://fdc.nal.usda.gov").toString(),
    release: `FNDDS ${years[1]}–${years[2]} (${month} ${latest.date.slice(0, 4)})`,
    date: latest.date,
  };
}

export async function loadFoods(archivePath: string): Promise<FoodRow[]> {
  const foodByID = new Map<number, FoodRow>();
  const canonicalNutrientByNumber = new Map<number, number>();
  await forEachCsvRow(archivePath, /(?:^|\/)nutrient\.csv$/i, (row) => {
    const id = numberValue(row.id);
    const nutrientNumber = numberValue(row.nutrient_nbr);

    if (id !== undefined && nutrientNumber !== undefined) canonicalNutrientByNumber.set(nutrientNumber, id);
  });
  await forEachCsvRow(archivePath, /(?:^|\/)food\.csv$/i, (row) => {
    const id = numberValue(row.fdc_id);
    const description = row.description?.trim();

    if (id === undefined || !description) return;
    foodByID.set(id, {
      fdcId: id,
      description,
      category: row.wweia_category_code ?? row.food_category_id ?? "",
      portions: [],
      nutrients: new Map(),
    });
  });

  const categories = new Map<string, string>();
  await forEachCsvRow(archivePath, /(?:^|\/)wweia_food_category\.csv$/i, (row) => {
    if (row.wweia_food_category && row.wweia_food_category_description) {
      categories.set(row.wweia_food_category, row.wweia_food_category_description);
    }
  });
  const categoryByFoodID = new Map<number, string>();
  await forEachCsvRow(archivePath, /(?:^|\/)survey_fndds_food\.csv$/i, (row) => {
    const id = numberValue(row.fdc_id);

    if (id !== undefined && row.wweia_category_number) categoryByFoodID.set(id, row.wweia_category_number);
  });

  for (const food of foodByID.values()) {
    food.category = categories.get(categoryByFoodID.get(food.fdcId) ?? "") ?? food.category;
  }

  await forEachCsvRow(archivePath, /(?:^|\/)food_nutrient\.csv$/i, (row) => {
    const food = foodByID.get(numberValue(row.fdc_id) ?? -1);
    const nutrientID = canonicalNutrientByNumber.get(numberValue(row.nutrient_id) ?? -1);
    const amount = numberValue(row.amount);

    if (food && nutrientID !== undefined && amount !== undefined) {
      food.nutrients.set(nutrientID, amount);
    }
  });
  await forEachCsvRow(archivePath, /(?:^|\/)food_portion\.csv$/i, (row) => {
    const food = foodByID.get(numberValue(row.fdc_id) ?? -1);
    const description = row.portion_description?.trim();
    const gramWeight = numberValue(row.gram_weight);

    if (food && description && gramWeight !== undefined && gramWeight > 0) {
      food.portions.push({ description, gramWeight });
    }
  });

  return [...foodByID.values()];
}

export async function downloadArchive(release: FNDDSRelease): Promise<string> {
  const cacheDirectory = join(homedir(), "Library", "Caches", "macros-food-db");
  mkdirSync(cacheDirectory, { recursive: true });
  const archivePath = join(cacheDirectory, `fndds-${release.date}.zip`);
  const existing = Bun.file(archivePath);

  if (await existing.exists()) return archivePath;

  const response = await fetch(release.url);

  if (!response.ok || !response.body) throw new Error(`USDA download failed: ${response.status} (${release.url})`);
  await Bun.write(archivePath, response);

  return archivePath;
}

async function forEachCsvRow(archivePath: string, filename: RegExp, visit: (row: CSVRow) => void): Promise<void> {
  const { zip, entries } = await openZip(archivePath);

  try {
    const entry = entries.find(({ fileName }) => filename.test(fileName));

    if (!entry) throw new Error(`Missing ${filename} in ${archivePath}`);
    const stream = await openEntry(zip, entry);

    for await (const record of stream.pipe(parse({ columns: true, bom: true, skip_empty_lines: true, relax_column_count: true }))) {
      // SAFETY: csv-parse returns keyed string fields because `columns: true` is set.
      visit(csvRowSchema.parse(record));
    }
  } finally {
    zip.close();
  }
}

type ZipFile = yauzl.ZipFile;

type ZipEntry = yauzl.Entry;

function openZip(path: string): Promise<{ zip: ZipFile; entries: ZipEntry[] }> {
  return new Promise((resolve, reject) => {
    yauzl.open(path, { lazyEntries: true, autoClose: false }, (error, zip) => {
      if (error || !zip) reject(error ?? new Error("Could not open USDA archive"));
      else {
        const entries: ZipEntry[] = [];
        zip.on("entry", (entry) => {
          entries.push(entry);
          zip.readEntry();
        });
        zip.on("end", () => resolve({ zip, entries }));
        zip.on("error", reject);
        zip.readEntry();
      }
    });
  });
}

function openEntry(zip: ZipFile, entry: ZipEntry): Promise<NodeJS.ReadableStream> {
  return new Promise((resolve, reject) => {
    zip.openReadStream(entry, (error, stream) => {
      if (error || !stream) reject(error ?? new Error(`Could not read ${entry.fileName}`));
      else resolve(stream);
    });
  });
}

function numberValue(value: string | undefined): number | undefined {
  if (value === undefined || value.trim() === "") return undefined;
  const number = Number(value);

  return Number.isFinite(number) ? number : undefined;
}
