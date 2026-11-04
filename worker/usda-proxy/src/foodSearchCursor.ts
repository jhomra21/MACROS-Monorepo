import { z } from 'zod'

const cursorSchema = z.object({
  version: z.literal(1),
  query: z.string().length(32),
  batch: z.number().int().min(1).max(9),
  positions: z.record(z.string().max(80), z.string().max(200).nullable()),
  seen: z.array(z.string().max(32)).max(800),
})

export type FoodSearchCursor = z.infer<typeof cursorSchema>

export class UnifiedSearchError extends Error {
  constructor(readonly status: number) {
    super('Try again')
  }
}

export function normalizedFoodQuery(query: string): string {
  const normalized = query.trim().toLowerCase().replace(/\s+/g, ' ')

  if (normalized.length < 3 || normalized.length > 120) throw new UnifiedSearchError(400)

  return normalized
}

export function parseSourcePage(cursor: string | null): number {
  if (cursor == null) return 1

  if (!/^(?:[1-9]|10)$/.test(cursor)) throw new UnifiedSearchError(400)

  return Number(cursor)
}

export async function fingerprint(value: string): Promise<string> {
  const hash = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value))

  return Array.from(new Uint8Array(hash).slice(0, 16), (byte) =>
    byte.toString(16).padStart(2, '0'),
  ).join('')
}

export async function decodeFoodCursor(
  value: string | undefined,
  query: string,
): Promise<FoodSearchCursor | undefined> {
  if (value == null) return undefined

  if (value.length > 16384 || !/^[A-Za-z0-9_-]+$/.test(value)) throw new UnifiedSearchError(400)

  try {
    const parsed = cursorSchema.parse(JSON.parse(atob(value.replace(/-/g, '+').replace(/_/g, '/'))))

    if (parsed.query !== (await fingerprint(query))) throw new Error('query mismatch')

    return parsed
  } catch {
    throw new UnifiedSearchError(400)
  }
}

export function encodeFoodCursor(cursor: FoodSearchCursor): string {
  const encoded = btoa(JSON.stringify(cursor))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '')

  if (encoded.length > 16384) throw new UnifiedSearchError(503)

  return encoded
}
