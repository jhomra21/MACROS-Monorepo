# Local runtime QA

Dev-only tests of the original auth, food proxy and web worker entries, bundled
with esbuild and executed in Miniflare/workerd through native Node HTTP on
ephemeral loopback ports. Node 22.18+ is required for native TypeScript execution.
Bun manages dependencies and scripts; Bun's undici shim cannot enforce
`MockAgent.disableNetConnect`, so the HTTP runner itself must use Node.

```sh
cd tools/runtime-qa && bun install --frozen-lockfile
cd ../.. && make qa-network
```

`make qa-network` also runs the separately registered Convex integration suite
(`convex-backend`: `bun run test:integration`). Install its dev dependencies with
`bun install --frozen-lockfile` first. No Convex deployment, remote profile or JWT
gateway is exercised. `convex/_qa/sharing.integration.ts` uses a multi-dot
basename, which Convex excludes from production function discovery.

Run `bun run test:response-contract` from this directory to check the shared
HTTP response reader against deliberately broken loopback responses. It proves
that raw error evidence, required results, and required OFF items cannot be
hidden by parsing fallbacks, while empty redirects and nullable barcodes remain
valid.

The HTTP suite verifies auth hashing/JWKS/claims and unusable bootstrap rejection,
food normalization/cache/error recovery, header/body deadlines with delayed and
indefinitely stalled fixtures, and web forms/errors against original D1 migration
SQL. All upstream requests are mocked or host-checked; unmatched network requests
are denied. RSA keys and tokens stay in memory. Resources and fixture timers are
disposed even after failed assertions. Findings fail the invocation.


Deadline checks assert the exact controlled failure status/payload, per-attempt
upstream call count, and same-route recovery. The harness cannot observe
`Request.signal` abort events across Miniflare's `outboundService` boundary, so
it does not claim to verify that event directly. Sanitized elapsed milliseconds
are diagnostics only, not a product latency SLA or benchmark; the separate
12-second native HTTP guard still fails a stuck route.
Sanitized JSON and log reports default to `build/runtime-qa/`. Set
`QA_OUTPUT_DIR` to another path **inside the repository's ignored `build/`**.
For isolated diagnosis, `QA_SECTION=deadlines` skips malformed-bootstrap checks;
`QA_SECTION=auth-deadline` also skips food deadlines. `QA_DEADLINE_PATH` selects a
single food route, and `QA_PHASE=headers|body|hang-headers|hang-body` selects its
fixture phase. Default invocation runs every contract.

Food routes have an 8-second total upstream deadline, threaded through each
fetch. Ordinary food attempts remain capped at 2.5 seconds, while bootstrap
keeps its existing 2.5-second deadline. Restaurant legacy requests are capped
at 4 seconds, with at most 3 attempts across 3 pages, and scanning stops when
less than 1.5 seconds remain. The harness has a separate 12-second client guard
to fail a stuck route, not to simulate the production deadline.
