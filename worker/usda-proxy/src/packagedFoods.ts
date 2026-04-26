import { OpenFoodFactsClientError, OpenFoodFactsRequestBudget, searchOpenFoodFactsFoods } from './openFoodFacts'
import type {
  HTTPFetcher,
  PackagedFoodSearchDegradedFallbackReason,
  PackagedFoodSearchQuery,
  PackagedFoodSearchResponse,
  ProviderPage,
  SearchProvider,
} from './types'
import { searchUSDAFoods } from './usda'

const OPEN_FOOD_FACTS_PROVIDER = 'openFoodFacts' as const
const USDA_PROVIDER = 'usda' as const
const REQUEST_TIMEOUT_MS = 2_500
const MAX_OPEN_FOOD_FACTS_HTTP_REQUESTS = 11
const BASE_RETRY_DELAY_MS = 750
const MAX_BACKOFF_DELAY_MS = 4_000
const MAX_TOTAL_RETRY_WAIT_MS = 40_000

type RetryWait = (delayMs: number) => Promise<void>

export interface PackagedFoodSearchExecution extends PackagedFoodSearchResponse {
  degradedFallbackReason?: PackagedFoodSearchDegradedFallbackReason
  openFoodFactsAttemptCount?: number
}

interface OpenFoodFactsSearchOutcome {
  kind: 'response' | 'unavailable'
  attempts: number
  page?: ProviderPage<PackagedFoodSearchResponse['results'][number]>
  error?: OpenFoodFactsClientError
}

export async function searchPackagedFoods(
  input: PackagedFoodSearchQuery,
  apiKey: string,
  openFoodFactsUserAgent: string,
  fetcher: HTTPFetcher = fetch,
  retryWait: RetryWait = defaultRetryWait,
): Promise<PackagedFoodSearchExecution> {
  if (input.provider === OPEN_FOOD_FACTS_PROVIDER) {
    return searchOpenFoodFactsPackagedFoods(input, openFoodFactsUserAgent, fetcher, retryWait)
  }

  if (input.provider === USDA_PROVIDER) {
    return searchUSDAPackagedFoods(input, apiKey, fetcher)
  }

  const outcome = await searchOpenFoodFactsWithOutcome(
    input,
    openFoodFactsUserAgent,
    fetcher,
    retryWait,
  )

  if (outcome.kind === 'response') {
    const openFoodFactsResult = outcome.page!
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
  retryWait: RetryWait,
): Promise<OpenFoodFactsSearchOutcome> {
  let lastError: OpenFoodFactsClientError | null = null
  let attemptsMade = 0
  let totalRetryWaitMs = 0
  const requestBudget = new OpenFoodFactsRequestBudget(MAX_OPEN_FOOD_FACTS_HTTP_REQUESTS)
  const openFoodFactsFetcher = withTimeout(fetcher, REQUEST_TIMEOUT_MS)

  for (let attempt = 0; attempt < MAX_OPEN_FOOD_FACTS_HTTP_REQUESTS; attempt += 1) {
    attemptsMade = attempt + 1

    try {
      const result = await searchOpenFoodFactsFoods(
        input,
        { userAgent, requestBudget },
        openFoodFactsFetcher,
      )
      return {
        kind: 'response',
        attempts: attemptsMade,
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
      if (shouldRetryOpenFoodFacts(lastError) === false || attempt + 1 >= MAX_OPEN_FOOD_FACTS_HTTP_REQUESTS) {
        break
      }

      const retryDelayMs = nextRetryDelayMs(lastError, attempt, totalRetryWaitMs)
      if (retryDelayMs == null) {
        break
      }

      await retryWait(retryDelayMs)
      totalRetryWaitMs += retryDelayMs
    }
  }

  return {
    kind: 'unavailable',
    attempts: attemptsMade,
    error: lastError ?? new OpenFoodFactsClientError('Open Food Facts is unavailable right now.', 503, true),
  }
}

async function searchOpenFoodFactsPackagedFoods(
  input: PackagedFoodSearchQuery,
  userAgent: string,
  fetcher: HTTPFetcher,
  retryWait: RetryWait,
): Promise<PackagedFoodSearchExecution> {
  const outcome = await searchOpenFoodFactsWithOutcome(input, userAgent, fetcher, retryWait)
  if (outcome.kind === 'unavailable') {
    throw outcome.error
  }

  return makeResponse(input, OPEN_FOOD_FACTS_PROVIDER, outcome.page!, undefined, outcome.attempts)
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

function shouldRetryOpenFoodFacts(error: unknown): boolean {
  if (error instanceof OpenFoodFactsClientError) {
    return error.retryable
  }

  return error instanceof DOMException || error instanceof TypeError
}

export function nextRetryDelayMs(
  error: OpenFoodFactsClientError,
  attempt: number,
  totalRetryWaitMs: number,
  randomValue: number = Math.random(),
): number | null {
  const retryAfterMs = normalizedRetryAfterMs(error.retryAfterMs)
  const backoffDelayMs = exponentialBackoffDelayMs(attempt, randomValue)
  const delayMs = Math.max(backoffDelayMs, retryAfterMs ?? 0)

  return totalRetryWaitMs + delayMs > MAX_TOTAL_RETRY_WAIT_MS ? null : delayMs
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

function exponentialBackoffDelayMs(attempt: number, randomValue: number): number {
  const jitterMs = Math.round(clampDelay(randomValue, 0, 1) * 250)
  const delayMs = BASE_RETRY_DELAY_MS * (2 ** attempt) + jitterMs
  return clampDelay(delayMs, 0, MAX_BACKOFF_DELAY_MS)
}

function normalizedRetryAfterMs(value: number | undefined): number | undefined {
  if (value == null || Number.isFinite(value) === false) {
    return undefined
  }

  return Math.max(0, Math.round(value))
}

function clampDelay(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value))
}

function withTimeout(fetcher: HTTPFetcher, timeoutMs: number): HTTPFetcher {
  return (input, init) => {
    const timeoutSignal = AbortSignal.timeout(timeoutMs)
    const signal = init?.signal == null ? timeoutSignal : AbortSignal.any([init.signal, timeoutSignal])
    return fetcher(input, { ...init, signal })
  }
}

async function defaultRetryWait(delayMs: number): Promise<void> {
  await scheduler.wait(delayMs)
}
