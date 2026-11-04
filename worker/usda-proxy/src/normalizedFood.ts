import type { FoodNutrition, NormalizedFood, ReviewNutrient } from './foodSearchTypes'
import type {
  OpenFoodFactsProxyNutriments,
  OpenFoodFactsProxyProduct,
  USDAProxyFoodResult,
} from './types'

const required: ReviewNutrient[] = ['calories', 'protein', 'fat', 'carbs']

const offNutrients = {
  calories: 'energy-kcal',
  protein: 'proteins',
  fat: 'fat',
  carbs: 'carbohydrates',
  saturatedFat: 'saturated-fat',
  fiber: 'fiber',
  sugars: 'sugars',
  addedSugars: 'added-sugars',
  sodium: 'sodium',
  cholesterol: 'cholesterol',
} as const

const nutrientKeys = [
  'calories',
  'protein',
  'fat',
  'carbs',
  'saturatedFat',
  'fiber',
  'sugars',
  'addedSugars',
  'sodium',
  'cholesterol',
] as const

const text = (value: string | undefined) => value?.trim() || undefined

const usable = (value: number | undefined): number | undefined =>
  value != null && Number.isFinite(value) && value >= 0 ? value : undefined

function offValue(
  n: OpenFoodFactsProxyNutriments,
  key: keyof typeof offNutrients,
  basis: 'serving' | '100g',
): number | undefined {
  const value = usable(n[`${offNutrients[key]}_${basis}`])

  if (key === 'sodium') {
    const grams =
      value ?? (usable(n[`salt_${basis}`]) != null ? n[`salt_${basis}`]! / 2.5 : undefined)

    return grams == null ? undefined : grams * 1000
  }

  return key === 'cholesterol' && value != null ? value * 1000 : value
}

export function normalizeOpenFoodFactsFood(
  product: OpenFoodFactsProxyProduct,
): NormalizedFood | null {
  const name = text(product.product_name)

  if (name == null) return null
  const basis = offBasis(product)
  const nutrition = offNutrition(product.nutriments ?? {}, basis)
  const barcode = text(product.code)

  const canonicalBarcode =
    barcode?.length === 13 && barcode.startsWith('0') ? barcode.slice(1) : barcode

  const externalProductID =
    text(product.externalProductID) ??
    `openfoodfacts:${canonicalBarcode ?? text(product.url) ?? name}`

  return {
    id: externalProductID,
    source: 'openFoodFacts',
    externalProductID,
    sourceName: 'Open Food Facts',
    sourceURL:
      text(product.url) ??
      (barcode != null ? `https://world.openfoodfacts.org/product/${barcode}` : undefined),
    name,
    brand: text(product.brands),
    barcode,
    servingDescription: basis.servingDescription,
    gramsPerServing: basis.gramsPerServing,
    nutrition,
    requiredReviewNutrients: required.filter((key) => nutrition[key] == null),
  }
}

function offBasis(product: OpenFoodFactsProxyProduct) {
  const n = product.nutriments ?? {}

  const knownGrams =
    product.serving_quantity_unit?.toLowerCase() === 'g' && (product.serving_quantity ?? 0) > 0
      ? usable(product.serving_quantity)
      : undefined

  const completeServing = required.every((key) => offValue(n, key, 'serving') != null)
  const hasServing = nutrientKeys.some((key) => offValue(n, key, 'serving') != null)
  const has100g = nutrientKeys.some((key) => offValue(n, key, '100g') != null)
  const servingBasis = completeServing || (knownGrams == null && hasServing && !has100g)

  const gramsPerServing =
    servingBasis || knownGrams != null ? knownGrams : has100g ? 100 : undefined

  const servingDescription =
    servingBasis || knownGrams != null
      ? (text(product.serving_size) ?? (knownGrams != null ? `${knownGrams} g` : '1 serving'))
      : has100g
        ? '100 g'
        : '1 serving'

  return { servingBasis, knownGrams, gramsPerServing, servingDescription }
}

function offNutrition(
  n: OpenFoodFactsProxyNutriments,
  basis: ReturnType<typeof offBasis>,
): FoodNutrition {
  const nutrition: FoodNutrition = {}

  for (const key of nutrientKeys) {
    const serving = offValue(n, key, 'serving')
    const per100g = offValue(n, key, '100g')

    const value =
      basis.servingBasis || basis.knownGrams != null
        ? (serving ??
          (per100g != null && basis.knownGrams != null
            ? (per100g * basis.knownGrams) / 100
            : undefined))
        : per100g

    if (value != null) nutrition[key] = value
  }

  return nutrition
}

type USDANutritionField = 'caloriesPerServing' | 'proteinPerServing' | 'fatPerServing' | 'carbsPerServing'

type USDASourceFood = Omit<USDAProxyFoodResult, USDANutritionField | 'fdcId'> & Partial<Pick<USDAProxyFoodResult, USDANutritionField>>

export function normalizeUSDAFood(food: USDASourceFood): NormalizedFood {
  const grams = usable(food.gramsPerServing)
  const knownGrams = grams != null && grams > 0 ? grams : undefined
  const multiplier = (knownGrams ?? 100) / 100
  const nutrition: FoodNutrition = {}

  for (const key of nutrientKeys) {
    const value = usable(food[`${key}PerServing`])

    if (value != null) nutrition[key] = value * multiplier
  }

  return {
    id: food.id,
    source: 'usda',
    externalProductID: food.id,
    sourceName: food.sourceName,
    sourceURL: food.sourceURL,
    name: food.name,
    brand: food.brand,
    barcode: food.barcode,
    servingDescription: knownGrams != null ? food.servingDescription : '100 g',
    gramsPerServing: knownGrams ?? 100,
    nutrition,
    requiredReviewNutrients: required.filter((key) => nutrition[key] == null),
  }
}
