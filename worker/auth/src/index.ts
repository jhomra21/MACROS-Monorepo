import { Hono } from "hono";
import { z } from "zod";
import { issueConvexToken, sha256Hex, tokenExpiresAt } from "./crypto";

const app = new Hono<{ Bindings: Env }>();

const jsonValueSchema = z.json();

type JsonValue = z.infer<typeof jsonValueSchema>;

const PROFILE_KEY_PATTERN = /^[A-Za-z0-9_-]{32,128}$/;

const PROFILE_SECRET_PATTERN = /^[A-Za-z0-9_-]{32,256}$/;

// Bound bootstrap headers and body, matching the food adapter's interactive deadline.
const BOOTSTRAP_TIMEOUT_MS = 2_500;

interface BootstrapResponse {
  profileKey: string;
  displayName: string;
  deleted: boolean;
}

const tokenRequestSchema = z.union([
  z.record(z.string(), z.json()),
  z.array(z.json()),
]);

const bootstrapResponseSchema = z.object({
  profileKey: z.string(),
  displayName: z.string(),
  deleted: z.literal(false),
});

app.post("/v1/token", async (c) => {
  const parsedBody = tokenRequestSchema.safeParse(await c.req.json().catch(() => null));

  if (!parsedBody.success) {
    return jsonError("Invalid request.", 400);
  }

  const body = Array.isArray(parsedBody.data) ? {} : parsedBody.data;
  const profileKey = String(body.profileKey ?? "");
  const profileSecret = String(body.profileSecret ?? "");
  const displayName = optionalString(body.displayName);

  if (PROFILE_KEY_PATTERN.test(profileKey) === false || PROFILE_SECRET_PATTERN.test(profileSecret) === false) {
    return jsonError("Invalid profile credentials.", 400);
  }

  const secretHash = await sha256Hex(`${profileKey}.${profileSecret}`);
  const profile = await bootstrapProfile(c.env, { profileKey, secretHash, displayName });
  const nowSeconds = Math.floor(Date.now() / 1000);

  const token = await issueConvexToken(profile.profileKey, nowSeconds, {
    issuer: c.env.JWT_ISSUER,
    audience: c.env.JWT_AUDIENCE,
    keyId: c.env.JWT_KEY_ID,
    privateKeyPkcs8: c.env.JWT_PRIVATE_KEY_PKCS8,
  });

  return c.json({
    token,
    expiresAt: tokenExpiresAt(nowSeconds),
    profile: {
      profileKey: profile.profileKey,
      displayName: profile.displayName,
      deleted: profile.deleted,
    },
  });
});

app.get("/.well-known/jwks.json", (c) => {
  return new Response(c.env.JWT_PUBLIC_JWKS, {
    headers: {
      "cache-control": "public, max-age=300",
      "content-type": "application/json; charset=utf-8",
    },
  });
});

app.get("/invite/:token", (c) => {
  return c.redirect(c.env.ASTRO_REDIRECT_URL, 302);
});

app.notFound(() => jsonError("Not found.", 404));

app.onError(() => jsonError("Request failed.", 500));

async function bootstrapProfile(
  env: Env,
  body: { profileKey: string; secretHash: string; displayName?: string },
): Promise<BootstrapResponse> {
  const response = await fetch(env.CONVEX_BOOTSTRAP_URL, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-macros-bootstrap-secret": env.CONVEX_BOOTSTRAP_SECRET,
    },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(BOOTSTRAP_TIMEOUT_MS),
  });

  if (response.ok === false) {
    throw new Error("Convex bootstrap failed.");
  }

  const parsed = bootstrapResponseSchema.safeParse(await response.json());

  if (!parsed.success) {
    throw new Error("Invalid bootstrap response.");
  }

  const profile = parsed.data;
  const name = profile.displayName;

  if (
    PROFILE_KEY_PATTERN.test(profile.profileKey) === false ||
    profile.profileKey !== body.profileKey ||
    name.length < 1 || name.length > 40 ||
    name !== name.trim().replace(/\s+/g, " ") ||
    /[\p{Cc}\p{Cf}]/u.test(name)
  ) {
    throw new Error("Invalid bootstrap response.");
  }

  return { profileKey: profile.profileKey, displayName: name, deleted: false };
}

function optionalString(value: JsonValue | undefined): string | undefined {
  const parsed = z.string().safeParse(value);

  return parsed.success && parsed.data.trim().length > 0 ? parsed.data : undefined;
}

function jsonError(message: string, status: number) {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { "content-type": "application/json; charset=utf-8" },
  });
}

export default app;
