import type {
  HTTPFetcher,
  OpenFoodFactsProxyNutriments,
  OpenFoodFactsProxyProduct,
  ProviderPage,
} from './types'
import { matchesSearchTokens, normalizedSearchText, searchTokens } from './searchText'

const OPEN_FOOD_FACTS_LEGACY_SEARCH_URLS = [
  'https://world.openfoodfacts.net/cgi/search.pl',
  'https://world.openfoodfacts.org/cgi/search.pl',
]
const OPEN_FOOD_FACTS_SEARCH_A_LICIOUS_URL = 'https://search.openfoodfacts.org/search'
const OPEN_FOOD_FACTS_PRODUCT_URLS = [
  'https://world.openfoodfacts.org/api/v2/product',
  'https://world.openfoodfacts.net/api/v2/product',
]
const SEARCH_FIELDS = [
  '_id',
  'code',
  'product_name',
  'brands',
  'serving_size',
  'serving_quantity',
  'serving_quantity_unit',
  'quantity',
  'url',
  'nutriments',
].join(',')

interface OpenFoodFactsSearchResponse {
  count?: number
  products?: OpenFoodFactsRawProduct[]
}

interface OpenFoodFactsSearchALiciousResponse {
  hits?: unknown[]
  page?: number
  page_size?: number
  page_count?: number
  count?: number
  timed_out?: boolean
}

interface OpenFoodFactsRawPage {
  totalCount: number
  products: OpenFoodFactsProxyProduct[]
}

interface OpenFoodFactsRawProduct {
  _id?: string
  code?: string
  product_name?: string
  brands?: string | string[]
  serving_size?: string
  serving_quantity?: number
  serving_quantity_unit?: string
  quantity?: string
  nutriments?: OpenFoodFactsProxyNutriments
  url?: string
}

interface OpenFoodFactsProductResponse {
  product?: OpenFoodFactsRawProduct
}

export class OpenFoodFactsClientError extends Error {
  readonly status: number
  readonly retryable: boolean
  readonly retryAfterMs?: number

  constructor(message: string, status: number, retryable: boolean, retryAfterMs?: number) {
    super(message)
    this.name = 'OpenFoodFactsClientError'
    this.status = status
    this.retryable = retryable
    this.retryAfterMs = retryAfterMs
  }
}

export interface OpenFoodFactsQuery {
  query: string
  page: number
  pageSize: number
}

export interface OpenFoodFactsRequestOptions {
  userAgent: string
}

export function normalizedOpenFoodFactsBarcode(value: string): string | null {
  const barcode = trimmedText(value)
  return barcode != null && /^\d+$/.test(barcode) ? barcode : null
}

export async function searchOpenFoodFactsSearchALiciousFoods(
  input: OpenFoodFactsQuery,
  options: OpenFoodFactsRequestOptions,
  fetcher: HTTPFetcher = fetch,
): Promise<ProviderPage<OpenFoodFactsProxyProduct>> {
  const requestedPage = Math.max(1, input.page)
  const requestedPageSize = Math.max(1, input.pageSize)
  const response = await fetcher(buildSearchALiciousURL({
    query: input.query,
    page: requestedPage,
    pageSize: requestedPageSize,
  }), {
    headers: openFoodFactsHeaders(options),
  })

  assertOpenFoodFactsResponseOK(response)

  const decoded = (await response.json()) as OpenFoodFactsSearchALiciousResponse
  const rawProducts = (decoded.hits ?? []).filter(isOpenFoodFactsRawProduct)
  const products = usableMatchingUniqueProducts(
    rawProducts.map(makeProxyProduct),
    input.query,
  )
  if (decoded.timed_out === true && products.length === 0) {
    throw new OpenFoodFactsClientError('Open Food Facts is unavailable right now.', 503, true)
  }

  return {
    query: input.query,
    page: requestedPage,
    pageSize: requestedPageSize,
    results: products,
    hasMore: (decoded.page_count ?? 0) > requestedPage,
  }
}

