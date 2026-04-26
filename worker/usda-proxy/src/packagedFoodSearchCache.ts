import type {
  PackagedFoodSearchDegradedFallbackReason,
  PackagedFoodSearchQuery,
  PackagedFoodSearchResponse,
} from './types'
import { hasUsableOpenFoodFactsResult } from './packagedFoods'

export type PackagedFoodCacheKeyKind = 'default' | 'openFoodFacts' | 'openFoodFactsPinned' | 'usda'
type PackagedFoodCacheableResponse = PackagedFoodSearchResponse & {
  degradedFallbackReason?: PackagedFoodSearchDegradedFallbackReason
}

export interface NamedCacheKey {
  kind: PackagedFoodCacheKeyKind
  request: Request
}

const DEFAULT_CACHE_PATH = '/v1/packaged-foods/search/default'
const OPEN_FOOD_FACTS_CACHE_PATH = '/v1/packaged-foods/search/openFoodFacts'
const OPEN_FOOD_FACTS_PINNED_CACHE_PATH = '/v1/packaged-foods/search/openFoodFacts/pinned'
const USDA_CACHE_PATH = '/v1/packaged-foods/search/usda'

export function cacheReadOrder(url: URL, params: PackagedFoodSearchQuery): NamedCacheKey[] {
  switch (params.provider) {
  case 'openFoodFacts':
    return [
      namedCacheKey(url, params, 'openFoodFactsPinned'),
      namedCacheKey(url, params, 'openFoodFacts'),
    ]
  case 'usda':
    return [namedCacheKey(url, params, 'usda')]
  default:
    return [
      namedCacheKey(url, params, 'openFoodFacts'),
      namedCacheKey(url, params, 'default'),
    ]
  }
}

export function cacheWritePlan(url: URL, params: PackagedFoodSearchQuery, response: PackagedFoodCacheableResponse): NamedCacheKey[] {
  switch (params.provider) {
  case 'openFoodFacts':
    if (response.resolvedProvider !== 'openFoodFacts') {
      return []
    }

    return [
      namedCacheKey(url, params, 'openFoodFactsPinned'),
      ...(shouldShareOpenFoodFactsResponse(params, response)
        ? [namedCacheKey(url, params, 'openFoodFacts')]
        : []),
    ]
  case 'usda':
    return response.resolvedProvider === 'usda'
      ? [namedCacheKey(url, params, 'usda')]
      : []
  default:
    return defaultCacheWritePlan(url, params, response)
  }
}

export function shouldPersistDefaultFallback(
  degradedFallbackReason: PackagedFoodSearchDegradedFallbackReason | undefined,
): boolean {
  return degradedFallbackReason == null || degradedFallbackReason === 'openFoodFactsNoUsableResults'
}

function defaultCacheWritePlan(url: URL, params: PackagedFoodSearchQuery, response: PackagedFoodCacheableResponse): NamedCacheKey[] {
  switch (response.resolvedProvider) {
  case 'openFoodFacts':
    return [
      ...(shouldShareOpenFoodFactsResponse(params, response)
        ? [namedCacheKey(url, params, 'openFoodFacts')]
        : []),
      namedCacheKey(url, params, 'default'),
    ]
  case 'usda':
    if (shouldPersistDefaultFallback(response.degradedFallbackReason)) {
      return [
        namedCacheKey(url, params, 'usda'),
        namedCacheKey(url, params, 'default'),
      ]
    }

    return [namedCacheKey(url, params, 'usda')]
  default:
    return []
  }
}

function namedCacheKey(url: URL, params: PackagedFoodSearchQuery, kind: PackagedFoodCacheKeyKind): NamedCacheKey {
  return {
    kind,
    request: buildCacheKey(url, pathForKind(kind), cacheQueryItems(kind, params)),
  }
}

function pathForKind(kind: PackagedFoodCacheKeyKind): string {
  switch (kind) {
  case 'default':
    return DEFAULT_CACHE_PATH
  case 'openFoodFacts':
    return OPEN_FOOD_FACTS_CACHE_PATH
  case 'openFoodFactsPinned':
    return OPEN_FOOD_FACTS_PINNED_CACHE_PATH
  case 'usda':
    return USDA_CACHE_PATH
  }
}

function cacheQueryItems(kind: PackagedFoodCacheKeyKind, params: PackagedFoodSearchQuery): Array<[string, string]> {
  const items: Array<[string, string]> = [
    ['q', params.query.toLowerCase()],
    ['page', String(params.page)],
    ['pageSize', String(params.pageSize)],
  ]

  if (kind === 'default') {
    items.push(['fallbackOnEmpty', params.fallbackOnEmpty ? '1' : '0'])
  }

  return items
}

export function buildCacheKey(url: URL, path: string, queryItems: Array<[string, string]>): Request {
  const cacheURL = new URL(url.origin)
  cacheURL.pathname = path
  for (const [key, value] of queryItems) {
    cacheURL.searchParams.set(key, value)
  }
  return new Request(cacheURL.toString(), { method: 'GET' })
}

function shouldShareOpenFoodFactsResponse(
  params: PackagedFoodSearchQuery,
  response: PackagedFoodCacheableResponse,
): boolean {
  return params.page === 1 && hasUsableOpenFoodFactsResult(response)
}
