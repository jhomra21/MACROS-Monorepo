import {
  OpenFoodFactsClientError,
  normalizeOpenFoodFactsError,
  searchOpenFoodFactsLegacyFoods,
  searchOpenFoodFactsLegacyRestaurantFoods,
  searchOpenFoodFactsSearchALiciousFoods,
} from './openFoodFacts'
import type { OpenFoodFactsQuery, OpenFoodFactsRequestOptions } from './openFoodFacts'
import type {
  HTTPFetcher,
  PackagedFoodSearchQuery,
  PackagedFoodSearchResponse,
  ProviderPage,
  SearchProvider,
  OpenFoodFactsProxyProduct,
} from './types'
import { isRestaurantLikeQuery } from './restaurantSearch'
import { searchUSDAFoods } from './usda'
import { REQUEST_TIMEOUT_MS, withTimeout } from './http'

const OPEN_FOOD_FACTS_PROVIDER = 'openFoodFacts' as const

const USDA_PROVIDER = 'usda' as const

const RESTAURANT_LEGACY_REQUEST_TIMEOUT_MS = 4_000

const RESTAURANT_LEGACY_MAX_ATTEMPTS = 3

const RESTAURANT_LEGACY_MAX_PAGE_SCAN = 3

const RESTAURANT_DEADLINE_BUFFER_MS = 1_500

export interface PackagedFoodSearchExecution extends PackagedFoodSearchResponse {
  openFoodFactsAttemptCount?: number
}

export interface PackagedFoodSearchDependencies {
  usdaApiKey: string
  openFoodFactsUserAgent: string
  fetcher?: HTTPFetcher
  requestDeadline?: { signal: AbortSignal; expiresAt: number }
  allowUSDA?: () => Promise<boolean>
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
  dependencies: PackagedFoodSearchDependencies,
): Promise<PackagedFoodSearchExecution> {
  const fetcher = dependencies.fetcher ?? fetch

  if (input.provider === USDA_PROVIDER) {
    return searchUSDAPackagedFoods(input, dependencies.usdaApiKey, fetcher, dependencies)
  }

  const result = isRestaurantLikeQuery(input.query)
    ? await searchRestaurantOpenFoodFactsPackagedFoods(input, dependencies.openFoodFactsUserAgent, fetcher, dependencies)
    : await searchOpenFoodFactsPackagedFoods(input, dependencies.openFoodFactsUserAgent, fetcher, dependencies)

  return result
}

async function searchOpenFoodFactsWithOutcome(
  input: PackagedFoodSearchQuery,
  userAgent: string,
  fetcher: HTTPFetcher,
  searcher: OpenFoodFactsSearcher,
  maxAttempts = 1,
  timeoutMs = REQUEST_TIMEOUT_MS,
  deadlineSignal?: AbortSignal,
): Promise<OpenFoodFactsSearchOutcome> {
  const openFoodFactsFetcher = withTimeout(fetcher, timeoutMs, deadlineSignal)
  let lastError: OpenFoodFactsClientError | null = null
  let attempts = 0

  for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
    attempts = attempt

    try {
      const result = await searcher(
        input,
        { userAgent },
        openFoodFactsFetcher,
      )

      return {
        kind: 'response',
        attempts: attempt,
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

      lastError = normalizedError

      if (normalizedError.retryable === false || normalizedError.retryAfterMs != null) {
        break
      }
    }
  }

  return {
    kind: 'unavailable',
    attempts,
    error: lastError ?? new OpenFoodFactsClientError('Open Food Facts is unavailable right now.', 503, true),
  }
}

