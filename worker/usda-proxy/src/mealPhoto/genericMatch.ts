import { genericFoodRows, type GenericFoodRow } from './genericFoodData'
import { normalizedSearchText } from '../searchText'

export interface GenericMatchQuery {
  genericName: string | null
  name: string
  preparation: string | null
}

export interface GenericNutritionPer100g {
  calories: number
  protein: number
  carbs: number
  fat: number
  saturatedFat?: number
  fiber?: number
  sugars?: number
  sodium?: number
  cholesterol?: number
}

export interface GenericMatch {
  source: 'usdaFNDDS'
  fdcId: number
  description: string
  per100g: GenericNutritionPer100g
}

const MAX_QUERY_TOKENS = 12
const MIN_COVERAGE = 0.5
// A first-segment head such as "Fish" or "Chicken" is too broad to pick a food on its own.
const BROAD_HEAD_POSTINGS = 60

const STOP_WORDS = new Set(['a', 'an', 'and', 'the', 'of', 'with', 'w', 'on', 'in', 'at', 'for', 'from', 'or', 'as', 'to', 'ns', 'nfs', 'without'])
const CONNECTORS = new Set(['with', 'w', 'in', 'on', 'and', 'of', 'from', 'for', 'or'])
const JUNK_WORDS = new Set(['school', 'restaurant'])

// Cooking words a query may use, mapped to the FNDDS words that satisfy them.
const ACCEPTED_COOKING: Record<string, readonly string[]> = {
  raw: ['raw'],
  cooked: ['cooked', 'boiled', 'steamed'],
  grilled: ['grilled', 'broiled'],
  broiled: ['grilled', 'broiled'],
  baked: ['baked', 'roasted', 'broiled'],
  roasted: ['roasted', 'baked', 'broiled'],
  fried: ['fried'],
  sauteed: ['fried', 'sauteed', 'cooked'],
  steamed: ['steamed', 'cooked', 'boiled'],
  boiled: ['boiled', 'cooked'],
  poached: ['poached', 'boiled', 'cooked'],
  stewed: ['stewed', 'cooked'],
  smoked: ['smoked'],
  canned: ['canned'],
  dried: ['dried'],
  frozen: ['frozen'],
  pickled: ['pickled'],
  braised: ['braised', 'cooked'],
  toasted: ['toasted'],
}
// Preservation methods describe the product, not how it was prepared at home, so they never conflict with a cooking word.
const PRESERVATION_WORDS = new Set(['smoked', 'canned', 'dried', 'frozen', 'pickled'])
const COOKING_WORDS = new Set([...Object.keys(ACCEPTED_COOKING), ...Object.values(ACCEPTED_COOKING).flat()])

const FOLDED_PLURALS = new Set(['cookies', 'brownies', 'smoothies', 'veggies'])

// Applied to query and FNDDS words alike, so only consistency matters.
function singular(token: string): string {
  if (token.length <= 3) return token
  if (FOLDED_PLURALS.has(token)) return token.slice(0, -1)
  if (/(?:ch|sh|x|ss|z|o)es$/.test(token)) return token.slice(0, -2)
  if (token.endsWith('ies')) return `${token.slice(0, -3)}y`
  return token.endsWith('s') && !token.endsWith('ss') ? token.slice(0, -1) : token
}

function words(value: string): string[] {
  return normalizedSearchText(value, { removeApostrophes: true }).split(' ').filter((word) => word.length > 0)
}

function contentTokens(value: string): string[] {
  return words(value).filter((word) => !STOP_WORDS.has(word)).map(singular)
}

interface Candidate {
  row: GenericFoodRow
  tokens: Set<string>
  /** Tokens of the first comma segment: the food itself rather than its qualifiers. */
  core: Set<string>
  bigrams: Set<string>
  cooking: string[]
  processed: boolean
  produce: boolean
  junk: boolean
}

// WWEIA fruit (not dried), vegetable and vegetable-on-sandwich categories.
function isProduce(category: number): boolean {
  return (category >= 6002 && category <= 6024 && category !== 6016) || (category >= 6402 && category <= 6420) || category === 6489
}

function bigramsOf(ordered: string[]): Set<string> {
  const pairs = new Set<string>()
  for (let i = 0; i + 1 < ordered.length; i += 1) {
    // Cooking words are rewarded separately and sit at different positions across FNDDS names.
    if (!COOKING_WORDS.has(ordered[i]!) && !COOKING_WORDS.has(ordered[i + 1]!)) pairs.add(`${ordered[i]} ${ordered[i + 1]}`)
  }
  return pairs
}

const candidates: Candidate[] = []
// Token -> candidates whose first two comma segments contain it. Built once at module load.
const postings = new Map<string, number[]>()

genericFoodRows.forEach((row, position) => {
  const ordered = contentTokens(row[1])
  const tokens = new Set(ordered)
  candidates.push({
    row,
    tokens,
    core: new Set(contentTokens(row[1].split(',')[0]!)),
    bigrams: bigramsOf(ordered),
    cooking: [...tokens].filter((token) => COOKING_WORDS.has(token) && !PRESERVATION_WORDS.has(token)),
    processed: [...tokens].some((token) => PRESERVATION_WORDS.has(token)),
    produce: isProduce(row[2]),
    junk: [...tokens].some((token) => JUNK_WORDS.has(token)),
  })
  for (const token of new Set(contentTokens(row[1].split(',').slice(0, 2).join(' ')))) {
    const list = postings.get(token)
    if (list == null) postings.set(token, [position])
    else list.push(position)
  }
})

