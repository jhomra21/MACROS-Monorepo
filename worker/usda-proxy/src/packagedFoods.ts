import {
  OpenFoodFactsClientError,
  searchOpenFoodFactsLegacyFoods,
  searchOpenFoodFactsSearchALiciousFoods,
} from './openFoodFacts'
import type { OpenFoodFactsQuery, OpenFoodFactsRequestOptions } from './openFoodFacts'
import type {
  HTTPFetcher,
  PackagedFoodSearchDegradedFallbackReason,
  PackagedFoodSearchQuery,
  PackagedFoodSearchResponse,
  ProviderPage,
  SearchProvider,
  OpenFoodFactsProxyProduct,
} from './types'
import { searchUSDAFoods } from './usda'

const OPEN_FOOD_FACTS_PROVIDER = 'openFoodFacts' as const
const USDA_PROVIDER = 'usda' as const
const REQUEST_TIMEOUT_MS = 2_500

export interface PackagedFoodSearchExecution extends PackagedFoodSearchResponse {
  degradedFallbackReason?: PackagedFoodSearchDegradedFallbackReason
  openFoodFactsAttemptCount?: number
}

type OpenFoodFactsSearchOutcome =
  | {
    kind: 'response'
    attempts: number
    page: ProviderPage<PackagedFoodSearchResponse['results'][number]>
  }
  | {
    kind: 'unavailable'
    attempts: number
    error: OpenFoodFactsClientError
  }

type OpenFoodFactsSearcher = (
  input: OpenFoodFactsQuery,
  options: OpenFoodFactsRequestOptions,
  fetcher: HTTPFetcher,
) => Promise<ProviderPage<OpenFoodFactsProxyProduct>>

export async function searchPackagedFoods(
  input: PackagedFoodSearchQuery,
  apiKey: string,
  openFoodFactsUserAgent: string,
  fetcher: HTTPFetcher = fetch,
): Promise<PackagedFoodSearchExecution> {
  if (input.provider === OPEN_FOOD_FACTS_PROVIDER) {
    return searchOpenFoodFactsPackagedFoods(input, openFoodFactsUserAgent, fetcher)
  }

  if (input.provider === USDA_PROVIDER) {
    return searchUSDAPackagedFoods(input, apiKey, fetcher)
  }

  const outcome = await searchOpenFoodFactsWithOutcome(
    input,
    openFoodFactsUserAgent,
    fetcher,
    searchOpenFoodFactsSearchALiciousFoods,
  )

  if (outcome.kind === 'response') {
    const openFoodFactsResult = outcome.page
    if (shouldUseOpenFoodFactsResult(input, openFoodFactsResult)) {
      return makeResponse(input, OPEN_FOOD_FACTS_PROVIDER, openFoodFactsResult, undefined, outcome.attempts)
    }

    return searchUSDAPackagedFoods(
      input,
      apiKey,
      fetcher,
      'openFoodFactsNoUsableResults',
      outcome.attempts,
    )
  }

  return searchUSDAPackagedFoods(input, apiKey, fetcher, 'openFoodFactsUnavailable', outcome.attempts)
}

async function searchOpenFoodFactsWithOutcome(
  input: PackagedFoodSearchQuery,
  userAgent: string,
  fetcher: HTTPFetcher,
  searcher: OpenFoodFactsSearcher,
): Promise<OpenFoodFactsSearchOutcome> {
  const openFoodFactsFetcher = withTimeout(fetcher, REQUEST_TIMEOUT_MS)

  try {
    const result = await searcher(
      input,
      { userAgent },
      openFoodFactsFetcher,
    )
    return {
      kind: 'response',
      attempts: 1,
      page: {
        ...result,
        results: result.results.map((item) => ({ provider: OPEN_FOOD_FACTS_PROVIDER, item })),
      },
    }
  } catch (error) {
    const normalizedError = normalizeOpenFoodFactsError(error)
    if (normalizedError == null) {
      throw error
    }

    return {
      kind: 'unavailable',
      attempts: 1,
      error: normalizedError,
    }
  }
}

