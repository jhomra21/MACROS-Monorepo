import {
  fetchOpenFoodFactsProduct,
  searchOpenFoodFactsLegacyRestaurantFoods,
  searchOpenFoodFactsSearchALiciousFoods,
} from '../openFoodFacts'
import { normalizeOpenFoodFactsFood } from '../normalizedFood'
import { isNamedRestaurantQuery } from '../restaurantSearch'
import type { FoodSource } from '../foodSearchTypes'
import type { HTTPFetcher } from '../types'
import { withTimeout } from '../http'
import { parseSourcePage } from '../foodSearchCursor'

export function createOpenFoodFactsSource(options: {
  userAgent: string
  allowRequest: () => Promise<boolean>
  cooldown?: (milliseconds: number) => Promise<void>
  fetcher?: HTTPFetcher
}): FoodSource {
  return {
    id: 'openFoodFacts',
    async search(query, cursor, deadline) {
      if (!(await options.allowRequest())) throw new Error('OFF budget exhausted')

      const fetcher = withTimeout(
        async (input, init) => {
          const response = await (options.fetcher ?? fetch)(input, init)
          const retryAfter = response.headers.get('Retry-After')

          if (!response.ok && retryAfter != null) {
            const seconds = Number(retryAfter)

            const ms = Number.isFinite(seconds)
              ? seconds * 1000
              : Date.parse(retryAfter) - Date.now()

            if (Number.isFinite(ms) && ms > 0) await options.cooldown?.(ms)
          }

          return response
        },
        Math.max(1, deadline.expiresAt - Date.now()),
        deadline.signal,
      )

      const requestOptions = { userAgent: options.userAgent, singleRequest: true }

      if (/^(?:\d{8}|\d{12}|\d{13}|\d{14})$/.test(query)) {
        const item = normalizeOpenFoodFactsFood(
          await fetchOpenFoodFactsProduct(query, requestOptions, fetcher),
        )

        return { items: item == null ? [] : [item], nextCursor: null }
      }

      const page = parseSourcePage(cursor)

      const searcher = isNamedRestaurantQuery(query)
        ? searchOpenFoodFactsLegacyRestaurantFoods
        : searchOpenFoodFactsSearchALiciousFoods

      const result = await searcher({ query, page, pageSize: 12 }, requestOptions, fetcher)

      return {
        items: result.results.flatMap((product) => {
          const food = normalizeOpenFoodFactsFood(product)

          return food == null ? [] : [food]
        }),
        nextCursor: result.hasMore && page < 10 ? String(page + 1) : null,
      }
    },
  }
}
