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
- **The 150–235 ms samples are server-side.** In the apex run, 15 of 200 requests took over 150 ms, while their TCP and TLS times were normal (27–35 ms and about 33 ms). That points to the Worker and asset-fetch tail, not the network. One `/privacy/` sample was an exception, with a 74 ms TCP connect (network jitter). `/` had 7 of 20 samples over 150 ms.
- **The first lookup of a hostname adds DNS time.** For example, the first www request took 202 ms.
- **Not the cause:** compression format, cache misses (all requests were HITs), and colo changes (every request went to DFW).

## Findings

1. **Assets ran through the Worker.** `run_worker_first: true` made the Worker run before every request, only so that www and workers.dev could redirect. On Free-plan Workers, matched requests also count toward the daily request limit; past that limit, they get a 429 instead of the asset. [Billing](https://developers.cloudflare.com/workers/static-assets/billing-and-limitations/)
2. **Hashed files revalidated on every use.** Cloudflare's default is `max-age=0, must-revalidate`. Its docs recommend `_headers` with `immutable` for fingerprinted folders. [Headers](https://developers.cloudflare.com/workers/static-assets/headers/)
3. **The stylesheet was render-blocking.** It is 22,981 bytes raw and 5.1 KB brotli, and it is the only render-blocking resource.
4. **Full zod shipped to browsers and the Worker.** `lib/json.ts` imported `zod`'s non-tree-shakable namespace. That produced a 90 KB client chunk for two form scripts, and zod was 782 KB of the 811 KB Worker script.
5. **The compatibility date was 2026-04-15.** The flags that became defaults between then and the local workerd release (2026-10-23) do not touch this Worker's APIs: error serialization, Workflows, Python, TLS options, Durable Objects, `dispatchEvent`, and Node defaults that `nodejs_compat` already enabled. [Flags](https://developers.cloudflare.com/workers/configuration/compatibility-flags/)
6. **CI skipped the Worker tests.** The web job ran `bun run check` only, so `src/worker.test.ts` was never run in CI. The job does not run `build`, which matches the macOS-only Helvetica requirement for OG images.
7. **Web Analytics conflicts with the privacy page (dashboard).** Cloudflare Web Analytics automatic setup injects `static.cloudflareinsights.com/beacon.min.js` into HTML for browser requests. `/privacy/` says, "We do not use analytics SDKs or advertising trackers on the website or in the app." This is an owner decision.
8. **HTML has no ETag (dashboard).** Assets get the documented `ETag`, but HTML gets none, even for non-browser requests. Cloudflare drops strong ETags when it may modify HTML. [ETags](https://developers.cloudflare.com/cache/reference/etag-headers/) Email Obfuscation is not rewriting the footer address, and live HTML matches `dist` byte for byte, so the likely cause is Web Analytics HTML injection. The wrangler token cannot read zone settings to confirm it. The impact is small: the browser re-downloads 3–12 KB of compressed HTML instead of getting a 304, at the same round-trip cost.
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
| `run_worker_first` runs the Worker only for pages, feeds, unknown paths, and `/api/*`. `/_astro/*`, `/social/*`, the icons, and the badge are excluded with `!` patterns. www and workers.dev pages and form POSTs still redirect. | `web/wrangler.jsonc` |
| `/_astro/*` and `/social/*` (content-hashed) get `Cache-Control: public, max-age=31536000, immutable`. | `web/public/_headers` |
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

**Local routing.** `wrangler dev --local-upstream` checked both www and workers.dev.

- These requests returned 301 to the same path and query on `https://macrosios.com`: `/`, `/guides/how-to-set-macro-goals/?ref=ig`, `/about`, `/sitemap.xml`, `/robots.txt`, and `/missing/`.
- `POST /api/waitlist` returned 308.
- These returned 200 without the Worker: the CSS, a `/social/*` PNG, both favicons, the touch icon, and the badge.
- A missing `/_astro/*` file returns the 404 page. Because `_headers` matches the path, that 404 also carries the immutable header. This is harmless, since hashed URLs are never reused.
- localhost returned 200 everywhere, with the expected `Content-Type` for the sitemap and robots.

**Forms E2E.** `forms-e2e.mjs` ran Playwright against local `wrangler dev` with local D1. The failure list was written first. All 8 checks passed:

- invalid email disables submit
- a 400 response's `fieldErrors` sets the field's custom validity
- a non-JSON success falls back to the default message
- the real API returns the joined message, then the already-joined message
- server-side support field errors are applied
- support success is shown
- no page or console errors

## Validation

These checks passed:

- In `web/`: `bun install --frozen-lockfile`, `bun run check` (0 errors, warnings, and hints), `bun test src/worker.test.ts` (9 pass), `bun run build`, and `bun run deploy:dry-run` (no warnings).
- At the root: oxlint (`tools/oxlint/node_modules/oxlint/bin/oxlint --config .oxlintrc.json`) and `make lint-js`, both 0 warnings and errors on 135 files, and `git diff --check`.

## Verify after deploy

1. Static files skip the Worker. Run `cd web && bunx wrangler tail macros-web --format json`, then request `/_astro/<css-or-image>`, `/favicon.svg`, and `/social/home.<hash>.png`. None of them should appear in the tail. `/`, `/guides/`, and `/sitemap.xml` should still appear.
2. Headers. `curl -sI https://macrosios.com/_astro/<any hashed file>` should show `cache-control: public, max-age=31536000, immutable`. HTML should still show `max-age=0, must-revalidate`, and the page source should have `<style>` with no `stylesheet` link.
3. Redirects are unchanged. Each of these should return 301 to the apex with the path and query kept: `curl -sI 'https://www.macrosios.com/guides/how-to-set-macro-goals/?ref=ig'`, `https://macros-web.jhonra121.workers.dev/`, and `https://www.macrosios.com/robots.txt`. `curl -si -X POST https://www.macrosios.com/api/waitlist` should return 308.
4. Assets on www are served directly. `curl -sI https://www.macrosios.com/favicon.svg` should now return 200; it returned 301 before.
5. Latency. Rerun `bash docs/evidence/web-perf/measure.sh build/evidence/after.txt macrosios.com 20` from the same network, then `python3 docs/evidence/web-perf/analyze.py build/evidence/after.txt`. Update the hashed CSS and AVIF paths in `measure.sh` first; the CSS file no longer exists after inlining, so use a JS or image file. Expect asset server time to fall from about 55 ms toward the 38–45 ms edge and redirect controls, and the asset p95 to fall. This is a prediction from the controls above, not a measurement. HTML should be unchanged, since it still invokes the Worker.
6. Worker invocations. After a day, rerun the GraphQL query. The invocation-to-page-view ratio should drop from roughly 15–19 requests per home view to the HTML and API requests only.
7. Forms. Join the waitlist with a throwaway address on the live site, then delete the row if needed.

## Dashboard and owner proposals (not applied)

1. **Web Analytics (owner decision, privacy).** Either disable automatic injection or change the privacy text so it describes Cloudflare Web Analytics.
   - To disable it: in Web Analytics, select `macrosios.com`, open **Manage site**, and choose **Disable**. [Web Analytics setup](https://developers.cloudflare.com/web-analytics/get-started/)
   - Disabling removes a 10.5 KB third-party script, a second TLS connection, and the RUM posts. It probably also restores HTML ETags.
   - Verify: `curl -s -A 'Mozilla/5.0' -H 'accept: text/html' https://macrosios.com/ | grep -c cloudflareinsights` should print `0`, and `curl -sI https://macrosios.com/` should then show an `etag`.
2. **Optional: keep HTML off the Worker too.** This saves about 8 ms at the median per page and removes the Worker's wall-time tail. It needs both of the following, in this order:
   - Add two Single Redirect rules on zone `macrosios.com`, and keep the existing www custom domain, which supplies its DNS record. Rules run before the Worker, so www never reaches it.
     - Rule 1: when `(http.host eq "www.macrosios.com" and http.request.method in {"GET" "HEAD"})`, use a dynamic redirect to `concat("https://macrosios.com", http.request.uri.path)` with status 301 and preserve query string on.
     - Rule 2: when `(http.host eq "www.macrosios.com" and not http.request.method in {"GET" "HEAD"})`, use the same target with status 308 and preserve query string on.
     - Verify with `curl -sI https://www.macrosios.com/x/?a=1` while tailing; the request must not appear in the tail.
   - Decide on workers.dev. Zone rules cannot redirect it. Either set `"workers_dev": false`, which breaks old workers.dev links (SEO.md currently says to keep those redirects indefinitely), or keep the current Worker-first page routing. Only after both steps can `run_worker_first` become `["/api/*"]`. Keep `canonicalRedirect` in the Worker as the API fallback.

## Repeat

```sh
mkdir -p build/perf-tools && cd build/perf-tools && echo '{"private":true}' > package.json
bun add lighthouse@13.6.0 playwright@1.64.1 && bunx playwright install chromium && cd ../..
bash docs/evidence/web-perf/measure.sh build/evidence/apex.txt macrosios.com 20
python3 docs/evidence/web-perf/analyze.py build/evidence/apex.txt
bash docs/evidence/web-perf/lighthouse.sh https://macrosios.com build/evidence/lh-prod
python3 docs/evidence/web-perf/lh-summary.py build/evidence/lh-prod
cd web && bunx wrangler d1 migrations apply SUPPORT_DB --local && cd .. && node docs/evidence/web-perf/forms-e2e.mjs
```

The Lighthouse runs above used Chrome for Testing 158.0.8127.18 headless. The GraphQL queries used wrangler's OAuth token without printing it; the request bodies are in the raw evidence folder.
