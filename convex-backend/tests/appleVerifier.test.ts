import { describe, expect, it } from "bun:test";
import { SignedDataVerifier, Environment } from "@apple/app-store-server-library";
import { AppleVerifier } from "../convex/_lib/appleVerifier.node";
import { appleRootG3 } from "../convex/appleRoots/root";
import { readFileSync } from "node:fs";
import { generateKeyPairSync, sign, verify } from "node:crypto";

type RoutingPayload = { environment?: string; bundleId?: string; data?: { environment: string } };

const jws = (payload: RoutingPayload) => `e30.${Buffer.from(JSON.stringify(payload)).toString("base64url")}.invalid`;

describe("Apple verifier boundary", () => {
  const verifier = new AppleVerifier();
  it.each(["XCODE", "LOCAL_TESTING", "Xcode", undefined])("rejects unsupported environment %s before verification", async environment => {
    await expect(verifier.transaction(jws({ environment }))).rejects.toThrow("environment");
  });
  it.each(["Production", "Sandbox"])("routes %s only to its matching verifier", async environment => {
    const calls: string[] = [];

    const routed = new AppleVerifier(env => ({
      verifyAndDecodeTransaction: async () => {
        calls.push(env);

        return { environment, bundleId: "juan-test.cal-macro-tracker" };
      },
      verifyAndDecodeRenewalInfo: async () => ({ environment }),
      verifyAndDecodeNotification: async () => ({ data: { environment } }),
    }));

    await routed.transaction(jws({ environment }));
    expect(calls).toEqual([environment]);
  });
  it("rejects a verified wrong bundle at the boundary", async () => {
    const wrong = new AppleVerifier(() => ({
      verifyAndDecodeTransaction: async () => ({ environment: Environment.SANDBOX, bundleId: "other.app" }),
      verifyAndDecodeRenewalInfo: async () => ({}),
      verifyAndDecodeNotification: async () => ({}),
    }));

    await expect(wrong.transaction(jws({ environment: "Sandbox" }))).rejects.toThrow("bundle");
  });
  it("rejects garbage and forged JWS in both real Apple verifiers", async () => {
    await expect(verifier.transaction("garbage")).rejects.toThrow();

    for (const environment of ["Production", "Sandbox"]) {
      await expect(verifier.transaction(jws({ environment, bundleId: "juan-test.cal-macro-tracker" }))).rejects.toThrow();
      await expect(verifier.notification(jws({ data: { environment } }))).rejects.toThrow();
    }
  });
  it("constructs Apple's offline verifiers from the committed DER root", () => {
    expect(new SignedDataVerifier([Buffer.from(appleRootG3, "base64")], false, Environment.PRODUCTION, "juan-test.cal-macro-tracker", 6767565938)).toBeDefined();
  });
  it("rejects a correctly signed synthetic JWS without an Apple certificate chain", async () => {
    // Ephemeral test-only keys never leave memory. The signature is genuine,
    // but a self-issued key must never authorize an App Store purchase.
    const { privateKey, publicKey } = generateKeyPairSync("ec", { namedCurve: "prime256v1" });
    const header = Buffer.from(JSON.stringify({ alg: "ES256", typ: "JWT" })).toString("base64url");

    const payload = Buffer.from(JSON.stringify({
      environment: "Sandbox", bundleId: "juan-test.cal-macro-tracker", signedDate: Date.now(),
    })).toString("base64url");

    const input = Buffer.from(`${header}.${payload}`);
    const signature = sign("sha256", input, { key: privateKey, dsaEncoding: "ieee-p1363" });
    expect(verify("sha256", input, { key: publicKey, dsaEncoding: "ieee-p1363" }, signature)).toBe(true);
    await expect(verifier.transaction(`${input.toString()}.${signature.toString("base64url")}`)).rejects.toThrow();
  });
  it("uses the same DER bytes embedded in the deployable bundle", () => {
    const der = readFileSync(new URL("../convex/appleRoots/AppleRootCA-G3.cer", import.meta.url));
    expect(Buffer.from(appleRootG3, "base64")).toEqual(der);
  });
});
