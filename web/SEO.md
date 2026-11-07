# Search and launch operations

## One public origin

`site.url` in `src/data/site.ts` is the only public-origin setting. Canonicals, Open Graph images and URLs, JSON-LD, the sitemap, robots, and RSS use `absoluteURL()` from `src/lib/seo.ts`. Do not put the deployment hostname in Astro config or content.

HTML pages use trailing slashes. Astro emits directory indexes; Wrangler forces the same final URLs. File endpoints keep their extensions. `public/_headers` sets sitemap XML and robots text content types because these Astro endpoints are prerendered to static assets, not served by an Astro runtime. A published RSS file uses the Worker's XML extension mapping. Do not force an RSS content type when the file is absent, as that would mislabel its HTML 404 response. Wrangler's `404-page` handling serves `404.html` with a real 404 status and `noindex`.

Support result states are fragments on `/support/`, not separate pages. Waitlist results are inline or POST-only text responses with `X-Robots-Tag: noindex`. Do not mark the useful support page or home page `noindex`.

## Publish editorial content

Guides and blog posts live in typed Astro Markdown collections. Frontmatter requires `title`, `description`, `published`, `updated`, `draft`, `image`, and `imageAlt`. Dates must be truthful; update `updated` when the content materially changes. The sitemap uses that date for article `lastmod`.

Only non-draft entries generate article routes or enter the sitemap. The blog index, navigation link, RSS discovery link, and RSS file stay absent until at least one blog post has `draft: false`. The launch announcement must remain a draft until 1.0 is approved. At publication, replace its provisional dates and review the release claims before rebuilding. No draft-preview route is shipped publicly.

Every `publicPages()` path gets a prerendered 1200 × 630 PNG at `/social/<path>.<hash>.png` (home uses `home`). Metadata comes from `pages` or published entry frontmatter; article screenshots use frontmatter `image`, while other screens and section labels live in the small `social.ts` map. Open Graph, Twitter, and Article schema use the same pure URL helper. Draft images and the unpublished blog index stay absent.

The SHA-256 prefix includes the title, description, subtitle, path (which seeds ring fills), screenshot bytes, macOS Helvetica font bytes, sharp renderer versions, and template version. Bump `templateVersion` in `src/lib/social.ts` whenever rendering geometry, typography, or colors change. Images regenerate at build time only; there is no runtime renderer or client dependency. Sharp/Pango measures glyph widths and fits complete text blocks, replacing the old character-count wrap. Builds require `/System/Library/Fonts/Helvetica.ttc`, deliberately failing rather than silently substituting a font. See `../docs/evidence/web-og/README.md` for costs and repeatable checks.

Long guides use `render()` headings for their on-page contents list. Authors place static visuals with `<!-- visual:calorie-flow -->`, `amdr`, `calculator`, `settings`, `profile`, `activity`, or `review` comments. `ArticleBody.astro` renders those comments as Astro components at build time. Keep each comment between paragraphs, not inside a table or list. Screenshots use explicit dimensions, 320/640/960 sources, accurate sizes, lazy loading, and AVIF with WebP fallback. The system font stack needs no font download. External citations stay in the same tab, so they do not need `noopener`; do not add `nofollow` to the primary sources.

Navigation uses browser-native document transitions, with the opt-in inline in the head so it is available before external CSS loads. Reduced motion uses ordinary document navigation. Page scripts initialize on document load, not `astro:page-load`. Keep prefetch off unless measurements justify its extra script and background traffic.

Home JSON-LD includes MobileApplication, Organization, WebSite, and FAQPage. Inner public pages include BreadcrumbList; guides and posts also include Article and article Open Graph dates. The FAQ comes from the exact same data as the visible answers. Google restricts FAQ rich results mainly to authoritative government and health sites; valid markup does not promise a rich result. There are no ratings or reviews.

## App Store launch flag

Set `site.appStore.live` to `true` only when the listing is available. Its ID drives both the Smart App Banner and the listing link. With the flag off, neither the banner nor the badge or its trademark credit renders.

The unmodified black English badge is from [Apple's marketing artwork](https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg). Follow [Apple's guidelines](https://developer.apple.com/app-store/marketing/guidelines/): one badge per page, 40px minimum onscreen height, at least one-quarter-height clear space, no filtering, redrawing, stretching, or animation. The component provides 10px clear space around a 40px badge, uses its original aspect ratio, and appears in the home hero or an inner page's footer, never both. The flag-on local preview is in `../docs/evidence/web-seo/`; the committed flag is off.

App screenshots appear as plain rounded screens (`AppScreen.astro`). Do not draw simulated Apple hardware such as CSS bezels, islands, or side buttons; Apple's guidelines forbid simulating its products. Apple's official product bezels may be added only after the App Store listing is live and the account owner has accepted Apple's [App Store Marketing Artwork License Agreement](https://developer.apple.com/app-store/marketing/guidelines/), which licenses them only for apps available on the App Store. Use them unmodified: no recoloring, cropping, shadows, tilt, or animation.

## Custom domain

The public origin is `https://macrosios.com`, set once in `src/data/origin.ts` and read by `site.url` and the Worker. `wrangler.jsonc` attaches `macrosios.com` and `www.macrosios.com` as Worker custom domains and keeps `workers_dev` on. `run_worker_first: true` makes every request pass through the Worker, which answers `www.macrosios.com` and `macros-web.jhonra121.workers.dev` with a permanent redirect to the same path and query on the apex host: 301 for GET and HEAD, 308 for other methods so a form POST stays a POST. Local hosts are not redirected. Keep these redirects indefinitely.

Search Console has a Domain property for `macrosios.com`. On 2026-11-06 `/sitemap.xml` was submitted (read successfully, 7 pages) and indexing was requested for every sitemap URL. The old workers.dev host was never a Search Console property, so there is no Change of Address to file; its 301s carry any existing links.
## Repeat local verification

From the repository root, run `cd web && bun run check && bun run build`, then run `make lint-js` and `git diff --check` from the root. Use `bun run dev:worker` in `web/` for built-asset verification, not only the Astro dev server. Do not deploy as part of an SEO check.

The evidence README documents the optional isolated Lighthouse/Playwright tooling and repeatable audit. Lighthouse gives laboratory LCP, CLS, and TBT, not field INP or a Core Web Vitals pass. Recheck field data in Search Console once traffic is sufficient.
