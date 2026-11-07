# Website performance and Cloudflare setup audit

Audited on November 7, 2026, from branch `web/perf`. Measurements and the local Lighthouse comparison used base `2e90865`. The branch was then rebased onto `cd9042f`, which changes only guide copy, AMDR presets, and showcase markup, and validation was repeated. Production (`macros-web`, deployment `8831919b`, created 2026-11-07T04:05Z) was measured as it was; nothing was deployed. The client was this Mac, on a network served by Cloudflare's DFW colo. Raw output is in ignored `build/evidence/2026-11-07-web-perf/`.

## Key numbers before the change

Each curl request opened a new connection: DNS, TCP, TLS 1.3, then the request. "Server" is time to first byte (TTFB) minus TLS completion, so it includes one network round trip of about 27 ms. All responses were HTTP/2 from DFW with `cf-cache-status: HIT`; `alt-svc` advertises HTTP/3.

| Request | TTFB p50 / p95 (ms) | Server p50 / p95 (ms) | ETag |
| --- | --- | --- | --- |
| `/` | 124 / 226 | 61 / 161 | none |
| `/about/`, `/support/`, `/guides/`, guide, `/privacy/` | 116–123 / 124–162 | 55–57 / 60–98 | none |
| CSS, AVIF, `/favicon.svg`, `/sitemap.xml` | 118–120 / 130–151 | 54–57 / 65–77 | yes |
| Control: `/cdn-cgi/trace`, no Worker | 99–101 / 109–157 | 37–39 / 43–51 | n/a |
| www redirect, Worker only | 108–110 / 120–124 | 45–46 / 52–64 | n/a |
| workers.dev redirect, Worker only | 124 / 147–158 | 59–60 / 78–82 | n/a |

The same requests on one reused connection had a server time of 46–54 ms for HTML and 45–49 ms for assets (p50, 10 requests each). Response encoding did not matter: br, zstd, gzip, and identity all landed within 48–56 ms p50.

Every response, including the content-hashed `/_astro/*` files, had `Cache-Control: public, max-age=0, must-revalidate`, the static-assets default.

**Worker.** `wrangler tail` captured 40 of 40 test requests, so CSS, AVIF, the favicon, and the sitemap all invoked the Worker. Each had 5–14 ms wall time and 0–1 ms CPU. GraphQL `workersInvocationsAdaptive` for 2026-10-31T16:00Z to 2026-11-07T16:00Z recorded:

- 4,529 invocations, 0 errors, and 4,218 subrequests (almost all `ASSETS.fetch`).
- CPU time p50 / p90 / p99: 0.48 / 1.38 / 2.66 ms.
- Wall time p50 / p90 / p99: 7.5 / 57.6 / 187.8 ms.

Zone analytics for the last day show most traffic is static files. They also show 1,500+ HTML 404s from scanners and `/cdn-cgi/rum` posts from Web Analytics. The Free plan does not expose edge TTFB fields.

**Lighthouse (production).** These are medians of three runs, Lighthouse 13.6.0, performance category only. Mobile is simulated throttling; desktop uses `--preset=desktop`.

| Page | Mode | Score | FCP | LCP | CLS | TBT | Doc TTFB | Transfer | Requests |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Home | Mobile | 100 | 950 ms | 1,106 ms | 0 | 0 ms | 57 ms | 164.6 KB | 15 |
| Home | Desktop | 100 | 311 ms | 311 ms | 0 | 0 ms | 59 ms | 175.4 KB | 19 |
| Guide | Mobile | 100 | 939 ms | 939 ms | 0 | 0 ms | 51 ms | 26.7 KB | 5 |
| Guide | Desktop | 100 | 296 ms | 299 ms | 0 | 0 ms | 49 ms | 26.7 KB | 5 |

Lighthouse advisories:

- The stylesheet is render-blocking, with an estimated saving of 90–120 ms on mobile.
- The home page has 22 KiB of unused JavaScript in `json.*.js`, which is 90,083 bytes raw and 26.6 KB transferred.
- The Cloudflare Insights beacon adds 10.5 KB and an extra origin. It is the only third party.

## Why some requests take 100 ms and others 200 ms