export async function fetchOpenFoodFactsProduct(
  barcode: string,
  options: OpenFoodFactsRequestOptions,
  fetcher: HTTPFetcher = fetch,
): Promise<OpenFoodFactsProxyProduct> {
  let lastRetryableError: OpenFoodFactsClientError | null = null
  let sawProductResponse = false

  for (const barcodeAlias of barcodeAliases(barcode)) {
    for (const productURL of OPEN_FOOD_FACTS_PRODUCT_URLS) {
      let response: Response

      try {
        response = await fetcher(`${productURL}/${barcodeAlias}.json`, {
          headers: openFoodFactsHeaders(options),
        })
        assertOpenFoodFactsResponseOK(response)
      } catch (error) {
        const normalizedError = normalizeOpenFoodFactsError(error)
        if (normalizedError != null && normalizedError.retryable) {
          lastRetryableError = normalizedError
          continue
        }

        throw error
      }

      sawProductResponse = true
      const decoded = (await response.json()) as OpenFoodFactsProductResponse
      if (decoded.product != null) {
        return makeProxyProduct(decoded.product)
      }

      break
    }
  }

  if (sawProductResponse === false && lastRetryableError != null) {
    throw lastRetryableError
  }

  throw new OpenFoodFactsClientError('No product was found for that barcode.', 404, false)
}

export async function searchOpenFoodFactsLegacyFoods(
  input: OpenFoodFactsQuery,
  options: OpenFoodFactsRequestOptions,
  fetcher: HTTPFetcher = fetch,
): Promise<ProviderPage<OpenFoodFactsProxyProduct>> {
  return searchOpenFoodFactsLegacyFoodsWithMatcher(input, options, fetcher, usableMatchingUniqueProducts)
}

export async function searchOpenFoodFactsLegacyRestaurantFoods(
  input: OpenFoodFactsQuery,
  options: OpenFoodFactsRequestOptions,
  fetcher: HTTPFetcher = fetch,
): Promise<ProviderPage<OpenFoodFactsProxyProduct>> {
  return searchOpenFoodFactsLegacyFoodsWithMatcher(input, options, fetcher, usableRestaurantUniqueProducts)
}

async function searchOpenFoodFactsLegacyFoodsWithMatcher(
  input: OpenFoodFactsQuery,
  options: OpenFoodFactsRequestOptions,
  fetcher: HTTPFetcher,
  productMatcher: (products: OpenFoodFactsProxyProduct[], query: string) => OpenFoodFactsProxyProduct[],
): Promise<ProviderPage<OpenFoodFactsProxyProduct>> {
  const requestedPage = Math.max(1, input.page)
  const requestedPageSize = Math.max(1, input.pageSize)

  const rawPage = await fetchOpenFoodFactsPage(
    {
      query: input.query,
      page: requestedPage,
      pageSize: requestedPageSize,
    },
    options,
    fetcher,
    productMatcher,
  )

  return {
    query: input.query,
    page: requestedPage,
    pageSize: requestedPageSize,
    results: rawPage.products,
    hasMore: requestedPage < pageCount(rawPage.totalCount, requestedPageSize),
  }
}

async function fetchOpenFoodFactsPage(
  input: OpenFoodFactsQuery,
  options: OpenFoodFactsRequestOptions,
  fetcher: HTTPFetcher,
  productMatcher: (products: OpenFoodFactsProxyProduct[], query: string) => OpenFoodFactsProxyProduct[],
): Promise<OpenFoodFactsRawPage> {
  let lastRetryableError: OpenFoodFactsClientError | null = null

  for (const searchURL of OPEN_FOOD_FACTS_LEGACY_SEARCH_URLS) {
    let response: Response

    try {
      response = await fetcher(buildSearchURL(input, searchURL), {
        headers: openFoodFactsHeaders(options),
      })
      assertOpenFoodFactsResponseOK(response)
    } catch (error) {
      const normalizedError = normalizeOpenFoodFactsError(error)
      if (normalizedError != null && normalizedError.retryable) {
        lastRetryableError = normalizedError
        continue
      }

      throw error
    }

    const decoded = (await response.json()) as OpenFoodFactsSearchResponse
    return {
      totalCount: decoded.count ?? 0,
      products: productMatcher((decoded.products ?? []).map(makeProxyProduct), input.query),
    }
  }

  throw lastRetryableError ?? new OpenFoodFactsClientError('Open Food Facts is unavailable right now.', 503, true)
}

