import type { PackagedFoodCacheKeyKind } from './packagedFoodSearchCache'
import type { PackagedFoodSearchQuery, SearchProvider } from './types'

export interface PackagedFoodSearchLogContext {
  page: number
  pageSize: number
  provider: SearchProvider | 'default'
}

export interface PackagedFoodSearchLogMetadata {
  cacheKey?: PackagedFoodCacheKeyKind
  openFoodFactsAttemptCount?: number
  resolvedProvider?: SearchProvider
}

export function packagedFoodSearchLogContext(
  params: Pick<PackagedFoodSearchQuery, 'page' | 'pageSize' | 'provider'>,
): PackagedFoodSearchLogContext {
  return {
    page: params.page,
    pageSize: params.pageSize,
    provider: params.provider ?? 'default',
  }
}

export function packagedFoodSearchLogEntry(
  phase: string,
  context: PackagedFoodSearchLogContext,
  metadata: PackagedFoodSearchLogMetadata = {},
) {
  return {
    phase,
    page: context.page,
    pageSize: context.pageSize,
    provider: context.provider,
    ...metadata,
  }
}
