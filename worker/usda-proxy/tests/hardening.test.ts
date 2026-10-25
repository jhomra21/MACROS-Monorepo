import { describe, expect, it } from 'bun:test'
import { clientKey, enforceRateLimit, RATE_LIMIT_ERROR } from '../src/rateLimit'
import { searchPackagedFoods } from '../src/packagedFoods'

// Failure cases covered: missing IP, absent dev binding, rejected request,
// successful request, and exhausted shared USDA budget.
describe('service hardening failure cases', () => {
  it('uses a stable fallback key when the client IP header is missing', () => {
    expect(clientKey(new Request('https://example.test'))).toBe('unknown-client')
  })

  it('allows requests when the binding is absent in local development', async () => {
    await expect(enforceRateLimit(undefined, 'test')).resolves.toBeNull()
  })

  it('returns a non-cacheable 429 with Retry-After when exhausted', async () => {
    const response = await enforceRateLimit({ limit: async () => ({ success: false }) }, 'test')

    expect(response?.status).toBe(429)
    expect(response?.headers.get('Retry-After')).toBe('60')
    expect(response?.headers.get('Cache-Control')).toBe('no-store')
    expect(await response?.text()).toBe(JSON.stringify({ error: RATE_LIMIT_ERROR }))
  })

  it('allows a successful rate-limit decision', async () => {
    await expect(enforceRateLimit({ limit: async () => ({ success: true }) }, 'test')).resolves.toBeNull()
  })

  it('skips USDA when the global budget is exhausted', async () => {
    let upstreamCalls = 0

    const response = await searchPackagedFoods({
      query: 'protein bar',
      page: 1,
      pageSize: 10,
      fallbackOnEmpty: true,
      provider: 'usda',
    }, {
      usdaApiKey: 'test',
      openFoodFactsUserAgent: 'test',
      fetcher: async () => {
        upstreamCalls += 1

        return Response.json({ foods: [] })
      },
      allowUSDA: async () => false,
    })

    expect(response.results).toEqual([])
    expect(response.resolvedProvider).toBe('usda')
    expect(upstreamCalls).toBe(0)
  })
})
