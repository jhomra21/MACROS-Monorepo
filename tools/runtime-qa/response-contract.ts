import assert from "node:assert/strict";
import { z } from "zod";

const runtimeResponseBodySchema = z.object({
  token: z.string().optional(),
  expiresAt: z.number().optional(),
  keys: z.array(z.object({ d: z.string().optional() }).passthrough()).optional(),
  results: z.array(z.object({
    fdcId: z.number().optional(),
    caloriesPerServing: z.number().optional(),
    proteinPerServing: z.number().optional(),
    item: z.object({ nutriments: z.json().optional() }).passthrough().optional(),
  }).passthrough()).optional(),
  hasMore: z.boolean().optional(),
  resolvedProvider: z.string().optional(),
  product: z.object({ code: z.string().optional() }).passthrough().nullable().optional(),
}).passthrough();

export type RuntimeResponseBody = z.infer<typeof runtimeResponseBodySchema>;

const jsonValueSchema = z.json();

type JsonValue = z.infer<typeof jsonValueSchema>;

export interface RuntimeResponse {
  status: number;
  headers: Headers;
  text: string;
  decoded: JsonValue | undefined;
}

export async function readRuntimeResponse(response: Response): Promise<RuntimeResponse> {
  const text = await response.text();
  let parsed: unknown;

  try {
    parsed = JSON.parse(text);
  } catch {
    return { status: response.status, headers: response.headers, text, decoded: undefined };
  }

  return { status: response.status, headers: response.headers, text, decoded: jsonValueSchema.parse(parsed) };
}

export function responseBody(response: RuntimeResponse): RuntimeResponseBody {
  return runtimeResponseBodySchema.parse(response.decoded);
}

export function responseResults(response: RuntimeResponse) {
  const results = responseBody(response).results;

  assert(Array.isArray(results), "Expected response to contain a results array.");

  return results;
}

export function assertNoResponseLeak(response: RuntimeResponse, leak: RegExp): void {
  const evidence = `${response.text}\n${JSON.stringify(response.decoded)}`;

  assert.doesNotMatch(evidence, leak);
}

export function assertIncompleteOpenFoodFactsItem(response: RuntimeResponse): void {
  const secondResult = responseResults(response)[1];

  assert(secondResult?.item, "Expected the second Open Food Facts result to contain an item.");
  assert.equal(secondResult.item.nutriments, undefined);
}
