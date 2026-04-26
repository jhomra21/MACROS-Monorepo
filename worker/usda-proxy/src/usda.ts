import type { HTTPFetcher, USDAProxyFoodResult, USDAProxySearchResponse } from './types'

const USDA_SEARCH_URL = 'https://api.nal.usda.gov/fdc/v1/foods/search'
const USDA_FOOD_DETAILS_URL = 'https://api.nal.usda.gov/fdc/v1/food'
const USDA_PROVIDER_NAME = 'USDA FoodData Central' as const
const BRANDED_DATA_TYPE = 'Branded'
const MAX_PAGE = 10
const CACHE_TTL_SECONDS = 300

const NUTRIENT_IDS = {
  calories: 1008,
  protein: 1003,
  fat: 1004,
  carbs: 1005,
  fiber: 1079,
  sodium: 1093,
  sugars: 2000,
  addedSugars: 1235,
  cholesterol: 1253,
  saturatedFat: 1258,
} as const

interface USDAFoodSearchResponse {
  foods?: USDASearchFood[]
  totalHits?: number
}

interface USDASearchFood {
  fdcId?: number
  description?: string
  brandName?: string
  brandOwner?: string
  gtinUpc?: string
  servingSize?: number
  servingSizeUnit?: string
  householdServingFullText?: string
  foodNutrients?: USDASearchFoodNutrient[]
}

interface USDAFoodDetails {
  fdcId?: number
  description?: string
  brandName?: string
  brandOwner?: string
  gtinUpc?: string
  servingSize?: number
  servingSizeUnit?: string
  householdServingFullText?: string
  foodNutrients?: USDAFoodDetailsNutrient[]
}

interface USDASearchFoodNutrient {
  nutrientId?: number
  value?: number
}

interface USDAFoodDetailsNutrient {
  amount?: number
  nutrient?: {
    id?: number
    number?: string
  }
}

export class USDAClientError extends Error {
  readonly status: number

  constructor(message: string, status: number) {
    super(message)
    this.name = 'USDAClientError'
    this.status = status
  }
}

export interface USDAQuery {
  query: string
  page: number
  pageSize: number
}

export async function searchUSDAFoods(
  input: USDAQuery,
  apiKey: string,
  fetcher: HTTPFetcher = fetch,
): Promise<USDAProxySearchResponse> {
  const response = await fetcher(buildSearchURL(), {
    method: 'POST',
    headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-Api-Key': apiKey,
    },
    body: JSON.stringify({
      query: input.query,
      dataType: [BRANDED_DATA_TYPE],
      pageNumber: input.page,
      pageSize: input.pageSize,
    }),
    cf: {
      cacheTtl: CACHE_TTL_SECONDS,
      cacheEverything: true,
    },
  })

  if (response.status === 401 || response.status === 403) {
    throw new USDAClientError('USDA search is unavailable right now.', 503)
  }

  if (response.status === 429) {
    throw new USDAClientError('USDA search is temporarily busy. Please try again shortly.', 503)
  }

  if (response.ok === false) {
    throw new USDAClientError('USDA search is unavailable right now.', 503)
  }

  const decoded = (await response.json()) as USDAFoodSearchResponse
  const foods = decoded.foods ?? []
  const results = foods
    .map(makeProxyFoodResult)
    .filter((value): value is USDAProxyFoodResult => value != null)
  const totalHits = decoded.totalHits ?? 0
  const hasMore = input.page < MAX_PAGE && input.page * input.pageSize < totalHits

  return {
    query: input.query,
    page: input.page,
    pageSize: input.pageSize,
    provider: USDA_PROVIDER_NAME,
    results,
    hasMore,
  }
}

export async function fetchUSDAFood(
  fdcId: number,
  apiKey: string,
  fetcher: HTTPFetcher = fetch,
): Promise<USDAProxyFoodResult> {
  const response = await fetcher(buildFoodDetailsURL(fdcId), {
    method: 'GET',
    headers: {
      'Accept': 'application/json',
      'X-Api-Key': apiKey,
    },
    cf: {
      cacheTtl: CACHE_TTL_SECONDS,
      cacheEverything: true,
    },
  })

  if (response.status === 401 || response.status === 403) {
    throw new USDAClientError('USDA food details are unavailable right now.', 503)
  }

  if (response.status === 404) {
    throw new USDAClientError('USDA food not found.', 404)
  }

  if (response.status === 429) {
    throw new USDAClientError('USDA food details are temporarily busy. Please try again shortly.', 503)
  }

  if (response.ok === false) {
    throw new USDAClientError('USDA food details are unavailable right now.', 503)
  }

  const decoded = (await response.json()) as USDAFoodDetails
  const result = makeProxyFoodResult(decoded)
  if (result == null) {
    throw new USDAClientError('USDA food details are unavailable right now.', 503)
  }

  return result
}

function buildSearchURL(): string {
  return USDA_SEARCH_URL
}

function buildFoodDetailsURL(fdcId: number): string {
  return `${USDA_FOOD_DETAILS_URL}/${fdcId}`
}

type USDAFood = USDASearchFood | USDAFoodDetails
type USDAFoodNutrient = USDASearchFoodNutrient | USDAFoodDetailsNutrient

