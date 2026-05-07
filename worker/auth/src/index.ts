import { Hono } from "hono";
import { issueConvexToken, sha256Hex, tokenExpiresAt } from "./crypto";

const app = new Hono<{ Bindings: Env }>();
const PROFILE_KEY_PATTERN = /^[A-Za-z0-9_-]{32,128}$/;
const PROFILE_SECRET_PATTERN = /^[A-Za-z0-9_-]{32,256}$/;

interface BootstrapResponse {
  profileKey: string;
  displayName: string;
  deleted: boolean;
}

app.post("/v1/token", async (c) => {
  const body = await c.req.json().catch(() => null);
  if (body == null || typeof body !== "object") {
    return jsonError("Invalid request.", 400);
  }

  const profileKey = String((body as Record<string, unknown>).profileKey ?? "");
  const profileSecret = String((body as Record<string, unknown>).profileSecret ?? "");
  const displayName = optionalString((body as Record<string, unknown>).displayName);
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
  });

  if (response.ok === false) {
    throw new Error("Convex bootstrap failed.");
  }

  return await response.json();
}

function optionalString(value: unknown): string | undefined {
  return typeof value === "string" && value.trim().length > 0 ? value : undefined;
}

function jsonError(message: string, status: number) {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { "content-type": "application/json; charset=utf-8" },
  });
}

export default app;
