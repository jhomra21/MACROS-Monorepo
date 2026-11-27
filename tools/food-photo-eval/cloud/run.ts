import { mkdir, mkdtemp, readFile, readdir, rm, writeFile } from "node:fs/promises";
import { basename, extname, join, resolve } from "node:path";
import { tmpdir } from "node:os";

// Model IDs and REST contracts: https://ai.google.dev/gemini-api/docs/models,
// https://ai.google.dev/gemini-api/docs/generate-content/image-understanding,
// https://ai.google.dev/gemini-api/docs/generate-content/structured-output
const GEMINI_MODELS = ["gemini-3.5-flash-lite", "gemini-3.8-flash"];
// GPT-5.4 mini and Responses API schema/image contract:
// https://developers.openai.com/api/docs/models/gpt-5.4-mini
// https://developers.openai.com/api/docs/guides/structured-outputs
const OPENAI_MODEL = "gpt-5.4-mini";
// Clairic vision and account REST endpoint:
// https://developers.cloudflare.com/workers-ai/models/clairic/
const CLOUDFLARE_MODEL = "@cf/cloudflare/clairic";
const ROOT = resolve(import.meta.dir, "..");
const SCHEMA = JSON.parse(await readFile(join(ROOT, "schema.json"), "utf8"));
const PROMPT = (await readFile(join(ROOT, "prompt.md"), "utf8")).trim();
const IMAGE_EXTENSIONS = new Set([".jpg", ".jpeg", ".png", ".heic", ".webp"]);
const dryRun = Bun.argv.includes("--dry-run");
const datasetArg = Bun.argv.find((arg) => arg.startsWith("--dataset="))?.split("=")[1]
  ?? valueAfter("--dataset")
  ?? "dataset";
const dataset = resolve(process.cwd(), datasetArg);
const resultsRoot = resolve(process.cwd(), "results");

function valueAfter(flag: string): string | undefined {
  const index = Bun.argv.indexOf(flag);
  return index >= 0 ? Bun.argv[index + 1] : undefined;
}

type Image = { id: string; path: string };
type Usage = { inputTokens: number | null; outputTokens: number | null };

async function imagesIn(folder: string): Promise<Image[]> {
  const entries = await readdir(folder, { withFileTypes: true });
  return entries
    .filter((entry) => entry.isFile() && IMAGE_EXTENSIONS.has(extname(entry.name).toLowerCase()))
    .map((entry) => ({ id: basename(entry.name, extname(entry.name)), path: join(folder, entry.name) }))
    .sort((a, b) => a.id.localeCompare(b.id));
}

async function jpeg1024(source: string): Promise<{ path: string; cleanup: () => Promise<void> }> {
  const directory = await mkdtemp(join(tmpdir(), "food-photo-eval-"));
  const output = join(directory, "image.jpg");
  if (process.platform === "darwin") {
    await Bun.$`sips -s format jpeg -Z 1024 ${source} --out ${output}`.quiet();
  } else {
    // Same result as sips -Z 1024: longest side scaled to 1024 px, JPEG output.
    const scale = "scale='if(gte(iw,ih),1024,-2)':'if(gte(iw,ih),-2,1024)'";
    await Bun.$`ffmpeg -y -loglevel error -i ${source} -vf ${scale} -q:v 2 ${output}`.quiet();
  }
  return { path: output, cleanup: () => rm(directory, { recursive: true, force: true }) };
}

function isResult(value: unknown): boolean {
  if (!value || typeof value !== "object" || Array.isArray(value)) return false;
  const result = value as Record<string, unknown>;
  const status = ["ok", "not_food", "unclear", "packaged"].includes(String(result.status));
  if (Object.keys(result).length !== 2 || !status || !Array.isArray(result.foods)) return false;
  const required = ["name", "grams", "lowGrams", "highGrams", "preparation", "hiddenFatLikely", "volumeMl", "foodKey"];
  return result.foods.every((food) => {
    if (!food || typeof food !== "object" || Array.isArray(food)) return false;
    const item = food as Record<string, unknown>;
    return Object.keys(item).length === required.length
      && required.every((key) => Object.hasOwn(item, key))
      && typeof item.name === "string"
      && [item.grams, item.lowGrams, item.highGrams, item.volumeMl].every((number) => number === null || typeof number === "number")
      && (item.preparation === null || typeof item.preparation === "string")
      && typeof item.hiddenFatLikely === "boolean"
      && (item.foodKey === null || typeof item.foodKey === "string");
  });
}

