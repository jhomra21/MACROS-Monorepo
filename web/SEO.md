# Search and launch operations

## One public origin

`site.url` in `src/data/site.ts` is the only public-origin setting. Canonicals, Open Graph images and URLs, JSON-LD, the sitemap, robots, and RSS use `absoluteURL()` from `src/lib/seo.ts`. Do not put the deployment hostname in Astro config or content.

HTML pages use trailing slashes. Astro emits directory indexes; Wrangler forces the same final URLs. File endpoints keep their extensions. `public/_headers` sets sitemap XML and robots text content types because these Astro endpoints are prerendered to static assets, not served by an Astro runtime. A published RSS file uses the Worker's XML extension mapping. Do not force an RSS content type when the file is absent, as that would mislabel its HTML 404 response. Every miss reaches the Worker (`not_found_handling: "none"`), which serves `404.html` with a real 404 status and `noindex`.

Support result states are fragments on `/support/`, not separate pages. Waitlist results are inline or POST-only text responses with `X-Robots-Tag: noindex`. Do not mark the useful support page or home page `noindex`.

Videos live in `public/media/` with a SHA-256 prefix in the filename, and `public/_headers` caches `/media/*` for a year as immutable, so a re-encoded file must get a new name. Workers static assets ignore `Range` and always return the whole file, but Safari plays MP4 only after a `206`. The Worker therefore slices `/media/` responses itself (`src/lib/byte-range.ts`). The home demo uses `preload="none"`, plays only while half visible, and never plays on its own under reduced motion.

## Publish editorial content

Guides and blog posts live in typed Astro Markdown collections. Frontmatter requires `title`, `description`, `published`, `updated`, `draft`, `image`, and `imageAlt`. Dates must be truthful; update `updated` when the content materially changes. The sitemap uses that date for article `lastmod`.

Only non-draft entries generate article routes or enter the sitemap. The blog index, navigation link, RSS discovery link, and RSS file stay absent until at least one blog post has `draft: false`. The launch announcement must remain a draft until 1.0 is approved. At publication, replace its provisional dates and review the release claims before rebuilding. No draft-preview route is shipped publicly.

The blog link in the main navigation needs no separate flag. `Header.astro` renders it only while a blog post has `draft: false`, so publishing the first post is the one-line switch.

Posts and guides take an optional `related` list in frontmatter, such as `related: [guides/how-to-set-macro-goals, blog/serving-size]` (up to four, each `guides/<id>` or `blog/<id>`). The page renders those titles as a "Related" list in place of the generic More guides, Get help, and privacy row. A reference to an entry that does not exist fails the build. A reference to a draft is skipped, so a draft is never linked in production, and the link appears once the target is published. When a post goes live, add it to the `related` list of each guide and post that should point to it. The title is the link text, so keep titles descriptive.

Every `publicPages()` path gets a prerendered 1200 × 630 PNG at `/social/<path>.<hash>.png` (home uses `home`). Metadata comes from `pages` or published entry frontmatter; article screenshots use frontmatter `image`, while other screens and section labels live in the small `social.ts` map. Open Graph, Twitter, and Article schema use the same pure URL helper. Draft images and the unpublished blog index stay absent.

The SHA-256 prefix includes the title, description, subtitle, path (which seeds ring fills), screenshot bytes, macOS Helvetica font bytes, sharp renderer versions, and template version. Bump `templateVersion` in `src/lib/social.ts` whenever rendering geometry, typography, or colors change. Images regenerate at build time only; there is no runtime renderer or client dependency. Sharp/Pango measures glyph widths and fits complete text blocks, replacing the old character-count wrap. Builds require `/System/Library/Fonts/Helvetica.ttc`, deliberately failing rather than silently substituting a font. See `../docs/evidence/web-og/README.md` for costs and repeatable checks.

