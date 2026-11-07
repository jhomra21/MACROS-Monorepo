import { describe, expect, it } from 'bun:test'
import { searchUnifiedFoods, UnifiedSearchError } from '../src/unifiedFoods'
import type {
  FoodSource,
  NormalizedFood,
  SourcePage,
  SourcePageCache,
} from '../src/foodSearchTypes'
import { createFoodSearchApp } from '../src/foodSearchRoute'
import { createOpenFoodFactsSource } from '../src/foodSources/openFoodFacts'
import { createUSDASource } from '../src/foodSources/usda'
import { normalizeOpenFoodFactsFood, normalizeUSDAFood } from '../src/normalizedFood'
import { usdaSourceFood } from '../src/usda'
import { decideFoodSearchBudget } from '../src/foodSearchBudgetLogic'
import fixtures from '../../../cal-macro-trackerTests/Fixtures/UnifiedFoodSearchParity.json'

const food = (id: string, overrides: Partial<NormalizedFood> = {}): NormalizedFood => ({
  id,
  source: 'futureSource',
  externalProductID: id,
  name: 'Chicken breast',
  servingDescription: '100 g',
  gramsPerServing: 100,
  nutrition: { calories: 100, protein: 20, fat: 2, carbs: 0 },
  requiredReviewNutrients: [],
  ...overrides,
})

const source = (id: string, search: FoodSource['search']): FoodSource => ({ id, search })

const page = (items: NormalizedFood[], nextCursor: string | null = null): SourcePage => ({
  items,
  nextCursor,
})

const terminal = (id: string, items = [food(id)]): FoodSource => source(id, async () => page(items))

const failed = (id: string): FoodSource =>
  source(id, async () => {
    throw new Error('upstream 503')
  })

const deadline = () => ({ signal: AbortSignal.timeout(200), expiresAt: Date.now() + 200 })

function memoryCache() {
  const entries = new Map<string, SourcePage>()
  const writes: Array<{ key: string; ttl: number }> = []

  const cache: SourcePageCache = {
    read: async (key) => entries.get(key),
    write: async (key, value, ttl) => {
      entries.set(key, value)
      writes.push({ key, ttl })
    },
  }

  return { cache, writes }
}

const run = (sources: FoodSource[], cursor?: string, cache?: SourcePageCache) =>
  searchUnifiedFoods({ query: 'chicken breast', cursor }, { sources, cache, deadline: deadline() })

