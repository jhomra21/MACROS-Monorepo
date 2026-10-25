import { Hono } from 'hono'
import type { Context } from 'hono'
import {
  fetchOpenFoodFactsProduct,
  normalizedOpenFoodFactsBarcode,
  OpenFoodFactsClientError,
} from './openFoodFacts'
import {
  buildCacheKey,
  cacheReadOrder,
  cacheWritePlan,
} from './packagedFoodSearchCache'
import { searchPackagedFoods } from './packagedFoods'
import type { PackagedFoodSearchExecution } from './packagedFoods'
import type {
  PackagedFoodSearchResponse,
  SearchProvider,
  USDAProxyErrorResponse,
} from './types'
import { fetchUSDAFood, USDAClientError, searchUSDAFoods } from './usda'
import { withTimeout } from './http'
import { clientKey, enforceRateLimit } from './rateLimit'

import {
  packagedFoodSearchLogContext,
  packagedFoodSearchLogEntry,
} from './packagedFoodSearchLogging'
import type { PackagedFoodSearchLogContext, PackagedFoodSearchLogMetadata } from './packagedFoodSearchLogging'

export { UsdaBudget } from './usdaBudget'

const app = new Hono<{ Bindings: Env }>()

const CACHE_TTL_SECONDS = 86_400

const MAX_PAGE = 10

const MAX_PAGE_SIZE = 25

const MIN_QUERY_LENGTH = 2

const SEARCH_QUERY_KEYS = new Set(['q', 'page', 'pageSize'])

const PACKAGED_SEARCH_QUERY_KEYS = new Set([...SEARCH_QUERY_KEYS, 'fallbackOnEmpty', 'provider'])

const DEFAULT_REQUEST_DEADLINE_MS = 8_000

const DEFAULT_USDA_BUDGET_TIMEOUT_MS = 500

app.get('/v1/packaged-foods/search', async (c) => {
  const params = parseSearchParams(c, PACKAGED_SEARCH_QUERY_KEYS, true)

  if (params instanceof Response) {
    return params
  }

  const cache = await caches.open('usda-proxy')
  const requestURL = new URL(c.req.url)
  const logContext = packagedFoodSearchLogContext(params)

  for (const cacheKey of cacheReadOrder(requestURL, params)) {
    const cachedResponse = await cache.match(cacheKey.request)

    if (cachedResponse != null) {
      logPackagedFoodSearch('cache-hit', logContext, {
        cacheKey: cacheKey.kind,
      })

      return cachedResponse
    }
  }

  const rateLimitResponse = await enforceRateLimit(c.env.PACKAGED_SEARCH_LIMITER, clientKey(c.req.raw))

  if (rateLimitResponse != null) {
    return rateLimitResponse
  }

  const requestDeadlineMs = positiveEnvInteger(c.env.REQUEST_DEADLINE_MS, DEFAULT_REQUEST_DEADLINE_MS)
  const requestDeadline = { signal: AbortSignal.timeout(requestDeadlineMs), expiresAt: Date.now() + requestDeadlineMs }
  const budgetTimeoutMs = usdaBudgetTimeoutMs(c.env)

  try {
    const response = await searchPackagedFoods(
      params,
      {
        usdaApiKey: c.env.USDA_API_KEY,
        openFoodFactsUserAgent: c.env.OPEN_FOOD_FACTS_USER_AGENT,
        requestDeadline,
        allowUSDA: () => checkGlobalUSDABudget(c.env.USDA_BUDGET, budgetTimeoutMs, requestDeadline.signal),
      },
    )

    logPackagedFoodSearch('cache-miss', logContext, {
      openFoodFactsAttemptCount: response.openFoodFactsAttemptCount,
      resolvedProvider: response.resolvedProvider,
    })

    const cacheWrites = response.cacheable === false ? [] : cacheWritePlan(requestURL, params, response)
    const jsonResponse = cachedJSONResponse(publicPackagedFoodResponse(response))

    if (response.cacheable === false) {
      jsonResponse.headers.set('Cache-Control', 'no-store')
      jsonResponse.headers.set('X-MACROS-Degraded', response.degradedReason ?? 'upstream-unavailable')
    }

    if (cacheWrites.length > 0) {
      c.executionCtx.waitUntil(
        Promise.all(
          cacheWrites.map((cacheKey) => cache.put(cacheKey.request, jsonResponse.clone())),
        ),
      )
    }

    return jsonResponse
  } catch (error) {
    return handleSearchError(error, 'Packaged food search is unavailable right now.')
  }
})

