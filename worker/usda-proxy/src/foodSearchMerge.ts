import type { NormalizedFood } from './foodSearchTypes'
import { normalizedSearchText, searchTokens } from './searchText'
import { fingerprint } from './foodSearchCursor'

function gtin(barcode: string | undefined): string | undefined {
  return barcode != null && /^(?:\d{8}|\d{12}|\d{13}|\d{14})$/.test(barcode)
    ? barcode.padStart(14, '0')
    : undefined
}

function rank(food: NormalizedFood, query: string): number[] {
  const name = normalizedSearchText(food.name)
  const normalizedQuery = normalizedSearchText(query)
  const tokens = searchTokens(query)
  const fields = normalizedSearchText(`${food.name} ${food.brand ?? ''}`)

  return [
    gtin(food.barcode) != null && gtin(food.barcode) === gtin(query) ? 1 : 0,
    name === normalizedQuery ? 1 : 0,
    name.startsWith(normalizedQuery) ? 1 : 0,
    name.includes(normalizedQuery) ? 1 : 0,
    tokens.filter((token) => fields.includes(token)).length,
    4 - food.requiredReviewNutrients.length,
  ]
}

export async function mergeFoodResults(items: NormalizedFood[], query: string, seen: string[]) {
  const ranked = items.map((item) => ({ item, rank: rank(item, query) }))
  ranked.sort((a, b) => {
    for (let i = 0; i < a.rank.length; i += 1) {
      if (a.rank[i] !== b.rank[i]) return b.rank[i]! - a.rank[i]!
    }

    return a.item.id < b.item.id ? -1 : a.item.id === b.item.id ? 0 : 1
  })
  const emitted = new Set(seen)

  const identities = await Promise.all(
    ranked.map(async ({ item }) => {
      const barcode = gtin(item.barcode)

      const text = JSON.stringify([
        normalizedSearchText(item.name),
        normalizedSearchText(item.brand ?? ''),
      ])

      const [barcodeKey, textKey, anyBarcodeKey] = await Promise.all([
        fingerprint(`g:${barcode}`),
        fingerprint(`t:${text}`),
        fingerprint(`a:${text}`),
      ])

      return {
        barcode,
        barcodeKey: barcodeKey.slice(0, 16),
        textKey: textKey.slice(0, 16),
        anyBarcodeKey: anyBarcodeKey.slice(0, 16),
      }
    }),
  )

  const results: NormalizedFood[] = []

  for (let i = 0; i < ranked.length; i += 1) {
    const keys = identities[i]!

    const duplicate =
      keys.barcode != null
        ? emitted.has(keys.barcodeKey) || emitted.has(keys.textKey)
        : emitted.has(keys.textKey) || emitted.has(keys.anyBarcodeKey)

    if (duplicate) continue
    results.push(ranked[i]!.item)

    if (keys.barcode != null) {
      emitted.add(keys.barcodeKey)
      emitted.add(keys.anyBarcodeKey)
    } else {
      emitted.add(keys.textKey)
    }
  }

  return { results, seen: [...emitted] }
}
