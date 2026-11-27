import type { FoodNutrition, FoodSource, NormalizedFood, ReviewNutrient } from '../foodSearchTypes'
import { normalizedSearchText } from '../searchText'
import {
  chainEntries,
  type ChainEntry,
  type MenuRow,
} from './restaurantMenuData'

const PAGE_SIZE = 20
const STOP_WORDS = new Set(['a', 'an', 'and', 'the', 'of', 'with', 'w', 'on', 'in', 'at'])

interface MenuRecord {
  chain: ChainEntry
  row: MenuRow
  position: number
  nameTokens: string[]
  isComponent: boolean
}

// "Chick-fil-A", "chik fil a" and "chickfila" collapse to one compact key;
// a trailing "s" is dropped so "McDonald's", "mcdonalds" and "mcdonald" agree.
function compactKey(words: string[]): string {
  return words.join('').replace(/s$/, '')
}

// Applied to query and menu words alike, so only consistency matters: "sandwiches", "fries" and "nuggets" fold to one form.
function singular(token: string): string {
  if (token.length <= 3) return token
  if (/(?:ch|sh|x|ss|z)es$/.test(token)) return token.slice(0, -2)
  if (token.endsWith('ies')) return `${token.slice(0, -3)}y`

  return token.endsWith('s') && !token.endsWith('ss') ? token.slice(0, -1) : token
}

function words(value: string): string[] {
  return normalizedSearchText(value, { removeApostrophes: true })
    .split(' ')
    .filter((word) => word.length > 0)
}

function contentTokens(value: string): string[] {
  return words(value)
    .filter((word) => !STOP_WORDS.has(word))
    .map(singular)
}

const chainByKey = new Map<string, ChainEntry>()

for (const chain of chainEntries) {
  chainByKey.set(compactKey(words(chain.menu.chain)), chain)
  for (const alias of chain.aliases) chainByKey.set(alias, chain)
}

const records: MenuRecord[] = []
const postings = new Map<string, number[]>()

function addPosting(token: string, position: number): void {
  const list = postings.get(token)

  if (list == null) postings.set(token, [position])
  else if (list[list.length - 1] !== position) list.push(position)
}

for (const chain of chainEntries) {
  chain.menu.items.forEach((row, rowIndex) => {
    const position = records.length
    const nameTokens = contentTokens(row[0])

    records.push({
      chain,
      row,
      position,
      nameTokens,
      isComponent: rowIndex < (chain.menu.components ?? 0),
    })

    // The serving text carries sizes such as "Grande"; adjacent-pair keys let
    // "bigmac" find "Big Mac".
    const tokens = new Set([...nameTokens, ...contentTokens(row[1])])
    for (const token of tokens) {
      addPosting(token, position)
      // Branded compounds such as "McNuggets" should also answer to the plain word.
      if (/^mc.{4,}/.test(token)) addPosting(token.slice(2), position)
    }
    for (let i = 0; i + 1 < nameTokens.length; i += 1) addPosting(nameTokens[i]! + nameTokens[i + 1]!, position)
  })
}

export const restaurantMenuCounts: Record<string, number> = Object.fromEntries(
  chainEntries.map((chain) => [chain.menu.chain, chain.menu.items.length]),
)

interface ParsedQuery {
  chain: ChainEntry | undefined
  tokens: string[]
}

function parseQuery(query: string): ParsedQuery {
  const queryWords = words(query)

  for (let start = 0; start < queryWords.length; start += 1) {
    for (let size = Math.min(3, queryWords.length - start); size >= 1; size -= 1) {
      const chain = chainByKey.get(compactKey(queryWords.slice(start, start + size)))

      if (chain != null) {
        const rest = [...queryWords.slice(0, start), ...queryWords.slice(start + size)]

        return { chain, tokens: contentTokens(rest.join(' ')) }
      }
    }
  }

  return { chain: undefined, tokens: contentTokens(query) }
}

export function detectRestaurantChain(query: string): string | undefined {
  return parseQuery(query).chain?.id
}

