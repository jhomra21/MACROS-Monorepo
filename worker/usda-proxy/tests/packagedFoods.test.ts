import { describe, expect, it } from 'bun:test'
import { z } from 'zod'

import { fetchOpenFoodFactsProduct } from '../src/openFoodFacts'
import { cacheReadOrder, cacheWritePlan, usdaFoodCacheKey, usdaSearchCacheKey } from '../src/packagedFoodSearchCache'
import { searchPackagedFoods } from '../src/packagedFoods'
import { isRestaurantLikeQuery } from '../src/restaurantSearch'
import type { PackagedFoodSearchDependencies, PackagedFoodSearchExecution } from '../src/packagedFoods'
import type { PackagedFoodSearchQuery, PackagedFoodSearchResponse } from '../src/types'
import { normalizeUSDAFood } from '../src/normalizedFood'
import { fetchUSDAFood, searchUSDAFoods, usdaSourceFood } from '../src/usda'

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

  it('keeps valid Search-a-licious hits beside malformed siblings, including timed-out pages', async () => {
    const response = await searchPackagedFoods(
      { ...DEFAULT_QUERY, query: 'QA cereal' },
      searchDependencies(async (input) => Response.json(isSearchALiciousRequest(requestURL(input))
        ? {
          hits: [searchALiciousCereal(), null, 'invalid', []],
          page_count: 1,
          timed_out: true,
        }
        : { count: 0, products: [] })),
    )

    expect(response.results).toHaveLength(1)
    expect(response.results[0].item).toMatchObject({ code: '1234567890123', product_name: 'QA cereal' })
    expect(response.hasMore).toBe(false)
  })

  it('keeps valid legacy products beside malformed siblings', async () => {
    const response = await searchPackagedFoods(
      { ...DEFAULT_QUERY, query: 'QA cereal' },
      searchDependencies(async (input) => {
        const url = requestURL(input)

        return isSearchALiciousRequest(url)
          ? new Response(null, { status: 503 })
          : Response.json({ products: [searchALiciousCereal(), null, 'invalid'], count: 1 })
      }),
    )

    expect(response.results).toHaveLength(1)
    expect(response.results[0].item).toMatchObject({ code: '1234567890123', product_name: 'QA cereal' })
  })

  it('rejects invalid Open Food Facts collection containers after all providers fail', async () => {
    await expect(
      searchPackagedFoods(
        { ...DEFAULT_QUERY, query: 'QA cereal', provider: 'openFoodFacts', fallbackOnEmpty: false },
        searchDependencies(async (input) => Response.json(isSearchALiciousRequest(requestURL(input))
          ? { hits: {}, timed_out: false }
          : { products: {}, count: 1 })),
      ),
    ).rejects.toThrow('Open Food Facts is unavailable right now.')
  })

  it('rejects invalid USDA collection containers', async () => {
    await expect(
      searchPackagedFoods(
        { ...DEFAULT_QUERY, query: 'QA cereal', provider: 'usda', page: 2 },
        searchDependencies(async () => Response.json({ foods: {}, totalHits: 100 })),
      ),
    ).rejects.toThrow('USDA search is unavailable right now.')
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

  it('tries the more reliable Open Food Facts staging host before production legacy search', async () => {
    const legacyHosts: string[] = []

    const response = await searchPackagedFoods(
      { ...DEFAULT_QUERY, query: 'wendys nuggets' },
      searchDependencies(async (input) => {
        const url = requestURL(input)

        if (isLegacyOpenFoodFactsRequest(url)) {
          legacyHosts.push(new URL(url).host)

          return Response.json(legacyRestaurantPayload())
        }

        return Response.json(searchALiciousEmptyPayload())
      }),
    )

    expect(response.results).toHaveLength(1)
    expect(legacyHosts).toEqual(['world.openfoodfacts.net'])
  })

  it('keeps restaurant chain results that match the menu item without requiring every query token', async () => {
    const response = await searchPackagedFoods(
      { ...DEFAULT_QUERY, query: 'mcdonalds burger' },
      searchDependencies(async (input) => {
        const url = requestURL(input)

        if (isLegacyOpenFoodFactsRequest(url)) {
          return Response.json({
            count: 3,
            products: [
              restaurantProduct('Big Mac Sauce', "McDonald's"),
              restaurantProduct("McDonald's, Bacon McDouble", "McDonald's"),
              restaurantProduct("McDonald's, Cheeseburger", "McDonald's"),
            ],
          })
        }

        return Response.json(searchALiciousEmptyPayload())
      }),
    )

    expect(response.results.map((result) => result.provider === 'openFoodFacts' ? result.item.product_name : undefined)).toEqual([
      "McDonald's, Bacon McDouble",
      "McDonald's, Cheeseburger",
    ])
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

  it('scans empty restaurant legacy pages before falling back to Search-a-licious', async () => {
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
    expect(response.openFoodFactsAttemptCount).toBe(3)
    expect(legacyPages).toEqual([1, 2, 3])
    expect(searchALiciousCallCount).toBe(0)
  })

  it('stops empty restaurant searches after scanned Open Food Facts pages miss', async () => {
    let legacyPageCount = 0

    const response = await searchPackagedFoods(
      { ...DEFAULT_QUERY, query: 'Raising cane’s' },
      searchDependencies(async (input) => {
        const url = requestURL(input)

        if (isLegacyOpenFoodFactsRequest(url)) {
          legacyPageCount += 1

          return Response.json({ count: 72, products: [] })
        }

        return Response.json({ ...searchALiciousEmptyPayload(), page_count: 7 })
      }),
    )

    expect(response.resolvedProvider).toBe('openFoodFacts')
    expect(response.results).toEqual([])
    expect(response.hasMore).toBe(false)
    expect(legacyPageCount).toBe(3)
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
    expect(isRestaurantLikeQuery('mcdonald’s cheeseburger')).toBe(true)
    expect(isRestaurantLikeQuery('wendys nuggets')).toBe(true)
    expect(isRestaurantLikeQuery('arbys sandwich')).toBe(true)
    expect(isRestaurantLikeQuery('checkers fries')).toBe(true)
    expect(isRestaurantLikeQuery('in n out double double')).toBe(true)
    expect(isRestaurantLikeQuery('in and out burger')).toBe(true)
    expect(isRestaurantLikeQuery('shake shack fries')).toBe(true)
    expect(isRestaurantLikeQuery('five guys cheeseburger')).toBe(true)
    expect(isRestaurantLikeQuery('raising canes tenders')).toBe(true)
    expect(isRestaurantLikeQuery('raising cane’s')).toBe(true)
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
      const body = parseUSDARequestBody(init?.body)
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
        const body = parseUSDARequestBody(init?.body)
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
      name: 'Wendys Chicken Nuggets',
      brand: 'Wendys',
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

    expect(response.results.map((result) => result.name)).toEqual(['Wendys Chicken Nuggets'])
  })

  it('maps USDA food details into the proxy contract', async () => {
    const response = await fetchUSDAFood(123, 'test-usda-key', async () => Response.json(usdaDetailsPayload()))

    expect(response).toMatchObject({
      id: 'usda:123',
      fdcId: 123,
      name: 'Protein Bar',
      brand: 'Macro',
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

  it('scales per-100 g USDA nutrients to the label serving for every gram unit spelling', async () => {
    for (const servingSizeUnit of ['GRM', 'grm', 'g', 'G', 'grams']) {
      const payload = { ...usdaDetailsPayload(), servingSizeUnit }
      const label = payload.labelNutrients
      const response = await fetchUSDAFood(123, 'test-usda-key', async () => Response.json(payload))

      expect([
        response.gramsPerServing,
        response.caloriesPerServing,
        response.proteinPerServing,
        response.fatPerServing,
        response.carbsPerServing,
        response.sodiumPerServing,
      ]).toEqual([
        50,
        label.calories.value,
        label.protein.value,
        label.fat.value,
        label.carbohydrates.value,
        label.sodium.value,
      ])
    }
  })

  it('scales per-100 ml USDA nutrients to volume servings without claiming grams', async () => {
    for (const servingSizeUnit of ['MLT', 'mlt', 'ml', 'ML', 'milliliter', 'Milliliters']) {
      for (const householdServingFullText of ['8 fl oz', undefined]) {
        const response = await fetchUSDAFood(321, 'test-usda-key', async () => Response.json({
          ...usdaBeverageDetailsPayload(),
          servingSizeUnit,
          householdServingFullText,
        }))

        expect(response).toMatchObject({ servingDescription: householdServingFullText ?? '240 ml', ...USDA_240_ML_EXPECTED })
        expect(response.gramsPerServing).toBeUndefined()
      }
    }
  })

  it('gives the same volume serving from v1 search, v1 details, and v2 when unit spellings differ', async () => {
    // Independent records shaped like an FDC Branded beverage: search reports MLT, details report ml.
    const searchRecord = {
      fdcId: 321,
      dataType: 'Branded',
      description: 'FIZZ COLA',
      brandOwner: 'FIZZ BEVERAGE CO.',
      servingSize: 240,
      servingSizeUnit: 'MLT',
      foodNutrients: [
        { nutrientId: 1008, value: 42 },
        { nutrientId: 1003, value: 0 },
        { nutrientId: 1004, value: 0 },
        { nutrientId: 1005, value: 10.6 },
        { nutrientId: 1093, value: 4 },
      ],
    }

    const detailsRecord = {
      fdcId: 321,
      dataType: 'Branded',
      description: 'FIZZ COLA',
      brandOwner: 'FIZZ BEVERAGE CO.',
      servingSize: 240.0,
      servingSizeUnit: 'ml',
      foodNutrients: [
        { amount: 42, nutrient: { id: 1008 } },
        { amount: 0, nutrient: { id: 1003 } },
        { amount: 0, nutrient: { id: 1004 } },
        { amount: 10.6, nutrient: { id: 1005 } },
        { amount: 4, nutrient: { id: 1093 } },
      ],
    }

    const search = await searchUSDAFoods(
      { ...DEFAULT_QUERY, query: 'fizz cola' },
      'test-usda-key',
      async () => Response.json({ totalHits: 1, foods: [searchRecord] }),
    )

    const details = await fetchUSDAFood(321, 'test-usda-key', async () => Response.json(detailsRecord))
    const v2 = normalizeUSDAFood(usdaSourceFood(searchRecord)!)
    const v1Key = (food: typeof details) => [food.name, food.brand, food.servingDescription, food.gramsPerServing, food.caloriesPerServing, food.proteinPerServing, food.fatPerServing, food.carbsPerServing, food.sodiumPerServing]
    const { calories, protein, fat, carbs, sodium } = v2.nutrition

    // 240 ml is 2.4 × the per-100 ml values: 100.8 → 101 kcal, 25.44 → 25.4 g carbs, 9.6 mg sodium.
    expect(v1Key(details)).toEqual(['Fizz Cola', 'Fizz Beverage', '240 ml', undefined, 101, 0, 0, 25.4, 9.6])
    expect(v1Key(search.results[0]!)).toEqual(v1Key(details))
    expect([v2.name, v2.brand, v2.servingDescription, v2.gramsPerServing, calories, protein, fat, carbs, sodium]).toEqual(v1Key(details))
  })

  it('keeps unscaled per-100 values on a "100 g or ml" serving without grams when a Branded basis is unknown', async () => {
    for (const serving of [
      { servingSizeUnit: undefined },
      { servingSizeUnit: 'IU' },
      { servingSize: 0 },
      { servingSize: -50 },
      { servingSize: undefined },
      { dataType: undefined, servingSizeUnit: undefined },
    ]) {
      const details = await fetchUSDAFood(123, 'test-usda-key', async () => Response.json({ ...usdaDetailsPayload(), ...serving }))
      const searchRecord = { ...usdaPayload().foods[0], ...serving }
      const search = await searchUSDAFoods(DEFAULT_QUERY, 'test-usda-key', async () => Response.json({ totalHits: 1, foods: [searchRecord] }))
      const v2 = normalizeUSDAFood(usdaSourceFood(searchRecord)!)

      for (const food of [details, search.results[0]!]) {
        expect(food).toMatchObject({
          servingDescription: '100 g or ml',
          caloriesPerServing: 420,
          proteinPerServing: 40,
          fatPerServing: 14,
          carbsPerServing: 36,
          sodiumPerServing: 640,
        })
        expect(food.gramsPerServing).toBeUndefined()
      }

      expect(v2.servingDescription).toBe('100 g or ml')
      expect(v2.gramsPerServing).toBeUndefined()
      expect(v2.nutrition).toMatchObject({ calories: 420, protein: 40, fat: 14, carbs: 36, sodium: 640 })
    }
  })

  it('keeps the 100 g basis for per-100 g non-branded records, even beside a volume serving', async () => {
    for (const dataType of ['Foundation', 'SR Legacy', 'Survey (FNDDS)']) for (const serving of [
      { servingSize: undefined, servingSizeUnit: undefined, householdServingFullText: undefined },
      { servingSize: 240, servingSizeUnit: 'MLT' },
    ]) {
      const response = await fetchUSDAFood(123, 'test-usda-key', async () => Response.json({
        ...usdaDetailsPayload(),
        dataType,
        ...serving,
      }))

      expect(response).toMatchObject({
        servingDescription: '100 g',
        gramsPerServing: 100,
        caloriesPerServing: 420,
        proteinPerServing: 40,
        fatPerServing: 14,
        carbsPerServing: 36,
        sodiumPerServing: 640,
      })
    }
  })
  it('renders gram fallback servings the same from search and details when unit spellings differ', async () => {
    // Independent records shaped like FDC 2026852: search reports GRM, details report g, neither has household text.
    const searchRecord = {
      fdcId: 2026852,
      description: 'NUTELLA WITH BREADSTICKS',
      brandOwner: 'FERRERO U.S.A., INCORPORATED',
      servingSize: 52,
      servingSizeUnit: 'GRM',
      foodNutrients: [
        { nutrientId: 1008, value: 519 },
        { nutrientId: 1003, value: 7.69 },
        { nutrientId: 1004, value: 26.92 },
        { nutrientId: 1005, value: 65.38 },
        { nutrientId: 1093, value: 250 },
      ],
    }

    const detailsRecord = {
      fdcId: 2026852,
      description: 'NUTELLA WITH BREADSTICKS',
      brandOwner: 'FERRERO U.S.A., INCORPORATED',
      servingSize: 52.0,
      servingSizeUnit: 'g',
      foodNutrients: [
        { amount: 519, nutrient: { id: 1008 } },
        { amount: 7.69, nutrient: { id: 1003 } },
        { amount: 26.92, nutrient: { id: 1004 } },
        { amount: 65.38, nutrient: { id: 1005 } },
        { amount: 250, nutrient: { id: 1093 } },
      ],
    }

    const search = await searchUSDAFoods(
      { ...DEFAULT_QUERY, query: 'nutella breadsticks' },
      'test-usda-key',
      async () => Response.json({ totalHits: 1, foods: [searchRecord] }),
    )

    const details = await fetchUSDAFood(2026852, 'test-usda-key', async () => Response.json(detailsRecord))
    const v2 = normalizeUSDAFood(usdaSourceFood(searchRecord)!)
    const v1Key = (food: typeof details) => [food.name, food.brand, food.servingDescription, food.gramsPerServing, food.caloriesPerServing, food.proteinPerServing, food.fatPerServing, food.carbsPerServing]
    const { calories, protein, fat, carbs } = v2.nutrition

    expect(v1Key(details)).toEqual(['Nutella with Breadsticks', 'Ferrero U.S.A., Incorporated', '52 g', 52, 270, 4, 14, 34])
    expect(v1Key(search.results[0]!)).toEqual(v1Key(details))
    expect([v2.name, v2.brand, v2.servingDescription, v2.gramsPerServing, calories, protein, fat, carbs]).toEqual(v1Key(details))
  })

  it('keeps household serving text and renders volume unit spellings as ml', async () => {
    const withHousehold = await fetchUSDAFood(123, 'test-usda-key', async () => Response.json(usdaDetailsPayload()))
    const volume = usdaSourceFood({ ...usdaDetailsPayload(), householdServingFullText: undefined, servingSize: 240, servingSizeUnit: 'MLT' })

    expect(withHousehold.servingDescription).toBe('1 bar')
    expect(volume?.servingDescription).toBe('240 ml')
  })})

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

  it('does not cache empty restaurant pinned Open Food Facts pages', () => {
    const cacheWrites = cacheWritePlan(
      new URL(BASE_URL),
      {
        ...DEFAULT_QUERY,
        query: 'Raising cane’s',
        page: 3,
        provider: 'openFoodFacts',
        fallbackOnEmpty: false,
      },
      makeResponse('openFoodFacts', { page: 3 }),
    )

    expect(cacheWrites).toEqual([])
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
  it('versions only the USDA basis cache keys and leaves Open Food Facts keys byte-identical', () => {
    const url = new URL(BASE_URL)
    const restaurant = { ...DEFAULT_QUERY, query: 'Raising cane’s' }
    const urls = (params: PackagedFoodSearchQuery) => cacheReadOrder(url, params).map((entry) => entry.request.url)

    expect(urls(DEFAULT_QUERY)).toEqual([
      'https://example.com/v1/packaged-foods/search/openFoodFacts?q=protein+bar&page=1&pageSize=10',
      'https://example.com/v1/packaged-foods/search/default?q=protein+bar&page=1&pageSize=10&fallbackOnEmpty=1',
    ])
    expect(urls({ ...DEFAULT_QUERY, provider: 'openFoodFacts' })).toEqual([
      'https://example.com/v1/packaged-foods/search/openFoodFacts/pinned?q=protein+bar&page=1&pageSize=10',
      'https://example.com/v1/packaged-foods/search/openFoodFacts?q=protein+bar&page=1&pageSize=10',
    ])
    expect(urls(restaurant)).toEqual([
      'https://example.com/v1/packaged-foods/search/openFoodFacts?q=raising+cane%E2%80%99s&page=1&pageSize=10&restaurantRetry=4',
    ])
    expect(urls({ ...DEFAULT_QUERY, provider: 'usda' })).toEqual([
      'https://example.com/v1/packaged-foods/search/usda?q=protein+bar&page=1&pageSize=10&usdaBasis=2',
    ])
    expect(cacheWritePlan(url, DEFAULT_QUERY, makeResponse('usda')).map((entry) => entry.request.url)).toEqual([
      'https://example.com/v1/packaged-foods/search/usda?q=protein+bar&page=1&pageSize=10&usdaBasis=2',
    ])
    expect(usdaSearchCacheKey(url, DEFAULT_QUERY).url).toBe(
      'https://example.com/v1/usda/search?q=protein+bar&page=1&pageSize=10&usdaBasis=2',
    )
    expect(usdaFoodCacheKey(url, 2026852).url).toBe('https://example.com/v1/usda/foods/2026852?usdaBasis=2')
  })})

function requestURL(input: RequestInfo | URL): string {
  return input instanceof Request ? input.url : new URL(input).toString()
}

function parseUSDARequestBody(body: BodyInit | null | undefined) {
  return z.object({
    dataType: z.array(z.string()).optional(),
    query: z.string().optional(),
  }).parse(JSON.parse(String(body ?? '{}')))
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

function restaurantProduct(productName: string, brands: string) {
  return {
    product_name: productName,
    brands,
    serving_size: '100g',
    nutriments: {
      'energy-kcal_100g': 250,
      proteins_100g: 12,
      fat_100g: 10,
      carbohydrates_100g: 20,
    },
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

function searchALiciousCereal() {
  return {
    code: '1234567890123',
    product_name: 'QA cereal',
    nutriments: {
      'energy-kcal_100g': 100,
      proteins_100g: 10,
      fat_100g: 2,
      carbohydrates_100g: 20,
    },
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

// FDC Branded shape: foodNutrients are per 100 g; labelNutrients are the 50 g label serving.
const USDA_PER_100_G = [
  [1008, 420],
  [1003, 40],
  [1004, 14],
  [1005, 36],
  [1258, 4],
  [1079, 12],
  [2000, 10],
  [1235, 8],
  [1093, 640],
  [1253, 30],
] as const

function usdaBrandedRecord() {
  return {
    fdcId: 123,
    dataType: 'Branded',
    description: 'Protein Bar',
    brandName: 'Macro Co',
    gtinUpc: '0123456789012',
    servingSize: 50,
    servingSizeUnit: 'GRM',
    householdServingFullText: '1 bar',
    labelNutrients: {
      calories: { value: 210 },
      protein: { value: 20 },
      fat: { value: 7 },
      carbohydrates: { value: 18 },
      saturatedFat: { value: 2 },
      fiber: { value: 6 },
      sugars: { value: 5 },
      addedSugar: { value: 4 },
      sodium: { value: 320 },
      cholesterol: { value: 15 },
    },
  }
}

// FDC Branded beverage shape: servingSizeUnit is volume, so foodNutrients are per 100 ml.
const USDA_PER_100_ML = [
  [1008, 42],
  [1003, 0],
  [1004, 0],
  [1005, 10.6],
  [2000, 10.6],
  [1093, 4],
] as const

// 240 ml is 2.4 × per 100 ml: 100.8 → 101 kcal, 25.44 → 25.4 g carbs and sugars, 9.6 mg sodium.
const USDA_240_ML_EXPECTED = {
  caloriesPerServing: 101,
  proteinPerServing: 0,
  fatPerServing: 0,
  carbsPerServing: 25.4,
  sugarsPerServing: 25.4,
  sodiumPerServing: 9.6,
}

function usdaBeverageDetailsPayload() {
  return {
    fdcId: 321,
    dataType: 'Branded',
    description: 'FIZZ COLA',
    brandOwner: 'FIZZ BEVERAGE CO.',
    servingSize: 240,
    servingSizeUnit: 'MLT',
    foodNutrients: USDA_PER_100_ML.map(([id, amount]) => ({ amount, nutrient: { id } })),
  }
}

function usdaPayload() {
  return {
    totalHits: 1,
    foods: [
      {
        ...usdaBrandedRecord(),
        foodNutrients: USDA_PER_100_G.map(([nutrientId, value]) => ({ nutrientId, value })),
      },
    ],
  }
}

function usdaDetailsPayload() {
  return {
    ...usdaBrandedRecord(),
    foodNutrients: USDA_PER_100_G.map(([id, amount]) => ({ amount, nutrient: { id } })),
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
