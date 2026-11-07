# Web Changes Log

Current history. Older records retain their original wording and dated limitations.

See the [web archive index](../docs/history/web/README.md) for every archived heading. See [plans](../docs/plans/README.md) for current obligations.

## November 7, 2026: faster static delivery

Measured production from the Mac and Worker analytics. Every request, including images, CSS, and icons, invoked the Worker before the asset lookup, and hashed files revalidated on every use. Existing static files now skip the Worker on all hosts, while pages, feeds, forms, and every miss still run it, so www and workers.dev keep their redirects and a missing hashed file, including a `/media/` video, gets the revalidating 404 page instead of an immutable one. Media keeps its Worker-first Range handling. Hashed files are cached as immutable, alias-host static files are marked noindex, the stylesheet is inlined, the browser form scripts use zod/mini (client chunk 90 KB to 21 KB), and the Worker is minified with a current compatibility date. CI now runs the Worker tests. HTML is still served without an ETag; turning off Email Obfuscation is an owner dashboard decision.

Check, Worker tests, build, deploy dry run, lint, the local routing matrix, and form E2E passed. No deployment. See the [performance evidence](../docs/evidence/web-perf/README.md).

## November 7, 2026: privacy page describes website analytics

The privacy page said the website had no analytics SDKs. The site uses Cloudflare Web Analytics, so the page now has a "Website analytics" section that says what the beacon collects, links Cloudflare's documentation, and limits the no-analytics claim to the app. Effective date is November 7, 2026. No deployment.

## November 5, 2026: shorter copy and an earlier mobile phone

Reviewed thirteen iPhone app websites at mobile and desktop widths. Rewrote the home copy and About and Support intros. Mobile now shows the food diary before the waitlist form; desktop keeps them side by side. Visible home copy fell from 886 to 718 words. Prices, legal bodies, the guide article, native transitions, and the launch flag are unchanged. Fixed narrow-header and tablet screenshot-track overflow found during checks.

Local browser, SEO, social-image, build, and lint checks passed. Home retained Lighthouse 100 in all four categories on mobile and desktop. No deployment. See the [research](../docs/research/app-website-patterns.md) and [copy comparison and evidence](../docs/evidence/web-copy/README.md).