app.get('/v1/packaged-foods/barcodes/:barcode', async (c) => {
  const barcode = normalizedOpenFoodFactsBarcode(c.req.param('barcode'))

  if (barcode == null) {
    return jsonError(c, 'Barcode must contain digits only.', 400)
  }

  const cache = await caches.open('usda-proxy')
  const cacheKey = buildCacheKey(new URL(c.req.url), `/v1/packaged-foods/barcodes/${barcode}`, [])
  const cachedResponse = await cache.match(cacheKey)

  if (cachedResponse != null) {
    return cachedResponse
  }

  const rateLimitResponse = await enforceRateLimit(c.env.BARCODE_LIMITER, clientKey(c.req.raw))

  if (rateLimitResponse != null) {
    return rateLimitResponse
  }

  const requestDeadline = AbortSignal.timeout(positiveEnvInteger(c.env.REQUEST_DEADLINE_MS, DEFAULT_REQUEST_DEADLINE_MS))

  try {
    const product = await fetchOpenFoodFactsProduct(
      barcode,
      { userAgent: c.env.OPEN_FOOD_FACTS_USER_AGENT },
      withTimeout(fetch, undefined, requestDeadline),
    )

    const jsonResponse = cachedJSONResponse({ product })
    c.executionCtx.waitUntil(cache.put(cacheKey, jsonResponse.clone()))

    return jsonResponse
  } catch (error) {
    if (error instanceof OpenFoodFactsClientError && error.status === 404) {
      const jsonResponse = cachedJSONResponse({ product: null })
      c.executionCtx.waitUntil(cache.put(cacheKey, jsonResponse.clone()))

      return jsonResponse
    }

    return handleSearchError(error, 'Open Food Facts product lookup is unavailable right now.')
  }
})

app.get('/v1/usda/search', async (c) => {
  const params = parseSearchParams(c, SEARCH_QUERY_KEYS, false)

  if (params instanceof Response) {
    return params
  }

  const cache = await caches.open('usda-proxy')

  const cacheKey = buildCacheKey(new URL(c.req.url), '/v1/usda/search', [
    ['q', params.query.toLowerCase()],
    ['page', String(params.page)],
    ['pageSize', String(params.pageSize)],
  ])

  const cachedResponse = await cache.match(cacheKey)

  if (cachedResponse != null) {
    return cachedResponse
  }

  const rateLimitResponse = await enforceRateLimit(c.env.USDA_SEARCH_LIMITER, clientKey(c.req.raw))

  if (rateLimitResponse != null) {
    return rateLimitResponse
  }

  const requestDeadline = AbortSignal.timeout(positiveEnvInteger(c.env.REQUEST_DEADLINE_MS, DEFAULT_REQUEST_DEADLINE_MS))
  const budgetTimeoutMs = usdaBudgetTimeoutMs(c.env)

  let budgetExhausted = false

  try {
    const response = await searchUSDAFoods(
      params,
      c.env.USDA_API_KEY,
      withTimeout(fetch, undefined, requestDeadline),
      async () => {
        const allowed = await checkGlobalUSDABudget(c.env.USDA_BUDGET, budgetTimeoutMs, requestDeadline)
        budgetExhausted ||= !allowed

        return allowed
      },
    )

    const jsonResponse = c.json(response)

    if (budgetExhausted && response.results.length === 0) {
      jsonResponse.headers.set('Cache-Control', 'no-store')
      jsonResponse.headers.set('X-MACROS-Degraded', 'usda-budget-exhausted')
    } else {
      jsonResponse.headers.set('Cache-Control', `public, s-maxage=${CACHE_TTL_SECONDS}`)
      c.executionCtx.waitUntil(cache.put(cacheKey, jsonResponse.clone()))
    }

    return jsonResponse
  } catch (error) {
    if (budgetExhausted) {
      const response = handleSearchError(error, 'USDA search is unavailable right now.')
      response.headers.set('Cache-Control', 'no-store')
      response.headers.set('X-MACROS-Degraded', 'usda-budget-exhausted')

      return response
    }

    return handleSearchError(error, 'USDA search is unavailable right now.')
  }
})