Long guides use `render()` headings for their on-page contents list. Authors place static visuals with `<!-- visual:calorie-flow -->`, `amdr`, `calculator`, `serving-label`, `calorie-gap`, `protein-lookup`, `serving-ruler`, `package-columns`, or a screenshot key from `GuideScreenshot.astro` (`settings`, `profile`, `activity`, `review`, `scan-review`, `scan-grams`, `scan-details`). An entry that places any visual skips the trailing frontmatter screenshot. `ArticleBody.astro` renders those comments as Astro components at build time. Keep each comment between paragraphs, not inside a table or list. Screenshots use explicit dimensions, 320/640/960 sources, accurate sizes, lazy loading, and AVIF with WebP fallback. The system font stack needs no font download. External citations stay in the same tab, so they do not need `noopener`; do not add `nofollow` to the primary sources.

Navigation uses browser-native document transitions, with the opt-in inline at the top of the head. Astro inlines the site stylesheet into each page (`build.inlineStylesheets: 'always'`), so no stylesheet blocks first render; recheck compressed HTML size if the CSS grows substantially. Reduced motion uses ordinary document navigation. Page scripts initialize on document load, not `astro:page-load`. Keep prefetch off unless measurements justify its extra script and background traffic.

Home JSON-LD includes MobileApplication, Organization, WebSite, and FAQPage. Inner public pages include BreadcrumbList; guides and posts also include Article and article Open Graph dates. The FAQ comes from the exact same data as the visible answers. Google stopped showing FAQ rich results on May 7, 2026 and removed the feature's documentation on June 15 (see [Search Central updates](https://developers.google.com/search/updates)). Keep the FAQPage markup anyway: it matches the visible text and costs nothing, but expect no rich result from it. There are no ratings or reviews.

