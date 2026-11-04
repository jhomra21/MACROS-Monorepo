// Local-only E2E observation boundary. Stop this process to make the Debug base URL unreachable.
// No fixtures or fabricated successes: every successful response comes from the deployed Worker.
import { appendFile } from 'node:fs/promises'

const upstream = 'https://cal-macro-tracker-usda-proxy.jhonra121.workers.dev'

const logPath = process.env.SEARCH_EVIDENCE_LOG ?? '/tmp/macros-unified-typing.jsonl'

Bun.serve({
  hostname: '127.0.0.1',
  port: 8799,
  async fetch(request) {
    const url = new URL(request.url)
    const start = Date.now()
    const response = await fetch(new URL(url.pathname + url.search, upstream))
    const body = await response.text()
    const payload = JSON.parse(body)
    const counts: Record<string, number> = {}

    for (const item of payload.results ?? []) counts[item.source] = (counts[item.source] ?? 0) + 1

    const record = {
      query: url.searchParams.get('q'),
      path: url.pathname,
      status: response.status,
      milliseconds: Date.now() - start,
      upstreamCalls: JSON.parse(response.headers.get('X-MACROS-Upstream-Calls') ?? '{}'),
      skipped: response.headers.get('X-MACROS-Skipped-Sources'),
      contributions: counts,
    }

    await appendFile(logPath, JSON.stringify(record) + '\n')

    return new Response(body, { status: response.status, headers: response.headers })
  },
})

console.info('Search observation gateway listening on 127.0.0.1:8799')
