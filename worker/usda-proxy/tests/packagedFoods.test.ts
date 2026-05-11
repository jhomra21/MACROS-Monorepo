import { describe, expect, it } from 'bun:test'

import { fetchOpenFoodFactsProduct } from '../src/openFoodFacts'
import { cacheReadOrder, cacheWritePlan } from '../src/packagedFoodSearchCache'
import { searchPackagedFoods } from '../src/packagedFoods'
import { isRestaurantLikeQuery } from '../src/restaurantSearch'
import type { PackagedFoodSearchDependencies, PackagedFoodSearchExecution } from '../src/packagedFoods'
import type { PackagedFoodSearchQuery, PackagedFoodSearchResponse } from '../src/types'
import { fetchUSDAFood, searchUSDAFoods } from '../src/usda'

const DEFAULT_QUERY: PackagedFoodSearchQuery = {
  query: 'protein bar',
  page: 1,
  pageSize: 10,
  fallbackOnEmpty: true,
}

const BASE_URL = 'https://example.com/v1/packaged-foods/search'

function searchDependencies(fetcher: PackagedFoodSearchDependencies['fetcher']): PackagedFoodSearchDependencies {
  return {
    usdaApiKey: 'test-usda-key',
    openFoodFactsUserAgent: 'cal-macro-tracker/1.0 (test@example.com)',
    fetcher,
  }
}