app.get('/v1/usda/foods/:fdcId', async (c) => {
  const fdcId = parsePositiveInt(c.req.param('fdcId'))

  if (fdcId == null) {
    return jsonError(c, 'fdcId must be a positive integer.', 400)
  }

  const cache = await caches.open('usda-proxy')
  const cacheKey = buildCacheKey(new URL(c.req.url), `/v1/usda/foods/${fdcId}`, [])
  const cachedResponse = await cache.match(cacheKey)

  if (cachedResponse != null) {
    return cachedResponse
  }

  const deadlineMs = positiveEnvInteger(c.env.REQUEST_DEADLINE_MS, DEFAULT_REQUEST_DEADLINE_MS)
  const requestDeadline = AbortSignal.timeout(deadlineMs)

  if (requestDeadline.aborted) {
    return degradedUSDADetailResponse(c, 'request-deadline-expired')
  }

  const budgetAllowed = await checkGlobalUSDABudget(c.env.USDA_BUDGET, usdaBudgetTimeoutMs(c.env), requestDeadline)

  if (requestDeadline.aborted) {
    return degradedUSDADetailResponse(c, 'request-deadline-expired')
  }

  if (!budgetAllowed) {
    return jsonError(c, 'USDA food details are unavailable right now.', 503)
  }

  try {
    const response = await fetchUSDAFood(fdcId, c.env.USDA_API_KEY, withTimeout(fetch, undefined, requestDeadline))
    const jsonResponse = c.json(response)
    jsonResponse.headers.set('Cache-Control', `public, s-maxage=${CACHE_TTL_SECONDS}`)
    c.executionCtx.waitUntil(cache.put(cacheKey, jsonResponse.clone()))

    return jsonResponse
  } catch (error) {
    return handleSearchError(error, 'USDA food details are unavailable right now.')
  }
})

app.notFound((c) => jsonError(c, 'Not found.', 404))

app.onError((error) => handleSearchError(error, 'Packaged food search is unavailable right now.'))

function degradedUSDADetailResponse(
  c: Context,
  reason: 'request-deadline-expired' | 'usda-budget-exhausted',
): Response {
  const response = jsonError(c, 'USDA food details are unavailable right now.', 503)
  response.headers.set('Cache-Control', 'no-store')
  response.headers.set('X-MACROS-Degraded', reason)

  return response
}

function usdaBudgetTimeoutMs(env: Env): number {
  return positiveEnvInteger(env.USDA_BUDGET_TIMEOUT_MS, DEFAULT_USDA_BUDGET_TIMEOUT_MS)
}

async function checkGlobalUSDABudget(
  budget: Env['USDA_BUDGET'] | undefined,
  timeoutMs: number,
  deadlineSignal?: AbortSignal,
): Promise<boolean> {
  if (budget == null) return true

  if (deadlineSignal?.aborted) return true

  try {
    let timeoutId: ReturnType<typeof setTimeout> | undefined
    let abortListener: (() => void) | undefined
    const acquire = budget.get(budget.idFromName('usda')).acquire()

    const timedOut = new Promise<never>((_resolve, reject) => {
      // A native timer bounds the RPC independently of the request's abort signal.
      timeoutId = setTimeout(() => reject(new Error('USDA budget coordination timed out')), timeoutMs)
    })

    const deadlineExpired = deadlineSignal == null
      ? undefined
      : new Promise<never>((_resolve, reject) => {
        abortListener = () => reject(deadlineSignal.reason)
        deadlineSignal.addEventListener('abort', abortListener, { once: true })

        if (deadlineSignal.aborted) abortListener()
      })

    try {
      return (await Promise.race(deadlineExpired == null
        ? [acquire, timedOut]
        : [acquire, timedOut, deadlineExpired])).allowed
    } finally {
      if (timeoutId != null) clearTimeout(timeoutId)

      if (abortListener != null) deadlineSignal?.removeEventListener('abort', abortListener)
    }
  } catch {
    // Keep USDA lookups available during a temporary coordination failure. Sample one line per invocation.
    if (Math.random() < 0.01) {
      console.warn('USDA budget check failed; allowing request')
    }

    return true
  }
}

function positiveEnvInteger(value: string | undefined, fallback: number): number {
  const parsed = Number.parseInt(value ?? '', 10)

  return Number.isSafeInteger(parsed) && parsed > 0 ? parsed : fallback
}