describe('unified food search failures, written before implementation', () => {
  it('versions only the USDA source-page cache key', async () => {
    const { cache, writes } = memoryCache()

    await run([terminal('openFoodFacts'), terminal('usda')], undefined, cache)

    expect(writes.map((write) => write.key)).toEqual([
      '[3,"openFoodFacts","chicken breast","1"]',
      '[4,"usda","chicken breast","1"]',
    ])
  })
  it('starts every source concurrently, including unknown future source IDs', async () => {
    const started: string[] = []
    const releases: Array<() => void> = []

    const sources = ['a', 'b', 'newVendor'].map((id) =>
      source(id, async () => {
        started.push(id)
        await new Promise<void>((resolve) => releases.push(resolve))

        return page([food(id, { name: id })])
      }),
    )

    const pending = run(sources)
    await Promise.resolve()
    await Promise.resolve()
    expect(started).toEqual(['a', 'b', 'newVendor'])
    releases.forEach((release) => release())
    expect((await pending).results).toHaveLength(3)
  })

  it('bounds a source that never settles and returns the other source by the shared deadline', async () => {
    const started = Date.now()

    const result = await searchUnifiedFoods(
      { query: 'chicken breast' },
      {
        sources: [source('slow', () => new Promise(() => undefined)), terminal('ok')],
        deadline: { signal: AbortSignal.timeout(20), expiresAt: Date.now() + 20 },
      },
    )

    expect(result.results.map((item) => item.id)).toEqual(['ok'])
    expect(result.degradedSources).toEqual(['slow'])
    expect(Date.now() - started).toBeLessThan(150)
  })

  it('skips one 5xx source and retains its position in the cursor', async () => {
    const result = await run([failed('bad'), terminal('ok')])
    expect(result.results).toHaveLength(1)
    expect(result.nextCursor).toBeString()
    let calls = 0

    const retry = await run(
      [
        source('bad', async (_q, cursor) => {
          expect(cursor).toBeNull()
          calls += 1

          return page([food('recovered', { name: 'Another food' })])
        }),
        source('ok', async () => {
          throw new Error('exhausted source must not run')
        }),
      ],
      result.nextCursor!,
    )

    expect(calls).toBe(1)
    expect(retry.results.map((item) => item.id)).toEqual(['recovered'])
    expect(retry.nextCursor).toBeNull()
  })

  it('fails only when every source fails, not for successful empty sources', async () => {
    await expect(run([failed('a'), failed('b')])).rejects.toBeInstanceOf(UnifiedSearchError)
    expect((await run([failed('a'), terminal('empty', [])])).results).toEqual([])
  })

  it('deduplicates GTIN aliases and preserves conflicting GTINs', async () => {
    const result = await run([
      terminal('a', [
        food('a', { barcode: '012345678905', name: 'Chicken breast', brand: 'Brand' }),
      ]),
      terminal('b', [
        food('b', { barcode: '0012345678905', name: 'Chicken breast', brand: 'Brand' }),
      ]),
      terminal('c', [
        food('c', { barcode: '9999999999999', name: 'Chicken breast', brand: 'Brand' }),
      ]),
    ])

    expect(result.results.map((item) => item.id)).toEqual(['a', 'c'])
  })

  it('deduplicates normalized name and brand without barcodes, choosing a whole complete record', async () => {
    const result = await run([
      terminal('a', [
        food('a', {
          name: 'CHICKEN  BREAST',
          brand: 'ACME',
          nutrition: {},
          requiredReviewNutrients: ['calories', 'protein', 'fat', 'carbs'],
        }),
      ]),
      terminal('b', [food('b', { brand: 'Acme' })]),
    ])

    expect(result.results.map((item) => item.id)).toEqual(['b'])
  })

  it('does not repeat emitted duplicates across source pages or fetch exhausted sources', async () => {
    let calls = 0

    const a = source('a', async (_q, cursor) => {
      calls += 1

      return cursor == null
        ? page([food('one')], '2')
        : page([food('one'), food('two', { name: 'Chicken breast sliced' })])
    })

    const first = await run([a, terminal('b', [])])

    const second = await run(
      [
        a,
        source('b', async () => {
          throw new Error('must not run')
        }),
      ],
      first.nextCursor!,
    )

    expect(calls).toBe(2)
    expect(second.results.map((item) => item.id)).toEqual(['two'])
    expect(second.nextCursor).toBeNull()
  })

  it('rejects empty, short, oversized queries and malformed/query-mismatched cursors before calls', async () => {
    let calls = 0

    const s = source('a', async () => {
      calls += 1

      return page([], '2')
    })

    for (const query of ['', 'zz', 'a'.repeat(121)]) {
      await expect(
        searchUnifiedFoods({ query }, { sources: [s], deadline: deadline() }),
      ).rejects.toMatchObject({ status: 400 })
    }

    for (const cursor of ['garbage', 'a'.repeat(16385)])
      await expect(run([s], cursor)).rejects.toMatchObject({ status: 400 })
    expect(calls).toBe(0)
    const first = await run([s])
    await expect(
      searchUnifiedFoods(
        { query: 'different query', cursor: first.nextCursor! },
        { sources: [s], deadline: deadline() },
      ),
    ).rejects.toMatchObject({ status: 400 })
    expect(calls).toBe(1)
  })

  it('caches source pages independently, retries failed pages, and uses long USDA TTL', async () => {
    const { cache, writes } = memoryCache()
    let calls = 0

    const usda = source('usda', async () => {
      calls += 1

      return page([food('usda:1')])
    })

    await run([usda, failed('off')], undefined, cache)
    await run([usda, failed('off')], undefined, cache)
    expect(calls).toBe(1)
    expect(writes).toHaveLength(1)
    expect(writes[0]?.ttl).toBe(86400)
  })

  it('normalizes whitespace/case into the same source cache key', async () => {
    const { cache } = memoryCache()
    let calls = 0

    const s = source('off', async () => {
      calls += 1

      return page([])
    })

    await run([s], undefined, cache)
    await searchUnifiedFoods(
      { query: ' CHICKEN   breast ' },
      { sources: [s], cache, deadline: deadline() },
    )
    expect(calls).toBe(1)
  })
})