function intersect(tokens: string[], chain: ChainEntry | undefined): number[] {
  const lists = tokens.map((token) => postings.get(token))

  if (lists.some((list) => list == null)) return []

  const sorted = (lists as number[][]).sort((a, b) => a.length - b.length)
  const rest = sorted.slice(1).map((list) => new Set(list))

  return sorted[0]!.filter(
    (position) =>
      (chain == null || records[position]!.chain === chain) &&
      rest.every((set) => set.has(position)),
  )
}

function matches(parsed: ParsedQuery): { positions: number[]; directCount: number } {
  const { chain } = parsed
  const buildWords = new Set(chain?.buildWords ?? [])
  const specific = parsed.tokens.filter((token) => !buildWords.has(token))
  const usedBuildWords = specific.length !== parsed.tokens.length

  // A bare chain name or a single generic word would flood unrelated searches.
  if (chain == null) {
    const positions = specific.length >= 2 ? intersect(specific, undefined) : []

    return { positions, directCount: positions.length }
  }

  const components = records.filter((record) => record.chain === chain && record.isComponent)

  if (specific.length === 0) {
    return { positions: usedBuildWords ? components.map((record) => record.position) : [], directCount: 0 }
  }

  const direct = intersect(specific, chain)

  if (!usedBuildWords || components.length === 0) return { positions: direct, directCount: direct.length }

  // A built meal has no official total, so offer its components after the direct matches.
  const seen = new Set(direct)

  return {
    positions: [...direct, ...components.map((record) => record.position).filter((p) => !seen.has(p))],
    directCount: direct.length,
  }
}

function rankMatches(positions: number[], parsed: ParsedQuery, directCount: number): number[] {
  const phrase = parsed.tokens.join(' ')

  const scored = positions.map((position, order) => {
    const record = records[position]!
    const name = record.nameTokens.join(' ')

    const direct = order < directCount

    return {
      position,
      order,
      direct,
      score: direct && name.includes(phrase) ? 1 : 0,
      length: direct ? record.nameTokens.length : 0,
    }
  })

  // Direct matches sort by closeness; appended components keep the chain's own order.
  return scored
    .sort((a, b) => Number(b.direct) - Number(a.direct) || b.score - a.score || a.length - b.length || a.order - b.order)
    .map((entry) => entry.position)
}

const REVIEW_FIELDS: Array<[ReviewNutrient, number]> = [
  ['calories', 3],
  ['protein', 4],
  ['carbs', 5],
  ['fat', 6],
]

function toNormalizedFood(record: MenuRecord): NormalizedFood {
  const { chain, row } = record
  const [name, serving, grams, calories, protein, carbs, fat, saturatedFat, fiber, sugars, sodium, cholesterol] = row
  const id = `restaurant:${normalizedSearchText(chain.menu.chain)}:${normalizedSearchText(name)}:${normalizedSearchText(serving)}`

  const nutrition: FoodNutrition = {}
  const values = { calories, protein, carbs, fat, saturatedFat, fiber, sugars, sodium, cholesterol }

  for (const [key, value] of Object.entries(values)) {
    if (value != null) nutrition[key as keyof FoodNutrition] = value
  }

  return {
    id,
    source: 'restaurantMenus',
    externalProductID: id,
    sourceName: chain.menu.sourceName,
    sourceURL: row[12] ?? chain.menu.sourceURL,
    retrievedAt: chain.menu.retrievedAt,
    name,
    brand: chain.menu.chain,
    servingDescription: serving,
    ...(grams != null ? { gramsPerServing: grams } : {}),
    nutrition,
    requiredReviewNutrients: REVIEW_FIELDS.filter(([, index]) => row[index] == null).map(([nutrient]) => nutrient),
  }
}

export function createRestaurantMenusSource(): FoodSource {
  return {
    id: 'restaurantMenus',
    cacheable: false,
    async search(query, cursor) {
      const parsed = parseQuery(query)
      const { positions, directCount } = matches(parsed)
      const ranked = rankMatches(positions, parsed, directCount)
      const offset = Number.parseInt(cursor ?? '0', 10) || 0

      return {
        items: ranked.slice(offset, offset + PAGE_SIZE).map((position) => toNormalizedFood(records[position]!)),
        nextCursor: offset + PAGE_SIZE < ranked.length ? String(offset + PAGE_SIZE) : null,
      }
    },
  }
}
