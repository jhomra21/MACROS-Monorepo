import type { HTTPFetcher } from './types'

// Per attempt, not per search: preserve OFF fallback/retry and restaurant budgets.
export const REQUEST_TIMEOUT_MS = 2_500

export function withTimeout(fetcher: HTTPFetcher, timeoutMs = REQUEST_TIMEOUT_MS): HTTPFetcher {
  return async (input, init) => {
    const timeoutSignal = AbortSignal.timeout(timeoutMs)
    const incomingSignal = init?.signal ?? (input instanceof Request ? input.signal : undefined)
    const signal = incomingSignal == null ? timeoutSignal : AbortSignal.any([incomingSignal, timeoutSignal])
    const response = await fetcher(input, { ...init, signal })
    // Consume the body under the same deadline, before returning to JSON decoding.
    const body = await response.arrayBuffer()

    return new Response(response.body == null ? null : body, {
      status: response.status,
      statusText: response.statusText,
      headers: response.headers,
    })
  }
}
