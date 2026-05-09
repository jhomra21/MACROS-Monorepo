import type {
  HTTPFetcher,
  OpenFoodFactsProxyNutriments,
  OpenFoodFactsProxyProduct,
  ProviderPage,
} from './types'

const OPEN_FOOD_FACTS_LEGACY_SEARCH_URL = 'https://world.openfoodfacts.org/cgi/search.pl'
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
    headers: openFoodFactsHeaders(options),
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
