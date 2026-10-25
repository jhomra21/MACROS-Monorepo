export interface RateLimiter {
  limit(options: { key: string }): Promise<{ success: boolean }>
}

export function clientKey(request: Request): string {
  return request.headers.get('cf-connecting-ip')?.trim() || 'unknown-client'
}

export async function enforceRateLimit(
  limiter: RateLimiter | undefined,
  key: string,
): Promise<Response | null> {
  if (limiter == null) {
    return null
  }

  const { success } = await limiter.limit({ key })

  if (success) {
    return null
  }

  return new Response(JSON.stringify({ error: RATE_LIMIT_ERROR }), {
    status: 429,
    headers: {
      'Cache-Control': 'no-store',
      'Content-Type': 'application/json; charset=utf-8',
      'Retry-After': '60',
    },
  })
}

export const RATE_LIMIT_ERROR = 'Too many requests. Please try again in a minute.'
