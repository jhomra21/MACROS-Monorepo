export type SearchProvider = 'openFoodFacts' | 'usda'

export type HTTPFetcher = (
  input: Parameters<typeof fetch>[0],
  init?: Parameters<typeof fetch>[1],
) => ReturnType<typeof fetch>

export interface OpenFoodFactsProxyProduct {
  externalProductID?: string
  code?: string
  product_name?: string
  brands?: string
  serving_size?: string
  serving_quantity?: number
  serving_quantity_unit?: string
  quantity?: string
  nutriments?: OpenFoodFactsProxyNutriments
  url?: string
}

export interface OpenFoodFactsProxyNutriments {
  'energy-kcal_serving'?: number
  'proteins_serving'?: number
  'fat_serving'?: number
  'carbohydrates_serving'?: number
  'saturated-fat_serving'?: number
  'fiber_serving'?: number
  'sugars_serving'?: number
  'added-sugars_serving'?: number
  'sodium_serving'?: number
  'cholesterol_serving'?: number
  'salt_serving'?: number
  'energy-kcal_100g'?: number
  'proteins_100g'?: number
  'fat_100g'?: number
  'carbohydrates_100g'?: number
  'saturated-fat_100g'?: number
  'fiber_100g'?: number
  'sugars_100g'?: number
  'added-sugars_100g'?: number
  'sodium_100g'?: number
  'cholesterol_100g'?: number
  'salt_100g'?: number
}

export interface USDAProxyFoodResult {
  id: string
  fdcId: number
  name: string
  brand?: string
  servingDescription: string
  gramsPerServing?: number
  caloriesPerServing: number
  proteinPerServing: number
  fatPerServing: number
  carbsPerServing: number
  saturatedFatPerServing?: number
  fiberPerServing?: number
  sugarsPerServing?: number
  addedSugarsPerServing?: number
  sodiumPerServing?: number
  cholesterolPerServing?: number
  sourceName: string
  sourceURL: string
  barcode?: string
}

export type PackagedFoodSearchResult =
  | {
      provider: 'openFoodFacts'
      item: OpenFoodFactsProxyProduct
    }
  | {
      provider: 'usda'
      item: USDAProxyFoodResult
    }

export interface PackagedFoodSearchResponse {
  query: string
  page: number
  pageSize: number
  resolvedProvider?: SearchProvider
  results: PackagedFoodSearchResult[]
  hasMore: boolean
}

export interface PackagedFoodSearchQuery {
  query: string
  page: number
  pageSize: number
  fallbackOnEmpty: boolean
  provider?: SearchProvider
}

export interface USDAProxySearchResponse {
  query: string
  page: number
  pageSize: number
  provider: 'USDA FoodData Central'
  results: USDAProxyFoodResult[]
  hasMore: boolean
}

export interface USDAProxyErrorResponse {
  error: string
}

export interface ProviderPage<T> {
  query: string
  page: number
  pageSize: number
  results: T[]
  hasMore: boolean
}
