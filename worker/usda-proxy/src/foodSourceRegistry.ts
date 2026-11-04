import type { Context } from 'hono'
import type { FoodSearchDependencies, SourcePage } from './foodSearchTypes'
import { createOpenFoodFactsSource } from './foodSources/openFoodFacts'
import { createUSDASource } from './foodSources/usda'
import { awaitWithAbort } from './http'
import type { HTTPFetcher } from './types'

export async function foodSearchDependencies(
  c: Context<{ Bindings: Env }>,
): Promise<FoodSearchDependencies> {
  const milliseconds = Number.parseInt(c.env.REQUEST_DEADLINE_MS, 10) || 8000
  const signal = AbortSignal.any([AbortSignal.timeout(milliseconds), c.req.raw.signal])
  const deadline = { signal, expiresAt: Date.now() + milliseconds }
  const cache = await caches.open('food-search-v2')
  const budget = c.env.USDA_BUDGET
  const upstreamCalls: Record<string, number> = {}

  const sourceFetcher =
    (source: string): HTTPFetcher =>
    async (input, init) => {
      upstreamCalls[source] = (upstreamCalls[source] ?? 0) + 1
      c.header('X-MACROS-Upstream-Calls', JSON.stringify(upstreamCalls))

      return fetch(input, init)
    }

  const coordinate = async (operation: () => Promise<{ allowed: boolean }>) => {
    try {
      return (
        await awaitWithAbort(operation(), AbortSignal.any([signal, AbortSignal.timeout(500)]))
      ).allowed
    } catch {
      return false
    }
  }

  return {
    deadline,
    // This is the only registry: add/remove adapters here, never in the app.
    sources: [
      createOpenFoodFactsSource({
        userAgent: c.env.OPEN_FOOD_FACTS_USER_AGENT,
        fetcher: sourceFetcher('openFoodFacts'),
        allowRequest: () =>
          coordinate(() => budget.get(budget.idFromName('food-search-off-v2')).acquireFoodSearch()),
        cooldown: async (ms) => {
          await awaitWithAbort(
            budget.get(budget.idFromName('food-search-off-v2')).cooldownFoodSearch(ms),
            signal,
          )
        },
      }),
      createUSDASource({
        apiKey: c.env.USDA_API_KEY,
        fetcher: sourceFetcher('usda'),
        allowRequest: () => coordinate(() => budget.get(budget.idFromName('usda')).acquire()),
      }),
    ],
    cache: {
      async read(key) {
        const request = sourceCacheRequest(c.req.url, key)

        try {
          const response = await cache.match(request)

          return response == null ? undefined : await response.json<SourcePage>()
        } catch {
          return undefined
        }
      },
      async write(key, page, ttlSeconds) {
        c.executionCtx.waitUntil(
          cache
            .put(
              sourceCacheRequest(c.req.url, key),
              new Response(JSON.stringify(page), {
                headers: {
                  'Content-Type': 'application/json',
                  'Cache-Control': `public, max-age=${ttlSeconds}`,
                },
              }),
            )
            .catch(() => console.warn('Food source cache write unavailable')),
        )
      },
    },
  }
}

function sourceCacheRequest(requestURL: string, key: string): Request {
  const url = new URL('/v2/foods/source-page', requestURL)
  url.searchParams.set('key', key)

  return new Request(url)
}
