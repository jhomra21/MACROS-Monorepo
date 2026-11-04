# Search and launch operations

## One public origin

`site.url` in `src/data/site.ts` is the only public-origin setting. Canonicals, Open Graph images and URLs, JSON-LD, the sitemap, robots, and RSS use `absoluteURL()` from `src/lib/seo.ts`. Do not put the deployment hostname in Astro config or content.

HTML pages use trailing slashes. Astro emits directory indexes; Wrangler forces the same final URLs. File endpoints keep their extensions. `public/_headers` sets sitemap XML and robots text content types because these Astro endpoints are prerendered to static assets, not served by an Astro runtime. A published RSS file uses the Worker's XML extension mapping. Do not force an RSS content type when the file is absent, as that would mislabel its HTML 404 response. Wrangler's `404-page` handling serves `404.html` with a real 404 status and `noindex`.

Support result states are fragments on `/support/`, not separate pages. Waitlist results are inline or POST-only text responses with `X-Robots-Tag: noindex`. Do not mark the useful support page or home page `noindex`.

## Publish editorial content

Guides and blog posts live in typed Astro Markdown collections. Frontmatter requires `title`, `description`, `published`, `updated`, `draft`, `image`, and `imageAlt`. Dates must be truthful; update `updated` when the content materially changes. The sitemap uses that date for article `lastmod`.

Only non-draft entries generate article routes or enter the sitemap. The blog index, navigation link, RSS discovery link, and RSS file stay absent until at least one blog post has `draft: false`. The launch announcement must remain a draft until 1.0 is approved. At publication, replace its provisional dates and review the release claims before rebuilding. No draft-preview route is shipped publicly.

Home JSON-LD includes MobileApplication, Organization, WebSite, and FAQPage. Inner public pages include BreadcrumbList; guides and posts also include Article and article Open Graph dates. The FAQ comes from the exact same data as the visible answers. Google restricts FAQ rich results mainly to authoritative government and health sites; valid markup does not promise a rich result. There are no ratings or reviews.

## App Store launch flag

Set `site.appStore.live` to `true` only when the listing is available. Its ID drives both the Smart App Banner and the listing link. With the flag off, neither the banner nor the badge or its trademark credit renders.

The unmodified black English badge is from [Apple's marketing artwork](https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg). Follow [Apple's guidelines](https://developer.apple.com/app-store/marketing/guidelines/): one badge per page, 40px minimum onscreen height, at least one-quarter-height clear space, no filtering, redrawing, stretching, or animation. The component provides 10px clear space around a 40px badge, uses its original aspect ratio, and appears in the home hero or an inner page's footer, never both. The flag-on local preview is in `../docs/evidence/web-seo/`; the committed flag is off.

## Move to a custom domain

1. Configure the new domain and TLS for this Worker.
2. Change only `site.url` to the new HTTPS origin. Rebuild and verify canonical, Open Graph, JSON-LD, sitemap, robots, and RSS URLs.
3. Add permanent **301 redirects** from the old workers.dev host to the new origin, preserving paths and query strings. This requires routing the old host through Worker code before static assets, or another host-aware redirect mechanism. Do not use a relative `_redirects` rule that also redirects the new host. Keep the old host responding with redirects, not duplicate content.
4. Verify both properties in Google Search Console. Submit Change of Address if Search Console supports the property types involved; a workers.dev URL-prefix property may not qualify. If unavailable, use the 301 redirects and new sitemap, and monitor indexing instead.
5. Resubmit `/sitemap.xml` for the new property. Check URL Inspection, redirects, robots access, and indexing. Keep redirects for at least a year, preferably indefinitely.

## Repeat local verification

From the repository root, run `cd web && bun run check && bun run build`, then run `make lint-js` and `git diff --check` from the root. Use `bun run dev:worker` in `web/` for built-asset verification, not only the Astro dev server. Do not deploy as part of an SEO check.

The evidence README documents the optional isolated Lighthouse/Playwright tooling and repeatable audit. Lighthouse gives laboratory LCP, CLS, and TBT, not field INP or a Core Web Vitals pass. Recheck field data in Search Console once traffic is sufficient.