export const genericFoodCount = candidates.length

function headOf(segment: string): string[] {
  const all = words(segment)
  const connector = all.findIndex((word, index) => index > 0 && CONNECTORS.has(word))
  const phrase = (connector < 0 ? all : all.slice(0, connector)).filter((word) => !STOP_WORDS.has(word)).map(singular)
  // Walk back from the last word: "lemon wedge" has no "wedge" food but does have "lemon".
  return phrase.reverse().filter((token) => !COOKING_WORDS.has(token))
}

function queryHeads(text: string): string[] {
  const segments = text.split(',').slice(0, 2)
  const heads: string[] = []
  segments.forEach((segment, index) => {
    const known = headOf(segment).find((token) => postings.has(token))
    if (known == null) return
    if (index === 0 || (heads.length > 0 && (postings.get(heads[0]!)?.length ?? 0) > BROAD_HEAD_POSTINGS)) heads.push(known)
  })
  return heads
}

function acceptedCooking(tokens: string[]): Set<string> {
  const accepted = new Set<string>()
  for (const token of tokens) for (const word of ACCEPTED_COOKING[token] ?? []) accepted.add(word)
  return accepted
}

function score(candidate: Candidate, query: Set<string>, queryBigrams: Set<string>, accepted: Set<string>, heads: string[]): number | null {
  let matched = 0
  for (const token of query) {
    // "grilled" is satisfied by FNDDS's "baked or broiled"; only the cooking family has to agree.
    const cookingMatch = ACCEPTED_COOKING[token]?.some((word) => candidate.tokens.has(word)) === true
    if (candidate.tokens.has(token) || cookingMatch) matched += 1
  }
  const coverage = matched / query.size
  if (coverage < MIN_COVERAGE) return null

  let extras = 0
  for (const token of candidate.tokens) {
    if (query.has(token) || COOKING_WORDS.has(token)) continue
    // An unrequested word in the food's own name ("Broccoli raab") changes the food more than a qualifier does.
    extras += candidate.core.has(token) ? 4 : 1
  }
  let phrases = 0
  for (const pair of queryBigrams) if (candidate.bigrams.has(pair)) phrases += 1

  // "Bacon, cooked" should not land on "Beef, bacon": the head noun belongs in the food's own name.
  const headInCore = heads.length > 0 && heads.some((head) => candidate.core.has(head))
  let value = 8 * coverage - 0.3 * extras + phrases + (headInCore ? 2 : 0)
  if (accepted.size > 0) {
    if (candidate.cooking.some((word) => accepted.has(word))) value += candidate.cooking.some((word) => query.has(word)) ? 3 : 2
    else if (candidate.cooking.length > 0) value -= 2
  } else if (candidate.produce) {
    if (candidate.cooking.includes('raw')) value += 2
    else if (candidate.cooking.length > 0 || candidate.processed) value -= 1
  }
  if (candidate.junk && ![...query].some((token) => JUNK_WORDS.has(token))) value -= 1.5
  return value
}

function matchText(rawText: string, preparation: string | null): Candidate | null {
  // Model text may carry markup, parenthetical asides and quantities that are not part of the food's name.
  const text = rawText.replace(/<[^>]*>|\([^)]*\)/g, ' ')
  const tokens = contentTokens(text).filter((token) => !/^\d+$/.test(token)).slice(0, MAX_QUERY_TOKENS)
  if (tokens.length === 0) return null
  const heads = queryHeads(text)
  const pool = new Set<number>()
  for (const head of heads) for (const position of postings.get(head) ?? []) pool.add(position)
  if (pool.size === 0) return null

  const query = new Set(tokens)
  const queryBigrams = bigramsOf(tokens)
  const accepted = acceptedCooking([...tokens, ...(preparation == null ? [] : contentTokens(preparation))])
  let best: Candidate | null = null
  let bestScore = -Infinity
  for (const position of pool) {
    const candidate = candidates[position]!
    const value = score(candidate, query, queryBigrams, accepted, heads)
    // Strict ">" keeps the lowest fdcId on ties, so results are deterministic.
    if (value != null && value > bestScore) {
      best = candidate
      bestScore = value
    }
  }
  return best
}

function toMatch(candidate: Candidate): GenericMatch {
  const [fdcId, description, , calories, protein, carbs, fat, saturatedFat, fiber, sugars, sodium, cholesterol] = candidate.row
  const optional = { saturatedFat, fiber, sugars, sodium, cholesterol }
  const per100g: GenericNutritionPer100g = { calories, protein, carbs, fat }
  for (const [key, value] of Object.entries(optional)) {
    if (value != null) per100g[key as keyof typeof optional] = value
  }
  return { source: 'usdaFNDDS', fdcId, description, per100g }
}

/** Deterministic generic-food match: the model's USDA-style name first, then its plain name. */
export function matchGenericFood(query: GenericMatchQuery): GenericMatch | null {
  for (const text of [query.genericName, query.name]) {
    if (text == null) continue
    const candidate = matchText(text, query.preparation)
    if (candidate != null) return toMatch(candidate)
  }
  return null
}