function buildSearchURL(input: OpenFoodFactsQuery, searchURL: string): string {
  const url = new URL(searchURL)
  url.searchParams.set('search_terms', input.query)
  url.searchParams.set('search_simple', '1')
  url.searchParams.set('action', 'process')
  url.searchParams.set('json', '1')
  url.searchParams.set('fields', SEARCH_FIELDS)
  url.searchParams.set('page', String(input.page))
  url.searchParams.set('page_size', String(input.pageSize))
  return url.toString()
}

function assertOpenFoodFactsResponseOK(response: Response): void {
  if (response.status === 429) {
    throw new OpenFoodFactsClientError(
      'Open Food Facts is temporarily busy. Please try again shortly.',
      503,
      true,
      retryAfterMs(response),
    )
  }

  if (response.ok === false) {
    const retryable = response.status >= 500
    throw new OpenFoodFactsClientError(
      'Open Food Facts is unavailable right now.',
      503,
      retryable,
      retryAfterMs(response),
    )
  }
}

export function normalizeOpenFoodFactsError(error: unknown): OpenFoodFactsClientError | null {
  if (error instanceof OpenFoodFactsClientError) {
    return error
  }

  if (error instanceof DOMException || error instanceof TypeError) {
    return new OpenFoodFactsClientError('Open Food Facts is unavailable right now.', 503, true)
  }

  return null
}

function openFoodFactsHeaders(options: OpenFoodFactsRequestOptions): HeadersInit {
  return {
    Accept: 'application/json',
    'User-Agent': options.userAgent,
    'X-User-Agent': options.userAgent,
  }
}

function buildSearchALiciousURL(input: OpenFoodFactsQuery): string {
  const url = new URL(OPEN_FOOD_FACTS_SEARCH_A_LICIOUS_URL)
  url.searchParams.set('q', input.query)
  url.searchParams.set('page', String(input.page))
  url.searchParams.set('page_size', String(input.pageSize))
  url.searchParams.set('fields', SEARCH_FIELDS)
  url.searchParams.set('langs', 'en')
  return url.toString()
}

function pageCount(totalCount: number, pageSize: number): number {
  if (totalCount <= 0 || pageSize <= 0) {
    return 0
  }

  return Math.ceil(totalCount / pageSize)
}

function makeProxyProduct(product: OpenFoodFactsRawProduct): OpenFoodFactsProxyProduct {
  return {
    externalProductID: makeExternalProductID(product),
    code: trimmedText(product.code),
    product_name: trimmedText(product.product_name),
    brands: trimmedText(joinText(product.brands)),
    serving_size: trimmedText(product.serving_size),
    serving_quantity: product.serving_quantity,
    serving_quantity_unit: trimmedText(product.serving_quantity_unit),
    quantity: trimmedText(product.quantity),
    nutriments: product.nutriments,
    url: trimmedText(product.url),
  }
}

function usableMatchingUniqueProducts(products: OpenFoodFactsProxyProduct[], query: string): OpenFoodFactsProxyProduct[] {
  const nutritionallyCompleteProducts: OpenFoodFactsProxyProduct[] = []
  const nutritionMissingProducts: OpenFoodFactsProxyProduct[] = []
  const seen = new Set<string>()
  const queryTokens = searchTokens(query, { removeApostrophes: true })

  for (const product of products) {
    const keys = productDeduplicationKeys(product)
    if (keys.some((key) => seen.has(key))) {
      continue
    }

    for (const key of keys) {
      seen.add(key)
    }

    if (hasCompleteMainNutrition(product)) {
      nutritionallyCompleteProducts.push(product)
    } else {
      nutritionMissingProducts.push(product)
    }
  }

  const completeMatches = relevantProducts(nutritionallyCompleteProducts, queryTokens)
  return [
    ...completeMatches,
    ...nameTokenMatches(nutritionMissingProducts, queryTokens),
  ]
}

