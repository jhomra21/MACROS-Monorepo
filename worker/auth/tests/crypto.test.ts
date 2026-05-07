import { describe, expect, it } from "bun:test";

import { issueConvexToken, sha256Hex, tokenExpiresAt, verifyIssuedToken } from "../src/crypto";

describe("auth crypto", () => {
  it("hashes profile secrets deterministically without returning raw secrets", async () => {
    await expect(sha256Hex("profile.secret")).resolves.toMatch(/^[a-f0-9]{64}$/);
    expect(await sha256Hex("profile.secret")).toBe(await sha256Hex("profile.secret"));
  });

  it("issues Convex JWTs with expected claims", async () => {
    const { privateKeyPkcs8, publicKeySpki } = await generateRsaKeyPair();
    const now = Math.floor(Date.now() / 1000);
    const token = await issueConvexToken("profile_key_123", now, {
      issuer: "https://macros-auth.workers.dev",
      audience: "macros-convex-dev",
      keyId: "macros-auth-dev-1",
      privateKeyPkcs8,
    });

    const verified = await verifyIssuedToken(
      token,
      publicKeySpki,
      "https://macros-auth.workers.dev",
      "macros-convex-dev",
    );

    expect(verified.payload).toMatchObject({
      iss: "https://macros-auth.workers.dev",
      aud: "macros-convex-dev",
      sub: "profile_key_123",
      iat: now,
      exp: now + 86_400,
    });
    expect(verified.protectedHeader.kid).toBe("macros-auth-dev-1");
    expect(tokenExpiresAt(now)).toBe((now + 86_400) * 1000);
  });
});

async function generateRsaKeyPair() {
  const keyPair = await crypto.subtle.generateKey(
    {
      name: "RSASSA-PKCS1-v1_5",
      modulusLength: 2048,
      publicExponent: new Uint8Array([1, 0, 1]),
      hash: "SHA-256",
    },
    true,
    ["sign", "verify"],
  );
  const privateKeyPkcs8 = pem("PRIVATE KEY", await crypto.subtle.exportKey("pkcs8", keyPair.privateKey));
  const publicKeySpki = pem("PUBLIC KEY", await crypto.subtle.exportKey("spki", keyPair.publicKey));
  return { privateKeyPkcs8, publicKeySpki };
}

function pem(label: string, key: ArrayBuffer): string {
  const base64 = Buffer.from(key).toString("base64");
  const lines = base64.match(/.{1,64}/g) ?? [];
  return `-----BEGIN ${label}-----\n${lines.join("\n")}\n-----END ${label}-----`;
}