describe('searchPackagedFoods', () => {
  it('uses Search-a-licious before falling back to USDA for default search', async () => {
    let searchALiciousCallCount = 0
    let usdaCallCount = 0

    const response = await searchPackagedFoods(
      DEFAULT_QUERY,
      searchDependencies(async (input) => {
        const url = requestURL(input)

        if (isSearchALiciousRequest(url)) {
          searchALiciousCallCount += 1
          return Response.json(searchALiciousPayload())
        }

        usdaCallCount += 1
        return Response.json(usdaPayload())
      }),
    )

    expect(response.resolvedProvider).toBe('openFoodFacts')
    expect(response.openFoodFactsAttemptCount).toBe(1)
    expect(searchALiciousCallCount).toBe(1)
    expect(usdaCallCount).toBe(0)
    expect(response.results).toHaveLength(1)
  })

  it('uses legacy Open Food Facts when Search-a-licious is unavailable for default search', async () => {
    let searchALiciousCallCount = 0
    let legacyOpenFoodFactsCallCount = 0

    const response = await searchPackagedFoods(
      DEFAULT_QUERY,
      searchDependencies(async (input) => {
        const url = requestURL(input)

        if (isSearchALiciousRequest(url)) {
          searchALiciousCallCount += 1
          return new Response(null, { status: 503 })
        }

        legacyOpenFoodFactsCallCount += 1
        return Response.json({ count: 0, products: [] })
      }),
    )

    expect(response.resolvedProvider).toBe('openFoodFacts')
    expect(response.results).toHaveLength(0)
    expect(response.openFoodFactsAttemptCount).toBe(2)
    expect(searchALiciousCallCount).toBe(1)
    expect(legacyOpenFoodFactsCallCount).toBe(1)
  })

  it('treats timed out empty Search-a-licious responses as unavailable', async () => {
    await expect(
      searchPackagedFoods(
        DEFAULT_QUERY,
        searchDependencies(async (input) => {
          const url = requestURL(input)
          return isSearchALiciousRequest(url)
            ? Response.json(searchALiciousTimedOutEmptyPayload())
            : new Response(null, { status: 503 })
        }),
      ),
    ).rejects.toThrow('Open Food Facts is unavailable right now.')
  })

  it('uses legacy Open Food Facts when Search-a-licious returns zero hits for default search', async () => {
    let searchALiciousCallCount = 0
    let legacyOpenFoodFactsCallCount = 0

    const response = await searchPackagedFoods(
      DEFAULT_QUERY,
      searchDependencies(async (input) => {
        const url = requestURL(input)

        if (isSearchALiciousRequest(url)) {
          searchALiciousCallCount += 1
          return Response.json(searchALiciousEmptyPayload())
        }

        legacyOpenFoodFactsCallCount += 1
        return Response.json({ count: 0, products: [] })
      }),
    )

    expect(response.resolvedProvider).toBe('openFoodFacts')
    expect(response.results).toHaveLength(0)
    expect(response.openFoodFactsAttemptCount).toBe(2)
    expect(searchALiciousCallCount).toBe(1)
    expect(legacyOpenFoodFactsCallCount).toBe(1)
  })

  it('uses legacy Open Food Facts when pinned Search-a-licious is unavailable', async () => {
    let searchALiciousCallCount = 0
    let legacyOpenFoodFactsCallCount = 0
    let usdaCallCount = 0

    const response = await searchPackagedFoods(
      { ...DEFAULT_QUERY, provider: 'openFoodFacts', fallbackOnEmpty: false },
      searchDependencies(async (input) => {
        const url = requestURL(input)

        if (isSearchALiciousRequest(url)) {
          searchALiciousCallCount += 1
          return new Response(null, { status: 503 })
        }

        if (isLegacyOpenFoodFactsRequest(url)) {
          legacyOpenFoodFactsCallCount += 1
          return Response.json(openFoodFactsPayload())
        }

        usdaCallCount += 1
        return Response.json(usdaPayload())
      }),
    )

    expect(response.resolvedProvider).toBe('openFoodFacts')
    expect(response.openFoodFactsAttemptCount).toBe(2)
    expect(searchALiciousCallCount).toBe(1)
    expect(legacyOpenFoodFactsCallCount).toBe(1)
    expect(usdaCallCount).toBe(0)
  })

  it('returns an empty Open Food Facts response when both pinned backends have zero hits', async () => {
    let searchALiciousCallCount = 0
    let legacyOpenFoodFactsCallCount = 0
    let usdaCallCount = 0

    const response = await searchPackagedFoods(
      { ...DEFAULT_QUERY, provider: 'openFoodFacts', fallbackOnEmpty: false },
      searchDependencies(async (input) => {
        const url = requestURL(input)

        if (isSearchALiciousRequest(url)) {
          searchALiciousCallCount += 1
          return Response.json(searchALiciousEmptyPayload())
        }

        if (isLegacyOpenFoodFactsRequest(url)) {
          legacyOpenFoodFactsCallCount += 1
          return Response.json({ count: 0, products: [] })
        }

        usdaCallCount += 1
        return Response.json(usdaPayload())
      }),
    )

    expect(response.resolvedProvider).toBe('openFoodFacts')
    expect(response.results).toHaveLength(0)
    expect(response.openFoodFactsAttemptCount).toBe(2)
    expect(searchALiciousCallCount).toBe(1)
    expect(legacyOpenFoodFactsCallCount).toBe(1)
    expect(usdaCallCount).toBe(0)
  })

  it('stays on Open Food Facts when products are missing main nutrition', async () => {
    let searchALiciousCallCount = 0
    let legacyOpenFoodFactsCallCount = 0

    const response = await searchPackagedFoods(
      DEFAULT_QUERY,
      searchDependencies(async (input) => {
        const url = requestURL(input)

        if (isSearchALiciousRequest(url)) {
          searchALiciousCallCount += 1
          return Response.json(searchALiciousIncompleteNutritionPayload())
        }

        legacyOpenFoodFactsCallCount += 1
        return Response.json({ count: 0, products: [] })
      }),
    )

    expect(response.resolvedProvider).toBe('openFoodFacts')
    expect(response.results).toHaveLength(0)
    expect(searchALiciousCallCount).toBe(1)
    expect(legacyOpenFoodFactsCallCount).toBe(1)
  })

  it('returns exact Open Food Facts matches that need manual nutrition entry', async () => {
    let legacyOpenFoodFactsCallCount = 0

    const response = await searchPackagedFoods(
      { ...DEFAULT_QUERY, query: 'missing nutrition' },
      searchDependencies(async (input) => {
        const url = requestURL(input)
        if (isSearchALiciousRequest(url)) {
          return Response.json(searchALiciousIncompleteNutritionPayload())
        }

        legacyOpenFoodFactsCallCount += 1
        return Response.json({ count: 0, products: [] })
      }),
    )

    expect(response.resolvedProvider).toBe('openFoodFacts')
    expect(response.results).toHaveLength(1)
    expect(response.results[0]).toMatchObject({
      provider: 'openFoodFacts',
      item: {
        product_name: 'Missing Nutrition',
      },
    })
    expect(legacyOpenFoodFactsCallCount).toBe(0)
  })

  it('keeps matching Open Food Facts results that need nutrition review beside complete matches', async () => {
    const response = await searchPackagedFoods(
      { ...DEFAULT_QUERY, query: 'protein bar' },
      searchDependencies(async (input) => Response.json(isSearchALiciousRequest(requestURL(input))
        ? searchALiciousMixedNutritionPayload()
        : { count: 0, products: [] })),
    )

    expect(response.results).toHaveLength(2)
    expect(response.results.map((result) => result.provider)).toEqual(['openFoodFacts', 'openFoodFacts'])
    const openFoodFactsNames = response.results.flatMap((result) => result.provider === 'openFoodFacts'
      ? [result.item.product_name]
      : [])
    expect(openFoodFactsNames).toEqual([
      'Protein Bar',
      'Protein Bar Missing Nutrition',
    ])
  })

  it('deduplicates repeated Open Food Facts search results', async () => {
    const response = await searchPackagedFoods(
      DEFAULT_QUERY,
      searchDependencies(async (input) => {
        const url = requestURL(input)
        return Response.json(isSearchALiciousRequest(url)
          ? searchALiciousDuplicatePayload()
          : usdaPayload())
      }),
    )

    expect(response.resolvedProvider).toBe('openFoodFacts')
    expect(response.results).toHaveLength(1)
    expect(response.results[0]).toMatchObject({
      provider: 'openFoodFacts',
      item: {
        product_name: 'Protein Bar',
      },
    })
  })

  it('does not force USDA fallback for default Open Food Facts searches', async () => {
    let legacyOpenFoodFactsCallCount = 0

    const response = await searchPackagedFoods(
      { ...DEFAULT_QUERY, query: 'chick fil a sandwich' },
      searchDependencies(async (input) => {
        const url = requestURL(input)
        return Response.json(isSearchALiciousRequest(url)
          ? searchALiciousChickFilASaucePayload()
          : (legacyOpenFoodFactsCallCount += 1, { count: 0, products: [] }))
      }),
    )

    expect(response.resolvedProvider).toBe('openFoodFacts')
    expect(response.results).toHaveLength(0)
    expect(legacyOpenFoodFactsCallCount).toBe(1)
  })

  it('preserves filtered-empty Open Food Facts pages when more pages are available', async () => {
    let legacyOpenFoodFactsCallCount = 0

    const response = await searchPackagedFoods(
      DEFAULT_QUERY,
      searchDependencies(async (input) => {
        const url = requestURL(input)
        if (isSearchALiciousRequest(url)) {
          return Response.json(searchALiciousFilteredEmptyHasMorePayload())
        }

        legacyOpenFoodFactsCallCount += 1
        return Response.json({ count: 0, products: [] })
      }),
    )

    expect(response.resolvedProvider).toBe('openFoodFacts')
    expect(response.results).toHaveLength(0)
    expect(response.hasMore).toBe(true)
    expect(legacyOpenFoodFactsCallCount).toBe(0)
  })

  it('fetches only the requested legacy Open Food Facts page after Search-a-licious misses', async () => {
    let searchALiciousCallCount = 0
    let legacyOpenFoodFactsCallCount = 0

    const response = await searchPackagedFoods(
      { ...DEFAULT_QUERY, provider: 'openFoodFacts', fallbackOnEmpty: false },
      searchDependencies(async (input) => {
        const url = requestURL(input)
        if (isSearchALiciousRequest(url)) {
          searchALiciousCallCount += 1
          return Response.json(searchALiciousEmptyPayload())
        }

        const page = Number(new URL(url).searchParams.get('page') ?? '1')
        legacyOpenFoodFactsCallCount += 1
        return Response.json(page <= 9 ? sparseUsableOpenFoodFactsPayload(page) : unusableOpenFoodFactsPayload())
      }),
    )

    expect(response.resolvedProvider).toBe('openFoodFacts')
    expect(response.results).toHaveLength(1)
    expect(response.hasMore).toBe(true)
    expect(searchALiciousCallCount).toBe(1)
    expect(legacyOpenFoodFactsCallCount).toBe(1)
  })

  it('maps USDA secondary nutrients into the packaged food response contract', async () => {
    const response = await searchPackagedFoods(
      { ...DEFAULT_QUERY, provider: 'usda' },
      searchDependencies(async () => Response.json(usdaPayload())),
    )

    expect(response.resolvedProvider).toBe('usda')
    expect(response.results).toHaveLength(1)

    const result = response.results[0]
    expect(result.provider).toBe('usda')
    expect(result.item).toMatchObject({
      saturatedFatPerServing: 2,
      fiberPerServing: 6,
      sugarsPerServing: 5,
      addedSugarsPerServing: 4,
      sodiumPerServing: 320,
      cholesterolPerServing: 15,
    })
  })

  it('routes restaurant-like default searches to legacy Open Food Facts first', async () => {
    let searchALiciousCallCount = 0
    let legacyOpenFoodFactsCallCount = 0

    const response = await searchPackagedFoods(
      { ...DEFAULT_QUERY, query: 'chicken nuggets' },
      searchDependencies(async (input) => {
        const url = requestURL(input)
        if (isSearchALiciousRequest(url)) {
          searchALiciousCallCount += 1
          return Response.json(searchALiciousEmptyPayload())
        }

        legacyOpenFoodFactsCallCount += 1
        return Response.json(legacyRestaurantPayload())
      }),
    )

    expect(response.resolvedProvider).toBe('openFoodFacts')
    expect(response.results).toHaveLength(1)
    expect(response.openFoodFactsAttemptCount).toBe(1)
    expect(response.results[0]).toMatchObject({
      provider: 'openFoodFacts',
      item: {
        product_name: "Wendy's, 4 Piece Chicken Nuggets",
        brands: "Wendy's",
      },
    })
    expect(legacyOpenFoodFactsCallCount).toBe(1)
    expect(searchALiciousCallCount).toBe(0)
  })

  it('retries flaky legacy Open Food Facts restaurant searches before Search-a-licious', async () => {
    let searchALiciousCallCount = 0
    let legacyOpenFoodFactsCallCount = 0

    const response = await searchPackagedFoods(
      { ...DEFAULT_QUERY, query: 'chicken nuggets' },
      searchDependencies(async (input) => {
        const url = requestURL(input)
        if (isLegacyOpenFoodFactsRequest(url)) {
          legacyOpenFoodFactsCallCount += 1
          return legacyOpenFoodFactsCallCount === 1
            ? new Response(null, { status: 503 })
            : Response.json(legacyRestaurantPayload())
        }

        searchALiciousCallCount += 1
        return Response.json(searchALiciousEmptyPayload())
      }),
    )

    expect(response.resolvedProvider).toBe('openFoodFacts')
    expect(response.results).toHaveLength(1)
    expect(response.openFoodFactsAttemptCount).toBe(1)
    expect(legacyOpenFoodFactsCallCount).toBe(2)
    expect(searchALiciousCallCount).toBe(0)
  })

  it('keeps retrying empty restaurant legacy pages before falling back to Search-a-licious', async () => {
    let searchALiciousCallCount = 0
    const legacyPages: number[] = []

    const response = await searchPackagedFoods(
      { ...DEFAULT_QUERY, query: 'chicken nuggets' },
      searchDependencies(async (input) => {
        const url = requestURL(input)
        if (isLegacyOpenFoodFactsRequest(url)) {
          const page = Number(new URL(url).searchParams.get('page'))
          legacyPages.push(page)
          return page < 3
            ? Response.json({ count: 72, products: [] })
            : Response.json(legacyRestaurantPayload())
        }

        searchALiciousCallCount += 1
        return Response.json(searchALiciousEmptyPayload())
      }),
    )

    expect(response.resolvedProvider).toBe('openFoodFacts')
    expect(response.page).toBe(3)
    expect(response.results).toHaveLength(1)
    expect(response.openFoodFactsAttemptCount).toBe(13)
    expect(legacyPages).toEqual([1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 3])
    expect(searchALiciousCallCount).toBe(0)
  })

  it('keeps restaurant-like pinned Open Food Facts pagination on legacy first', async () => {
    let searchALiciousCallCount = 0
    let legacyOpenFoodFactsCallCount = 0

    const response = await searchPackagedFoods(
      { ...DEFAULT_QUERY, query: 'Wendy nuggets', page: 2, provider: 'openFoodFacts', fallbackOnEmpty: false },
      searchDependencies(async (input) => {
        const url = requestURL(input)
        if (isLegacyOpenFoodFactsRequest(url)) {
          legacyOpenFoodFactsCallCount += 1
          return Response.json(legacyRestaurantPayload())
        }

        searchALiciousCallCount += 1
        return Response.json(searchALiciousEmptyPayload())
      }),
    )

    expect(response.resolvedProvider).toBe('openFoodFacts')
    expect(response.page).toBe(2)
    expect(response.results).toHaveLength(1)
    expect(legacyOpenFoodFactsCallCount).toBe(1)
    expect(searchALiciousCallCount).toBe(0)
  })

  it('preserves Open Food Facts secondary nutriments in search results', async () => {
    const response = await searchPackagedFoods(
      { ...DEFAULT_QUERY, provider: 'openFoodFacts' },
      searchDependencies(async (input) => {
        const url = requestURL(input)
        return Response.json(isSearchALiciousRequest(url)
          ? searchALiciousPayload()
          : openFoodFactsPayload())
      }),
    )

    expect(response.resolvedProvider).toBe('openFoodFacts')
    expect(response.results).toHaveLength(1)

    const result = response.results[0]
    expect(result.provider).toBe('openFoodFacts')
    expect(result.item).toMatchObject({
      nutriments: {
        'saturated-fat_serving': 2,
        fiber_serving: 6,
        sugars_serving: 5,
        'added-sugars_serving': 4,
        sodium_serving: 0.32,
        cholesterol_serving: 0.015,
      },
    })
  })

  it('rethrows unexpected Open Food Facts errors instead of masking them as fallback', async () => {
    await expect(
      searchPackagedFoods(
        DEFAULT_QUERY,
        searchDependencies(async (input) => {
          const url = requestURL(input)

          if (isSearchALiciousRequest(url)) {
            throw new SyntaxError('broken payload')
          }

          return Response.json(usdaPayload())
        }),
      ),
    ).rejects.toThrow('broken payload')
  })
})