async function searchOpenFoodFactsPackagedFoods(
  input: PackagedFoodSearchQuery,
  userAgent: string,
  fetcher: HTTPFetcher,
  dependencies: PackagedFoodSearchDependencies,
): Promise<PackagedFoodSearchExecution> {
  const searchALiciousOutcome = await searchOpenFoodFactsWithOutcome(
    input,
    userAgent,
    fetcher,
    searchOpenFoodFactsSearchALiciousFoods,
    1,
    REQUEST_TIMEOUT_MS,
    dependencies.requestDeadline?.signal,
  )

  if (searchALiciousOutcome.kind === 'response' && hasUsableOpenFoodFactsResult(searchALiciousOutcome.page)) {
    return makeResponse(input, OPEN_FOOD_FACTS_PROVIDER, searchALiciousOutcome.page, searchALiciousOutcome.attempts)
  }

  const legacyOutcome = await searchOpenFoodFactsWithOutcome(
    input,
    userAgent,
    fetcher,
    searchOpenFoodFactsLegacyFoods,
    1,
    REQUEST_TIMEOUT_MS,
    dependencies.requestDeadline?.signal,
  )

  const totalAttempts = searchALiciousOutcome.attempts + legacyOutcome.attempts

  if (legacyOutcome.kind === 'unavailable') {
    if (searchALiciousOutcome.kind === 'response') {
      return makeResponse(input, OPEN_FOOD_FACTS_PROVIDER, searchALiciousOutcome.page, totalAttempts)
    }

    if (dependencies.requestDeadline?.signal.aborted) {
      return emptyUnavailableResponse(input)
    }

    throw legacyOutcome.error
  }

  return makeResponse(input, OPEN_FOOD_FACTS_PROVIDER, legacyOutcome.page, totalAttempts)
}

async function searchRestaurantOpenFoodFactsPackagedFoods(
  input: PackagedFoodSearchQuery,
  userAgent: string,
  fetcher: HTTPFetcher,
  dependencies: PackagedFoodSearchDependencies,
): Promise<PackagedFoodSearchExecution> {
  const legacyOutcome = await searchRestaurantLegacyOpenFoodFactsWithOutcome(
    input,
    userAgent,
    fetcher,
    dependencies.requestDeadline,
  )

  if (legacyOutcome.kind === 'response' && legacyOutcome.page.results.length > 0) {
    return makeResponse(input, OPEN_FOOD_FACTS_PROVIDER, legacyOutcome.page, legacyOutcome.attempts)
  }

  const searchALiciousOutcome = await searchOpenFoodFactsWithOutcome(
    input,
    userAgent,
    fetcher,
    searchOpenFoodFactsSearchALiciousFoods,
    1,
    REQUEST_TIMEOUT_MS,
    dependencies.requestDeadline?.signal,
  )

  const totalAttempts = legacyOutcome.attempts + searchALiciousOutcome.attempts

  if (searchALiciousOutcome.kind === 'response' && searchALiciousOutcome.page.results.length > 0) {
    return makeResponse(input, OPEN_FOOD_FACTS_PROVIDER, searchALiciousOutcome.page, totalAttempts)
  }

  if (legacyOutcome.kind === 'response') {
    return makeResponse(input, OPEN_FOOD_FACTS_PROVIDER, emptyTerminalRestaurantPage(legacyOutcome.page), totalAttempts)
  }

  if (searchALiciousOutcome.kind === 'response') {
    return makeResponse(input, OPEN_FOOD_FACTS_PROVIDER, emptyTerminalRestaurantPage(searchALiciousOutcome.page), totalAttempts)
  }

  if (dependencies.requestDeadline?.signal.aborted) {
    return emptyUnavailableResponse(input)
  }

  throw legacyOutcome.error
}

