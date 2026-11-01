import { httpRouter } from "convex/server";
import { z } from "zod";
import { internal } from "./_generated/api";
import { httpAction } from "./_generated/server";

const http = httpRouter();

const jsonValueSchema = z.json();

type JsonValue = z.infer<typeof jsonValueSchema>;

const bootstrapRequestSchema = z.object({
  profileKey: z.string().min(16).max(128).regex(/^[A-Za-z0-9_-]+$/),
  secretHash: z.string().regex(/^[a-f0-9]{64}$/),
  displayName: z.string().trim().min(1).max(40).regex(/^[^\p{Cc}\p{Cf}]+$/u).optional(),
}).strict();

http.route({
  path: "/v1/bootstrap-profile",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    const expectedSecret = process.env.MACROS_BOOTSTRAP_SECRET;
    const receivedSecret = request.headers.get("x-macros-bootstrap-secret");

    if (expectedSecret == null || receivedSecret == null || (await secretsMatch(receivedSecret, expectedSecret)) === false) {
      return json({ error: "Unauthorized." }, 401);
    }

    let body;

    try {
      body = bootstrapRequestSchema.parse(await request.json());
    } catch {
      return json({ error: "Invalid bootstrap body." }, 400);
    }

    const result = await ctx.runMutation(internal.bootstrap.registerOrVerifyProfile, {
      profileKey: body.profileKey,
      secretHash: body.secretHash,
      displayName: body.displayName,
    });

    return json(result, 200);
  }),
});

http.route({
  path: "/appstore/notifications",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    let record;

    try {
      const body = z.object({ signedPayload: z.string().min(1).max(100_000) }).strict().parse(await request.json());
      record = await ctx.runAction(internal.appleVerification.verifyNotification, body);
    } catch {
      return json({ error: "Invalid App Store notification." }, 400);
    }

    // Database failures must remain 5xx so Apple retries delivery.
    if (record) await ctx.runMutation(internal.entitlementRecords.applyNotification, record);

    return json({ ok: true }, 200);
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