describe('isRestaurantLikeQuery', () => {
  it('detects restaurant-shaped menu queries without a chain allowlist', () => {
    expect(isRestaurantLikeQuery('local diner burger')).toBe(true)
    expect(isRestaurantLikeQuery('in n out double double')).toBe(true)
    expect(isRestaurantLikeQuery('shake shack fries')).toBe(true)
    expect(isRestaurantLikeQuery('five guys cheeseburger')).toBe(true)
    expect(isRestaurantLikeQuery('raising canes tenders')).toBe(true)
    expect(isRestaurantLikeQuery('olive garden chicken alfredo')).toBe(true)
    expect(isRestaurantLikeQuery('panda express orange chicken bowl')).toBe(true)
  })

  it('keeps generic packaged grocery queries on the normal OFF path', () => {
    expect(isRestaurantLikeQuery('protein bar')).toBe(false)
    expect(isRestaurantLikeQuery('greek yogurt')).toBe(false)
    expect(isRestaurantLikeQuery('cheerios')).toBe(false)
    expect(isRestaurantLikeQuery('kind bar')).toBe(false)
    expect(isRestaurantLikeQuery('chobani yogurt')).toBe(false)
    expect(isRestaurantLikeQuery('frozen pizza')).toBe(false)
  })
})

describe('fetchOpenFoodFactsProduct', () => {
  it('fetches and normalizes products by barcode', async () => {
    const product = await fetchOpenFoodFactsProduct(
      '123456789012',
      { userAgent: 'cal-macro-tracker/1.0 (test@example.com)' },
      async () => Response.json({ product: openFoodFactsPayload().products[0] }),
    )

    expect(product.product_name).toBe('Protein Bar')
    expect(product.externalProductID).toBe('openfoodfacts:123456789012')
  })

  it('tries barcode aliases before reporting not found', async () => {
    const requestedURLs: string[] = []

    const product = await fetchOpenFoodFactsProduct(
      '123456789012',
      { userAgent: 'cal-macro-tracker/1.0 (test@example.com)' },
      async (input) => {
        requestedURLs.push(requestURL(input))
        return requestedURLs.length === 1
          ? Response.json({})
          : Response.json({ product: openFoodFactsPayload().products[0] })
      },
    )

    expect(product.product_name).toBe('Protein Bar')
    expect(requestedURLs).toHaveLength(2)
    expect(requestedURLs[0]).toContain('/123456789012.json')
    expect(requestedURLs[1]).toContain('/0123456789012.json')
  })

  it('falls back to the staging host after a retryable production product error', async () => {
    const requestedURLs: string[] = []

    const product = await fetchOpenFoodFactsProduct(
      '123456789012',
      { userAgent: 'cal-macro-tracker/1.0 (test@example.com)' },
      async (input) => {
        requestedURLs.push(requestURL(input))
        return requestedURLs.length === 1
          ? new Response('SSL handshake failed', { status: 525 })
          : Response.json({ product: openFoodFactsPayload().products[0] })
      },
    )

    expect(product.product_name).toBe('Protein Bar')
    expect(requestedURLs).toEqual([
      'https://world.openfoodfacts.org/api/v2/product/123456789012.json',
      'https://world.openfoodfacts.net/api/v2/product/123456789012.json',
    ])
  })

  it('falls back to the staging host after a rejected production product request', async () => {
    const requestedURLs: string[] = []

    const product = await fetchOpenFoodFactsProduct(
      '123456789012',
      { userAgent: 'cal-macro-tracker/1.0 (test@example.com)' },
      async (input) => {
        requestedURLs.push(requestURL(input))
        if (requestedURLs.length === 1) {
          throw new TypeError('fetch failed')
        }

        return Response.json({ product: openFoodFactsPayload().products[0] })
      },
    )

    expect(product.product_name).toBe('Protein Bar')
    expect(requestedURLs).toEqual([
      'https://world.openfoodfacts.org/api/v2/product/123456789012.json',
      'https://world.openfoodfacts.net/api/v2/product/123456789012.json',
    ])
  })
})