function usableRestaurantUniqueProducts(products: OpenFoodFactsProxyProduct[], query: string): OpenFoodFactsProxyProduct[] {
  const completeProducts: OpenFoodFactsProxyProduct[] = []
  const incompleteProducts: OpenFoodFactsProxyProduct[] = []
  const seen = new Set<string>()
  const queryTokens = searchTokens(query, { removeApostrophes: true })

  for (const product of products) {
    const keys = productDeduplicationKeys(product)
    if (keys.some((key) => seen.has(key)) || restaurantProductMatches(product, queryTokens) === false) {
      continue
    }

    for (const key of keys) {
      seen.add(key)
    }

    if (hasCompleteMainNutrition(product)) {
      completeProducts.push(product)
    } else {
      incompleteProducts.push(product)
    }
  }

  return [
    ...completeProducts,
    ...incompleteProducts,
  ]
}

function restaurantProductMatches(product: OpenFoodFactsProxyProduct, queryTokens: string[]): boolean {
  const text = normalizedSearchText(
    [product.product_name, product.brands].filter((value): value is string => value != null).join(' '),
    { removeApostrophes: true },
  )
  if (text.length === 0) {
    return false
  }

  if (queryTokens.includes('sauce') === false && RESTAURANT_SIDE_TOKENS.some((token) => text.includes(token))) {
    return false
  }

  const chainTokens = queryTokens.filter((token) => RESTAURANT_CHAIN_TOKEN_ALIASES[token] != null)
  const hasChainMatch = chainTokens.length === 0
    || chainTokens.some((token) => RESTAURANT_CHAIN_TOKEN_ALIASES[token].some((alias) => text.includes(alias)))
  if (hasChainMatch === false) {
    return false
  }

  const menuTokens = queryTokens.filter((token) => RESTAURANT_MENU_TOKEN_ALIASES[token] != null)
  return menuTokens.length === 0
    || menuTokens.some((token) => RESTAURANT_MENU_TOKEN_ALIASES[token].some((alias) => text.includes(alias)))
}

const RESTAURANT_CHAIN_TOKEN_ALIASES: Record<string, string[]> = {
  arbys: ['arbys'],
  canes: ['raising canes', 'raising cane'],
  checkers: ['checkers'],
  chickfila: ['chick fil a', 'chickfila'],
  chipotle: ['chipotle'],
  dominos: ['dominos'],
  dunkin: ['dunkin'],
  five: ['five guys'],
  guys: ['five guys'],
  in: ['in n out', 'in out', 'in and out'],
  king: ['burger king'],
  mcdonalds: ['mcdonalds', 'mc donalds', 'mcdonald'],
  out: ['in n out', 'in out', 'in and out'],
  popeyes: ['popeyes'],
  shack: ['shake shack'],
  shake: ['shake shack'],
  starbucks: ['starbucks'],
  subway: ['subway'],
  bell: ['taco bell'],
  wendys: ['wendys', 'wendy'],
  whataburger: ['whataburger'],
  wingstop: ['wingstop'],
}

const RESTAURANT_MENU_TOKEN_ALIASES: Record<string, string[]> = {
  alfredo: ['alfredo'],
  baconator: ['baconator'],
  bagel: ['bagel'],
  bigmac: ['big mac'],
  blizzard: ['blizzard'],
  bowl: ['bowl'],
  burger: ['burger', 'baconator', 'whopper', 'hamburger', 'cheeseburger', 'mcdouble', 'daves', 'double stack'],
  burrito: ['burrito'],
  cheeseburger: ['cheeseburger', 'burger'],
  chicken: ['chicken', 'mcnugget', 'nugget', 'tender'],
  coffee: ['coffee'],
  combo: ['combo', 'meal'],
  donut: ['donut'],
  donuts: ['donut'],
  fries: ['fries', 'fry'],
  fry: ['fries', 'fry'],
  mcflurry: ['mcflurry'],
  nugget: ['nugget', 'mcnugget'],
  nuggets: ['nugget', 'mcnugget'],
  pasta: ['pasta'],
  pizza: ['pizza'],
  ramen: ['ramen'],
  salad: ['salad'],
  sandwich: ['sandwich', 'burger', 'po boy'],
  shake: ['shake'],
  smoothie: ['smoothie'],
  sub: ['sub', 'sandwich'],
  taco: ['taco'],
  tender: ['tender', 'chicken'],
  tenders: ['tender', 'chicken'],
  whopper: ['whopper'],
  wings: ['wing'],
  wing: ['wing'],
  wrap: ['wrap'],
}

const RESTAURANT_SIDE_TOKENS = ['sauce', 'dressing', 'dip']