async function searchRestaurantLegacyOpenFoodFactsWithOutcome(
  input: PackagedFoodSearchQuery,
  userAgent: string,
  fetcher: HTTPFetcher,
  requestDeadline?: PackagedFoodSearchDependencies['requestDeadline'],
): Promise<OpenFoodFactsSearchOutcome> {
  const openFoodFactsFetcher = withTimeout(fetcher, RESTAURANT_LEGACY_REQUEST_TIMEOUT_MS, requestDeadline?.signal)
  let attempts = 0
  let lastError: OpenFoodFactsClientError | null = null
  let lastPage: ProviderPage<PackagedFoodSearchResponse['results'][number]> | null = null

  for (let pageOffset = 0; pageOffset < RESTAURANT_LEGACY_MAX_PAGE_SCAN; pageOffset += 1) {
    if (requestDeadline != null && requestDeadline.expiresAt - Date.now() <= RESTAURANT_DEADLINE_BUFFER_MS) {
      break
    }

    const pageInput = { ...input, page: input.page + pageOffset }

    for (let attempt = 1; attempt <= RESTAURANT_LEGACY_MAX_ATTEMPTS && attempts < RESTAURANT_LEGACY_MAX_ATTEMPTS; attempt += 1) {
      if (requestDeadline != null && requestDeadline.expiresAt - Date.now() <= RESTAURANT_DEADLINE_BUFFER_MS) {
        break
      }

      attempts += 1

      try {
        const result = await searchOpenFoodFactsLegacyRestaurantFoods(pageInput, { userAgent }, openFoodFactsFetcher)

        const page = {
          ...result,
          results: result.results.map((item) => ({ provider: OPEN_FOOD_FACTS_PROVIDER, item })),
        }

        if (page.results.length > 0) {
          return { kind: 'response', attempts, page }
        }

        lastPage = page

        if (page.hasMore === false) {
          return { kind: 'response', attempts, page }
        }

        break
      } catch (error) {
        const normalizedError = normalizeOpenFoodFactsError(error)

        if (normalizedError == null) {
          throw error
        }

        lastError = normalizedError

        if (normalizedError.retryable === false || normalizedError.retryAfterMs != null) {
          return { kind: 'unavailable', attempts, error: normalizedError }
        }
      }
    }
  }

  if (lastPage != null) {
    return { kind: 'response', attempts, page: emptyTerminalRestaurantPage(lastPage) }
  }

  return {
    kind: 'unavailable',
    attempts,
    error: lastError ?? new OpenFoodFactsClientError('Open Food Facts is unavailable right now.', 503, true),
  }
}

function emptyTerminalRestaurantPage<Result>(
  page: ProviderPage<Result>,
): ProviderPage<Result> {
  return { ...page, hasMore: false }
}

async function searchUSDAPackagedFoods(
  input: PackagedFoodSearchQuery,
  apiKey: string,
  fetcher: HTTPFetcher,
  dependencies: PackagedFoodSearchDependencies,
): Promise<PackagedFoodSearchExecution> {
  let budgetExhausted = false

  const allowUSDA = async () => {
    const allowed = dependencies.allowUSDA == null || await dependencies.allowUSDA()
    budgetExhausted ||= !allowed

    return allowed
  }

  try {
    const result = await searchUSDAFoods(
      input,
      apiKey,
      withTimeout(fetcher, REQUEST_TIMEOUT_MS, dependencies.requestDeadline?.signal),
      allowUSDA,
    )

    return makeResponse(input, USDA_PROVIDER, {
      ...result,
      results: result.results.map((item) => ({ provider: USDA_PROVIDER, item })),
    })
  } catch (error) {
    if (budgetExhausted) {
      return emptyUnavailableResponse(input, USDA_PROVIDER)
    }

    throw error
  }
}

function emptyUnavailableResponse(
  input: PackagedFoodSearchQuery,
  provider: SearchProvider = OPEN_FOOD_FACTS_PROVIDER,
): PackagedFoodSearchExecution {
  return {
    query: input.query,
    page: input.page,
    pageSize: input.pageSize,
    resolvedProvider: provider,
    results: [],
    hasMore: false,
    openFoodFactsAttemptCount: 0,
  }
}

export function hasUsableOpenFoodFactsResult(
  page: Pick<ProviderPage<PackagedFoodSearchResponse['results'][number]>, 'results' | 'hasMore'>,
): boolean {
  return page.results.length > 0 || page.hasMore
}

function makeResponse(
  input: PackagedFoodSearchQuery,
  provider: SearchProvider,
  page: ProviderPage<PackagedFoodSearchResponse['results'][number]>,
  openFoodFactsAttemptCount?: number,
): PackagedFoodSearchExecution {
  return {
    query: input.query,
    page: page.page,
    pageSize: page.pageSize,
    resolvedProvider: provider,
    results: page.results,
    hasMore: page.hasMore,
    openFoodFactsAttemptCount,
  }
}