describe('fetchUSDAFood', () => {
  it('sends USDA API keys in headers instead of traced URLs', async () => {
    const seenRequests: Array<{ url: string, apiKey: string | null, dataType?: string[] }> = []

    await searchUSDAFoods(DEFAULT_QUERY, 'test-usda-key', async (input, init) => {
      const body = JSON.parse(String(init?.body ?? '{}')) as { dataType?: string[] }
      seenRequests.push({
        url: requestURL(input),
        apiKey: new Headers(init?.headers).get('X-Api-Key'),
        dataType: body.dataType,
      })
      return Response.json(usdaPayload())
    })

    await fetchUSDAFood(123, 'test-usda-key', async (input, init) => {
      seenRequests.push({
        url: requestURL(input),
        apiKey: new Headers(init?.headers).get('X-Api-Key'),
      })
      return Response.json(usdaDetailsPayload())
    })

    expect(seenRequests).toEqual([
      {
        url: 'https://api.nal.usda.gov/fdc/v1/foods/search',
        apiKey: 'test-usda-key',
        dataType: ['Branded'],
      },
      {
        url: 'https://api.nal.usda.gov/fdc/v1/food/123',
        apiKey: 'test-usda-key',
      },
    ])
  })

  it('retries page-one USDA searches with punctuation-normalized restaurant names', async () => {
    const seenQueries: string[] = []

    const response = await searchUSDAFoods(
      { ...DEFAULT_QUERY, query: 'Wendy’s nuggets' },
      'test-usda-key',
      async (_input, init) => {
        const body = JSON.parse(String(init?.body ?? '{}')) as { query?: string }
        seenQueries.push(body.query ?? '')

        return Response.json(seenQueries.length === 1
          ? { totalHits: 0, foods: [] }
          : {
              totalHits: 1,
              foods: [
                {
                  ...usdaPayload().foods[0],
                  description: 'WENDYS CHICKEN NUGGETS',
                  brandOwner: 'WENDYS',
                },
              ],
            })
      },
    )

    expect(seenQueries).toEqual(['Wendy’s nuggets', 'wendys nuggets'])
    expect(response.query).toBe('Wendy’s nuggets')
    expect(response.results[0]).toMatchObject({
      name: 'WENDYS CHICKEN NUGGETS',
      brand: 'WENDYS',
    })
  })

  it('filters USDA search results to foods matching all query terms', async () => {
    const response = await searchUSDAFoods(
      { ...DEFAULT_QUERY, query: 'Wendy’s nuggets' },
      'test-usda-key',
      async () => Response.json({
        totalHits: 2,
        foods: [
          {
            ...usdaPayload().foods[0],
            description: 'WENDYS CHICKEN NUGGETS',
            brandOwner: 'WENDYS',
          },
          {
            ...usdaPayload().foods[0],
            fdcId: 124,
            description: 'WENDYS FRENCH FRIES',
            brandOwner: 'WENDYS',
          },
        ],
      }),
    )

    expect(response.results.map((result) => result.name)).toEqual(['WENDYS CHICKEN NUGGETS'])
  })

  it('maps USDA food details into the proxy contract', async () => {
    const response = await fetchUSDAFood(123, 'test-usda-key', async () => Response.json(usdaDetailsPayload()))

    expect(response).toMatchObject({
      id: 'usda:123',
      fdcId: 123,
      name: 'Protein Bar',
      brand: 'Macro Co',
      servingDescription: '1 bar',
      gramsPerServing: 50,
      caloriesPerServing: 210,
      proteinPerServing: 20,
      fatPerServing: 7,
      carbsPerServing: 18,
      saturatedFatPerServing: 2,
      fiberPerServing: 6,
      sugarsPerServing: 5,
      addedSugarsPerServing: 4,
      sodiumPerServing: 320,
      cholesterolPerServing: 15,
      sourceName: 'USDA FoodData Central',
      sourceURL: 'https://fdc.nal.usda.gov/food-details/123',
      barcode: '0123456789012',
    })
  })
})

