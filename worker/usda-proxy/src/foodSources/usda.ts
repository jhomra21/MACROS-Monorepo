import type { FoodSource } from '../foodSearchTypes'
import type { HTTPFetcher } from '../types'
import { normalizeUSDAFood } from '../normalizedFood'
import { fetchUSDASearchRecords, usdaSourceFood } from '../usda'
import { matchesSearchTokens, searchTokens } from '../searchText'
import { withTimeout } from '../http'
import { parseSourcePage } from '../foodSearchCursor'

export function createUSDASource(options: {
  apiKey: string
  allowRequest: () => Promise<boolean>
  fetcher?: HTTPFetcher
}): FoodSource {
  return {
    id: 'usda',
    async search(query, cursor, deadline) {
      const page = parseSourcePage(cursor)

      if (!(await options.allowRequest())) throw new Error('USDA budget exhausted')

      const response = await fetchUSDASearchRecords(
        { query, page, pageSize: 12 },
        options.apiKey,
        withTimeout(
          options.fetcher ?? fetch,
          Math.max(1, deadline.expiresAt - Date.now()),
          deadline.signal,
        ),
      )

      const tokens = searchTokens(query, { removeApostrophes: true })

      return {
        items: response.foods.flatMap((raw) => {
          const food = usdaSourceFood(raw)

          return food != null && matchesSearchTokens([food.name, food.brand], tokens, { removeApostrophes: true })
            ? [normalizeUSDAFood(food)] : []
        }),
        nextCursor: response.hasMore ? String(page + 1) : null,
      }
    },
  }
}