async function searchOpenFoodFactsPackagedFoods(
  input: PackagedFoodSearchQuery,
  userAgent: string,
  fetcher: HTTPFetcher,
): Promise<PackagedFoodSearchExecution> {
  const searchALiciousOutcome = await searchOpenFoodFactsWithOutcome(
    input,
    userAgent,
    fetcher,
    searchOpenFoodFactsSearchALiciousFoods,
  )
  if (searchALiciousOutcome.kind === 'response' && hasUsableOpenFoodFactsResult(searchALiciousOutcome.page)) {
    return makeResponse(input, OPEN_FOOD_FACTS_PROVIDER, searchALiciousOutcome.page, undefined, searchALiciousOutcome.attempts)
  }

  const legacyOutcome = await searchOpenFoodFactsWithOutcome(
    input,
    userAgent,
    fetcher,
    searchOpenFoodFactsLegacyFoods,
  )
  const totalAttempts = searchALiciousOutcome.attempts + legacyOutcome.attempts

  if (legacyOutcome.kind === 'unavailable') {
    throw legacyOutcome.error
  }

  return makeResponse(input, OPEN_FOOD_FACTS_PROVIDER, legacyOutcome.page, undefined, totalAttempts)
}

async function searchUSDAPackagedFoods(
  input: PackagedFoodSearchQuery,
  apiKey: string,
  fetcher: HTTPFetcher,
  degradedFallbackReason?: PackagedFoodSearchDegradedFallbackReason,
  openFoodFactsAttemptCount?: number,
): Promise<PackagedFoodSearchExecution> {
  const result = await searchUSDAFoods(input, apiKey, withTimeout(fetcher, REQUEST_TIMEOUT_MS))
  return makeResponse(input, USDA_PROVIDER, {
    ...result,
    results: result.results.map((item) => ({ provider: USDA_PROVIDER, item })),
  }, degradedFallbackReason, openFoodFactsAttemptCount)
}

function shouldFallbackOnEmpty(input: PackagedFoodSearchQuery): boolean {
  return input.fallbackOnEmpty && input.page === 1
}

export function hasUsableOpenFoodFactsResult(
  page: Pick<ProviderPage<PackagedFoodSearchResponse['results'][number]>, 'results' | 'hasMore'>,
): boolean {
  return page.results.length > 0 || page.hasMore
}

export function shouldUseOpenFoodFactsResult(
  input: PackagedFoodSearchQuery,
  page: ProviderPage<PackagedFoodSearchResponse['results'][number]>,
): boolean {
  return hasUsableOpenFoodFactsResult(page) || shouldFallbackOnEmpty(input) === false
}

function makeResponse(
  input: PackagedFoodSearchQuery,
  provider: SearchProvider,
  page: ProviderPage<PackagedFoodSearchResponse['results'][number]>,
  degradedFallbackReason?: PackagedFoodSearchDegradedFallbackReason,
  openFoodFactsAttemptCount?: number,
): PackagedFoodSearchExecution {
  return {
    query: input.query,
    page: page.page,
    pageSize: page.pageSize,
    resolvedProvider: provider,
    results: page.results,
    hasMore: page.hasMore,
    degradedFallbackReason,
    openFoodFactsAttemptCount,
  }
}

function normalizeOpenFoodFactsError(error: unknown): OpenFoodFactsClientError | null {
  if (error instanceof OpenFoodFactsClientError) {
    return error
  }

  if (error instanceof DOMException || error instanceof TypeError) {
    return new OpenFoodFactsClientError('Open Food Facts is unavailable right now.', 503, true)
  }

  return null
}

function withTimeout(fetcher: HTTPFetcher, timeoutMs: number): HTTPFetcher {
  return (input, init) => {
    const timeoutSignal = AbortSignal.timeout(timeoutMs)
    const signal = init?.signal == null ? timeoutSignal : AbortSignal.any([init.signal, timeoutSignal])
    return fetcher(input, { ...init, signal })
  }
}
