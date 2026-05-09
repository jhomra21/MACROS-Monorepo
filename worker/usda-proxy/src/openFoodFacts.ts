import type {
  HTTPFetcher,
  OpenFoodFactsProxyNutriments,
  OpenFoodFactsProxyProduct,
  ProviderPage,
} from './types'

const OPEN_FOOD_FACTS_LEGACY_SEARCH_URL = 'https://world.openfoodfacts.org/cgi/search.pl'
const OPEN_FOOD_FACTS_SEARCH_A_LICIOUS_URL = 'https://search.openfoodfacts.org/search'
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
    headers: {
      Accept: 'application/json',
      'User-Agent': options.userAgent,
    },
  })

  assertOpenFoodFactsResponseOK(response)

  const decoded = (await response.json()) as OpenFoodFactsSearchALiciousResponse
  const products = (decoded.hits ?? []).filter(isOpenFoodFactsRawProduct).map(makeProxyProduct)
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

export async function searchOpenFoodFactsLegacyFoods(
  input: OpenFoodFactsQuery,
  options: OpenFoodFactsRequestOptions,
  fetcher: HTTPFetcher = fetch,
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
): Promise<OpenFoodFactsRawPage> {
  const response = await fetcher(buildSearchURL(input), {
    headers: {
      Accept: 'application/json',
      'User-Agent': options.userAgent,
    },
  })

  assertOpenFoodFactsResponseOK(response)

  const decoded = (await response.json()) as OpenFoodFactsSearchResponse
  return {
    totalCount: decoded.count ?? 0,
    products: (decoded.products ?? []).map(makeProxyProduct),
  }
}

function buildSearchURL(input: OpenFoodFactsQuery): string {
  const url = new URL(OPEN_FOOD_FACTS_LEGACY_SEARCH_URL)
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
