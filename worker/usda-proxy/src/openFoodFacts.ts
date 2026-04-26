import type {
  HTTPFetcher,
  OpenFoodFactsProxyNutriments,
  OpenFoodFactsProxyProduct,
  ProviderPage,
} from './types'

const OPEN_FOOD_FACTS_SEARCH_URL = 'https://world.openfoodfacts.org/cgi/search.pl'
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

interface OpenFoodFactsRawPage {
  totalCount: number
  products: OpenFoodFactsProxyProduct[]
}

interface OpenFoodFactsRawProduct {
  _id?: string
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
  requestBudget?: OpenFoodFactsRequestBudget
}

export async function searchOpenFoodFactsFoods(
  input: OpenFoodFactsQuery,
  options: OpenFoodFactsRequestOptions,
  fetcher: HTTPFetcher = fetch,
): Promise<ProviderPage<OpenFoodFactsProxyProduct>> {
  const requestedPage = Math.max(1, input.page)
  const requestedPageSize = Math.max(1, input.pageSize)
  const requestedResultCount = requestedPage * requestedPageSize
  const collectedProducts: OpenFoodFactsProxyProduct[] = []

  let currentRawPage = 1
  let rawPageCount = 1

  while (currentRawPage <= rawPageCount && collectedProducts.length < requestedResultCount) {
    if (options.requestBudget != null && options.requestBudget.consume() === false) {
      return partialBudgetResponse(input.query, requestedPage, requestedPageSize, collectedProducts)
    }

    const rawPage = await fetchOpenFoodFactsPage(
      {
        query: input.query,
        page: currentRawPage,
        pageSize: requestedPageSize,
      },
      options,
      fetcher,
    )

    rawPageCount = pageCount(rawPage.totalCount, requestedPageSize)
    collectedProducts.push(...rawPage.products)
    currentRawPage += 1
  }

  const startIndex = (requestedPage - 1) * requestedPageSize
  const endIndex = startIndex + requestedPageSize

  return {
    query: input.query,
    page: requestedPage,
    pageSize: requestedPageSize,
    results: collectedProducts.slice(startIndex, endIndex),
    hasMore: collectedProducts.length > endIndex || currentRawPage <= rawPageCount,
  }
}

export class OpenFoodFactsRequestBudget {
  private requestCount = 0

  constructor(private readonly maxRequests: number) {}

  consume(): boolean {
    if (this.requestCount >= this.maxRequests) {
      return false
    }

    this.requestCount += 1
    return true
  }
}

function partialBudgetResponse(
  query: string,
  requestedPage: number,
  requestedPageSize: number,
  collectedProducts: OpenFoodFactsProxyProduct[],
): ProviderPage<OpenFoodFactsProxyProduct> {
  const startIndex = (requestedPage - 1) * requestedPageSize
  const endIndex = startIndex + requestedPageSize
  const results = collectedProducts.slice(startIndex, endIndex)
  if (results.length === 0) {
    throw new OpenFoodFactsClientError('Open Food Facts request budget was exhausted.', 503, false)
  }

  return {
    query,
    page: requestedPage,
    pageSize: requestedPageSize,
    results,
    hasMore: false,
  }
}

async function fetchOpenFoodFactsPage(
  input: OpenFoodFactsQuery,
  options: OpenFoodFactsRequestOptions,
  fetcher: HTTPFetcher,
): Promise<OpenFoodFactsRawPage> {
  const response = await fetcher(buildSearchURL(input), {
    headers: {
      Accept: 'application/json',
      'User-Agent': options.userAgent,
    },
  })

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

  const decoded = (await response.json()) as OpenFoodFactsSearchResponse
  return {
    totalCount: decoded.count ?? 0,
    products: (decoded.products ?? [])
      .filter(hasUsableNutrition)
      .map(makeProxyProduct),
  }
}

function buildSearchURL(input: OpenFoodFactsQuery): string {
  const url = new URL(OPEN_FOOD_FACTS_SEARCH_URL)
  url.searchParams.set('search_terms', input.query)
  url.searchParams.set('search_simple', '1')
  url.searchParams.set('action', 'process')
  url.searchParams.set('json', '1')
  url.searchParams.set('fields', SEARCH_FIELDS)
  url.searchParams.set('page', String(input.page))
  url.searchParams.set('page_size', String(input.pageSize))
  return url.toString()
}

function hasUsableNutrition(product: OpenFoodFactsRawProduct): boolean {
  const nutriments = product.nutriments ?? {}
  const hasServingNutrition = [
    nutriments['energy-kcal_serving'],
    nutriments['proteins_serving'],
    nutriments['fat_serving'],
    nutriments['carbohydrates_serving'],
  ].every(isFiniteNumber)

  if (hasServingNutrition) {
    return true
  }

  const servingGrams = gramsPerServing(product)
  const hasScaledServingNutrition = servingGrams != null && [
    nutriments['energy-kcal_100g'],
    nutriments['proteins_100g'],
    nutriments['fat_100g'],
    nutriments['carbohydrates_100g'],
  ].every(isFiniteNumber)

  if (hasScaledServingNutrition) {
    return true
  }

  return [
    nutriments['energy-kcal_100g'],
    nutriments['proteins_100g'],
    nutriments['fat_100g'],
    nutriments['carbohydrates_100g'],
  ].every(isFiniteNumber)
}

function gramsPerServing(product: OpenFoodFactsRawProduct): number | undefined {
  const servingQuantity = product.serving_quantity
  const unit = product.serving_quantity_unit?.trim().toLowerCase()
  if (typeof servingQuantity !== 'number' || Number.isFinite(servingQuantity) === false || servingQuantity <= 0) {
    return undefined
  }

  return unit === 'g' ? servingQuantity : undefined
}

function isFiniteNumber(value: number | undefined): value is number {
  return typeof value === 'number' && Number.isFinite(value)
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
    brands: trimmedText(product.brands),
    serving_size: trimmedText(product.serving_size),
    serving_quantity: product.serving_quantity,
    serving_quantity_unit: trimmedText(product.serving_quantity_unit),
    quantity: trimmedText(product.quantity),
    nutriments: product.nutriments,
    url: trimmedText(product.url),
  }
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