describe('packaged food cache policy', () => {
  it('shares successful pinned Open Food Facts results under the default read key', () => {
    const warmedOpenFoodFactsQuery: PackagedFoodSearchQuery = {
      ...DEFAULT_QUERY,
      provider: 'openFoodFacts',
      fallbackOnEmpty: false,
    }

    const warmedSharedCacheKey = cacheWritePlan(
      new URL(BASE_URL),
      warmedOpenFoodFactsQuery,
      makeResponse('openFoodFacts', {
        results: [makeOpenFoodFactsSearchResult()],
      }),
    ).find((entry) => entry.kind === 'openFoodFacts')

    const nextDefaultReadKey = cacheReadOrder(new URL(BASE_URL), DEFAULT_QUERY)[0]

    expect(warmedSharedCacheKey?.kind).toBe('openFoodFacts')
    expect(nextDefaultReadKey.kind).toBe('openFoodFacts')
    expect(warmedSharedCacheKey?.request.url).toBe(nextDefaultReadKey.request.url)
  })

  it('keeps empty pinned Open Food Facts page-1 results out of the shared default key', () => {
    const pinnedOpenFoodFactsQuery: PackagedFoodSearchQuery = {
      ...DEFAULT_QUERY,
      provider: 'openFoodFacts',
      fallbackOnEmpty: false,
    }

    const pinnedCacheWrites = cacheWritePlan(
      new URL(BASE_URL),
      pinnedOpenFoodFactsQuery,
      makeResponse('openFoodFacts'),
    )

    expect(pinnedCacheWrites.map((entry) => entry.kind)).toEqual(['openFoodFactsPinned'])
    expect(pinnedCacheWrites[0]?.request.url).not.toBe(
      cacheReadOrder(new URL(BASE_URL), DEFAULT_QUERY)[0]?.request.url,
    )
  })

  it('keeps empty default Open Food Facts responses scoped to their fallback mode', () => {
    const noFallbackQuery: PackagedFoodSearchQuery = {
      ...DEFAULT_QUERY,
      fallbackOnEmpty: false,
    }

    const cacheWrites = cacheWritePlan(
      new URL(BASE_URL),
      noFallbackQuery,
      makeResponse('openFoodFacts'),
    )

    expect(cacheWrites.map((entry) => entry.kind)).toEqual(['default'])
    expect(cacheWrites[0]?.request.url).not.toBe(
      cacheReadOrder(new URL(BASE_URL), DEFAULT_QUERY)[0]?.request.url,
    )
  })

  it('keeps default USDA responses out of the default Open Food Facts cache key', () => {
    const pageTwoQuery: PackagedFoodSearchQuery = {
      ...DEFAULT_QUERY,
      page: 2,
    }

    const cacheKinds = cacheWritePlan(
      new URL(BASE_URL),
      pageTwoQuery,
      makeResponse('usda', {
        page: 2,
      }),
    ).map((entry) => entry.kind)

    expect(cacheKinds).toEqual(['usda'])
    expect(cacheReadOrder(new URL(BASE_URL), pageTwoQuery).map((entry) => entry.kind)).toEqual([
      'openFoodFacts',
      'default',
    ])
  })

  it('keeps provider-pinned cache keys stable across fallback policy changes', () => {
    const pinnedOpenFoodFactsWithFallback = cacheReadOrder(new URL(BASE_URL), {
      ...DEFAULT_QUERY,
      provider: 'openFoodFacts',
      fallbackOnEmpty: true,
    })[0]
    const pinnedOpenFoodFactsWithoutFallback = cacheReadOrder(new URL(BASE_URL), {
      ...DEFAULT_QUERY,
      provider: 'openFoodFacts',
      fallbackOnEmpty: false,
    })[0]
    const pinnedUSDAWithFallback = cacheReadOrder(new URL(BASE_URL), {
      ...DEFAULT_QUERY,
      provider: 'usda',
      fallbackOnEmpty: true,
    })[0]
    const pinnedUSDAWithoutFallback = cacheReadOrder(new URL(BASE_URL), {
      ...DEFAULT_QUERY,
      provider: 'usda',
      fallbackOnEmpty: false,
    })[0]

    expect(pinnedOpenFoodFactsWithFallback.request.url).toBe(pinnedOpenFoodFactsWithoutFallback.request.url)
    expect(pinnedUSDAWithFallback.request.url).toBe(pinnedUSDAWithoutFallback.request.url)
  })
})

