// [name, serving, gramsPerServing, calories, protein, carbs, fat, saturatedFat, fiber, sugars, sodium, cholesterol, itemSourceURL?]
// null means the chain's official table gives no exact number; it is never estimated.
export type MenuRow = readonly [
  name: string,
  serving: string,
  grams: number | null,
  calories: number | null,
  protein: number | null,
  carbs: number | null,
  fat: number | null,
  saturatedFat: number | null,
  fiber: number | null,
  sugars: number | null,
  sodium: number | null,
  cholesterol: number | null,
  sourceURL?: string,
]

export interface ChainMenu {
  chain: string
  sourceName: string
  sourceURL: string
  retrievedAt: string
  /** The first N items are build-your-own components (no bundled totals exist). */
  components?: number
  items: readonly MenuRow[]
}