describe('v2 endpoint', () => {
  it('returns normalized results, no-store and header-only degradation', async () => {
    const app = createFoodSearchApp(async () => ({
      sources: [terminal('ok'), failed('openFoodFacts')],
      deadline: deadline(),
    }))

    const response = await app.request('/search?q=chicken%20breast')
    expect(response.status).toBe(200)
    expect(response.headers.get('cache-control')).toBe('no-store')
    expect(response.headers.get('x-macros-skipped-sources')).toBe('openFoodFacts')

    const body = await response.json<{
      query: string
      results: NormalizedFood[]
      nextCursor: string | null
    }>()

    expect(Object.keys(body).sort()).toEqual(['nextCursor', 'query', 'results'])
    expect(body.results[0].source).toBe('futureSource')
  })

  it('maps all-source failure and client 429 to only Try again, with no upstream for 429', async () => {
    let factories = 0

    const app = createFoodSearchApp(
      async () => {
        factories += 1

        return { sources: [failed('a')], deadline: deadline() }
      },
      async () => new Response('{}', { status: 429, headers: { 'Retry-After': '60' } }),
    )

    const limited = await app.request('/search?q=chicken')
    expect(limited.status).toBe(429)
    expect(await limited.json()).toEqual({ error: 'Try again' })
    expect(limited.headers.get('retry-after')).toBe('60')
    expect(factories).toBe(0)

    const broken = createFoodSearchApp(async () => ({
      sources: [failed('a')],
      deadline: deadline(),
    }))

    const response = await broken.request('/search?q=chicken')
    expect(response.status).toBe(503)
    expect(await response.json()).toEqual({ error: 'Try again' })
  })
})

