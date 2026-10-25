# Services Hardening Implementation Tracker (WS1)

Branch `launch/ws1-services-hardening`. TypeScript only; no Xcode. Read `AGENTS.md`, `README.md`, `worker/usda-proxy/`, `worker/auth/`, `convex-backend/convex/_generated/ai/guidelines.md` (mandatory before Convex edits), `web/src/worker.ts`, and `implementation-trackers/launch-program-tracker.md`.

## Shared Understanding

- Three public services sit in front of the app: the packaged-food Worker (`worker/usda-proxy`), the sharing auth Worker (`worker/auth`), and the Convex sharing backend (`convex-backend`). The Astro site (`web/`) exposes two POST APIs backed by D1.
- Today none of them limit request volume. The USDA key is capped upstream at 1,000 requests/hour, so a single abusive client can disable USDA fallback for everyone. Convex bootstrap accepts any well-formed new profile. Support and waitlist forms accept unlimited writes.
- The app-facing contracts (`GET /v1/packaged-foods/search`, `GET /v1/packaged-foods/barcodes/:barcode`, `GET /v1/usda/search`, auth token route, invite redirect, Convex function signatures) must not change shape. The iOS app is not part of this workstream.

## Core Decisions

### Rate limiting at the edge

- Use the Cloudflare Workers Rate Limiting binding. Verify the current config key against `node_modules/wrangler/config-schema.json` in each package (top-level `ratelimits` array with `name`, `namespace_id`, `simple: { limit, period }`; `period` must be 10 or 60). If the installed Wrangler only supports the `unsafe.bindings` form, use that and note it.
- Client key: `cf-connecting-ip` request header. Fall back to a constant key when absent (local dev).
- Limits (per key, per 60 s): search 30, barcode 60, USDA direct search 10, auth token exchange 10, support form 5, waitlist form 5.
- Global USDA budget: a single SQLite-backed Durable Object named `usda` enforces a fixed 60-second window and limit 14 (about 840/hour, under the 1,000/hour key quota). On a binding failure, fail open and emit a sampled log; on budget exhaustion, skip USDA and do not cache a degraded empty result.
- On a per-client limit hit respond `429` with `Retry-After: 60` and the existing JSON error shape from `src/http.ts` / `jsonError`.
- Dependency injection: the handlers receive the limiter through `env`; tests inject a fake `{ limit: async () => ({ success }) }` so no Cloudflare runtime is needed.

### Total request deadline and retry budgets (usda-proxy)

- Add a per-request deadline of 8,000 ms created once in the route handler (`AbortSignal.timeout`) and threaded into every upstream fetch through the existing `withTimeout` fetcher (`src/http.ts` already composes signals with `AbortSignal.any`). When the deadline fires, return what has been collected so far or the existing unavailable response.
- Restaurant legacy scan budget in `src/packagedFoods.ts`: `RESTAURANT_LEGACY_MAX_PAGE_SCAN` 6 to 3, `RESTAURANT_LEGACY_MAX_ATTEMPTS` 6 to 3, `RESTAURANT_LEGACY_REQUEST_TIMEOUT_MS` 6,000 to 4,000. Stop scanning once the deadline has under 1,500 ms left.
- Keep the 2,500 ms per-attempt timeout and the Search-a-licious then legacy ordering. Keep cache keys and TTL unchanged.

### Convex quotas

- Add a `profileQuotas` table keyed by `(profileId, dayKey)` with counters for `invitesCreated`, `snapshotUpserts`, `displayNameUpdates`. Enforce in the mutations in `convex/sharing.ts`: invites 20/day, snapshot upserts 200/day, display-name updates 20/day. Over-quota throws a `ConvexError` with a stable code the Swift client surfaces as a generic failure (no Swift change required; verify `SharingRemoteClient.swift` maps unknown errors to the banner).
- Bootstrap (`convex/bootstrap.ts` via the auth Worker) stays unlimited at the Convex layer; the Worker limits it per IP.
- Follow `convex/_generated/ai/guidelines.md` for validators, indexes, and function syntax.

### Website forms

