import assert from "node:assert/strict";
import { Miniflare, createFetchMock } from "miniflare";
import type { MiniflareOptions } from "miniflare";
import { build } from "esbuild";
import * as jose from "jose";
import { z } from "zod";
import { createHash } from "node:crypto";
import { readFile, writeFile, mkdir } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { resolve } from "node:path";
import { serve, type LocalServer } from "./native-http.ts";
import { assertIncompleteOpenFoodFactsItem, assertNoResponseLeak, readRuntimeResponse, responseBody, responseResults } from "./response-contract.ts";

const root = fileURLToPath(new URL("../../", import.meta.url));

const outputDir = resolve(process.env.QA_OUTPUT_DIR ?? `${root}/build/runtime-qa`);

const buildDir = resolve(root, "build");

if (outputDir !== buildDir && !outputDir.startsWith(`${buildDir}/`)) {
  throw new Error("QA_OUTPUT_DIR must be under the repository's ignored build directory.");
}

await mkdir(outputDir, { recursive: true });

const fixtureTimers = new Set<ReturnType<typeof setTimeout>>();

const fixtureClosers = new Set<() => void>();

type FixturePhase = "headers" | "body" | "hang-headers" | "hang-body" | "success";

const fixturePayloadSchema = z.json();

type FixturePayload = z.infer<typeof fixturePayloadSchema>;

const fixturePhaseSchema = z.enum(["headers", "body", "hang-headers", "hang-body", "success"]);

const tokenResponseSchema = z.object({ token: z.string(), expiresAt: z.number() });

const jwksResponseSchema = z.object({
  keys: z.array(z.object({
    kty: z.literal("RSA"),
    n: z.string(),
    e: z.string(),
    kid: z.string(),
    alg: z.literal("RS256"),
    use: z.literal("sig"),
    d: z.string().optional(),
  })),
});

function fixtureResponse(data: FixturePayload, phase: FixturePhase): Promise<Response> | Response {
  const text = JSON.stringify(data);

  if (phase === "success") return Response.json(data);

  // Deliberately stalled fixtures are settled at owner cleanup, never by real upstream.
  if (phase === "hang-headers") return new Promise(resolve => fixtureClosers.add(() => resolve(new Response(null, { status: 503 }))));

  if (phase === "hang-body") {
    let close: () => void;

    return new Response(new ReadableStream({
      start(controller) { close = () => controller.error(new Error("Fixture disposed.")); fixtureClosers.add(close); },
      cancel() { fixtureClosers.delete(close); },
    }), { headers: { "content-type": "application/json" } });
  }

  const later = (done: () => void) => { const timer = setTimeout(() => { fixtureTimers.delete(timer); done(); }, 3600); fixtureTimers.add(timer);

 return timer; };

  if (phase === "headers") return new Promise(resolve => later(() => resolve(Response.json(data))));
  let timer: ReturnType<typeof setTimeout>;

  return new Response(new ReadableStream({ start(controller) { timer = later(() => { controller.enqueue(new TextEncoder().encode(text)); controller.close(); }); }, cancel() { clearTimeout(timer); fixtureTimers.delete(timer); } }), { headers: { "content-type": "application/json" } });
}

const checks: { label: string; transport: string }[] = [];

const findings: string[] = [];

const timingDiagnostics: { label: string; elapsedMs: number }[] = [];

const runtimes: InstanceType<typeof Miniflare>[] = [];

const servers: LocalServer[] = [];

const mocks: ReturnType<typeof createFetchMock>[] = [];

let httpRequests = 0;

function pass(label: string) { checks.push({ label, transport: "native HTTP loopback -> Miniflare original worker" }); }

