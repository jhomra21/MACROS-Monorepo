export type ReviewNutrient = 'calories' | 'protein' | 'fat' | 'carbs'

export type FoodNutrition = Partial<
  Record<
    ReviewNutrient | 'saturatedFat' | 'fiber' | 'sugars' | 'addedSugars' | 'sodium' | 'cholesterol',
    number
  >
>

export interface NormalizedFood {
  id: string
  source: string
  externalProductID: string
  sourceName?: string
  sourceURL?: string
  name: string
  brand?: string
  barcode?: string
  servingDescription: string
  gramsPerServing?: number
  nutrition: FoodNutrition
  requiredReviewNutrients: ReviewNutrient[]
}

export interface SearchDeadline {
  signal: AbortSignal
  expiresAt: number
}

export interface SourcePage {
  items: NormalizedFood[]
  nextCursor: string | null
}

export interface FoodSource {
  id: string
  search(query: string, cursor: string | null, deadline: SearchDeadline): Promise<SourcePage>
}

export interface SourcePageCache {
  read(key: string): Promise<SourcePage | undefined>
  write(key: string, page: SourcePage, ttlSeconds: number): Promise<void>
}

export interface FoodSearchDependencies {
  sources: FoodSource[]
  deadline: SearchDeadline
  cache?: SourcePageCache
}
