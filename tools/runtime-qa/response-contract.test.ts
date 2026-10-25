import assert from "node:assert/strict";
import { serve } from "./native-http.ts";
import {
  assertIncompleteOpenFoodFactsItem,
  assertNoResponseLeak,
  readRuntimeResponse,
  responseBody,
  responseResults,
} from "./response-contract.ts";

const fixtures = new Map<string, { status: number; body: string }>([
  ["/plain-sql-leak", { status: 500, body: "no such table: support_requests" }],
  ["/json-provider-leak", { status: 503, body: JSON.stringify("private-provider-detail") }],
  ["/missing-results", { status: 200, body: JSON.stringify({ hasMore: true }) }],
  ["/missing-item", { status: 200, body: JSON.stringify({ results: [{}, {}] }) }],
  ["/empty-redirect", { status: 303, body: "" }],
  ["/nullable-barcode", { status: 200, body: JSON.stringify({ product: null }) }],
]);

const server = serve({
  hostname: "127.0.0.1",
  port: 0,
  async fetch(request) {
    const fixture = fixtures.get(new URL(request.url).pathname);

    assert(fixture, `Unexpected request path: ${new URL(request.url).pathname}`);

    return new Response(fixture.body, { status: fixture.status });
  },
});

const failures: string[] = [];

async function check(name: string, test: () => Promise<void>): Promise<void> {
  try {
    await test();
  } catch (error) {
    failures.push(`${name}: ${error instanceof Error ? error.message : "unexpected failure"}`);
  }
}

try {
  await server.ready;
  const response = async (path: string) => readRuntimeResponse(await fetch(`http://127.0.0.1:${server.port}${path}`, { redirect: "manual" }));

  await check("plain SQL leak is rejected using raw body evidence", async () => {
    const result = await response("/plain-sql-leak");

    assert.throws(() => assertNoResponseLeak(result, /no such table: support_requests/));
  });

  await check("JSON scalar provider leak is rejected using decoded JSON", async () => {
    const result = await response("/json-provider-leak");

    assert.throws(() => assertNoResponseLeak(result, /private-provider-detail/));
  });

  await check("200 response with hasMore but no results is rejected", async () => {
    const result = await response("/missing-results");

    assert.throws(() => responseResults(result));
  });

  await check("second OFF result without item is rejected", async () => {
    const result = await response("/missing-item");

    assert.throws(() => assertIncompleteOpenFoodFactsItem(result));
  });

  await check("empty redirect body remains valid", async () => {
    const result = await response("/empty-redirect");

    assert.equal(result.status, 303);
    assert.equal(result.text, "");
  });

  await check("nullable barcode response remains exact", async () => {
    const result = await response("/nullable-barcode");

    assert.equal(result.status, 200);
    assert.deepEqual(responseBody(result), { product: null });
  });
} finally {
  await server.stop();
}

if (failures.length > 0) {
  console.error(JSON.stringify({ result: "FAIL", failures }, null, 2));
  process.exitCode = 1;
} else {
  console.log(JSON.stringify({ result: "PASS", loopbackCases: fixtures.size }, null, 2));
}
