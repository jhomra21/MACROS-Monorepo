import { Hono } from 'hono'
import type { Context } from 'hono'
import { OpenFoodFactsClientError } from './openFoodFacts'
import {
  buildCacheKey,
  cacheReadOrder,
  cacheWritePlan,
} from './packagedFoodSearchCache'
import type { PackagedFoodCacheKeyKind } from './packagedFoodSearchCache'
import { searchPackagedFoods } from './packagedFoods'
import type { PackagedFoodSearchExecution } from './packagedFoods'
import type {
  PackagedFoodSearchQuery,
  PackagedFoodSearchResponse,
  SearchProvider,
  USDAProxyErrorResponse,
} from './types'
import { fetchUSDAFood, USDAClientError, searchUSDAFoods } from './usda'

const app = new Hono<{ Bindings: Env }>()
const CACHE_TTL_SECONDS = 300
const MAX_PAGE = 10
const MAX_PAGE_SIZE = 25
const MIN_QUERY_LENGTH = 2
const SEARCH_QUERY_KEYS = new Set(['q', 'page', 'pageSize'])
const PACKAGED_SEARCH_QUERY_KEYS = new Set([...SEARCH_QUERY_KEYS, 'fallbackOnEmpty', 'provider'])

interface PackagedFoodSearchLogContext {
  page: number
  pageSize: number
  provider: SearchProvider | 'default'
}

interface PackagedFoodSearchLogMetadata {
  cacheKey?: PackagedFoodCacheKeyKind
  openFoodFactsAttemptCount?: number
  resolvedProvider?: SearchProvider
  degradedFallbackReason?: PackagedFoodSearchExecution['degradedFallbackReason']
  errorMessage?: string
}

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

  try {
    const response = await searchPackagedFoods(
      params,
      c.env.USDA_API_KEY,
      c.env.OPEN_FOOD_FACTS_USER_AGENT,
    )

    logPackagedFoodSearch('cache-miss', logContext, {
      openFoodFactsAttemptCount: response.openFoodFactsAttemptCount,
      resolvedProvider: response.resolvedProvider,
      degradedFallbackReason: response.degradedFallbackReason,
    })

    const cacheWrites = cacheWritePlan(requestURL, params, response)
    const jsonResponse = cachedJSONResponse(publicPackagedFoodResponse(response))

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

  try {
    const response = await searchUSDAFoods(params, c.env.USDA_API_KEY)
    const jsonResponse = c.json(response)
    jsonResponse.headers.set('Cache-Control', `public, s-maxage=${CACHE_TTL_SECONDS}`)
    c.executionCtx.waitUntil(cache.put(cacheKey, jsonResponse.clone()))
    return jsonResponse
  } catch (error) {
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

  try {
    const response = await fetchUSDAFood(fdcId, c.env.USDA_API_KEY)
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

  const fallbackOnEmpty = allowFallbackOnEmpty ? parseBooleanFlag(c.req.query('fallbackOnEmpty') ?? '1') : false
  if (allowFallbackOnEmpty && fallbackOnEmpty == null) {
    return jsonError(c, 'fallbackOnEmpty must be 0, 1, true, or false.', 400)
  }

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
    fallbackOnEmpty: fallbackOnEmpty ?? false,
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

export function packagedFoodSearchLogContext(
  params: Pick<PackagedFoodSearchQuery, 'page' | 'pageSize' | 'provider'>,
): PackagedFoodSearchLogContext {
  return {
    page: params.page,
    pageSize: params.pageSize,
    provider: params.provider ?? 'default',
  }
}

export function packagedFoodSearchLogEntry(
  phase: string,
  context: PackagedFoodSearchLogContext,
  metadata: PackagedFoodSearchLogMetadata = {},
) {
  return {
    phase,
    page: context.page,
    pageSize: context.pageSize,
    provider: context.provider,
    ...metadata,
  }
}

function logPackagedFoodSearch(
  phase: string,
  context: PackagedFoodSearchLogContext,
  metadata: PackagedFoodSearchLogMetadata = {},
): void {
  console.info(JSON.stringify(packagedFoodSearchLogEntry(phase, context, metadata)))
}

function handleSearchError(error: unknown, fallbackMessage: string) {
  if (error instanceof USDAClientError || error instanceof OpenFoodFactsClientError) {
    return jsonError(undefined, error.message, error.status)
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