The site speaks as MACROS, not as a person: no first-person singular copy, no personal byline, and no Person node. The Organization (`/#organization`) carries the app icon as `logo` (the 180 × 180 `apple-touch-icon.png`) and `sameAs` for the Instagram profile; the home and About pages both emit it. Every Article `author` and `publisher` is that Organization `@id` with its name and URL ([Google accepts Organization authors](https://developers.google.com/search/docs/appearance/structured-data/article)), and the visible byline reads "By MACROS". Use "we", "our", or "us" only where an operator must be named, such as privacy, terms, support, and waitlist copy. Add other profiles to `sameAs` only if the owner decides to publish them. At App Store launch, add the listing URL to the Organization `sameAs`.

## Notify IndexNow after a deploy

IndexNow tells Bing and its partner engines which URLs changed. Bing asks for it in its [webmaster guidelines](https://www.bing.com/webmasters/help/webmaster-guidelines-30fba23a), and the protocol is in the [IndexNow documentation](https://www.indexnow.org/documentation). A `200` or `202` response means the engine received the list, not that it indexed anything.

The key file is `public/<key>.txt`, served at `https://macrosios.com/<key>.txt` and containing only the key. The key is public by design: it proves host ownership, not authority. Keep exactly one such file. The script reads the key from the file name.

This is a manual step after an authorized deploy. It is not part of `check`, `build`, `test`, or `deploy`, and no validation run may send it.

1. Deploy, with authorization, so the pages and the key file are live.
2. From `web/`, run `bun run indexnow --dry-run` and read the payload. It sends nothing and skips the live key check.
3. Run `bun run indexnow` to submit every URL in `dist/sitemap.xml` (and any `dist/sitemap-*.xml`). Prefer explicit URLs for a small change: `bun run indexnow https://macrosios.com/blog/example/`.

The script refuses to send when something is wrong. Exit codes:

| Code | Cause |
| --- | --- |
| 1 | Unknown flag |
| 2 | Not exactly one `<32 hex>.txt` key file in `public/`, or its content differs from its name |
| 3 | `dist/` or its sitemap is missing, or the sitemap lists no pages. Build first, or pass explicit URLs |
| 4 | A URL is not canonical: not https, not the apex host, has a query or fragment, or an HTML page lacks its trailing slash |
| 5 | The key file is not live at `keyLocation`. Deploy first |
| 6 | The key check or the POST could not reach the network |
| 7 | IndexNow answered something other than 200 or 202: 400 bad format, 403 key not valid, 422 URLs not on the host or key mismatch, 429 too many requests |

Submit only URLs that really changed or were added. Draft posts are not in the sitemap, so a sitemap run never announces one. Do not send a URL for a draft by hand.

## App Store launch flag

Set `site.appStore.live` to `true` only when the listing is available. Its ID drives both the Smart App Banner and the listing link. With the flag off, neither the banner nor the badge or its trademark credit renders.

The unmodified black English badge is from [Apple's marketing artwork](https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg). Follow [Apple's guidelines](https://developer.apple.com/app-store/marketing/guidelines/): one badge per page, 40px minimum onscreen height, at least one-quarter-height clear space, no filtering, redrawing, stretching, or animation. The component provides 10px clear space around a 40px badge, uses its original aspect ratio, and appears in the home hero or an inner page's footer, never both. The flag-on local preview is in `../docs/evidence/web-seo/`; the committed flag is off.

App screenshots appear as plain rounded screens (`AppScreen.astro`). Do not draw simulated Apple hardware such as CSS bezels, islands, or side buttons; Apple's guidelines forbid simulating its products. Apple's official product bezels may be added only after the App Store listing is live and the account owner has accepted Apple's [App Store Marketing Artwork License Agreement](https://developer.apple.com/app-store/marketing/guidelines/), which licenses them only for apps available on the App Store. Use them unmodified: no recoloring, cropping, shadows, tilt, or animation.

## Custom domain

The public origin is `https://macrosios.com`, set once in `src/data/origin.ts` and read by `site.url` and the Worker. `wrangler.jsonc` attaches `macrosios.com` and `www.macrosios.com` as Worker custom domains and keeps `workers_dev` on. `run_worker_first` sends existing pages (`/` and `/*/`), the sitemap, robots, and RSS feed, `/api/*`, and `/media/*` (for byte ranges) through the Worker; with `not_found_handling: "none"`, every unknown path reaches it too. The Worker answers `www.macrosios.com` and `macros-web.jhonra121.workers.dev` with a permanent redirect to the same path and query on the apex host: 301 for GET and HEAD, 308 for other methods so a form POST stays a POST. Local hosts are not redirected. Keep these redirects indefinitely. Existing static files match no pattern, so every host serves them straight from the asset cache without a billed Worker invocation; on www and workers.dev, `public/_headers` marks them `X-Robots-Tag: noindex`. `public/_headers` caches the content-hashed `/_astro/*`, `/social/*`, and `/media/*` files for a year as immutable; the Worker serves misses there with the revalidating 404 page, so a 404 is never cached as immutable. When adding a page or endpoint whose URL does not end in `/`, add it to `run_worker_first`. Do not add `!` patterns: they send misses to the asset router and skip the redirect. See `../docs/evidence/web-perf/README.md` for measurements and the optional zone-redirect setup that would keep HTML off the Worker too.

Search Console has a Domain property for `macrosios.com`. On 2026-11-06 `/sitemap.xml` was submitted (read successfully, 7 pages) and indexing was requested for every sitemap URL. The old workers.dev host was never a Search Console property, so there is no Change of Address to file; its 301s carry any existing links.
## Repeat local verification

From the repository root, run `cd web && bun run check && bun run build`, then run `make lint-js` and `git diff --check` from the root. Use `bun run dev:worker` in `web/` for built-asset verification, not only the Astro dev server. Do not deploy as part of an SEO check.

The evidence README documents the optional isolated Lighthouse/Playwright tooling and repeatable audit. Lighthouse gives laboratory LCP, CLS, and TBT, not field INP or a Core Web Vitals pass. Recheck field data in Search Console once traffic is sufficient.