function requestURL(input: RequestInfo | URL): string {
  if (typeof input === 'string') {
    return input
  }

  if (input instanceof URL) {
    return input.toString()
  }

  return input.url
}

function isSearchALiciousRequest(url: string): boolean {
  return url.includes('search.openfoodfacts.org')
}

function isLegacyOpenFoodFactsRequest(url: string): boolean {
  return url.includes('world.openfoodfacts.org') || url.includes('world.openfoodfacts.net')
}

function openFoodFactsPayload() {
  return {
    count: 1,
    products: [
      {
        _id: '123',
        code: '0123456789012',
        product_name: 'Protein Bar',
        brands: 'Macro Co',
        serving_size: '1 bar',
        serving_quantity: 50,
        serving_quantity_unit: 'g',
        quantity: '50 g',
        url: 'https://world.openfoodfacts.org/product/0123456789012',
        nutriments: {
          'energy-kcal_serving': 210,
          proteins_serving: 20,
          fat_serving: 7,
          carbohydrates_serving: 18,
          'saturated-fat_serving': 2,
          fiber_serving: 6,
          sugars_serving: 5,
          'added-sugars_serving': 4,
          sodium_serving: 0.32,
          cholesterol_serving: 0.015,
        },
      },
    ],
  }
}

function legacyRestaurantPayload() {
  return {
    count: 1,
    products: [
      {
        product_name: "Wendy's, 4 Piece Chicken Nuggets",
        brands: "Wendy's",
        serving_size: '100g',
        nutriments: {
          'energy-kcal_100g': 175,
          proteins_100g: 10,
          fat_100g: 12,
          carbohydrates_100g: 10,
        },
      },
    ],
  }
}

