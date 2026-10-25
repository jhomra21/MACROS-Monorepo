import { describe, expect, it, mock } from 'bun:test'
import { withTimeout } from '../src/http'

describe('withTimeout', () => {
  it('does not start fetch for a pre-aborted signal or emit an unhandled rejection', async () => {
    const onUnhandledRejection = mock(() => undefined)
    process.on('unhandledRejection', onUnhandledRejection)
    const fetchMock = mock(async () => Response.json({}))

    try {
      await expect(withTimeout(fetchMock, 1_000, AbortSignal.abort(new Error('aborted')))(
        'https://example.test',
      )).rejects.toThrow('aborted')
      await new Promise((resolve) => setTimeout(resolve, 0))

      expect(fetchMock).not.toHaveBeenCalled()
      expect(onUnhandledRejection).not.toHaveBeenCalled()
    } finally {
      process.off('unhandledRejection', onUnhandledRejection)
    }
  })
})