async function save(arm: string, image: Image, response: {
  model: string; latencyMs: number | null; rawOutput: string; usage: Usage; schemaValid: boolean; error?: string;
  providerRawOutput?: string;
}): Promise<void> {
  const folder = join(resultsRoot, arm);
  await mkdir(folder, { recursive: true });
  await writeFile(join(folder, `${image.id}.json`), `${JSON.stringify({
    photoId: image.id,
    arm,
    model: response.model,
    latencyMs: response.latencyMs,
    tokenUsage: response.usage,
    rawOutput: response.rawOutput,
    ...(response.providerRawOutput ? { providerRawOutput: response.providerRawOutput } : {}),
    schemaValid: response.schemaValid,
    ...(response.error ? { error: response.error } : {}),
    recordedAt: new Date().toISOString()
  }, null, 2)}\n`);
}

async function requestGemini(image: Image, model: string, key: string): Promise<void> {
  const processed = await jpeg1024(image.path);
  const started = performance.now();
  try {
    const bytes = await readFile(processed.path);
    const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-goog-api-key": key },
      body: JSON.stringify({
        contents: [{ parts: [
          { inlineData: { mimeType: "image/jpeg", data: bytes.toString("base64") } },
          { text: PROMPT }
        ] }],
        generationConfig: { responseMimeType: "application/json", responseJsonSchema: SCHEMA }
      })
    });
    const body = await response.json() as {
      candidates?: Array<{ content?: { parts?: Array<{ text?: string }> } }>;
      usageMetadata?: { promptTokenCount?: number; candidatesTokenCount?: number };
      error?: { message?: string };
    };
    const raw = body.candidates?.[0]?.content?.parts?.map((part) => part.text ?? "").join("") ?? "";
    let parsed: unknown;
    try { parsed = JSON.parse(raw); } catch { /* preserve malformed output for scoring */ }
    await save(`gemini-${model}`, image, {
      model, latencyMs: performance.now() - started, rawOutput: raw,
      usage: { inputTokens: body.usageMetadata?.promptTokenCount ?? null, outputTokens: body.usageMetadata?.candidatesTokenCount ?? null },
      schemaValid: response.ok && isResult(parsed),
      ...(!response.ok ? { error: body.error?.message ?? `HTTP ${response.status}` } : {})
    });
  } finally {
    await processed.cleanup();
  }
}

async function requestOpenAI(image: Image, key: string): Promise<void> {
  const processed = await jpeg1024(image.path);
  const started = performance.now();
  try {
    const bytes = await readFile(processed.path);
    const response = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        model: OPENAI_MODEL,
        input: [{ role: "user", content: [
          { type: "input_text", text: PROMPT },
          { type: "input_image", image_url: `data:image/jpeg;base64,${bytes.toString("base64")}`, detail: "high" }
        ] }],
        text: { format: { type: "json_schema", name: "meal_photo_estimate", strict: true, schema: SCHEMA } }
      })
    });
    const body = await response.json() as {
      output_text?: string;
      output?: Array<{ content?: Array<{ text?: string }> }>;
      usage?: { input_tokens?: number; output_tokens?: number };
      error?: { message?: string };
    };
    const raw = body.output_text ?? body.output?.flatMap((item) => item.content ?? []).map((part) => part.text ?? "").join("") ?? "";
    let parsed: unknown;
    try { parsed = JSON.parse(raw); } catch { /* preserve malformed output for scoring */ }
    await save("openai-gpt-5.4-mini", image, {
      model: OPENAI_MODEL, latencyMs: performance.now() - started, rawOutput: raw,
      usage: { inputTokens: body.usage?.input_tokens ?? null, outputTokens: body.usage?.output_tokens ?? null },
      schemaValid: response.ok && isResult(parsed),
      ...(!response.ok ? { error: body.error?.message ?? `HTTP ${response.status}` } : {})
    });
  } finally {
    await processed.cleanup();
  }
}

