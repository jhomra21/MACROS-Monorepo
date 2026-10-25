import type { HTTPFetcher } from './types'

// Per attempt, not per search: preserve OFF fallback/retry and restaurant budgets.
export const REQUEST_TIMEOUT_MS = 2_500

export function withTimeout(
  fetcher: HTTPFetcher,
  timeoutMs = REQUEST_TIMEOUT_MS,
  deadlineSignal?: AbortSignal,
): HTTPFetcher {
  return async (input, init) => {
    const timeoutSignal = AbortSignal.timeout(timeoutMs)
    const incomingSignal = init?.signal ?? (input instanceof Request ? input.signal : undefined)

    const signals = [timeoutSignal, deadlineSignal, incomingSignal].filter(
      (signal): signal is AbortSignal => signal != null,
    )

    const signal = signals.length === 1 ? signals[0] : AbortSignal.any(signals)
    const response = await awaitWithAbort(fetcher(input, { ...init, signal }), signal)
    // Consume the body under the same deadline, before returning to JSON decoding.
    const body = await awaitWithAbort(response.arrayBuffer(), signal)

    return new Response(response.body == null ? null : body, {
      status: response.status,
      statusText: response.statusText,
      headers: response.headers,
    })
  }
}

function awaitWithAbort<Value>(operation: Promise<Value>, signal: AbortSignal): Promise<Value> {
  if (signal.aborted) {
    return Promise.reject(signal.reason)
  }

  return new Promise((resolve, reject) => {
    const cleanup = () => signal.removeEventListener('abort', abort)

    const abort = () => {
      cleanup()
      reject(signal.reason)
    }

    signal.addEventListener('abort', abort, { once: true })
    operation.then(
      (value) => {
        cleanup()
        resolve(value)
      },
      (error: Error) => {
        cleanup()
        reject(error)
      },
    )
  })
}
