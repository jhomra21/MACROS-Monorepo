import { z } from 'zod'
import type { HTTPFetcher, USDAProxyFoodResult, USDAProxySearchResponse } from './types'
import { matchesSearchTokens, normalizedSearchText, searchTokens } from './searchText'

const USDA_SEARCH_URL = 'https://api.nal.usda.gov/fdc/v1/foods/search'

const USDA_FOOD_DETAILS_URL = 'https://api.nal.usda.gov/fdc/v1/food'

const USDA_PROVIDER_NAME = 'USDA FoodData Central' as const

const BRANDED_DATA_TYPE = 'Branded'

const MAX_PAGE = 10

const CACHE_TTL_SECONDS = 300

const jsonValueSchema = z.json()

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

const optionalNumber = z.number().optional().catch(undefined)

const optionalString = z.string().optional().catch(undefined)

const searchNutrientSchema = z.object({
  nutrientId: optionalNumber,
  value: optionalNumber,
})

const detailsNutrientSchema = z.object({
  amount: optionalNumber,
  nutrient: z.object({
    id: optionalNumber,
    number: optionalString,
  }).optional().catch(undefined),
})

const searchFoodSchema = z.object({
  fdcId: optionalNumber,
  description: optionalString,
  brandName: optionalString,
  brandOwner: optionalString,
  gtinUpc: optionalString,
  servingSize: optionalNumber,
  servingSizeUnit: optionalString,
  householdServingFullText: optionalString,
  foodNutrients: z.array(searchNutrientSchema).optional().catch(undefined),
})

const detailsFoodSchema = z.object({
  fdcId: optionalNumber,
  description: optionalString,
  brandName: optionalString,
  brandOwner: optionalString,
  gtinUpc: optionalString,
  servingSize: optionalNumber,
  servingSizeUnit: optionalString,
  householdServingFullText: optionalString,
  foodNutrients: z.array(detailsNutrientSchema).optional().catch(undefined),
})

const searchResponseSchema = z.object({
  foods: z.array(z.json()).nullable().optional(),
  totalHits: optionalNumber,
})

type USDASearchFood = z.infer<typeof searchFoodSchema>

type USDAFoodDetails = z.infer<typeof detailsFoodSchema>

type USDASearchFoodNutrient = z.infer<typeof searchNutrientSchema>

type USDAFoodDetailsNutrient = z.infer<typeof detailsNutrientSchema>

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
  allowRequest?: () => Promise<boolean>,
): Promise<USDAProxySearchResponse> {
  let lastResponse: USDAProxySearchResponse | null = null

  for (const query of usdaSearchQueries(input.query, input.page)) {
    if (allowRequest != null && !(await allowRequest())) {
      if (lastResponse != null) {
        return lastResponse
      }

      throw new USDAClientError('USDA search is unavailable right now.', 503)
    }

    const response = await searchUSDAFoodsOnce({ ...input, query }, apiKey, fetcher)

    if (response.results.length > 0 || input.page > 1) {
      return response.query === input.query ? response : { ...response, query: input.query }
    }

    lastResponse = response
  }

  return lastResponse == null || lastResponse.query === input.query
    ? (lastResponse ?? searchUSDAFoodsOnce(input, apiKey, fetcher))
    : { ...lastResponse, query: input.query }
}