async function runtime(entry: string, options: Partial<MiniflareOptions>) {
  const output = await build({ entryPoints: [`${root}/${entry}`], bundle: true, format: "esm", platform: "browser", write: false });

  const runtimeOptions: MiniflareOptions = {
    rootPath: outputDir, cf: false, modules: true, script: output.outputFiles[0].text, compatibilityDate: "2026-05-01",
  };

  if (options.fetchMock == null && options.outboundService == null) {
    runtimeOptions.outboundService = () => { throw new Error("Unmatched outbound traffic."); };
  }

  Object.assign(runtimeOptions, options);

  const mf = new Miniflare(runtimeOptions);

  runtimes.push(mf);

  const server = serve({ hostname: "127.0.0.1", port: 0, async fetch(req) {
    const response = await mf.dispatchFetch(req.url, { redirect: "manual", method: req.method, headers: Object.fromEntries(req.headers), body: req.method === "GET" ? undefined : await req.arrayBuffer() });

    return new Response(await response.arrayBuffer(), { status: response.status, headers: Object.fromEntries(response.headers) });
  } });

  servers.push(server);
  await server.ready;

  return { mf, url: `http://127.0.0.1:${server.port}` };
}

const post = (body: FixturePayload) => ({ method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify(body) });

async function request(url: string, path: string, init?: RequestInit) {
  httpRequests++;
  const response = await fetch(url + path, { ...init, redirect: "manual", signal: AbortSignal.timeout(12000) });

  return readRuntimeResponse(response);
}

