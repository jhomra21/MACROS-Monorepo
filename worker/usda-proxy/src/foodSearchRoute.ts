import { Hono } from 'hono'
import type { Context } from 'hono'
import type { FoodSearchDependencies } from './foodSearchTypes'
import { searchUnifiedFoods, UnifiedSearchError } from './unifiedFoods'
import { normalizedFoodQuery } from './foodSearchCursor'

export function createFoodSearchApp(
  dependencies: (c: Context<{ Bindings: Env }>) => Promise<FoodSearchDependencies>,
  rateLimit?: (c: Context<{ Bindings: Env }>) => Promise<Response | null>,
) {
  const app = new Hono<{ Bindings: Env }>()
  app.get('/search', async (c) => {
    c.header('Cache-Control', 'no-store')

    try {
      const url = new URL(c.req.url)

      if ([...url.searchParams.keys()].some((key) => key !== 'q' && key !== 'cursor'))
        throw new UnifiedSearchError(400)
      normalizedFoodQuery(c.req.query('q') ?? '')
      const limited = await rateLimit?.(c)

      if (limited != null)
        return new Response(JSON.stringify({ error: 'Try again' }), {
          status: limited.status,
          headers: {
            'Content-Type': 'application/json',
            'Cache-Control': 'no-store',
            'Retry-After': limited.headers.get('Retry-After') ?? '60',
          },
        })

      const result = await searchUnifiedFoods(
        { query: c.req.query('q') ?? '', cursor: c.req.query('cursor') },
        await dependencies(c),
      )

      if (result.degradedSources.length > 0)
        c.header('X-MACROS-Skipped-Sources', result.degradedSources.join(','))
      console.info(
        JSON.stringify({
          phase: 'unified-food-search',
          count: result.results.length,
          contributions: result.results.reduce<Record<string, number>>((counts, item) => {
            counts[item.source] = (counts[item.source] ?? 0) + 1

            return counts
          }, {}),
          skippedSources: result.degradedSources,
        }),
      )

      return c.json({ query: result.query, results: result.results, nextCursor: result.nextCursor })
    } catch (error) {
      return new Response(JSON.stringify({ error: 'Try again' }), {
        status: error instanceof UnifiedSearchError ? error.status : 503,
        headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' },
      })
    }
  })

  return app
}
