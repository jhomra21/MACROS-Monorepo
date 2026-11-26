import { z } from "zod";

interface SupportRequest {
  category: "Bug" | "Feature request" | "Question" | "Other";
  message: string;
  email?: string;
  appVersion: string;
  build: string;
  osVersion: string;
  deviceModel: string;
}

export interface SupportWorkerEnv {
  SUPPORT_DESTINATION: string;
  EMAIL: {
    send(message: SupportEmail): Promise<SupportEmailSendResult>;
  };
  BURST_LIMITER: {
    limit(options: { key: string }): Promise<{ success: boolean }>;
  };
  REQUEST_LIMITS: {
    get(key: string, type: "json"): Promise<{ timestamps: number[] } | null>;
    put(key: string, value: string, options: { expirationTtl: number }): Promise<void>;
  };
}

export interface SupportEmailSendResult {
  messageId: string;
}

export interface SupportEmail {
  to: string;
  from: string;
  subject: string;
  text: string;
  replyTo?: string;
}

const jsonValueSchema = z.json();

type JsonValue = z.infer<typeof jsonValueSchema>;

const MAX_BODY_BYTES = 16 * 1024;

const supportRequestSchema = z.object({
  category: z.enum(["Bug", "Feature request", "Question", "Other"]),
  message: z.string().refine((message) => {
    const count = characterCount(message);

    return count >= 10 && count <= 4_000 && message.trim().length >= 10;
  }),
  email: z.email().max(254).optional(),
  appVersion: z.string().min(1).max(40),
  build: z.string().min(1).max(40),
  osVersion: z.string().min(1).max(40),
  deviceModel: z.string().min(1).max(40),
}).strict();

function characterCount(value: string): number {
  return Array.from(new Intl.Segmenter(undefined, { granularity: "grapheme" }).segment(value)).length;
}

export default {
  async fetch(request: Request, env: SupportWorkerEnv): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname !== "/v1/requests") return jsonError("Not found.", 404);

    if (request.method !== "POST") return jsonError("Method not allowed.", 405);

    const declaredLength = Number(request.headers.get("content-length") ?? 0);

    if (declaredLength > MAX_BODY_BYTES) return jsonError("Request body too large.", 413);
    const body = await readBoundedBody(request);

    if (body === null) return jsonError("Request body too large.", 413);

    let value: JsonValue;

    try {
      value = JSON.parse(body);
    } catch {
      return jsonError("Invalid request.", 400);
    }

    const supportRequest = validate(value);

    if (!supportRequest) return jsonError("Invalid request.", 400);

    const ip = request.headers.get("cf-connecting-ip")?.trim();
    const clientIP = ip || "unknown-client";
    const { success } = await env.BURST_LIMITER.limit({ key: clientIP });

    if (!success) return jsonError("Too many requests.", 429, { "retry-after": "60" });

    if (!(await allowHourlyRequest(env.REQUEST_LIMITS, clientIP))) {
      return jsonError("Too many requests.", 429, { "retry-after": "3600" });
    }

    try {
      const subjectSnippet = supportRequest.message.slice(0, 60).replace(/[\r\n\p{Cc}]/gu, " ");

      const email: SupportEmail = {
        to: env.SUPPORT_DESTINATION,
        from: "no-reply@macrosios.com",
        subject: `[MACROS ${supportRequest.category}] ${subjectSnippet}`,
        text: formatEmail(supportRequest),
      };

      if (supportRequest.email) email.replyTo = supportRequest.email;
      await env.EMAIL.send(email);
    } catch {
      return jsonError("Unable to send request.", 503);
    }

    return Response.json({ success: true }, { headers: { "cache-control": "no-store" } });
  },
};

function validate(value: JsonValue): SupportRequest | null {
  const parsed = supportRequestSchema.safeParse(value);

  return parsed.success ? parsed.data : null;
}

function formatEmail(request: SupportRequest): string {
  return [
    `Category: ${request.category}`,
    `App version: ${request.appVersion} (${request.build})`,
    `iOS version: ${request.osVersion}`,
    `Device model: ${request.deviceModel}`,
    "",
    "Message:",
    request.message,
  ].join("\n");
}

async function allowHourlyRequest(
  limits: SupportWorkerEnv["REQUEST_LIMITS"],
  ip: string,
  now: number = Date.now()
): Promise<boolean> {
  const key = `support:${ip}`;
  const current = await limits.get(key, "json");
  const recentRequests = current?.timestamps.filter((timestamp) => now - timestamp < 3_600_000) ?? [];

  if (recentRequests.length >= 5) return false;
  recentRequests.push(now);
  await limits.put(key, JSON.stringify({ timestamps: recentRequests }), { expirationTtl: 3_600 });

  return true;
}

async function readBoundedBody(request: Request): Promise<string | null> {
  if (!request.body) return "";
  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let size = 0;

  while (true) {
    const { done, value } = await reader.read();

    if (done) break;
    size += value.byteLength;

    if (size > MAX_BODY_BYTES) {
      await reader.cancel();

      return null;
    }

    chunks.push(value);
  }

  const bytes = new Uint8Array(size);
  let offset = 0;

  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }

  return new TextDecoder().decode(bytes);
}

function jsonError(message: string, status: number, headers: Record<string, string> = {}): Response {
  return Response.json({ error: message }, {
    status,
    headers: { "cache-control": "no-store", ...headers },
  });
}