async function searchUSDAFoodsOnce(
  input: USDAQuery,
  apiKey: string,
  fetcher: HTTPFetcher,
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

  const decoded = parseSearchResponse(jsonValueSchema.parse(await response.json()))

  const foods = (decoded.foods ?? []).flatMap((food) => {
    const parsed = searchFoodSchema.safeParse(food)

    return parsed.success ? [parsed.data] : []
  })

  const queryTokens = searchTokens(input.query, { removeApostrophes: true })

  const results = foods
    .map(makeProxyFoodResult)
    .filter((value): value is USDAProxyFoodResult => value != null)
    .filter((food) => matchesSearchQuery(food, queryTokens))

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

function parseSearchResponse(payload: z.infer<typeof jsonValueSchema>): z.infer<typeof searchResponseSchema> {
  try {
    return searchResponseSchema.parse(payload)
  } catch {
    throw new USDAClientError('USDA search is unavailable right now.', 503)
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

  const decoded = detailsFoodSchema.parse(await response.json())
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

function usdaSearchQueries(query: string, page: number): string[] {
  if (page > 1) {
    return [query]
  }

  const normalizedQuery = normalizedSearchQuery(query)

  return [...new Set([query, normalizedQuery].filter((value) => value.length > 0))]
}

function normalizedSearchQuery(query: string): string {
  return normalizedSearchText(query, { removeApostrophes: true })
}

function matchesSearchQuery(food: USDAProxyFoodResult, tokens: string[]): boolean {
  return matchesSearchTokens([food.name, food.brand], tokens, { removeApostrophes: true })
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

  const mainNutrition = { calories, protein, fat, carbs }
  const foodData = { fdcId, name, mainNutrition }

  if (!hasRequiredFoodData(foodData)) {
    return null
  }

  return {
    id: `usda:${foodData.fdcId}`,
    fdcId: foodData.fdcId,
    name: foodData.name,
    brand: firstNonEmpty(food.brandOwner, food.brandName),
    servingDescription,
    gramsPerServing: gramsPerServing(food),
    caloriesPerServing: foodData.mainNutrition.calories,
    proteinPerServing: foodData.mainNutrition.protein,
    fatPerServing: foodData.mainNutrition.fat,
    carbsPerServing: foodData.mainNutrition.carbs,
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

function hasRequiredFoodData(foodData: {
  fdcId: number | undefined
  name: string | undefined
  mainNutrition: { calories: number | null; protein: number | null; fat: number | null; carbs: number | null }
}): foodData is {
  fdcId: number
  name: string
  mainNutrition: { calories: number; protein: number; fat: number; carbs: number }
} {
  return foodData.fdcId != null
    && Number.isFinite(foodData.fdcId)
    && foodData.name != null
    && foodData.name.length > 0
    && hasCompleteMainNutrition(foodData.mainNutrition)
}

function hasCompleteMainNutrition(values: {
  calories: number | null
  protein: number | null
  fat: number | null
  carbs: number | null
}): values is { calories: number; protein: number; fat: number; carbs: number } {
  return values.calories != null && values.protein != null && values.fat != null && values.carbs != null
}

function makeServingDescription(food: USDAFood): string {
  const householdServing = normalizedText(food.householdServingFullText)

  if (householdServing != null) {
    return householdServing
  }

  const servingSize = food.servingSize
  const servingSizeUnit = normalizedText(food.servingSizeUnit)

  if (servingSize != null && Number.isFinite(servingSize) && servingSize > 0 && servingSizeUnit != null) {
    return `${roundForDisplay(servingSize)} ${servingSizeUnit}`
  }

  return '1 serving'
}

function gramsPerServing(food: USDAFood): number | undefined {
  const servingSize = food.servingSize
  const servingSizeUnit = normalizedText(food.servingSizeUnit)?.toLowerCase()

  if (servingSize == null || Number.isFinite(servingSize) === false || servingSize <= 0) {
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

    if (nutrientId == null || Number.isFinite(nutrientId) === false) {
      continue
    }

    if (value == null || Number.isFinite(value) === false) {
      continue
    }

    values.set(nutrientId, value)
  }

  return values
}

function nutrientID(nutrient: USDAFoodNutrient): number | undefined {
  if (isUSDAFoodDetailsNutrient(nutrient)) {
    const value = nutrient.nutrient?.id

    return value != null && Number.isFinite(value) ? value : undefined
  }

  return nutrient.nutrientId
}

function nutrientValue(nutrient: USDAFoodNutrient): number | undefined {
  const value = isUSDAFoodDetailsNutrient(nutrient) ? nutrient.amount : nutrient.value

  return value != null && Number.isFinite(value) ? value : undefined
}

function isUSDAFoodDetailsNutrient(nutrient: USDAFoodNutrient): nutrient is USDAFoodDetailsNutrient {
  return 'nutrient' in nutrient
}