- **About 100 ms is the floor for a new connection from DFW.** A new connection needs DNS, TCP, and TLS before the request, about three 27 ms round trips plus edge time. The `/cdn-cgi/trace` control, which never reaches the Worker, also took 99–101 ms. A reused connection drops to roughly 40–55 ms.
- **The Worker adds roughly 8 ms at the median and much more at the tail.** Its 7-day wall time reached 58 ms at p90 and 188 ms at p99. Edge-only requests took 37–39 ms server time, a Worker-only redirect 45 ms, and a Worker plus `ASSETS.fetch` 54–61 ms.
- **The 150–235 ms samples happened after the handshake.** In the apex run, 15 of 200 requests took over 150 ms, while their TCP and TLS times were normal (27–35 ms and about 33 ms). Normal handshakes do not rule out the network: the extra time could be on the request's own round trip or inside Cloudflare, and curl cannot separate the two. It fits the Worker's measured wall-time tail (58 ms p90, 188 ms p99), but this run does not prove that cause. One `/privacy/` sample also had a 74 ms TCP connect. `/` had 7 of 20 samples over 150 ms.
- **The first lookup of a hostname adds DNS time.** For example, the first www request took 202 ms.
- **Not the cause:** compression format, cache misses (all requests were HITs), and colo changes (every request went to DFW).

## Findings