describe('adapters and budgets', () => {
  it('skips budget-exhausted USDA before an upstream call', async () => {
    let calls = 0

    const s = createUSDASource({
      apiKey: 'test',
      allowRequest: async () => false,
      fetcher: async () => {
        calls += 1

        return Response.json({})
      },
    })

    const result = await run([s, terminal('ok')])
    expect(result.degradedSources).toEqual(['usda'])
    expect(calls).toBe(0)
  })

  it('skips OFF when its global gate denies or coordination fails', async () => {
    for (const allowRequest of [
      async () => false,
      async () => {
        throw new Error('RPC failure')
      },
    ]) {
      let calls = 0

      const off = createOpenFoodFactsSource({
        userAgent: 'test',
        allowRequest,
        fetcher: async () => {
          calls += 1

          return Response.json({ hits: [] })
        },
      })

      const result = await run([off, terminal('ok')])
      expect(calls).toBe(0)
      expect(result.degradedSources).toEqual(['openFoodFacts'])
      expect(result.nextCursor).toBeString()
    }
  })

  it('honors upstream 429 Retry-After without retries and returns the other source', async () => {
    const cooldowns: number[] = []
    let calls = 0

    const off = createOpenFoodFactsSource({
      userAgent: 'test',
      allowRequest: async () => true,
      cooldown: async (ms) => {
        cooldowns.push(ms)
      },
      fetcher: async () => {
        calls += 1

        return new Response('', { status: 429, headers: { 'Retry-After': '120' } })
      },
    })

    expect((await run([off, terminal('ok')])).results).toHaveLength(1)
    expect(calls).toBe(1)
    expect(cooldowns).toEqual([120000])
  })

  it('skips malformed items but keeps valid results and never fabricates nutrition', async () => {
    const off = createOpenFoodFactsSource({
      userAgent: 'test',
      allowRequest: async () => true,
      fetcher: async () =>
        Response.json({
          hits: [null, 12, {}, { code: '12345678', product_name: 'Chicken breast' }],
          page_count: 1,
        }),
    })

    const result = await run([off])
    expect(result.results).toHaveLength(1)
    expect(result.results[0]?.nutrition).toEqual({})
    expect(result.results[0]?.requiredReviewNutrients).toEqual([
      'calories',
      'protein',
      'fat',
      'carbs',
    ])
  })

  it('makes one request per source for normalized plain queries and barcode product lookup', async () => {
    const urls: string[] = []

    const off = createOpenFoodFactsSource({
      userAgent: 'test',
      allowRequest: async () => true,
      fetcher: async (url) => {
        urls.push(String(url))

        return Response.json({ product: { code: '012345678905', product_name: 'Chicken' } })
      },
    })

    await off.search('012345678905', null, deadline())
    expect(urls).toHaveLength(1)
    expect(urls[0]).toContain('/api/v2/product/')
  })

  it('enforces rolling 8/min and cooldown, without mutating input state', () => {
    const timestamps = [1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000]
    expect(decideFoodSearchBudget(timestamps, 0, 60000).allowed).toBe(false)
    const rolled = decideFoodSearchBudget(timestamps, 0, 62000)
    expect(rolled.allowed).toBe(true)
    expect(rolled.timestamps).toHaveLength(7)
    expect(decideFoodSearchBudget([], 120000, 62000).allowed).toBe(false)
    expect(timestamps).toHaveLength(8)
  })
})

describe('normalization parity fixtures', () => {
  for (const fixture of fixtures)
    it(fixture.name, () => {
      const normalized = normalizeOpenFoodFactsFood(fixture.product)
      expect(normalized).not.toBeNull()
      expect(normalized?.servingDescription).toBe(fixture.expected.servingDescription)
      expect(normalized?.gramsPerServing ?? null).toBe(fixture.expected.gramsPerServing)
      expect(normalized?.nutrition).toEqual(fixture.expected.nutrition)
      expect(normalized?.requiredReviewNutrients.map(String)).toEqual(
        fixture.expected.requiredReviewNutrients,
      )
    })

  it('USDA scales per-100 nutrients to known gram or milliliter servings, claiming grams only for grams', () => {
    const raw = {
      fdcId: 1,
      dataType: 'Branded',
      description: 'Food',
      servingSize: 50,
      servingSizeUnit: 'GRM',
      householdServingFullText: '1 piece',
      foodNutrients: [
        { nutrientId: 1008, value: 200 },
        { nutrientId: 1003, value: 10 },
        { nutrientId: 1004, value: 4 },
        { nutrientId: 1005, value: 30 },
        { nutrientId: 1093, value: 100 },
      ],
    }

    const normalized = (overrides: Partial<typeof raw>) => normalizeUSDAFood(usdaSourceFood({ ...raw, ...overrides })!)
    const halved = { calories: 100, protein: 5, fat: 2, carbs: 15, sodium: 50 }

    expect(normalized({})).toMatchObject({ servingDescription: '1 piece', gramsPerServing: 50, nutrition: halved })
    expect(normalized({ servingSizeUnit: 'MLT' })).toMatchObject({ servingDescription: '1 piece', nutrition: halved })
    expect(normalized({ servingSizeUnit: 'MLT' }).gramsPerServing).toBeUndefined()
    expect(normalized({ servingSizeUnit: undefined })).toMatchObject({ servingDescription: '100 g or ml', nutrition: { calories: 200 } })
    expect(normalized({ servingSizeUnit: undefined }).gramsPerServing).toBeUndefined()
  })
})
