import { describe, expect, it } from "bun:test";
import app from "../src/index";

describe("token exchange rate limit", () => {
  it("returns 429 with Retry-After when the IP quota is exhausted", async () => {
    let key = "";

    const env: Env = {
      TOKEN_LIMITER: {
        limit: async ({ key: value }) => {
          key = value;

          return { success: false };
        },
      },
      JWT_ISSUER: "https://macros-auth.jhonra121.workers.dev",
      JWT_AUDIENCE: "macros-convex-dev",
      JWT_KEY_ID: "macros-auth-dev-1",
      ASTRO_REDIRECT_URL: "https://macros-web.jhonra121.workers.dev/",
      CONVEX_BOOTSTRAP_URL: "https://convex.example",
      CONVEX_BOOTSTRAP_SECRET: "test",
      JWT_PRIVATE_KEY_PKCS8: "test",
      JWT_PUBLIC_JWKS: "test",
    };

    const response = await app.fetch(new Request("https://auth.example/v1/token", {
      method: "POST",
      headers: { "cf-connecting-ip": "203.0.113.5", "content-type": "application/json" },
      body: "{}",
    }), env);

    expect(key).toBe("203.0.113.5");
    expect(response.status).toBe(429);
    expect(response.headers.get("retry-after")).toBe("60");
    expect(JSON.parse(await response.text())).toEqual({ error: "Too many requests. Please try again in a minute." });
  });
});
