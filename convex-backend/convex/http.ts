import { httpRouter } from "convex/server";
import { z } from "zod";
import { internal } from "./_generated/api";
import { httpAction } from "./_generated/server";

const http = httpRouter();

const jsonValueSchema = z.json();

type JsonValue = z.infer<typeof jsonValueSchema>;

const bootstrapRequestSchema = z.object({
  profileKey: z.json().optional(),
  secretHash: z.json().optional(),
  displayName: z.json().optional(),
}).catch({});

http.route({
  path: "/v1/bootstrap-profile",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    const expectedSecret = process.env.MACROS_BOOTSTRAP_SECRET;
    const receivedSecret = request.headers.get("x-macros-bootstrap-secret");

    if (expectedSecret == null || receivedSecret == null || (await secretsMatch(receivedSecret, expectedSecret)) === false) {
      return json({ error: "Unauthorized." }, 401);
    }

    const body = bootstrapRequestSchema.parse(await request.json());

    const result = await ctx.runMutation(internal.bootstrap.registerOrVerifyProfile, {
      profileKey: String(body.profileKey ?? ""),
      secretHash: String(body.secretHash ?? ""),
      displayName: body.displayName == null ? undefined : String(body.displayName),
    });

    return json(result, 200);
  }),
});

function json(value: JsonValue, status: number) {
  return new Response(JSON.stringify(value), {
    status,
    headers: { "content-type": "application/json; charset=utf-8" },
  });
}

async function secretsMatch(received: string, expected: string): Promise<boolean> {
  const encoder = new TextEncoder();

  const [receivedDigest, expectedDigest] = await Promise.all([
    crypto.subtle.digest("SHA-256", encoder.encode(received)),
    crypto.subtle.digest("SHA-256", encoder.encode(expected)),
  ]);

  const receivedBytes = new Uint8Array(receivedDigest);
  const expectedBytes = new Uint8Array(expectedDigest);
  let diff = 0;

  for (let index = 0; index < expectedBytes.length; index += 1) {
    diff |= receivedBytes[index] ^ expectedBytes[index];
  }

  return diff === 0;
}

export default http;