- Rate limit `/api/support` and `/api/waitlist` in `web/src/worker.ts` with the same binding pattern. Add a hidden honeypot field (`website`) to both forms; a filled honeypot returns the normal success response without writing.
- Document retention in the privacy page (WS8 owns copy): support and waitlist rows kept 12 months. Do not add cron pruning in this workstream.

### Observability

- Lower `head_sampling_rate` for logs and traces from `1` to `0.1` in all three `wrangler.jsonc` files. Keep `invocation_logs` as is.

## Proposed File Shape

- `worker/usda-proxy/wrangler.jsonc` — rate limit bindings.
- `worker/usda-proxy/src/rateLimit.ts` — `clientKey(request)`, `enforce(limiter, key)` returning a `Response | null`.
- `worker/usda-proxy/src/index.ts` — apply limiters, create the deadline signal, pass it down.
- `worker/usda-proxy/src/packagedFoods.ts`, `src/restaurantSearch.ts`, `src/usda.ts` — accept the deadline signal, apply the USDA budget gate, new restaurant constants.
- `worker/usda-proxy/tests/*.test.ts` — limiter, budget, deadline tests.
- `worker/auth/wrangler.jsonc`, `worker/auth/src/index.ts` — limiter on the token route.
- `convex-backend/convex/schema.ts`, `convex/sharing.ts`, `convex/quotas.ts` (helper), tests under the existing test layout.
- `web/wrangler.jsonc`, `web/src/worker.ts`, `web/src/pages/support.astro`, `web/src/pages/index.astro` (honeypot input only).

## Milestones and Tasks

### Milestone 1 — Failure list and tests first

- Write `worker/usda-proxy/tests/hardening.test.ts` cases before code: limit exceeded returns 429 with Retry-After; limit ok passes through; USDA budget exhausted skips USDA and still returns OFF results; deadline expiry returns partial/unavailable within 8.5 s; restaurant scan stops at 3 pages / 3 attempts; missing `cf-connecting-ip` uses fallback key.
- Convex: tests for quota increment, quota exceeded, day rollover reset.
- Web: tests (or runtime-qa cases) for 429 and honeypot.

### Milestone 2 — usda-proxy

- Bindings, `rateLimit.ts`, handler wiring, deadline threading, restaurant budget constants, USDA budget gate.

### Milestone 3 — auth Worker and Convex quotas

### Milestone 4 — Website forms and sampling

### Milestone 5 — Validation and docs

- `bun run check` + `bun test` in `worker/usda-proxy`, `worker/auth`, `convex-backend`, `web`; `make lint-js`; `make qa-network` (install `tools/runtime-qa` deps first; Node 22.18+).
- Update `README.md` service sections briefly (limits, deadline). Changes-log entry.
- Do not deploy. Report the exact `wrangler deploy` and `convex deploy` commands the owner must run, and any dashboard steps (none expected).

## Edge Cases

- Local `wrangler dev` without a Rate Limiting binding must still run: guard for `env.X_RATE_LIMITER === undefined` and treat as allow.
- Cached responses (`caches.open("usda-proxy")`) should be served before the limiter is charged for search and barcode routes, so repeat queries stay cheap.
- `429` must not be cached.

## Validation Plan

- All package checks green; `make qa-network` green; a short `build/ws1-qa-<date>/QA.md` with the limiter behavior exercised against `wrangler dev` (loopback), including a 31st request in a minute returning 429.

## Open Questions / Blockers

- Rate Limiting binding availability on the account's plan (free plan supports it). If `wrangler dev` rejects the binding locally, note the fallback used.

## Status log — WS1 review remediation (2026-10-25)

- Replaced the approximate per-location USDA budget with the `UsdaBudget` SQLite Durable Object; added route-level rate-limit/cache checks, fail-open coverage, configurable deadlines, and degraded-response cache protection.
- Added bounded quota-row cleanup during sharing-profile deletion and documented the remaining iOS 429 handling as a WS7 follow-up.
- Validated all package checks, Wrangler type generation, runtime Miniflare integration, Convex integrations, and a local Wrangler loopback budget run; no deployment was performed.