1. **Assets ran through the Worker.** `run_worker_first: true` made the Worker run before every request, only so that www and workers.dev could redirect. On Free-plan Workers, matched requests also count toward the daily request limit; past that limit, they get a 429 instead of the asset. [Billing](https://developers.cloudflare.com/workers/static-assets/billing-and-limitations/)
2. **Hashed files revalidated on every use.** Cloudflare's default is `max-age=0, must-revalidate`. Its docs recommend `_headers` with `immutable` for fingerprinted folders. [Headers](https://developers.cloudflare.com/workers/static-assets/headers/)
3. **The stylesheet was render-blocking.** It is 22,981 bytes raw and 5.1 KB brotli, and it is the only render-blocking resource.
4. **Full zod shipped to browsers and the Worker.** `lib/json.ts` imported `zod`'s non-tree-shakable namespace. That produced a 90 KB client chunk for two form scripts, and zod was 782 KB of the 811 KB Worker script.
5. **The compatibility date was 2026-04-15.** The flags that became defaults between then and the local workerd release (2026-10-23) do not touch this Worker's APIs: error serialization, Workflows, Python, TLS options, Durable Objects, `dispatchEvent`, and Node defaults that `nodejs_compat` already enabled. [Flags](https://developers.cloudflare.com/workers/configuration/compatibility-flags/)
6. **CI skipped the Worker tests.** The web job ran `bun run check` only, so `src/worker.test.ts` was never run in CI. The job does not run `build`, which matches the macOS-only Helvetica requirement for OG images.
7. **Web Analytics conflicted with the privacy page (dashboard).** Cloudflare Web Analytics automatic setup injects `static.cloudflareinsights.com/beacon.min.js` into HTML for browser requests. `/privacy/` said, "We do not use analytics SDKs or advertising trackers on the website or in the app." Resolved on `main` (`ae7cbd8`, `84c6e71`): the privacy page now has a "Website analytics" section describing the beacon.
8. **HTML has no ETag (dashboard).** Assets get the documented `ETag`, but HTML gets none, even for non-browser requests. Cloudflare keeps an origin's strong ETag only when Email Obfuscation, Rocket Loader, and Replace insecure JavaScript libraries are all off. [ETags](https://developers.cloudflare.com/cache/reference/etag-headers/) The owner's dashboard (checked by the parent, 2026-11-07) shows **Email Address Obfuscation ON**, which is a documented cause of the drop. Web Analytics HTML injection may also contribute. A real Chromium load of `/`, `/support/`, and `/about/` found no actual rewrite: no `email-decode.min.js`, no `__cf_email__` markup, and the footer address in plain text. Live HTML for non-browser requests also matches `dist` byte for byte. So today the setting costs the ETag but adds no page weight. The impact is small: the browser re-downloads 3–12 KB of compressed HTML instead of getting a 304, at the same round-trip cost.
9. **Ruled out:**
   - Fonts: the site uses system fonts with no downloads.
   - Images: AVIF and WebP with explicit sizes; image-delivery and LCP audits passed.
   - View transitions: CSS-only, with no router script.
   - Smart Placement: not applicable. Assets are always served nearest the visitor, and the only backend is D1 for rare form posts. [Placement](https://developers.cloudflare.com/workers/configuration/placement/)
   - Early Hints: nothing left to hint once the CSS is inlined.
   - Builds: `astro check` reported 0 errors, 0 warnings, and 0 hints. The build has no Vite chunk warnings. Sharp prints a harmless `Fontconfig error: Cannot load default config file` while rendering OG images.
   - Deployments: `wrangler deployments list` shows routine 100% deployments with no failures.
   - CI: the last 20 runs all succeeded.
   - Wrangler: 4.156.0 is pinned; 4.158.0 is available, and it was not upgraded.

## Zone security context (dashboard, parent-verified 2026-11-07)

AI Crawl Control over the last 7 days blocked no crawler, and every crawler request succeeded. The busiest were archive.org_bot (209), Googlebot (73), GPTBot (36), and Applebot (14). Bot Fight Mode, AI Labyrinth, and Hotlink protection are off. Browser Integrity Check is on; its cost is already included in the timings above. Live `robots.txt` is the site's own (allow all, plus the sitemap), not a Cloudflare-managed one. None of these settings is a performance problem. Nothing was changed.

## Guidance checked

- [Cloudflare's Astro guide](https://developers.cloudflare.com/workers/framework-guides/web-apps/astro/) and [Astro's Cloudflare deploy guide](https://docs.astro.build/en/guides/deploy/cloudflare/) say a fully prerendered Astro site needs no `@astrojs/cloudflare` adapter, only `assets.directory`. Use `not_found_handling: "404-page"` for the custom 404. This site follows that. Its Worker exists only for forms, host redirects, and the retention cron.
- [Worker script routing](https://developers.cloudflare.com/workers/static-assets/routing/worker-script/) and the [`run_worker_first` reference](https://developers.cloudflare.com/workers/static-assets/binding/#run_worker_first): assets are served first by default. An array of patterns supports `*` deep globs and `!` negative patterns, and negative patterns win regardless of order.
- [HTML handling](https://developers.cloudflare.com/workers/static-assets/routing/advanced/html-handling/): `force-trailing-slash` gives a 307 from `/about` to `/about/`. This is unchanged.
- [`_redirects`](https://developers.cloudflare.com/workers/static-assets/redirects/) cannot do domain-level redirects. [Custom Domains](https://developers.cloudflare.com/workers/configuration/routing/custom-domains/) recommends a zone redirect rule for www. [Single Redirects](https://developers.cloudflare.com/rules/url-forwarding/single-redirects/) run first in the [Rules execution order](https://developers.cloudflare.com/rules/url-forwarding/#execution-order). See the [www-to-root example](https://developers.cloudflare.com/rules/url-forwarding/examples/redirect-www-to-root/).
- [workers.dev](https://developers.cloudflare.com/workers/configuration/routing/workers-dev/): zone rules cannot apply to it, and Browser Integrity Check always runs there. `workers_dev: false` disables it, but version and preview URLs stay available.
- [Astro `build.inlineStylesheets`](https://docs.astro.build/en/reference/configuration-reference/#buildinlinestylesheets): `'always'` inlines project styles.

## Changes

| Change | Files |
| --- | --- |
| `run_worker_first` lists only existing pages and feeds plus `/api/*`: `["/", "/*/", "/sitemap.xml", "/robots.txt", "/rss.xml", "/api/*", "/media/*"]`, where `/media/*` keeps the demo video's byte-range handling. `not_found_handling` is `"none"`, so every miss reaches the Worker, which redirects www and workers.dev and otherwise serves `404.html` with status 404. Existing static files match no pattern and skip the Worker on every host. See [Missing static files](#missing-static-files-review-follow-up). | `web/wrangler.jsonc`, `web/src/worker.ts` |
| `/_astro/*` and `/social/*` (content-hashed) get `Cache-Control: public, max-age=31536000, immutable`. Existing static files on www and workers.dev get `X-Robots-Tag: noindex`. | `web/public/_headers` |
| `build.inlineStylesheets: 'always'` | `web/astro.config.mjs` |
| Client-shared JSON schemas use `zod/mini`, with identical results on null, object, wrong-type, nested-function, and string inputs. The server's form schemas keep full zod. | `web/src/lib/json.ts` |
| `compatibility_date` set to 2026-10-23, plus `minify: true` and `upload_source_maps: true`. Types regenerated. | `web/wrangler.jsonc`, `web/wrangler.api.jsonc`, `web/worker-configuration.d.ts` |
| Web CI job also runs `bun test src/worker.test.ts`. | `.github/workflows/quality.yml` |

**Local results.** Same machine and method, `wrangler dev`, Lighthouse medians of three runs:

| Page / mode | `origin/main` FCP / LCP / transfer | This branch FCP / LCP / transfer |
| --- | --- | --- |
| Home mobile | 771 / 1,594 ms / 147.5 KB | 618 / 1,437 ms / 129.3 KB |
| Home desktop | 263 / 404 ms / 157.1 KB | 180 / 300 ms / 138.9 KB |
| Guide mobile | 759 / 763 ms / 14.1 KB | 611 / 611 ms / 13.6 KB |
| Guide desktop | 209 / 209 ms / 14.1 KB | 176 / 176 ms / 13.6 KB |

- Scores stayed 100, CLS 0, and TBT 0–4 ms. Local runs have no Web Analytics beacon, so they show 3 guide requests instead of production's 5. A local run cannot show edge latency.
- Inlining was also measured on its own, on top of the other changes. It cut mobile FCP from 754–760 to 611–618 ms and guide mobile LCP from 904 to 611 ms. Each page's HTML grew by about 5.6 KB compressed (home 7.5 to 13.6 KB in Lighthouse). The home page is 11.1 KB at brotli quality 11, which still fits in a typical first send window of about 14.6 KB. Overall first-view transfer was unchanged.
- The client JSON chunk went from 90,083 to 20,516 bytes raw, about 5.8 KB brotli. The Worker upload went from 797 KiB / 129 KiB gzip to 478 KiB / 105 KiB gzip.

**Local routing.** `routing-matrix.sh` ran against three `probe-dev.sh` servers, one per host (`--local-upstream`), serving the real `wrangler.jsonc` and built `dist` with Wrangler 4.156.0. The full matrix is in [Missing static files](#missing-static-files-review-follow-up). localhost returned 200 for pages and files, with the expected `Content-Type` for the sitemap and robots.

**Forms E2E.** `forms-e2e.mjs` ran Playwright against local `wrangler dev` with local D1. The failure list was written first. All 8 checks passed, before and after the missing-file change:

- invalid email disables submit
- a 400 response's `fieldErrors` sets the field's custom validity
- a non-JSON success falls back to the default message
- the real API returns the joined message, then the already-joined message
- server-side support field errors are applied
- support success is shown
- no page or console errors

## Missing static files (review follow-up)

The first version of this branch used `"/*"` with `!/_astro/*`, `!/social/*`, and the icon files as negative patterns, plus `not_found_handling: "404-page"`. Review found two problems, reproduced locally with the matrix below:

- A negative pattern sends a request to the asset router whether or not the file exists, so `/_astro/missing.js`, `/social/missing.png`, `/_astro/`, and `/social/` on www and workers.dev returned 404 instead of a 301 to the apex.
- `_headers` rules match the request path, not the file served. A miss under `/_astro/*` or `/social/*` got the 404 page with `max-age=31536000, immutable`, so a stale page asking for an old file would cache that 404 for a year, even after a rollback restored the file.

### Failure modes, written before the fix

1. A hashed file that exists (`/_astro/*`, `/social/*`) loses `immutable`, or starts invoking the Worker again.
2. A missing hashed file returns the 404 page with `max-age=31536000, immutable`. A browser or shared cache keeps that 404 for a year, so a stale page stays broken even after a rollback brings the file back.
3. A missing file under `/_astro/` or `/social/` on www or workers.dev returns 404 instead of the 301 to the apex that every other unknown path gets.
4. The directory paths `/_astro/` and `/social/` behave differently from other unknown paths.
5. A missing page on the apex stops returning the custom 404 page with status 404 and `noindex`, or returns 200.
6. A browser navigation (`Sec-Fetch-Mode: navigate`) to a missing page skips the Worker and gets a different answer than curl.
7. The 404 page fetched for a missing path is answered with a 304 or a 206 because the visitor's conditional or range headers were forwarded.
8. Pages, feeds, and `/api/*` on www or workers.dev stop redirecting, or the apex starts redirecting.
9. Static files that exist on www or workers.dev are indexable as duplicates of the apex files.
10. A fix needs a generated list that outgrows a platform limit or silently goes stale when files are added.

Added before rebasing onto the demo-video merge (`f7f83f0`), which made `/media/*` Worker-first and immutable:

11. An existing `/media/*` MP4 stops answering `Range: bytes=0-1` with a 206, or loses `immutable`.
12. A missing `/media/*` file returns a 404 with `immutable`, or a 206 or 416 sliced from the 404 page.
13. `/media/*` on www or workers.dev stops redirecting.

### How the routing works

Sources: [`run_worker_first`](https://developers.cloudflare.com/workers/static-assets/binding/#run_worker_first), the [routing decision diagram](https://developers.cloudflare.com/workers/static-assets/routing/static-site-generation/), [`_headers`](https://developers.cloudflare.com/workers/static-assets/headers/), [static-asset limits](https://developers.cloudflare.com/workers/platform/limits/#static-assets), and [billing](https://developers.cloudflare.com/workers/static-assets/billing-and-limitations/). Where the docs are silent, the behavior was read from the router that Wrangler 4.156.0 runs locally (`miniflare/dist/src/workers/assets/`, built from `workers-shared`).

- A request matching a positive pattern runs the Worker. One matching a `!` pattern goes to the asset router, even if the file is missing. Patterns are globs where `*` matches across `/`.
- A request matching neither goes to the assets if a file exists, and to the Worker otherwise. With `not_found_handling: "404-page"` and a pattern list, the router counts the 404 page as a match (`unstable_canFetch` keeps the 404-page setting when static routing is present). So a miss never reached the Worker unless a positive pattern sent it there. With `"none"`, a miss reaches the Worker. Navigation requests don't change this, because the navigation rule only applies when `not_found_handling` is set.
- `_headers` rules match the request URL, including the host for absolute rules (`attachCustomHeaders(request, …)`). They apply to every asset-router response, 404s included, and they can't test the status or the file served. The limit is 100 rules and 2,000 characters per line.

### Options

| Option | Result |
| --- | --- |
| (a) Build-generated exact rules: an immutable `_headers` rule per file, plus exact `!` exclusions | Rejected. `dist` has 128 `/_astro/*` and 7 `/social/*` files, so 135 rules are already over the 100-rule limit, and every new image adds one. `run_worker_first` lives in `wrangler.jsonc`, not `dist`, so generating it needs a generated Wrangler config at deploy time. Exact `!` rules would fix redirects only for files that exist; a miss would still need the Worker to remove `immutable`. |
| (b) Worker-first for `/_astro/*` and `/social/*`, with `immutable` set only on successful responses | Correct, but it undoes finding 1. Before this branch, when every request ran the Worker, there were 4,529 invocations in 7 days, about 650 a day. The Free plan allows 100,000 a day, so cost is not the issue. The issue is that every hashed file again pays the Worker's measured 8 ms median and 58 / 188 ms p90 / p99 wall time, and gets a 429 instead of the file if the daily limit is ever hit. |
| (c) Detach `Cache-Control` from 404s in `_headers` | Not possible. Rules match the request path, so a rule on `/404.html` never applies to `/_astro/missing.js`. `! Cache-Control` on `/_astro/*` would strip the header from hits too. |
| (d) Positive patterns for pages, `not_found_handling: "none"`, and the Worker serves the 404 page | **Chosen.** No generated lists. Existing static files never run the Worker. Every miss on every host runs the Worker, which redirects alias hosts like any unknown path. On the apex, it fetches `/404/` by its own URL, so no `/_astro/*` rule attaches, and no conditional or range header is forwarded. |

`/media/*` stays a positive pattern because the Worker slices MP4 byte ranges (`src/lib/byte-range.ts`). It runs `withByteRange` on the result of `serveAsset`, which passes any non-200 through, so a missing MP4 gets the plain 404 page. On `main`, `run_worker_first: true` with `"404-page"` already sent media misses to the Worker, but the 404 page came from the missed path, so `/media/*`'s immutable rule attached to it.

Option (d) adds a Worker invocation only for misses under `/_astro/` and `/social/`, which were the only misses not already running the Worker. The 1,500+ scanner 404s a day already ran it, both before this branch and under its `"/*"` list. The Worker change is 6 lines in `serveAsset`. Two trade-offs:

- A page URL without its trailing slash (`/about`) on www or workers.dev gets the asset router's 307 to `/about/` on the same host, then the Worker's 301. Before, it got the 301 directly. Every link the site publishes ends in `/`.
- A new extensionless or non-`/` page endpoint must be added to `run_worker_first`, or www and workers.dev would serve it with only the `noindex` header.

### Alias-host static files

Existing static files on www and workers.dev return 200 without the Worker, so they have no canonical redirect. Two host-matched `_headers` rules add `X-Robots-Tag: noindex` to them: `https://www.macrosios.com/*` and `https://:worker.jhonra121.workers.dev/*`. The second also covers version preview URLs. Google honors `X-Robots-Tag` for non-HTML files, including images ([robots meta and X-Robots-Tag](https://developers.google.com/search/docs/crawling-indexing/robots-meta-tag)). Pages on those hosts are unaffected, because they never reach the asset router.

### Local matrix

`worker` is 1 when the response ran Worker code (`probe-worker.ts` marks it) and 0 when the asset router answered alone. The JS, PNG, and MP4 are real hashed files from `dist`. "Before" is the first version of this branch (`3fe4828`), except the `/media/` rows, which are `main` at `f7f83f0`. "After" is this branch rebased onto `main` at `e930d05`, which added the IndexNow key file. Raw output for `main` and after is in `build/evidence/2026-11-07-web-perf/routing-{main,after}.txt`; the first-version run is recorded only in this table.

| Host | Request | Before | After |
| --- | --- | --- | --- |
| apex | existing `/_astro/*.js`, `/social/*.png` | 200, worker 0, immutable | 200, worker 0, immutable |
| apex | `/favicon.svg`, `/apple-touch-icon.png` | 200, worker 0, revalidate | 200, worker 0, revalidate |
| apex | IndexNow key `/e318eb91764f851a50c779d954962280.txt` | not on the branch yet | 200, worker 0, `text/plain; charset=utf-8`, body is the key |
| apex | `/_astro/missing.abc123.js`, `/social/missing.abc123.png`, `/_astro/`, `/social/` | 404, worker 0, **immutable** | 404 page, worker 1, `max-age=0, must-revalidate` |
| apex | missing `.js` with `If-None-Match` and `Range` | 404, worker 0, **immutable** | 404 page, worker 1, revalidate |
| apex | `/missing/`, also with `Sec-Fetch-Mode: navigate` | 404 page, worker 1 | 404 page, worker 1 (title "Page not found", `noindex, follow`) |
| apex | `/`, guide, `/sitemap.xml`, `/robots.txt` | 200, worker 1 | 200, worker 1 |
| apex | `/about` | 307 to `/about/`, worker 1 | 307 to `/about/`, worker 0 |
| apex | `POST /api/waitlist` (invalid) | 400, worker 1 | 400, worker 1 |
| apex | existing `/media/*.mp4` with `Range: bytes=0-1` | 206, worker 1, immutable, `bytes 0-1/1164984` | 206, worker 1, immutable, `bytes 0-1/1164984` (body `00 00`; without `Range`, 200 with all 1,164,984 bytes) |
| apex | `/media/missing.abc123.mp4`, with and without `Range`, and `/media/` | 404, worker 1, **immutable** | 404 page, worker 1, revalidate, no `Content-Range` |
| www, workers.dev | `/`, guide with `?ref=ig`, `/sitemap.xml`, `/robots.txt`, `/missing/` | 301 to apex | 301 to apex |
| www, workers.dev | `/_astro/missing.abc123.js`, `/social/missing.abc123.png`, `/_astro/`, `/social/` | **404, worker 0, immutable** | 301 to apex, worker 1 |
| www, workers.dev | existing hashed files, favicon, touch icon, IndexNow key | 200, worker 0, no `X-Robots-Tag` | 200, worker 0, `noindex` (hashed files keep immutable; the key keeps `text/plain` and its body) |
| www, workers.dev | `/about` | 301 to apex `/about` | 307 to `/about/` (noindex), then 301 |
| www, workers.dev | `POST /api/waitlist` | 308 to apex | 308 to apex |
| www, workers.dev | existing and missing `/media/*.mp4` (with `Range`), `/media/` | 301 to apex | 301 to apex |

## Validation

These checks passed:

- In `web/`: `bun install --frozen-lockfile`, `bun run check` (0 errors, warnings, and hints), `bun test src/worker.test.ts` (25 pass, including the demo-video byte-range tests), `bun run build`, and `bun run deploy:dry-run` (no warnings).
- At the root: `make lint-js` (0 warnings and errors on 140 files) and `git diff --check`.
- Lighthouse scripts: with `LH=/bin/false`, and with `LH=/bin/true` (exits 0, writes no report), `lighthouse.sh` reported 12 `FAIL` lines and exited 1. `lh-summary.py` exited 1 on an empty folder and on a folder missing one of the 12 reports. A real local run (Lighthouse 13.6.0) wrote all 12 reports, and both scripts exited 0.

## Verify after deploy

1. Static files skip the Worker. Run `cd web && bunx wrangler tail macros-web --format json`, then request `/_astro/<js-or-image>`, `/favicon.svg`, and `/social/home.<hash>.png`. None of them should appear in the tail. `/`, `/guides/`, `/sitemap.xml`, and `/_astro/missing.abc123.js` should still appear.
2. Headers. `curl -sI https://macrosios.com/_astro/<any hashed file>` should show `cache-control: public, max-age=31536000, immutable`. HTML should still show `max-age=0, must-revalidate`, and the page source should have `<style>` with no `stylesheet` link.
3. Redirects are unchanged. Each of these should return 301 to the apex with the path and query kept: `curl -sI 'https://www.macrosios.com/guides/how-to-set-macro-goals/?ref=ig'`, `https://macros-web.jhonra121.workers.dev/`, and `https://www.macrosios.com/robots.txt`. `curl -si -X POST https://www.macrosios.com/api/waitlist` should return 308.
4. Assets on www are served directly. `curl -sI https://www.macrosios.com/favicon.svg` should now return 200 with `x-robots-tag: noindex`; it returned 301 before.
5. Misses. `curl -sI https://macrosios.com/_astro/missing.abc123.js` should return 404 with `cache-control: public, max-age=0, must-revalidate`, and `curl -s` of it should show the "Page not found" title. `curl -sI https://www.macrosios.com/social/missing.abc123.png` should return 301 to the apex.
6. Latency. Rerun `bash docs/evidence/web-perf/measure.sh build/evidence/after.txt macrosios.com 20` from the same network, then `python3 docs/evidence/web-perf/analyze.py build/evidence/after.txt`. Update the hashed CSS and AVIF paths in `measure.sh` first; the CSS file no longer exists after inlining, so use a JS or image file. Expect asset server time to fall from about 55 ms toward the 38–45 ms edge and redirect controls, and the asset p95 to fall. This is a prediction from the controls above, not a measurement. HTML should be unchanged, since it still invokes the Worker.
7. Worker invocations. After a day, rerun the GraphQL query. The invocation-to-page-view ratio should drop from roughly 15–19 requests per home view to the HTML and API requests only.
8. Forms. Join the waitlist with a throwaway address on the live site, then delete the row if needed.

## Dashboard and owner proposals (not applied)

1. **Web Analytics (optional).** The privacy text now describes it. Disabling it is still a performance option.
   - To disable it: in Web Analytics, select `macrosios.com`, open **Manage site**, and choose **Disable**. [Web Analytics setup](https://developers.cloudflare.com/web-analytics/get-started/)
   - Disabling removes a 10.5 KB third-party script, a second TLS connection, and the RUM posts. It probably also restores HTML ETags.
   - Verify: `curl -s -A 'Mozilla/5.0' -H 'accept: text/html' https://macrosios.com/ | grep -c cloudflareinsights` should print `0`.
1. **Email Address Obfuscation (optional).** Turning it off (Security > Settings, or Scrape Shield) should restore strong HTML ETags, so repeat views get a 304 instead of the full page. It does not rewrite these pages today. If it ever starts, it would add an `email-decode.min.js` request on every page, because every page footer has the address. The trade-off is that the address stays readable to scrapers, which is already true today. Verify after both proposals: `curl -sI -H 'accept-encoding: br' https://macrosios.com/ | grep -i etag` shows a value, and a second request with `If-None-Match` set to that value returns 304.
2. **Optional: keep HTML off the Worker too.** This saves about 8 ms at the median per page and removes the Worker's wall-time tail. It needs both of the following, in this order:
   - Add two Single Redirect rules on zone `macrosios.com`, and keep the existing www custom domain, which supplies its DNS record. Rules run before the Worker, so www never reaches it.
     - Rule 1: when `(http.host eq "www.macrosios.com" and http.request.method in {"GET" "HEAD"})`, use a dynamic redirect to `concat("https://macrosios.com", http.request.uri.path)` with status 301 and preserve query string on.
     - Rule 2: when `(http.host eq "www.macrosios.com" and not http.request.method in {"GET" "HEAD"})`, use the same target with status 308 and preserve query string on.
     - Verify with `curl -sI https://www.macrosios.com/x/?a=1` while tailing; the request must not appear in the tail.
   - Decide on workers.dev. Zone rules cannot redirect it. Either set `"workers_dev": false`, which breaks old workers.dev links (SEO.md currently says to keep those redirects indefinitely), or keep the current Worker-first page routing. Only after both steps can `run_worker_first` become `["/api/*", "/media/*"]`. Keep `not_found_handling: "none"`, so misses still get the Worker's 404 page. `/media/*` must stay Worker-first, because the Worker answers HTTP Range requests for MP4s. Static assets ignore `Range`, and Safari needs 206 responses. Keep `canonicalRedirect` in the Worker as the API fallback.

## Demo video (`/media/*`)

`web/demo-video` merged to `main` as `f7f83f0`, and this branch is rebased onto it. `"/media/*"` is in `run_worker_first`; never add `!/media/*`, which would skip the Range handling and send misses to the asset router. `_headers` keeps the `/media/*`, `/_astro/*`, and `/social/*` immutable rules and the two alias-host `noindex` rules. The streamed 206 has no `Content-Length`, because workerd drops the manual one and sends it chunked; that is valid and unchanged here.

## Repeat

```sh
mkdir -p build/perf-tools && cd build/perf-tools && echo '{"private":true}' > package.json
bun add lighthouse@13.6.0 playwright@1.64.1 && bunx playwright install chromium && cd ../..
bash docs/evidence/web-perf/measure.sh build/evidence/apex.txt macrosios.com 20
python3 docs/evidence/web-perf/analyze.py build/evidence/apex.txt
bash docs/evidence/web-perf/lighthouse.sh https://macrosios.com build/evidence/lh-prod
python3 docs/evidence/web-perf/lh-summary.py build/evidence/lh-prod
cd web && bun run build && cd .. && for h in macrosios.com:8797 www.macrosios.com:8798 macros-web.jhonra121.workers.dev:8799; do
  bash docs/evidence/web-perf/probe-dev.sh ${h%:*} ${h#*:} > build/evidence/dev-${h#*:}.log 2>&1 &
done  # wait for "Ready on" in each log, then:
bash docs/evidence/web-perf/routing-matrix.sh
cd web && bunx wrangler d1 migrations apply SUPPORT_DB --local && cd .. && node docs/evidence/web-perf/forms-e2e.mjs
```

Stop the probe servers before `forms-e2e.mjs`, which uses port 8798. The Lighthouse runs above used Chrome for Testing 158.0.8127.18 headless. The GraphQL queries used wrangler's OAuth token without printing it; the request bodies are in the raw evidence folder.