async function requestCloudflare(image: Image, accountId: string, token: string): Promise<void> {
  const processed = await jpeg1024(image.path);
  const started = performance.now();
  try {
    const bytes = await readFile(processed.path);
    const response = await fetch(`https://api.cloudflare.com/client/v4/accounts/${accountId}/ai/run/${CLOUDFLARE_MODEL}`, {
      method: "POST",
      headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        model: "clairic",
        state: PROMPT,
        images: [{ content_type: "image/jpeg", base64: bytes.toString("base64") }],
        fields: {
          status: { type: "enum", enum: ["ok", "not_food", "unclear", "packaged"] },
          foods: {
            type: "list",
            instructions: "Each list item is one visible food. Do not include calories. Use null for unknown values.",
            items: {
              type: "object",
              properties: {
                name: { type: "text" },
                grams: { type: "number" },
                lowGrams: { type: "number" },
                highGrams: { type: "number" },
                preparation: { type: "text" },
                hiddenFatLikely: { type: "boolean" },
                volumeMl: { type: "number" },
                foodKey: { type: "text" }
              }
            }
          }
        }
      })
    });
    const body = await response.json() as {
      result?: { answers?: Record<string, { value?: unknown }> ; usage?: { input_tokens?: number; output_tokens?: number } };
      success?: boolean;
      errors?: Array<{ message?: string }>;
    };
    const answers = body.result?.answers ?? {};
    const list = answers.foods?.value;
    const foods = Array.isArray(list) ? list : [];
    const raw = JSON.stringify({ status: answers.status?.value ?? "unclear", foods });
    const parsed = JSON.parse(raw);
    await save("cloudflare-clairic", image, {
      model: CLOUDFLARE_MODEL, latencyMs: performance.now() - started, rawOutput: raw,
      usage: { inputTokens: body.result?.usage?.input_tokens ?? null, outputTokens: body.result?.usage?.output_tokens ?? null },
      schemaValid: response.ok && body.success !== false && Array.isArray(list) && foods.length === list.length && isResult(parsed),
      providerRawOutput: JSON.stringify(body),
      ...(!response.ok || body.success === false ? { error: body.errors?.map((error) => error.message).join("; ") || `HTTP ${response.status}` } : {})
    });
  } finally {
    await processed.cleanup();
  }
}

// Rate limits and overload responses are retried with linear backoff; anything else is recorded as-is.
const TRANSIENT = /quota|rate|high demand|overloaded|unavailable|HTTP (429|500|503)/i;
const MAX_ATTEMPTS = 6;
const resume = Bun.argv.includes("--resume");

function resultFile(arm: string, image: Image): string {
  return join(resultsRoot, arm, `${image.id}.json`);
}

async function readSaved(arm: string, image: Image): Promise<{ schemaValid?: boolean; error?: string } | null> {
  try { return JSON.parse(await readFile(resultFile(arm, image), "utf8")); } catch { return null; }
}

async function savedValid(name: string, image: Image): Promise<boolean> {
  return (await readSaved(armFolder(name), image))?.schemaValid === true;
}

async function savedError(name: string, image: Image): Promise<string | undefined> {
  return (await readSaved(armFolder(name), image))?.error;
}

// Gemini arms save under "gemini-<model>"; other arms save under their own name.
function armFolder(name: string): string {
  return GEMINI_MODELS.includes(name) ? `gemini-${name}` : name;
}

const photos = await imagesIn(join(dataset, "photos")).catch(() => []);
if (photos.length === 0) console.log(`No photos found in ${join(dataset, "photos")}.`);
const arms = [
  ...GEMINI_MODELS.map((model) => ({
    name: model, key: process.env.GEMINI_API_KEY,
    run: (photo: Image) => requestGemini(photo, model, process.env.GEMINI_API_KEY!)
  })),
  {
    name: "openai-gpt-5.4-mini", key: process.env.OPENAI_API_KEY,
    run: (photo: Image) => requestOpenAI(photo, process.env.OPENAI_API_KEY!)
  },
  {
    name: "cloudflare-clairic",
    key: process.env.CLOUDFLARE_ACCOUNT_ID && process.env.CLOUDFLARE_API_TOKEN,
    run: (photo: Image) => requestCloudflare(photo, process.env.CLOUDFLARE_ACCOUNT_ID!, process.env.CLOUDFLARE_API_TOKEN!)
  }
];
for (const arm of arms) {
  if (!arm.key) {
    console.log(`Skipped ${arm.name}: required credential(s) missing.`);
    continue;
  }
  if (dryRun) {
    console.log(`Dry run: ${arm.name} would process ${photos.length} photo(s).`);
    continue;
  }
  for (const photo of photos) {
    if (resume && await savedValid(arm.name, photo)) continue;
    try {
      for (let attempt = 1; ; attempt++) {
        await arm.run(photo);
        const error = await savedError(arm.name, photo);
        if (!error || !TRANSIENT.test(error) || attempt === MAX_ATTEMPTS) break;
        console.log(`Retrying ${arm.name}/${photo.id} (attempt ${attempt + 1}): ${error.slice(0, 80)}`);
        await Bun.sleep(15_000 * attempt);
      }
      console.log(`Saved ${arm.name}/${photo.id}.json`);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      await save(arm.name, photo, {
        model: arm.name, latencyMs: null, rawOutput: "", usage: { inputTokens: null, outputTokens: null },
        schemaValid: false, error: message
      });
      console.error(`Failed ${arm.name}/${photo.id}: ${message}`);
    }
  }
}
