import { SignJWT, importPKCS8, jwtVerify, importSPKI } from "jose";

const TOKEN_TTL_SECONDS = 24 * 60 * 60;
const encoder = new TextEncoder();
const importedPrivateKeys = new Map<string, Promise<CryptoKey>>();

export interface JwtConfig {
  issuer: string;
  audience: string;
  keyId: string;
  privateKeyPkcs8: string;
}

export async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", encoder.encode(value));
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

export async function issueConvexToken(profileKey: string, nowSeconds: number, config: JwtConfig): Promise<string> {
  const key = await privateKeyFor(config.privateKeyPkcs8);
  return await new SignJWT({})
    .setProtectedHeader({ alg: "RS256", kid: config.keyId })
    .setIssuer(config.issuer)
    .setAudience(config.audience)
    .setSubject(profileKey)
    .setIssuedAt(nowSeconds)
    .setExpirationTime(nowSeconds + TOKEN_TTL_SECONDS)
    .sign(key);
}

function privateKeyFor(privateKeyPkcs8: string): Promise<CryptoKey> {
  const cachedKey = importedPrivateKeys.get(privateKeyPkcs8);
  if (cachedKey != null) {
    return cachedKey;
  }

  const key = importPKCS8(privateKeyPkcs8, "RS256");
  importedPrivateKeys.set(privateKeyPkcs8, key);
  return key;
}

export async function verifyIssuedToken(
  token: string,
  publicKeySpki: string,
  issuer: string,
  audience: string,
) {
  const key = await importSPKI(publicKeySpki, "RS256");
  return await jwtVerify(token, key, { issuer, audience });
}

export function tokenExpiresAt(nowSeconds: number): number {
  return (nowSeconds + TOKEN_TTL_SECONDS) * 1000;
}