function searchALiciousPayload() {
  return {
    hits: [
      {
        code: '0123456789012',
        product_name: 'Protein Bar',
        brands: ['Macro Co'],
        serving_size: '1 bar',
        serving_quantity: 50,
        serving_quantity_unit: 'g',
        quantity: '50 g',
        nutriments: {
          'energy-kcal_serving': 210,
          proteins_serving: 20,
          fat_serving: 7,
          carbohydrates_serving: 18,
          'saturated-fat_serving': 2,
          fiber_serving: 6,
          sugars_serving: 5,
          'added-sugars_serving': 4,
          sodium_serving: 0.32,
          cholesterol_serving: 0.015,
        },
      },
    ],
    page: 1,
    page_size: 10,
    page_count: 1,
    count: 1,
    timed_out: false,
  }
}

function searchALiciousEmptyPayload() {
  return {
    hits: [],
    page: 1,
    page_size: 10,
    page_count: 0,
    count: 0,
    timed_out: false,
  }
}

function searchALiciousTimedOutEmptyPayload() {
  return {
    ...searchALiciousEmptyPayload(),
    timed_out: true,
  }
}

function searchALiciousIncompleteNutritionPayload() {
  return {
    hits: [
      {
        code: '999',
        product_name: 'Missing Nutrition',
        brands: ['Sparse Co'],
      },
    ],
    page: 1,
    page_size: 10,
    page_count: 1,
    count: 1,
    timed_out: false,
  }
}

