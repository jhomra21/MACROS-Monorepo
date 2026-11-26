import { describe, expect, it } from "bun:test";
import worker, { type SupportEmail, type SupportWorkerEnv } from "../src/index";

function harness(limit = true) {
  const sent: SupportEmail[] = [];
  const counts = new Map<string, { timestamps: number[] }>();

  const env: SupportWorkerEnv = {
    BURST_LIMITER: { limit: async () => ({ success: limit }) },
    REQUEST_LIMITS: {
      get: async (key: string) => counts.get(key) ?? null,
      put: async (key: string, value: string) => { counts.set(key, JSON.parse(value)); },
    },
    EMAIL: {
      send: async (email) => {
        sent.push(email);

        return { messageId: "local-test" };
      },
    },
  };

  return { env, sent };
}

const validRequest = {
  category: "Bug",
  message: "The saved item does not appear.",
  email: "person@example.com",
  appVersion: "1.2",
  build: "42",
  osVersion: "iOS 27.0",
  deviceModel: "iPhone17,1",
};

describe("support request endpoint", () => {
  it("sends valid requests with expected headers", async () => {
    const { env, sent } = harness();

    const response = await worker.fetch(new Request("https://support.macrosios.com/v1/requests", {
      method: "POST",
      headers: { "content-type": "application/json", "cf-connecting-ip": "192.0.2.3" },
      body: JSON.stringify(validRequest),
    }), env);

    expect(response.status).toBe(200);
    expect(sent[0]).toMatchObject({
      to: "support@macrosios.com",
      from: "no-reply@macrosios.com",
      subject: "[MACROS Bug] The saved item does not appear.",
      replyTo: "person@example.com",
    });
  });

  it("rejects invalid payloads", async () => {
    const { env } = harness();

    const response = await worker.fetch(new Request("https://support.macrosios.com/v1/requests", {
      method: "POST",
      body: JSON.stringify({ ...validRequest, extra: "not allowed" }),
    }), env);

    expect(response.status).toBe(400);
  });

  it("rejects oversized bodies", async () => {
    const { env } = harness();

    const response = await worker.fetch(new Request("https://support.macrosios.com/v1/requests", {
      method: "POST",
      body: JSON.stringify({ ...validRequest, message: "x".repeat(16_500) }),
    }), env);

    expect(response.status).toBe(413);
  });

  it("rate limits by client IP", async () => {
    const { env } = harness(false);

    const response = await worker.fetch(new Request("https://support.macrosios.com/v1/requests", {
      method: "POST",
      headers: { "cf-connecting-ip": "192.0.2.3" },
      body: JSON.stringify(validRequest),
    }), env);

    expect(response.status).toBe(429);
  });

  it("limits valid requests to five per IP per hour", async () => {
    const { env } = harness();

    for (let requestNumber = 0; requestNumber < 5; requestNumber += 1) {
      const response = await worker.fetch(new Request("https://support.macrosios.com/v1/requests", {
        method: "POST",
        headers: { "cf-connecting-ip": "192.0.2.8" },
        body: JSON.stringify(validRequest),
      }), env);

      expect(response.status).toBe(200);
    }

    const limited = await worker.fetch(new Request("https://support.macrosios.com/v1/requests", {
      method: "POST",
      headers: { "cf-connecting-ip": "192.0.2.8" },
      body: JSON.stringify(validRequest),
    }), env);

    expect(limited.status).toBe(429);
  });
});