try {
  const section = process.env.QA_SECTION;
  const pair = await jose.generateKeyPair("RS256", { extractable: true });
  const jwk = { ...await jose.exportJWK(pair.publicKey), kid: "qa-key", alg: "RS256", use: "sig" };
  const profileKey = "A".repeat(32), raw = "B".repeat(32);
  const hash = createHash("sha256").update(`${profileKey}.${raw}`).digest("hex");
  let bootstrapMode: number | "malformed" | "invalid-shape" | "invalid-contract" = 200, bootstrapCalls = 0;
  let bootstrapPayload: FixturePayload;

  const bootstrap = async (req: Request) => {
    assert.equal(req.url, "https://bootstrap.qa.invalid/bootstrap");
    bootstrapCalls++;
    const bodyText = await req.text();
    const body = JSON.parse(bodyText);
    assert.equal(body.secretHash, hash); assert.equal(body.profileSecret, undefined); assert(!bodyText.includes(raw));

    const bootstrapStatusResult = z.number().safeParse(bootstrapMode);
    const bootstrapStatus = bootstrapStatusResult.success ? bootstrapStatusResult.data : 200;

    return new Response(bootstrapMode === "malformed" ? "{" : JSON.stringify(bootstrapMode === "invalid-shape" ? {} : bootstrapMode === "invalid-contract" ? bootstrapPayload : bootstrapMode === 200 ? { profileKey, displayName: "QA", deleted: false } : { secret: "upstream-private-detail" }),
      { status: bootstrapStatus, headers: { "content-type": "application/json" } });
  };

  const auth = await runtime("worker/auth/src/index.ts", { outboundService: bootstrap, bindings: {
    CONVEX_BOOTSTRAP_URL: "https://bootstrap.qa.invalid/bootstrap", CONVEX_BOOTSTRAP_SECRET: "qa-synthetic-only",
    JWT_PRIVATE_KEY_PKCS8: await jose.exportPKCS8(pair.privateKey), JWT_PUBLIC_JWKS: JSON.stringify({ keys: [jwk] }),
    JWT_ISSUER: "https://auth.qa.invalid", JWT_AUDIENCE: "convex", JWT_KEY_ID: "qa-key", ASTRO_REDIRECT_URL: "https://web.qa.invalid",
  } });

  const tokenResult = await request(auth.url, "/v1/token", post({ profileKey, profileSecret: raw }));
  assert.equal(tokenResult.status, 200);
  const token = tokenResponseSchema.parse(responseBody(tokenResult));
  const keys = jwksResponseSchema.parse(responseBody(await request(auth.url, "/.well-known/jwks.json")));
  assert.equal(keys.keys[0].d, undefined);
  const verified = await jose.jwtVerify(token.token, jose.createLocalJWKSet(keys), { issuer: "https://auth.qa.invalid", audience: "convex" });
  assert.equal(verified.payload.sub, profileKey); assert.equal(verified.protectedHeader.kid, "qa-key");
  assert.equal(verified.payload.exp! - verified.payload.iat!, 86400);
  assert.equal(token.expiresAt, verified.payload.exp! * 1000);
  pass("auth success, hashed bootstrap boundary, public JWKS and verified JWT claims");
  await assert.rejects(jose.jwtVerify(token.token, pair.publicKey, { audience: "wrong" }));
  await assert.rejects(jose.jwtVerify(token.token, pair.publicKey, { currentDate: new Date(verified.payload.exp! * 1000) }));
  const rotated = await jose.generateKeyPair("RS256");
  await assert.rejects(jose.jwtVerify(token.token, rotated.publicKey));
  pass("JWT wrong audience, exact expiry and different signing key rejected");

  for (const mode of [401, 500, "malformed"] as const) {
    bootstrapMode = mode;
    const result = await request(auth.url, "/v1/token", post({ profileKey, profileSecret: raw }));
    assert.equal(result.status, 500); assert.deepEqual(responseBody(result), { error: "Request failed." });
    pass(`auth upstream ${mode} generic failure`);
  }

  assert.equal(bootstrapCalls, 4);
  bootstrapMode = "invalid-shape";
  const invalidProfile = await request(auth.url, "/v1/token", post({ profileKey, profileSecret: raw }));

  if (section !== "deadlines" && section !== "auth-deadline") {
  assert.equal(invalidProfile.status, 500);
  assert.deepEqual(responseBody(invalidProfile), { error: "Request failed." });
  pass("invalid bootstrap object rejected");

  for (const payload of [null, [], { profileKey: "Z".repeat(32), displayName: "QA", deleted: false },
    { profileKey, displayName: "", deleted: false }, { profileKey, displayName: "x".repeat(41), deleted: false },
    { profileKey, displayName: "QA\u200b", deleted: false }, { profileKey, displayName: " QA ", deleted: false },
    { profileKey, displayName: "QA", deleted: "false" }, { profileKey, displayName: "QA", deleted: true }]) {
    bootstrapMode = "invalid-contract"; bootstrapPayload = payload;
    const rejected = await request(auth.url, "/v1/token", post({ profileKey, profileSecret: raw }));
    assert.equal(rejected.status, 500); assert.deepEqual(responseBody(rejected), { error: "Request failed." });
  }

  pass("bootstrap identity, normalized visible name and deletion contracts rejected");
  }


  const providers = createFetchMock(); providers.disableNetConnect(); mocks.push(providers);
  let mode = "success", upstreamCalls = 0;
  const offProduct = { code: "1234567890123", product_name: "QA cereal", brands: "QA", nutriments: { "energy-kcal_100g": 100, proteins_100g: 10, fat_100g: 2, carbohydrates_100g: 20 } };
  const usdaFood = { fdcId: 42, description: "QA cereal", brandName: "QA", servingSize: 30, servingSizeUnit: "g", foodNutrients: [{ nutrientId: 1008, value: 100 }, { nutrientId: 1003, value: 10 }, { nutrientId: 1004, value: 2 }, { nutrientId: 1005, value: 20 }] };

  for (const origin of ["https://api.nal.usda.gov", "https://search.openfoodfacts.org", "https://world.openfoodfacts.org", "https://world.openfoodfacts.net"]) {
    providers.get(origin).intercept({ path: /.*/, method: origin.includes("usda") ? "POST" : "GET" }).reply((options) => {
      upstreamCalls++;

      if (mode === "malformed") return { statusCode: 200, data: "{" };

      if (/^\d+$/.test(mode)) return { statusCode: Number(mode), data: "private-provider-detail" };
      const barcode = options.path.includes("/product/");

      const data = mode === "invalid-collections"
        ? { foods: {}, hits: {}, products: {}, totalHits: 100, page_count: 1, count: 1 }
        : mode === "null-collections"
          ? { foods: null, hits: null, products: null, totalHits: 100, page_count: 4, count: 20 }
          : mode === "missing-collections"
            ? { totalHits: 100, page_count: 4, count: 20 }
            : mode === "mixed-off-hits" && origin.includes("openfoodfacts") && !options.path.includes("/cgi/")
              ? { hits: [{ ...offProduct, product_name: "Mixed QA cereal" }, null, "invalid", []], page_count: 1, timed_out: true }
        : barcode ? (mode === "notfound" ? {} : { product: offProduct })
        : origin.includes("usda") ? { foods: mode === "empty" ? [] : [usdaFood, { fdcId: 43, description: "QA cereal incomplete" }], totalHits: 100 }
        : options.path.includes("/cgi/") ? { products: mode === "empty" ? [] : [offProduct], count: 100 }
        : { hits: mode === "empty" ? [{ ...offProduct, product_name: "unrelated food" }] : [offProduct, offProduct, { code: "1234567890999", product_name: "QA cereal incomplete" }], page_count: 4 };

      return { statusCode: 200, data: JSON.stringify(data), responseOptions: { headers: { "content-type": "application/json" } } };
    }).persist();
  }

  const usda = await runtime("worker/usda-proxy/src/index.ts", { fetchMock: providers, bindings: { USDA_API_KEY: "qa-only", OPEN_FOOD_FACTS_USER_AGENT: "QA-local" } });
  const search = "/v1/usda/search?q=QA%20cereal&pageSize=2";
  const result = await request(usda.url, search);
  assert.equal(result.status, 200); assert.equal(responseResults(result).length, 1); assert.equal(responseBody(result).hasMore, true);
  assert.equal(responseResults(result)[0].fdcId, 42);
  const calls = upstreamCalls; await request(usda.url, search); assert.equal(upstreamCalls, calls);
  await request(usda.url, "/v1/usda/search?q=otherquery&pageSize=2");
  assert(upstreamCalls > calls);
  const pageCalls = upstreamCalls;
  await request(usda.url, "/v1/usda/search?q=QA%20cereal&pageSize=2&page=2");
  assert(upstreamCalls > pageCalls);
  assert.equal(responseResults(result)[0].caloriesPerServing, 100);
  pass("USDA complete nutrition, incomplete result filtered, pagination and real runtime cache hit");
  const off = await request(usda.url, "/v1/packaged-foods/search?q=QA%20cereal&provider=openFoodFacts");
  assert.equal(off.status, 200); assert.equal(responseResults(off).length, 2); assert.equal(responseBody(off).resolvedProvider, "openFoodFacts");
  assertIncompleteOpenFoodFactsItem(off);
  const offCalls = upstreamCalls; await request(usda.url, "/v1/packaged-foods/search?q=QA%20cereal&provider=openFoodFacts"); assert.equal(upstreamCalls, offCalls);
  const isolated = await request(usda.url, "/v1/packaged-foods/search?q=QA%20cereal&provider=usda");
  assert.equal(responseBody(isolated).resolvedProvider, "usda"); assert(upstreamCalls > offCalls);
  pass("OFF positive deduplication/cache and cross-provider cache isolation");
  const detailsMock = providers.get("https://api.nal.usda.gov");
  detailsMock.intercept({ path: "/fdc/v1/food/42", method: "GET" }).reply(200, JSON.stringify({
    ...usdaFood, foodNutrients: usdaFood.foodNutrients.map(n => ({ nutrient: { id: n.nutrientId }, amount: n.value })),
  }), { headers: { "content-type": "application/json" } }).persist();
  const details = await request(usda.url, "/v1/usda/foods/42");
  assert.equal(details.status, 200); assert.equal(responseBody(details).fdcId, 42); assert.equal(responseBody(details).proteinPerServing, 10);
  pass("USDA food details real route normalizes detail nutrient shape");
  mode = "empty";
  const empty = await request(usda.url, "/v1/packaged-foods/search?q=filteredempty&page=2&provider=openFoodFacts");
  assert.equal(empty.status, 200); assert.equal(responseResults(empty).length, 0); assert.equal(responseBody(empty).hasMore, true);
  pass("filtered-empty OFF pagination preserves hasMore");

  for (const [provider, path, attempts, errorMessage] of [
    ["usda", "/v1/usda/search?q=invalidcollections&page=2&pageSize=2", 1, "USDA search is unavailable right now."],
    ["openFoodFacts", "/v1/packaged-foods/search?q=invalidcollections&provider=openFoodFacts", 2, "Open Food Facts is unavailable right now."],
  ] as const) {
    mode = "invalid-collections";
    const beforeFailure = upstreamCalls;
    const failed = await request(usda.url, path);
    assert.equal(failed.status, 503);
    assert.deepEqual(responseBody(failed), { error: errorMessage });
    assert.equal(upstreamCalls - beforeFailure, attempts);
    mode = "success";
    const beforeRecovery = upstreamCalls;
    const recovered = await request(usda.url, path);
    assert.equal(recovered.status, 200);
    assert(upstreamCalls > beforeRecovery);
    pass(`${provider} invalid collection is non-cacheable, controlled 503 and same-route recovery`);
  }

  for (const collectionMode of ["null-collections", "missing-collections"] as const) {
    mode = collectionMode;
    const usdaEmpty = await request(usda.url, `/v1/usda/search?q=${collectionMode}&page=2&pageSize=2`);
    assert.equal(usdaEmpty.status, 200);
    assert.equal(responseResults(usdaEmpty).length, 0);
    assert.equal(responseBody(usdaEmpty).hasMore, true);
    const offEmpty = await request(usda.url, `/v1/packaged-foods/search?q=${collectionMode}&provider=openFoodFacts&pageSize=2`);
    assert.equal(offEmpty.status, 200);
    assert.equal(responseResults(offEmpty).length, 0);
    assert.equal(responseBody(offEmpty).hasMore, true);
    pass(`${collectionMode} provider collections remain valid empty pages with hasMore`);
  }

  mode = "mixed-off-hits";
  const mixedHits = await request(usda.url, "/v1/packaged-foods/search?q=Mixed%20QA%20cereal&provider=openFoodFacts");
  assert.equal(mixedHits.status, 200);
  assert.equal(responseResults(mixedHits).length, 1);
  assert.equal(responseResults(mixedHits)[0].item?.code, offProduct.code);
  pass("Search-a-licious mixed malformed hits preserve valid timed-out sibling");

  mode = "success";

  for (const failure of ["401", "429", "500", "malformed"]) {
    mode = failure;
    const failed = await request(usda.url, `/v1/usda/search?q=failure${failure}`);
    assert.equal(failed.status, 503); assertNoResponseLeak(failed, /private-provider-detail/);
    mode = "success";
    const recovered = await request(usda.url, `/v1/usda/search?q=failure${failure}`);
    assert.equal(recovered.status, 200);
    pass(`USDA ${failure} generic 503 and nonsticky recovery`);
  }

  mode = "success";
  assert.equal(responseBody(await request(usda.url, "/v1/packaged-foods/barcodes/1234567890123")).product?.code, offProduct.code);
  const barcodeCalls = upstreamCalls; await request(usda.url, "/v1/packaged-foods/barcodes/1234567890123"); assert.equal(upstreamCalls, barcodeCalls);
  mode = "notfound"; assert.deepEqual(responseBody(await request(usda.url, "/v1/packaged-foods/barcodes/9999999999999")), { product: null });
  pass("barcode product, real cache and not-found null");
  mode = "500";
  assert.equal((await request(usda.url, "/v1/packaged-foods/barcodes/8888888888888")).status, 503);
  mode = "success";
  assert.equal((await request(usda.url, "/v1/packaged-foods/barcodes/8888888888888")).status, 200);
  pass("barcode provider outage and nonsticky recovery");

  for (const failure of ["401", "429", "500", "malformed"]) {
    mode = failure;
    const failed = await request(usda.url, `/v1/packaged-foods/search?q=offfailure${failure}&provider=openFoodFacts`);
    assert.equal(failed.status, 503);
    mode = "success";
    assert.equal((await request(usda.url, `/v1/packaged-foods/search?q=offfailure${failure}&provider=openFoodFacts`)).status, 200);
    pass(`OFF ${failure} generic failure and subsequent recovery`);
  }

  // Fixture latency is bounded and abortable; timers are owned by the runtime fixture.
  let delayMode: FixturePhase = "headers";

  const phases = process.env.QA_PHASE == null
    ? ["headers", "body", "hang-headers", "hang-body"] as const
    : [fixturePhaseSchema.parse(process.env.QA_PHASE)];

  for (const phase of phases) {
    for (const path of (section === "auth-deadline" ? [] : process.env.QA_DEADLINE_PATH ? [process.env.QA_DEADLINE_PATH] : ["/v1/usda/search?q=QA%20cereal", "/v1/usda/foods/42", "/v1/packaged-foods/barcodes/1234567890123", "/v1/packaged-foods/search?q=QA%20cereal&provider=openFoodFacts"])) {
      // A fresh runtime per phase prevents recovery cache from masking the next failure.
      let upstreamAttempts = 0;

      const fresh = await runtime("worker/usda-proxy/src/index.ts", {
        bindings: { USDA_API_KEY: "qa-only", OPEN_FOOD_FACTS_USER_AGENT: "QA-local" },
        outboundService: async (req: Request) => {
          assert(["api.nal.usda.gov", "search.openfoodfacts.org", "world.openfoodfacts.org", "world.openfoodfacts.net"].includes(new URL(req.url).hostname));
          upstreamAttempts++;
          let data: FixturePayload;

          if (req.url.includes("/product/")) {
            data = { product: offProduct };
          } else if (req.url.includes("/food/")) {
            data = { ...usdaFood, foodNutrients: usdaFood.foodNutrients.map(n => ({ nutrient: { id: n.nutrientId }, amount: n.value })) };
          } else {
            data = { foods: [usdaFood], hits: [offProduct], products: [offProduct], count: 1, page_count: 1 };
          }

          return fixtureResponse(data, delayMode);
        },
      });

      delayMode = phase;
      const start = performance.now();
      const failed = await request(fresh.url, path);
      const elapsed = performance.now() - start;
      const failedAttemptCount = upstreamAttempts;
      timingDiagnostics.push({ label: `${path.split("?")[0]} ${phase} (${failedAttemptCount} attempts)`, elapsedMs: Math.round(elapsed) });
      assert.equal(failed.status, 503);

      const expectedMessage = path.includes("/v1/usda/search")
        ? "USDA search is unavailable right now."
        : path.includes("/v1/usda/foods/")
          ? "USDA food details are unavailable right now."
          : "Open Food Facts is unavailable right now.";

      assert.deepEqual(responseBody(failed), { error: expectedMessage });
      const expectedAttempts = path.includes("/packaged-foods/search") ? 3 : path.includes("/barcodes/") ? 2 : 1;
      assert.equal(failedAttemptCount, expectedAttempts);
      delayMode = "success";
      assert.equal((await request(fresh.url, path)).status, 200);
      pass(`${path.split("?")[0]} ${phase} deadline and nonsticky recovery`);
    }
  }

  for (const phase of phases) {
    const authDeadline = await runtime("worker/auth/src/index.ts", { outboundService: async (req: Request) => {
      assert.equal(req.url, "https://bootstrap.qa.invalid/bootstrap");

      return fixtureResponse({ profileKey, displayName: "QA", deleted: false }, delayMode);
    }, bindings: {
      CONVEX_BOOTSTRAP_URL: "https://bootstrap.qa.invalid/bootstrap", CONVEX_BOOTSTRAP_SECRET: "qa-synthetic-only",
      JWT_PRIVATE_KEY_PKCS8: await jose.exportPKCS8(pair.privateKey), JWT_PUBLIC_JWKS: JSON.stringify({ keys: [jwk] }),
      JWT_ISSUER: "https://auth.qa.invalid", JWT_AUDIENCE: "convex", JWT_KEY_ID: "qa-key", ASTRO_REDIRECT_URL: "https://web.qa.invalid",
    } });

    delayMode = phase;
    const start = performance.now();
    const failed = await request(authDeadline.url, "/v1/token", post({ profileKey, profileSecret: raw }));
    timingDiagnostics.push({ label: `bootstrap ${phase}`, elapsedMs: Math.round(performance.now() - start) });
    assert.equal(failed.status, 500); assert.deepEqual(responseBody(failed), { error: "Request failed." });
    delayMode = "success";
    assert.equal((await request(authDeadline.url, "/v1/token", post({ profileKey, profileSecret: raw }))).status, 200);
    pass(`bootstrap ${phase} deadline and recovery`);
  }

  const web = await runtime("web/src/worker.ts", { d1Databases: { SUPPORT_DB: "qa-isolated" }, serviceBindings: { ASSETS: () => new Response("not found", { status: 404 }) } });
  const db = await web.mf.getD1Database("SUPPORT_DB");

  for (const name of ["0000_create_support_requests.sql", "0001_create_waitlist_entries.sql"]) {
    const sql = await readFile(`${root}/web/migrations/${name}`, "utf8");

    for (const statement of sql.split(";").filter(value => value.trim())) await db.prepare(statement).run();
  }

  const form = (body: Record<string, string>) => ({ method: "POST", headers: { "content-type": "application/x-www-form-urlencoded" }, body: new URLSearchParams(body).toString() });
  const support = await request(web.url, "/api/support", form({ name: "QA", email: "qa@example.com", message: "Synthetic local QA message." }));
  assert.equal(support.status, 303); assert.equal(new URL(support.headers.get("location")!).origin, web.url);
  assert(support.headers.get("location")!.includes("submitted"));
  assert.equal((await db.prepare("SELECT COUNT(*) AS n FROM support_requests").first<{ n: number }>())?.n, 1);
  const invalid = await request(web.url, "/api/support", form({})); assert.equal(invalid.status, 303); assert(invalid.headers.get("location")!.includes("invalid"));
  pass("real support form insert and fixed same-origin success/invalid redirects");
  assert.equal((await request(web.url, "/api/waitlist", form({ email: " QA@EXAMPLE.COM " }))).status, 200);
  assert.equal((await request(web.url, "/api/waitlist", form({ email: "qa@example.com" }))).status, 200);
  assert.equal((await db.prepare("SELECT COUNT(*) AS n FROM waitlist_entries").first<{ n: number }>())?.n, 1);
  assert.equal((await request(web.url, "/api/waitlist", { method: "POST", headers: { "content-type": "application/json" }, body: "{" })).status, 400);
  pass("real waitlist form normalization/duplicate and malformed JSON");
  const broken = await runtime("web/src/worker.ts", { d1Databases: { SUPPORT_DB: "qa-isolated-broken" }, serviceBindings: { ASSETS: () => new Response("not found", { status: 404 }) } });

  for (const path of ["/api/support", "/api/waitlist"]) {
    const failed = await request(broken.url, path, post({ name: "QA", email: "qa@example.com", message: "Synthetic local QA message." }));
    assert.equal(failed.status, 500); assertNoResponseLeak(failed, /no such table: support_requests/);
    pass(`real D1 missing-table ${path} controlled 500`);
  }

  const dbForm = await request(broken.url, "/api/support", form({ name: "QA", email: "qa@example.com", message: "Synthetic local QA message." }));
  assert.equal(dbForm.status, 303); assert(dbForm.headers.get("location")!.includes("error"));
  pass("D1 failure support form fixed error redirect");
} catch (error) {
  // Assertion messages cannot include token/key fixture values.
  findings.push(error instanceof Error ? `${error.name}: ${error.message.replace(/eyJ[A-Za-z0-9_.-]+/g, "[redacted]")}` : "Harness failure");
  process.exitCode = 1;
} finally {
  for (const timer of fixtureTimers) clearTimeout(timer);

  for (const close of fixtureClosers) close();

  const cleanup = await Promise.allSettled([
    ...servers.map(server => server.stop()),
    ...runtimes.map(mf => mf.dispose()),
    ...mocks.map(mock => mock.close()),
  ]);

  const cleanupFailures = cleanup.filter(result => result.status === "rejected").length;

  if (cleanupFailures > 0) { process.exitCode = 1; findings.push(`${cleanupFailures} resource cleanup failures.`); }

  const report = { result: process.exitCode ? "FAIL" : "PASS", httpRequests, assertionGroups: checks.length, checks, findings, timingDiagnostics, cleanup: cleanupFailures ? "FAILED" : "all loopback servers, Miniflare instances, mocks and fixtures disposed" };
  await writeFile(`${outputDir}/runtime-e2e.json`, JSON.stringify(report, null, 2));
  await writeFile(`${outputDir}/runtime-e2e.log`, JSON.stringify(report, null, 2) + "\n");
  console.log(JSON.stringify(report, null, 2));
}