function searchALiciousMixedNutritionPayload() {
  return {
    ...searchALiciousPayload(),
    hits: [
      searchALiciousPayload().hits[0],
      {
        code: '999',
        product_name: 'Protein Bar Missing Nutrition',
        brands: ['Sparse Co'],
      },
    ],
    count: 2,
  }
}

function searchALiciousDuplicatePayload() {
  const product = searchALiciousPayload().hits[0]
  return {
    hits: [
      product,
      { ...product },
    ],
    page: 1,
    page_size: 10,
    page_count: 1,
    count: 2,
    timed_out: false,
  }
}

function searchALiciousChickFilASaucePayload() {
  return {
    hits: [
      {
        code: '070200856165',
        product_name: 'Chick-fil-A Sauce',
        brands: ['Chick-fil-A'],
        nutriments: {
          'energy-kcal_100g': 516,
          proteins_100g: 0,
          fat_100g: 45.2,
          carbohydrates_100g: 22.6,
        },
      },
    ],
    page: 1,
    page_size: 10,
    page_count: 1,
    count: 1,
    timed_out: false,
  }
}

function searchALiciousFilteredEmptyHasMorePayload() {
  return {
    ...searchALiciousChickFilASaucePayload(),
    page_count: 2,
    count: 20,
  }
}

function unusableOpenFoodFactsPayload() {
  return {
    count: 1_000,
    products: [
      {
        _id: 'missing-nutrition',
        product_name: 'Missing Nutrition',
      },
    ],
  }
}

function sparseUsableOpenFoodFactsPayload(page: number) {
  const product = {
    ...openFoodFactsPayload().products[0],
    _id: String(page),
    code: `01234567890${page}`,
    product_name: `Protein Bar ${page}`,
  }

  return {
    count: 1_000,
    products: [product],
  }
}

function usdaPayload() {
  return {
    totalHits: 1,
    foods: [
      {
        fdcId: 123,
        description: 'Protein Bar',
        brandName: 'Macro Co',
        gtinUpc: '0123456789012',
        servingSize: 50,
        servingSizeUnit: 'g',
        householdServingFullText: '1 bar',
        foodNutrients: [
          { nutrientId: 1008, value: 210 },
          { nutrientId: 1003, value: 20 },
          { nutrientId: 1004, value: 7 },
          { nutrientId: 1005, value: 18 },
          { nutrientId: 1258, value: 2 },
          { nutrientId: 1079, value: 6 },
          { nutrientId: 2000, value: 5 },
          { nutrientId: 1235, value: 4 },
          { nutrientId: 1093, value: 320 },
          { nutrientId: 1253, value: 15 },
        ],
      },
    ],
  }
}

function usdaDetailsPayload() {
  return {
    fdcId: 123,
    description: 'Protein Bar',
    brandName: 'Macro Co',
    gtinUpc: '0123456789012',
    servingSize: 50,
    servingSizeUnit: 'g',
    householdServingFullText: '1 bar',
    foodNutrients: [
      { amount: 210, nutrient: { id: 1008, number: '208' } },
      { amount: 20, nutrient: { id: 1003, number: '203' } },
      { amount: 7, nutrient: { id: 1004, number: '204' } },
      { amount: 18, nutrient: { id: 1005, number: '205' } },
      { amount: 2, nutrient: { id: 1258, number: '606' } },
      { amount: 6, nutrient: { id: 1079, number: '291' } },
      { amount: 5, nutrient: { id: 2000, number: '269' } },
      { amount: 4, nutrient: { id: 1235, number: '539' } },
      { amount: 320, nutrient: { id: 1093, number: '307' } },
      { amount: 15, nutrient: { id: 1253, number: '601' } },
    ],
  }
}

function makeResponse(
  resolvedProvider: PackagedFoodSearchResponse['resolvedProvider'],
  overrides: Partial<PackagedFoodSearchExecution> = {},
): PackagedFoodSearchExecution {
  return {
    query: DEFAULT_QUERY.query,
    page: DEFAULT_QUERY.page,
    pageSize: DEFAULT_QUERY.pageSize,
    results: [],
    hasMore: false,
    resolvedProvider,
    ...overrides,
  }
}

function makeOpenFoodFactsSearchResult(): PackagedFoodSearchExecution['results'][number] {
  return {
    provider: 'openFoodFacts',
    item: openFoodFactsPayload().products[0],
  }
}