function parseSearchParams(c: Context, allowedKeys: Set<string>, allowFallbackOnEmpty: boolean) {
  const url = new URL(c.req.url)
  const invalidKeys = [...new Set(url.searchParams.keys())].filter((key) => allowedKeys.has(key) === false)

  if (invalidKeys.length > 0) {
    return jsonError(c, 'Unsupported query parameters.', 400)
  }

  const query = (c.req.query('q') ?? '').trim()

  if (query.length < MIN_QUERY_LENGTH) {
    return jsonError(c, 'Enter at least 2 characters to search packaged foods.', 400)
  }

  const page = parseBoundedPositiveInt(c.req.query('page') ?? '1', MAX_PAGE)

  if (page == null) {
    return jsonError(c, `Page must be between 1 and ${MAX_PAGE}.`, 400)
  }

  const pageSize = parseBoundedPositiveInt(c.req.query('pageSize') ?? '12', MAX_PAGE_SIZE)

  if (pageSize == null) {
    return jsonError(c, `Page size must be between 1 and ${MAX_PAGE_SIZE}.`, 400)
  }

  const parsedFallbackOnEmpty = allowFallbackOnEmpty ? parseBooleanFlag(c.req.query('fallbackOnEmpty') ?? '1') : false

  if (allowFallbackOnEmpty && parsedFallbackOnEmpty == null) {
    return jsonError(c, 'fallbackOnEmpty must be 0, 1, true, or false.', 400)
  }

  const fallbackOnEmpty = parsedFallbackOnEmpty ?? false

  const provider = allowFallbackOnEmpty ? parseSearchProvider(c.req.query('provider')) : undefined

  if (allowFallbackOnEmpty && c.req.query('provider') != null && provider == null) {
    return jsonError(c, 'provider must be openFoodFacts or usda.', 400)
  }

  if (allowFallbackOnEmpty && page > 1 && provider == null) {
    return jsonError(c, 'provider is required for packaged food search pages after page 1.', 400)
  }

  return {
    query,
    page,
    pageSize,
    fallbackOnEmpty,
    provider,
  }
}

function parseBoundedPositiveInt(value: string, max: number): number | null {
  if (/^\d+$/.test(value) === false) {
    return null
  }

  const parsed = Number.parseInt(value, 10)

  return Number.isInteger(parsed) && parsed > 0 && parsed <= max ? parsed : null
}

function parsePositiveInt(value: string): number | null {
  if (/^\d+$/.test(value) === false) {
    return null
  }

  const parsed = Number.parseInt(value, 10)

  return Number.isInteger(parsed) && parsed > 0 ? parsed : null
}

function parseBooleanFlag(value: string): boolean | null {
  if (value === '1' || value.toLowerCase() === 'true') {
    return true
  }

  if (value === '0' || value.toLowerCase() === 'false') {
    return false
  }

  return null
}

function parseSearchProvider(value: string | undefined): SearchProvider | undefined {
  if (value == null) {
    return undefined
  }

  if (value === 'openFoodFacts' || value === 'usda') {
    return value
  }

  return undefined
}

function cachedJSONResponse<T>(body: T): Response {
  const response = new Response(JSON.stringify(body), {
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
    },
  })

  response.headers.set('Cache-Control', `public, s-maxage=${CACHE_TTL_SECONDS}`)

  return response
}

function publicPackagedFoodResponse(response: PackagedFoodSearchExecution): PackagedFoodSearchResponse {
  return {
    query: response.query,
    page: response.page,
    pageSize: response.pageSize,
    resolvedProvider: response.resolvedProvider,
    results: response.results,
    hasMore: response.hasMore,
  }
}

function logPackagedFoodSearch(
  phase: string,
  context: PackagedFoodSearchLogContext,
  metadata: PackagedFoodSearchLogMetadata = {},
): void {
  console.info(JSON.stringify(packagedFoodSearchLogEntry(phase, context, metadata)))
}

function handleSearchError(cause: unknown, fallbackMessage: string) {
  if (cause instanceof USDAClientError || cause instanceof OpenFoodFactsClientError) {
    return jsonError(undefined, cause.message, cause.status)
  }

  console.error('Unhandled Worker search error')

  return jsonError(undefined, fallbackMessage, 503)
}

function jsonError(_c: Context | undefined, message: string, status: number) {
  const body: USDAProxyErrorResponse = { error: message }

  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
    },
  })
}

export default app
