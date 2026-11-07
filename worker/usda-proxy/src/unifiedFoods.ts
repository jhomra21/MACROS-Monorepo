import type { FoodSearchDependencies, FoodSource, SourcePage } from './foodSearchTypes'
import {
  decodeFoodCursor,
  encodeFoodCursor,
  fingerprint,
  normalizedFoodQuery,
  UnifiedSearchError,
} from './foodSearchCursor'
import type { FoodSearchCursor } from './foodSearchCursor'
import { mergeFoodResults } from './foodSearchMerge'
import { awaitWithAbort } from './http'

export { UnifiedSearchError } from './foodSearchCursor'

export async function searchUnifiedFoods(
  input: { query: string; cursor?: string },
  dependencies: FoodSearchDependencies,
) {
  const query = normalizedFoodQuery(input.query)
  const cursor = await decodeFoodCursor(input.cursor, query)

  const sources = dependencies.sources.filter(
    (source) =>
      cursor == null || (cursor.positions[source.id] !== null && source.id in cursor.positions),
  )

  const positions: FoodSearchCursor['positions'] = { ...cursor?.positions }

  const outcomes = await Promise.allSettled(
    sources.map((source) =>
      awaitWithAbort(
        loadSource(source, query, cursor?.positions[source.id] ?? null, dependencies),
        dependencies.deadline.signal,
      ),
    ),
  )

  const items: SourcePage['items'] = []
  const degradedSources: string[] = []

  for (let i = 0; i < outcomes.length; i += 1) {
    const source = sources[i]!
    const outcome = outcomes[i]!

    if (outcome.status === 'fulfilled') {
      items.push(...outcome.value.items)
      positions[source.id] = outcome.value.nextCursor
    } else {
      degradedSources.push(source.id)
      // The first position is represented as "1"; null exclusively means exhausted.
      positions[source.id] = cursor?.positions[source.id] ?? '1'
    }
  }

  if (sources.length > 0 && degradedSources.length === sources.length)
    throw new UnifiedSearchError(503)
  const merged = await mergeFoodResults(items, query, cursor?.seen ?? [])
  const batch = (cursor?.batch ?? 0) + 1
  const activeIDs = new Set(dependencies.sources.map((source) => source.id))

  const activePositions = Object.fromEntries(
    Object.entries(positions).filter(([id]) => activeIDs.has(id)),
  )

  const hasMore = batch < 10 && Object.values(activePositions).some((position) => position !== null)

  return {
    query,
    results: merged.results,
    nextCursor: hasMore
      ? encodeFoodCursor({
          version: 1,
          query: await fingerprint(query),
          batch,
          positions: activePositions,
          seen: merged.seen,
        })
      : null,
    degradedSources,
  }
}

async function loadSource(
  source: FoodSource,
  query: string,
  cursor: string | null,
  dependencies: FoodSearchDependencies,
): Promise<SourcePage> {
  // USDA pages use version 4 since its nutrient basis changed; other sources keep their warm entries.
  const key = JSON.stringify([source.id === 'usda' ? 4 : 3, source.id, query, cursor ?? '1'])
  const cached = await dependencies.cache?.read(key)

  if (cached != null) return cached

  if (dependencies.deadline.signal.aborted) throw dependencies.deadline.signal.reason
  const page = await source.search(query, cursor === '1' ? null : cursor, dependencies.deadline)

  if (dependencies.deadline.signal.aborted) throw dependencies.deadline.signal.reason
  const ttl = page.items.length === 0 ? 300 : source.id === 'usda' ? 86400 : 3600
  await dependencies.cache?.write(key, page, ttl)

  return page
}
