import type { Hono } from 'hono'
import { z } from 'zod'
import { prompt } from './prompt'
import responseSchema from './schema.json'
import { clientKey } from '../rateLimit'

const MODEL = 'gemini-3.5-flash-lite'
const MAX_IMAGE_BYTES = 1_572_864
const GEMINI_TIMEOUT_MS = 20_000
const feedbackSchema = z.object({
  requestId: z.string().uuid(),
  model: z.literal(MODEL),
  suggested: z.number().int().min(0).max(100),
  keptUnchanged: z.number().int().min(0).max(100),
  gramsEdited: z.number().int().min(0).max(100),
  medianGramChangePct: z.number().finite().min(-1000).max(1000).nullable(),
  removed: z.number().int().min(0).max(100),
  added: z.number().int().min(0).max(100),
  hiddenFatAnswer: z.enum(['yes', 'no', 'skipped']),
}).strict()

type MealPhotoApp = Hono<{ Bindings: Env }>

export function registerMealPhotoRoutes(app: MealPhotoApp): void {
  app.post('/v1/meal-photo/estimate', async (c) => {
    const noStore = { 'Cache-Control': 'no-store' }
    const installID = c.req.header('X-MACROS-Install-ID')?.trim()
    if (installID == null || !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(installID)) {
      return errorResponse('missing_install_id', 400)
    }
    if (c.req.header('Content-Type')?.split(';')[0]?.trim().toLowerCase() !== 'image/jpeg') {
      return errorResponse('unsupported_type', 415)
    }
    const declaredLength = Number(c.req.header('Content-Length') ?? 0)
    if (declaredLength > MAX_IMAGE_BYTES) return errorResponse('too_large', 413)

    const limiterResponse = await enforceMealPhotoRateLimit(c.env.MEAL_PHOTO_LIMITER, clientKey(c.req.raw))
    if (limiterResponse != null) return limiterResponse

    const image = await readBoundedBody(c.req.raw)
    if (image instanceof Response) return image
    const day = new Date().toISOString().slice(0, 10)
    const daily = c.env.MEAL_PHOTO_DAILY
    if (daily == null) return errorResponse('upstream_failed', 502)
    const counter = daily.get(daily.idFromName(installID))
    if (!await counter.canScan(installID, day)) {
      const retry = secondsUntilUtcMidnight()
      return errorResponse('daily_limit', 429, { 'Retry-After': String(retry) })
    }

    const started = Date.now()
    try {
      const result = await callGemini(c.env, image)
      await counter.recordSuccess(installID, day)
      const duration = Date.now() - started
      console.info(JSON.stringify({ status: 200, durationMs: duration, model: MODEL }))
      return Response.json({ requestId: crypto.randomUUID(), model: MODEL, ...result }, { headers: noStore })
    } catch (error) {
      const duration = Date.now() - started
      const code = error instanceof GeminiTimeoutError ? 'upstream_timeout' : 'upstream_failed'
      console.warn(JSON.stringify({ status: code === 'upstream_timeout' ? 504 : 502, durationMs: duration, model: MODEL }))
      return errorResponse(code, code === 'upstream_timeout' ? 504 : 502)
    }
  })

  app.post('/v1/meal-photo/feedback', async (c) => {
    const limited = await enforceMealPhotoRateLimit(c.env.MEAL_PHOTO_LIMITER, clientKey(c.req.raw))
    if (limited != null) return limited
    let body: unknown
    try {
      body = await c.req.json()
    } catch {
      return errorResponse('bad_input', 400)
    }
    const parsed = feedbackSchema.safeParse(body)
    if (!parsed.success) return errorResponse('bad_input', 400)
    const analytics = c.env.MEAL_PHOTO_FEEDBACK
    if (analytics == null) return errorResponse('upstream_failed', 502)
    const data = parsed.data
    try {
      analytics.writeDataPoint({
        blobs: [data.model, data.hiddenFatAnswer],
        doubles: [data.suggested, data.keptUnchanged, data.gramsEdited, data.medianGramChangePct ?? 0, data.removed, data.added],
        indexes: [data.requestId],
      })
    } catch {
      return errorResponse('upstream_failed', 502)
    }
    return new Response(null, { status: 204, headers: { 'Cache-Control': 'no-store' } })
  })
}

async function callGemini(env: Env, image: ArrayBuffer): Promise<Estimate> {
  if (env.GEMINI_API_KEY == null || env.GEMINI_API_KEY.length === 0) throw new Error('Missing Gemini configuration')
  const baseURL = env.GEMINI_BASE_URL || 'https://generativelanguage.googleapis.com'
  const endpoint = `${baseURL.replace(/\/$/, '')}/v1beta/models/${MODEL}:generateContent`
  const deadline = Date.now() + GEMINI_TIMEOUT_MS
  const payload = {
    contents: [{ parts: [{ text: prompt }, { inline_data: { mime_type: 'image/jpeg', data: toBase64(new Uint8Array(image)) } }] }],
    generationConfig: { responseMimeType: 'application/json', responseJsonSchema: responseSchema },
  }
  for (let attempt = 0; attempt < 2; attempt += 1) {
    const remainingMs = deadline - Date.now()
    if (remainingMs <= 0) throw new GeminiTimeoutError()
    const controller = new AbortController()
    const timeout = setTimeout(() => controller.abort(), remainingMs)
    try {
      const response = await fetch(endpoint, {
        method: 'POST',
        // Header, not a ?key= query, so the key never appears in request URLs or logs.
        headers: { 'Content-Type': 'application/json', 'x-goog-api-key': env.GEMINI_API_KEY },
        body: JSON.stringify(payload),
        signal: controller.signal,
      })
      if ((response.status === 429 || response.status === 503) && attempt === 0) continue
      if (!response.ok) throw new Error(`Gemini status ${response.status}`)
      const body: unknown = await response.json()
      const text = extractText(body)
      return sanitize(JSON.parse(text) as unknown)
    } catch (error) {
      if (controller.signal.aborted) throw new GeminiTimeoutError()
      if (attempt === 1 || !(error instanceof Error && error.message.startsWith('Gemini status 429'))) throw error
    } finally {
      clearTimeout(timeout)
    }
  }
  throw new Error('Gemini failed')
}

