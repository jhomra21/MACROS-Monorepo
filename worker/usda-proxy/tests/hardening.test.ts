import { describe, expect, it, mock, spyOn } from 'bun:test'
import { clientKey, enforceRateLimit, RATE_LIMIT_ERROR } from '../src/rateLimit'
import { searchPackagedFoods } from '../src/packagedFoods'
import { decideUsdaBudget, USDA_BUDGET_WINDOW_MS } from '../src/usdaBudgetLogic'
import { withTimeout } from '../src/http'

// Failure cases covered: missing IP, absent dev binding, rejected request,
// successful request, and exhausted shared USDA budget.
describe('service hardening failure cases', () => {
  it('uses a stable fallback key when the client IP header is missing', () => {
    expect(clientKey(new Request('https://example.test'))).toBe('unknown-client')
  })

  it('resets the shared budget on the next fixed minute window', () => {
    const at = 120_000
    const denied = decideUsdaBudget(at, 14, at + 1, 14)
    const rolled = decideUsdaBudget(denied.windowStart, 14, at + USDA_BUDGET_WINDOW_MS, 14)

    expect(denied.allowed).toBe(false)
    expect(rolled.allowed).toBe(true)
    expect(rolled.nextCount).toBe(1)
  })

  it('aborts the upstream fetch when the total request deadline expires', async () => {
    let observedSignal: AbortSignal | undefined

    const fetcher = withTimeout(
      (_input, init) => new Promise<Response>((_resolve, reject) => {
        if (init?.signal != null) {
          observedSignal = init.signal
          init.signal.addEventListener('abort', () => reject(init.signal?.reason), { once: true })
        }
      }),
      1_000,
      AbortSignal.timeout(10),
    )

    await expect(fetcher('https://example.test')).rejects.toBeDefined()
    expect(observedSignal?.aborted).toBe(true)
  })

  it('returns a degraded response by the deadline when budget acquisition never resolves', async () => {
    mock.module('cloudflare:workers', () => ({
      DurableObject: class {
      }
    }))
    const { default: app } = await import('../src/index')
    const previousCaches = globalThis.caches
    Object.defineProperty(globalThis, 'caches', {
      configurable: true,
      value: { open: async () => ({ match: async () => undefined }) },
    })
    const fetchMock = spyOn(globalThis, 'fetch').mockResolvedValue(Response.json({}))
    const startedAt = Date.now()

    // SAFETY: The fake namespace implements the exact ID and acquire operations this route invokes.
    const budgetBinding = {
      idFromName: () => 'usda',
      get: () => ({ acquire: () => new Promise(() => undefined) }),
    } as never

    const env: Env = {
      PACKAGED_SEARCH_LIMITER: { limit: async () => ({ success: true }) },
      BARCODE_LIMITER: { limit: async () => ({ success: true }) },
      USDA_SEARCH_LIMITER: { limit: async () => ({ success: true }) },
      USDA_BUDGET_PER_MINUTE: '14',
      USDA_BUDGET_TIMEOUT_MS: '500',
      REQUEST_DEADLINE_MS: '8000',
      USDA_API_KEY: 'test',
      OPEN_FOOD_FACTS_USER_AGENT: 'test',
      USDA_BUDGET: budgetBinding,
    }

    // SAFETY: Exercise the runtime-configurable deadline despite Wrangler's generated literal type.
    Object.defineProperty(env, 'REQUEST_DEADLINE_MS', { value: '50' })

    try {
      const response = await app.request(
        'https://example.test/v1/usda/foods/123',
        {},
        env,
      )

      expect(response.status).toBe(503)
      expect(response.headers.get('Cache-Control')).toBe('no-store')
      expect(response.headers.get('X-MACROS-Degraded')).toBe('request-deadline-expired')
      expect(Date.now() - startedAt).toBeLessThan(300)
      expect(fetchMock).not.toHaveBeenCalled()
    } finally {
      fetchMock.mockRestore()
      Object.defineProperty(globalThis, 'caches', {
        configurable: true,
        value: previousCaches,
      })
    }
  })

  it('stops cumulative upstream attempts at the deadline and recovers on retry', async () => {
    const input = {
      query: 'QA cereal',
      page: 1,
      pageSize: 10,
      fallbackOnEmpty: false,
      provider: 'openFoodFacts' as const,
    }

    let attempts = 0
    let abortedFetches = 0
    const startedAt = Date.now()
    const signal = AbortSignal.timeout(35)

    const fetcher = (url: string | URL | Request, init?: RequestInit) => new Promise<Response>((resolve, reject) => {
      attempts += 1
      const isSearchALicious = !String(url).includes('/cgi/search.pl')

      const timer = setTimeout(() => resolve(Response.json(isSearchALicious
        ? { hits: [], page_count: 1 }
        : { products: [], count: 0 })), isSearchALicious ? 20 : 80)

      init?.signal?.addEventListener('abort', () => {
        abortedFetches += 1
        clearTimeout(timer)
        reject(init.signal?.reason)
      }, { once: true })
    })

    const expired = await searchPackagedFoods(input, {
      usdaApiKey: 'test',
      openFoodFactsUserAgent: 'test',
      fetcher,
      requestDeadline: { signal, expiresAt: startedAt + 35 },
    })

    expect(attempts).toBeGreaterThanOrEqual(2)
    expect(abortedFetches).toBeGreaterThanOrEqual(1)
    expect(Date.now() - startedAt).toBeLessThan(100)
    expect(expired.cacheable).toBe(false)
    expect(expired.degradedReason).toBe('request-deadline-expired')

    const recovered = await searchPackagedFoods(input, {
      usdaApiKey: 'test',
      openFoodFactsUserAgent: 'test',
      fetcher: async () => Response.json({
        hits: [{
          code: '1234567890123',
          product_name: 'QA cereal',
          nutriments: {
            'energy-kcal_100g': 100,
            proteins_100g: 10,
            fat_100g: 2,
            carbohydrates_100g: 20,
          },
        }],
        page_count: 1,
      }),
    })

    expect(recovered.results).toHaveLength(1)
    expect(recovered.cacheable).toBeUndefined()
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
    expect(response.cacheable).toBe(false)
    expect(response.degradedReason).toBe('usda-budget-exhausted')
    expect(upstreamCalls).toBe(0)
  })
})
