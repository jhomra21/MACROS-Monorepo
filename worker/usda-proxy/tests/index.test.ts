import { describe, expect, it } from 'bun:test'

import { packagedFoodSearchLogContext, packagedFoodSearchLogEntry } from '../src/packagedFoodSearchLogging'

describe('packagedFoodSearchLogEntry', () => {
  it('omits raw query text from telemetry payloads', () => {
    const context = packagedFoodSearchLogContext({
      page: 1,
      pageSize: 10,
      provider: undefined,
    })

    const entry = packagedFoodSearchLogEntry('cache-miss', context, {
      cacheKey: 'default',
      openFoodFactsAttemptCount: 2,
      resolvedProvider: 'openFoodFacts',
    })

    expect(entry).toEqual({
      phase: 'cache-miss',
      page: 1,
      pageSize: 10,
      provider: 'default',
      cacheKey: 'default',
      openFoodFactsAttemptCount: 2,
      resolvedProvider: 'openFoodFacts',
    })
    expect('query' in entry).toBe(false)
  })
})