type Estimate = { status: 'ok' | 'not_food' | 'unclear' | 'packaged'; foods: Food[] }
type Food = { name: string; grams: number | null; lowGrams: number | null; highGrams: number | null; preparation: string | null; hiddenFatLikely: boolean; volumeMl: number | null }

function sanitize(value: unknown): Estimate {
  if (typeof value !== 'object' || value == null) throw new Error('Malformed Gemini output')
  const record = value as Record<string, unknown>
  if (!['ok', 'not_food', 'unclear', 'packaged'].includes(String(record.status)) || !Array.isArray(record.foods)) throw new Error('Malformed Gemini output')
  const foods = record.foods.slice(0, 15).flatMap((raw): Food[] => {
    if (typeof raw !== 'object' || raw == null) return []
    const food = raw as Record<string, unknown>
    if (typeof food.name !== 'string' || food.name.trim().length === 0 || typeof food.hiddenFatLikely !== 'boolean') return []
    const grams = finiteOrNull(food.grams)
    const lowGrams = finiteOrNull(food.lowGrams)
    const highGrams = finiteOrNull(food.highGrams)
    const volumeMl = finiteOrNull(food.volumeMl)
    const preparation = food.preparation == null ? null : typeof food.preparation === 'string' ? food.preparation.slice(0, 120) : undefined
    if (preparation === undefined) return []
    return [{
      name: food.name.trim().slice(0, 120),
      grams: grams == null ? null : clamp(grams, 0, 3000),
      lowGrams: lowGrams == null ? null : clamp(lowGrams, 0, 3000),
      highGrams: highGrams == null ? null : clamp(highGrams, 0, 3000),
      preparation,
      hiddenFatLikely: food.hiddenFatLikely,
      volumeMl: volumeMl == null ? null : clamp(volumeMl, 0, 10000),
    }]
  })
  const status = record.status as Estimate['status']
  return { status, foods: status === 'not_food' || status === 'unclear' ? [] : foods }
}

function finiteOrNull(value: unknown): number | null {
  return value == null ? null : typeof value === 'number' && Number.isFinite(value) && value >= 0 ? value : null
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value))
}

function extractText(value: unknown): string {
  if (typeof value !== 'object' || value == null) throw new Error('Malformed Gemini response')
  const candidates = (value as { candidates?: unknown }).candidates
  if (!Array.isArray(candidates) || typeof candidates[0] !== 'object' || candidates[0] == null) throw new Error('Malformed Gemini response')
  const content = (candidates[0] as { content?: { parts?: unknown } }).content
  if (!Array.isArray(content?.parts) || typeof content.parts[0] !== 'object' || content.parts[0] == null) throw new Error('Malformed Gemini response')
  const text = (content.parts[0] as { text?: unknown }).text
  if (typeof text !== 'string') throw new Error('Malformed Gemini response')
  return text
}

function toBase64(bytes: Uint8Array): string {
  let binary = ''
  for (let index = 0; index < bytes.length; index += 0x8000) {
    binary += String.fromCharCode(...bytes.subarray(index, index + 0x8000))
  }
  return btoa(binary)
}

function secondsUntilUtcMidnight(): number {
  const now = new Date()
  const midnight = Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() + 1)
  return Math.ceil((midnight - now.getTime()) / 1000)
}

class GeminiTimeoutError extends Error {}

function errorResponse(code: string, status: number, extraHeaders: Record<string, string> = {}): Response {
  return Response.json({ error: code }, { status, headers: { 'Cache-Control': 'no-store', ...extraHeaders } })
}

async function readBoundedBody(request: Request): Promise<ArrayBuffer | Response> {
  const reader = request.body?.getReader()
  if (reader == null) return errorResponse('empty_body', 400)
  const chunks: Uint8Array[] = []
  let size = 0
  try {
    while (true) {
      const { done, value } = await reader.read()
      if (done) break
      size += value.byteLength
      if (size > MAX_IMAGE_BYTES) {
        await reader.cancel()
        return errorResponse('too_large', 413)
      }
      chunks.push(value)
    }
  } catch {
    return errorResponse('upstream_failed', 502)
  }
  if (size === 0) return errorResponse('empty_body', 400)
  const bytes = new Uint8Array(size)
  let offset = 0
  for (const chunk of chunks) {
    bytes.set(chunk, offset)
    offset += chunk.byteLength
  }
  return bytes.buffer
}

async function enforceMealPhotoRateLimit(limiter: Env['MEAL_PHOTO_LIMITER'] | undefined, key: string): Promise<Response | null> {
  if (limiter == null) return null
  const { success } = await limiter.limit({ key })
  return success ? null : errorResponse('rate_limited', 429, { 'Retry-After': '60' })
}