function hasCompleteMainNutrition(product: OpenFoodFactsProxyProduct): boolean {
  const nutriments = product.nutriments
  if (nutriments == null) {
    return false
  }

  return hasFiniteNumbers(
    nutriments['energy-kcal_serving'],
    nutriments.proteins_serving,
    nutriments.fat_serving,
    nutriments.carbohydrates_serving,
  ) || hasFiniteNumbers(
    nutriments['energy-kcal_100g'],
    nutriments.proteins_100g,
    nutriments.fat_100g,
    nutriments.carbohydrates_100g,
  )
}

function hasFiniteNumbers(...values: unknown[]): boolean {
  return values.every((value) => typeof value === 'number' && Number.isFinite(value))
}

function relevantProducts(products: OpenFoodFactsProxyProduct[], queryTokens: string[]): OpenFoodFactsProxyProduct[] {
  return products.filter((product) => matchesSearchTokens([product.product_name, product.brands], queryTokens, { removeApostrophes: true }))
}

function nameTokenMatches(products: OpenFoodFactsProxyProduct[], queryTokens: string[]): OpenFoodFactsProxyProduct[] {
  if (queryTokens.length === 0) {
    return []
  }

  return products.filter((product) => matchesSearchTokens([product.product_name], queryTokens, { removeApostrophes: true }))
}

function productDeduplicationKeys(product: OpenFoodFactsProxyProduct): string[] {
  const keys: string[] = []
  const identifier = product.code ?? product.externalProductID
  if (identifier != null) {
    keys.push(`id:${identifier.toLowerCase()}`)
  }

  keys.push([
    'text',
    normalizedKeyPart(product.product_name),
    normalizedKeyPart(product.brands),
    normalizedKeyPart(product.serving_size ?? product.quantity),
    nutritionKeyPart(product),
  ].join('|'))

  return keys
}

function normalizedKeyPart(value: string | undefined): string {
  return normalizedSearchText(value ?? '')
}

function nutritionKeyPart(product: OpenFoodFactsProxyProduct): string {
  const nutriments = product.nutriments
  if (nutriments == null) {
    return ''
  }

  return [
    nutriments['energy-kcal_serving'] ?? nutriments['energy-kcal_100g'],
    nutriments.proteins_serving ?? nutriments.proteins_100g,
    nutriments.fat_serving ?? nutriments.fat_100g,
    nutriments.carbohydrates_serving ?? nutriments.carbohydrates_100g,
  ].map((value) => typeof value === 'number' && Number.isFinite(value) ? value.toFixed(3) : '').join(':')
}

function isOpenFoodFactsRawProduct(value: unknown): value is OpenFoodFactsRawProduct {
  return value != null && typeof value === 'object'
}

function joinText(value: string | string[] | undefined): string | undefined {
  return Array.isArray(value) ? value.join(', ') : value
}

function makeExternalProductID(product: OpenFoodFactsRawProduct): string | undefined {
  const identifier = barcodeAliases(product.code)[0] ?? trimmedText(product._id)
  return identifier == null ? undefined : `openfoodfacts:${identifier}`
}

function trimmedText(value: string | undefined): string | undefined {
  if (value == null) {
    return undefined
  }

  const trimmedValue = value.trim()
  return trimmedValue.length > 0 ? trimmedValue : undefined
}

function barcodeAliases(value: string | undefined): string[] {
  const barcode = trimmedText(value)
  if (barcode == null) {
    return []
  }

  if (/^\d+$/.test(barcode)) {
    if (barcode.length === 12) {
      return [barcode, `0${barcode}`]
    }

    if (barcode.length === 13 && barcode.startsWith('0')) {
      return [barcode.slice(1), barcode]
    }
  }

  return [barcode]
}

function retryAfterMs(response: Response): number | undefined {
  const headerValue = response.headers.get('Retry-After')
  if (headerValue == null) {
    return undefined
  }

  const seconds = Number.parseFloat(headerValue)
  if (Number.isFinite(seconds) && seconds >= 0) {
    return Math.round(seconds * 1000)
  }

  const timestamp = Date.parse(headerValue)
  if (Number.isNaN(timestamp)) {
    return undefined
  }

  return Math.max(0, timestamp - Date.now())
}