function makeProxyFoodResult(food: USDAFood): USDAProxyFoodResult | null {
  const fdcId = food.fdcId
  const name = food.description?.trim()
  const servingDescription = makeServingDescription(food)
  const nutrientValues = nutrientValueMap(food)
  const calories = nutrientValues.get(NUTRIENT_IDS.calories) ?? null
  const protein = nutrientValues.get(NUTRIENT_IDS.protein) ?? null
  const fat = nutrientValues.get(NUTRIENT_IDS.fat) ?? null
  const carbs = nutrientValues.get(NUTRIENT_IDS.carbs) ?? null
  const saturatedFat = nutrientValues.get(NUTRIENT_IDS.saturatedFat) ?? null
  const fiber = nutrientValues.get(NUTRIENT_IDS.fiber) ?? null
  const sugars = nutrientValues.get(NUTRIENT_IDS.sugars) ?? null
  const addedSugars = nutrientValues.get(NUTRIENT_IDS.addedSugars) ?? null
  const sodium = nutrientValues.get(NUTRIENT_IDS.sodium) ?? null
  const cholesterol = nutrientValues.get(NUTRIENT_IDS.cholesterol) ?? null

  if (fdcId == null || Number.isFinite(fdcId) === false) {
    return null
  }

  if (name == null || name.length === 0) {
    return null
  }

  if ([calories, protein, fat, carbs].some((value) => value == null)) {
    return null
  }

  const safeCalories = calories!
  const safeProtein = protein!
  const safeFat = fat!
  const safeCarbs = carbs!

  return {
    id: `usda:${fdcId}`,
    fdcId,
    name,
    brand: firstNonEmpty(food.brandOwner, food.brandName),
    servingDescription,
    gramsPerServing: gramsPerServing(food),
    caloriesPerServing: safeCalories,
    proteinPerServing: safeProtein,
    fatPerServing: safeFat,
    carbsPerServing: safeCarbs,
    saturatedFatPerServing: saturatedFat ?? undefined,
    fiberPerServing: fiber ?? undefined,
    sugarsPerServing: sugars ?? undefined,
    addedSugarsPerServing: addedSugars ?? undefined,
    sodiumPerServing: sodium ?? undefined,
    cholesterolPerServing: cholesterol ?? undefined,
    sourceName: USDA_PROVIDER_NAME,
    sourceURL: `https://fdc.nal.usda.gov/food-details/${fdcId}`,
    barcode: normalizedText(food.gtinUpc),
  }
}

function makeServingDescription(food: USDAFood): string {
  const householdServing = normalizedText(food.householdServingFullText)
  if (householdServing != null) {
    return householdServing
  }

  const servingSize = food.servingSize
  const servingSizeUnit = normalizedText(food.servingSizeUnit)
  if (typeof servingSize === 'number' && Number.isFinite(servingSize) && servingSize > 0 && servingSizeUnit != null) {
    return `${roundForDisplay(servingSize)} ${servingSizeUnit}`
  }

  return '1 serving'
}

function gramsPerServing(food: USDAFood): number | undefined {
  const servingSize = food.servingSize
  const servingSizeUnit = normalizedText(food.servingSizeUnit)?.toLowerCase()
  if (typeof servingSize !== 'number' || Number.isFinite(servingSize) === false || servingSize <= 0) {
    return undefined
  }

  if (servingSizeUnit === 'g' || servingSizeUnit === 'gram' || servingSizeUnit === 'grams') {
    return servingSize
  }

  return undefined
}

function normalizedText(value: string | undefined): string | undefined {
  const trimmed = value?.trim()
  return trimmed == null || trimmed.length === 0 ? undefined : trimmed
}

function firstNonEmpty(...values: Array<string | undefined>): string | undefined {
  return values.map(normalizedText).find((value) => value != null)
}

function roundForDisplay(value: number): string {
  return Math.abs(Math.round(value) - value) < 0.01 ? String(Math.round(value)) : value.toFixed(1)
}

function nutrientValueMap(food: USDAFood): Map<number, number> {
  const values = new Map<number, number>()

  for (const nutrient of food.foodNutrients ?? []) {
    const nutrientId = nutrientID(nutrient)
    const value = nutrientValue(nutrient)
    if (typeof nutrientId !== 'number' || Number.isFinite(nutrientId) === false) {
      continue
    }

    if (typeof value !== 'number' || Number.isFinite(value) === false) {
      continue
    }

    values.set(nutrientId, value)
  }

  return values
}

function nutrientID(nutrient: USDAFoodNutrient): number | undefined {
  if (isUSDAFoodDetailsNutrient(nutrient)) {
    const value = nutrient.nutrient?.id
    return typeof value === 'number' && Number.isFinite(value) ? value : undefined
  }

  return nutrient.nutrientId
}

function nutrientValue(nutrient: USDAFoodNutrient): number | undefined {
  const value = isUSDAFoodDetailsNutrient(nutrient) ? nutrient.amount : nutrient.value
  return typeof value === 'number' && Number.isFinite(value) ? value : undefined
}

function isUSDAFoodDetailsNutrient(nutrient: USDAFoodNutrient): nutrient is USDAFoodDetailsNutrient {
  return 'nutrient' in nutrient
}
