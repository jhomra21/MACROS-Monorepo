import { describe, expect, it } from 'bun:test'

import { cacheReadOrder, cacheWritePlan } from '../src/packagedFoodSearchCache'
import { searchPackagedFoods } from '../src/packagedFoods'
import type { PackagedFoodSearchExecution } from '../src/packagedFoods'
import type { PackagedFoodSearchQuery, PackagedFoodSearchResponse } from '../src/types'
import { fetchUSDAFood, searchUSDAFoods } from '../src/usda'

const DEFAULT_QUERY: PackagedFoodSearchQuery = {
  query: 'protein bar',
  page: 1,
  pageSize: 10,
  fallbackOnEmpty: true,
}

const BASE_URL = 'https://example.com/v1/packaged-foods/search'

describe('searchPackagedFoods', () => {
  it('uses Search-a-licious before falling back to USDA for default search', async () => {
    let searchALiciousCallCount = 0
    let usdaCallCount = 0

    const response = await searchPackagedFoods(
      DEFAULT_QUERY,
      'test-usda-key',
      'cal-macro-tracker/1.0 (test@example.com)',
      async (input) => {
        const url = requestURL(input)

        if (isSearchALiciousRequest(url)) {
          searchALiciousCallCount += 1
          return Response.json(searchALiciousPayload())
        }

        usdaCallCount += 1
        return Response.json(usdaPayload())
      },
    )

    expect(response.resolvedProvider).toBe('openFoodFacts')
    expect(response.openFoodFactsAttemptCount).toBe(1)
    expect(searchALiciousCallCount).toBe(1)
    expect(usdaCallCount).toBe(0)
    expect(response.results).toHaveLength(1)
  })

  it('falls back to USDA when Search-a-licious is unavailable for default search', async () => {
    let searchALiciousCallCount = 0
    let usdaCallCount = 0

    const response = await searchPackagedFoods(
      DEFAULT_QUERY,
      'test-usda-key',
      'cal-macro-tracker/1.0 (test@example.com)',
      async (input) => {
        const url = requestURL(input)

        if (isSearchALiciousRequest(url)) {
          searchALiciousCallCount += 1
          return new Response(null, { status: 503 })
        }

        usdaCallCount += 1
        return Response.json(usdaPayload())
      },
    )

    expect(response.resolvedProvider).toBe('usda')
    expect(response.degradedFallbackReason).toBe('openFoodFactsUnavailable')
    expect(response.openFoodFactsAttemptCount).toBe(1)
    expect(searchALiciousCallCount).toBe(1)
    expect(usdaCallCount).toBe(1)
  })

  it('falls back to USDA when Search-a-licious returns zero hits for default search', async () => {
    let searchALiciousCallCount = 0
    let usdaCallCount = 0

    const response = await searchPackagedFoods(
      DEFAULT_QUERY,
      'test-usda-key',
      'cal-macro-tracker/1.0 (test@example.com)',
      async (input) => {
        const url = requestURL(input)

        if (isSearchALiciousRequest(url)) {
          searchALiciousCallCount += 1
          return Response.json(searchALiciousEmptyPayload())
        }

        usdaCallCount += 1
        return Response.json(usdaPayload())
      },
    )

    expect(response.resolvedProvider).toBe('usda')
    expect(response.degradedFallbackReason).toBe('openFoodFactsNoUsableResults')
    expect(response.openFoodFactsAttemptCount).toBe(1)
    expect(searchALiciousCallCount).toBe(1)
    expect(usdaCallCount).toBe(1)
  })

  it('uses legacy Open Food Facts when pinned Search-a-licious is unavailable', async () => {
    let searchALiciousCallCount = 0
    let legacyOpenFoodFactsCallCount = 0
    let usdaCallCount = 0

    const response = await searchPackagedFoods(
      { ...DEFAULT_QUERY, provider: 'openFoodFacts', fallbackOnEmpty: false },
      'test-usda-key',
      'cal-macro-tracker/1.0 (test@example.com)',
      async (input) => {
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
      },
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
      'test-usda-key',
      'cal-macro-tracker/1.0 (test@example.com)',
      async (input) => {
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
      },
    )

    expect(response.resolvedProvider).toBe('openFoodFacts')
    expect(response.results).toHaveLength(0)
    expect(response.openFoodFactsAttemptCount).toBe(2)
    expect(searchALiciousCallCount).toBe(1)
    expect(legacyOpenFoodFactsCallCount).toBe(1)
    expect(usdaCallCount).toBe(0)
  })

  it('returns incomplete Open Food Facts products instead of filtering them out', async () => {
    let searchALiciousCallCount = 0
    let usdaCallCount = 0

    const response = await searchPackagedFoods(
      DEFAULT_QUERY,
      'test-usda-key',
      'cal-macro-tracker/1.0 (test@example.com)',
      async (input) => {
        const url = requestURL(input)

        if (isSearchALiciousRequest(url)) {
          searchALiciousCallCount += 1
          return Response.json(searchALiciousIncompleteNutritionPayload())
        }

        usdaCallCount += 1
        return Response.json(usdaPayload())
      },
    )

    expect(response.resolvedProvider).toBe('openFoodFacts')
    expect(response.results).toHaveLength(1)
    expect(response.results[0]).toMatchObject({
      provider: 'openFoodFacts',
      item: {
        product_name: 'Missing Nutrition',
      },
    })
    expect(searchALiciousCallCount).toBe(1)
    expect(usdaCallCount).toBe(0)
  })

  it('fetches only the requested legacy Open Food Facts page after Search-a-licious misses', async () => {
    let searchALiciousCallCount = 0
    let legacyOpenFoodFactsCallCount = 0

    const response = await searchPackagedFoods(
      { ...DEFAULT_QUERY, provider: 'openFoodFacts', fallbackOnEmpty: false },
      'test-usda-key',
      'cal-macro-tracker/1.0 (test@example.com)',
      async (input) => {
        const url = requestURL(input)
        if (isSearchALiciousRequest(url)) {
          searchALiciousCallCount += 1
          return Response.json(searchALiciousEmptyPayload())
        }

        const page = Number(new URL(url).searchParams.get('page') ?? '1')
        legacyOpenFoodFactsCallCount += 1
        return Response.json(page <= 9 ? sparseUsableOpenFoodFactsPayload(page) : unusableOpenFoodFactsPayload())
      },
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
      'test-usda-key',
      'cal-macro-tracker/1.0 (test@example.com)',
      async () => Response.json(usdaPayload()),
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

  it('preserves Open Food Facts secondary nutriments in search results', async () => {
    const response = await searchPackagedFoods(
      { ...DEFAULT_QUERY, provider: 'openFoodFacts' },
      'test-usda-key',
      'cal-macro-tracker/1.0 (test@example.com)',
      async (input) => {
        const url = requestURL(input)
        return Response.json(isSearchALiciousRequest(url)
          ? searchALiciousPayload()
          : openFoodFactsPayload())
      },
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
        'test-usda-key',
        'cal-macro-tracker/1.0 (test@example.com)',
        async (input) => {
          const url = requestURL(input)

          if (isSearchALiciousRequest(url)) {
            throw new SyntaxError('broken payload')
          }

          return Response.json(usdaPayload())
        },
      ),
    ).rejects.toThrow('broken payload')
  })
})

describe('fetchUSDAFood', () => {
  it('sends USDA API keys in headers instead of traced URLs', async () => {
    const seenRequests: Array<{ url: string, apiKey: string | null }> = []

    await searchUSDAFoods(DEFAULT_QUERY, 'test-usda-key', async (input, init) => {
      seenRequests.push({
        url: requestURL(input),
        apiKey: new Headers(init?.headers).get('X-Api-Key'),
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
      },
      {
        url: 'https://api.nal.usda.gov/fdc/v1/food/123',
        apiKey: 'test-usda-key',
      },
    ])
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

  it('does not persist degraded default USDA fallback under the default cache key', () => {
    const cacheKinds = cacheWritePlan(
      new URL(BASE_URL),
      DEFAULT_QUERY,
      makeResponse('usda', {
        degradedFallbackReason: 'openFoodFactsUnavailable',
      }),
    ).map((entry) => entry.kind)

    expect(cacheKinds).toEqual(['usda'])
    expect(cacheReadOrder(new URL(BASE_URL), DEFAULT_QUERY).map((entry) => entry.kind)).toEqual([
      'openFoodFacts',
      'default',
    ])
  })

  it('persists default USDA fallback when Open Food Facts returned a real unusable response', () => {
    const cacheKinds = cacheWritePlan(
      new URL(BASE_URL),
      DEFAULT_QUERY,
      makeResponse('usda', {
        degradedFallbackReason: 'openFoodFactsNoUsableResults',
      }),
    ).map((entry) => entry.kind)

    expect(cacheKinds).toEqual(['usda', 'default'])
  })

  it('keeps page-specific fallback responses from locking later default retries onto USDA', () => {
    const pageTwoQuery: PackagedFoodSearchQuery = {
      ...DEFAULT_QUERY,
      page: 2,
    }

    const cacheKinds = cacheWritePlan(
      new URL(BASE_URL),
      pageTwoQuery,
      makeResponse('usda', {
        page: 2,
        degradedFallbackReason: 'openFoodFactsUnavailable',
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
  return url.includes('world.openfoodfacts.org')
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
