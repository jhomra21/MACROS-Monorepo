## 2026-10-29 Redesign Follow-ups (Support Contact, Insights Wording, Privacy Disclosure, Waitlist CTA, Narrow Widths)

### Delivered

- Support contact: `supportEmail` in `src/data/site.ts` is `jhonra121@gmail.com`. `/support` shows "Email us at ..." above the form, and the footer shows the same mailto link.
- Insights wording: the Pro list, the Pro plan highlight, and the Pro FAQ answer now say "Insights ranges beyond 7 days". Free users keep 7-day Insights.
- Privacy page: effective date is October 30, 2026. The food-search section discloses sampled operational logs (about 10% of requests) that can include the request URL, IP address, and coarse location, kept up to 7 days for reliability and abuse prevention. These logs are not linked to any sharing profile. The sharing section says shared totals are linked to the sharing profile (display name and device-generated key), which makes them pseudonymous.
- Waitlist primary button: validation is unchanged. The disabled state keeps the primary fill at 65% on the background only, so the label stays at full contrast. Label contrast is about 5.1:1 in light mode and 7.2:1 in dark mode.
- Narrow widths: removed horizontal overflow at 320 px and at 320 px with 200% text on home, support, and privacy. Hero, bento, support, and footer grids use `minmax(0, 1fr)` tracks. The footer group track uses `min(9rem, 100%)`. The header wraps instead of forcing width. Form inputs no longer size the layout from their intrinsic width. Body text uses `overflow-wrap: anywhere`. `.table-wrap` is `position: relative`, so the sr-only table caption clips inside it.
- Copy: em dashes are gone from the two status strings in `lib/waitlist-validation.ts` and `lib/support.ts`. Home-page copy got one unslop pass: the why-section lead, the Pro plan summary, and the feature body apostrophe.

### Open items

- The food-search Worker's own log lines (`worker/usda-proxy/src/packagedFoodSearchLogging.ts`) hold only page, page size, provider, cache key, attempt count, and resolved provider. The URL, IP, and location in the privacy text come from platform request logs at the sampled rate (`head_sampling_rate: 0.1`). Confirm that, and the 7-day retention, in the Cloudflare dashboard before launch.
- Screenshots in `build/web-redesign-2026-10-29/screens/` predate these changes.

### Validation recorded

- `bun run check`, `bun run build`, `bun test src/worker.test.ts` (5 pass), oxlint with the repo config (0 errors), `git diff --check -- web` clean. Headless Edge overflow audit at 320x568, 320 with 200% text, and 640 wide is clean on home, support, and privacy.

## 2026-10-29 Marketing Site Redesign (Apple-style, "The product performs")

### Delivered

- New plain-CSS design system (`src/styles/global.css`, about 18 KB built): light and dark tokens, fluid type, system fonts only, calm reveal motion that is off under reduced motion.
- Direction "The product performs": app screens shown inside CSS device frames are the page's main material. Hero is a device frame with the waitlist form and privacy note.
- New components: `DeviceFrame`, `Header`, `Footer`, `Hero`, `FeatureGrid`, `Showcase`, `ProPlans`, `FAQ`, `WaitlistForm`, `WaitlistCta`, `ProseLayout` (sticky table of contents). `SiteLayout` adds a skip link, canonical URL, Open Graph and Twitter meta.
- All pages restyled: home (hero, why, showcase, plans, FAQ, waitlist), about, privacy, terms (legal text unchanged), support (same fields, validation, and API).
- Plans: free core, MACROS Pro $2.99/mo or $19.99/yr with a 7-day trial, $49.99 lifetime. Copy never promises AI photo logging, Apple Watch, or iCloud sync.
- `site.ts` is the single source for copy and images. `public/og.png` comes from `scripts/generate-og.mjs`. `site.appStoreURL` is empty until launch, so no App Store button shows.
- Open: replace placeholder screenshots with the new captures listed in the TODO in `site.ts`, then rerun the OG script.

### Validation recorded

- `bun run check`, `bun run build`, `bun test src/worker.test.ts` (5 pass), repo oxlint, and `git diff --check -- web` all exit 0. Screenshots for five pages at 390 and 1440 wide in both schemes are in `build/web-redesign-2026-10-29/screens/`.

## 2026-10-29 Workers Observability and cf Migration Deferral

### Delivered

- Enabled Workers Issues (`observability.issues.enabled`) in `wrangler.jsonc`. Issues processes new traffic only after the next deploy.
- Set observability to explicit `enabled: true` for logs and traces, and raised head sampling from 0.1 to 1 at every level. Every request is now logged and traced, so log and trace volume rises. Check the cost after the first deploy.
- Kept Wrangler as the build and deploy tool for `web/`. `cf migrate` was run and reverted. Its output was 4 files and one follow-up (`migrations_dir`), but `cf build` delegates to `astro build` for Astro projects and never writes Worker Build Output. The Cloudflare docs say Astro 6 and later does not build with `cf` during the beta. Re-evaluate when that changes.
- No `cf` dependency was added. Scripts, `wrangler.jsonc`, `wrangler.api.jsonc`, and `worker-configuration.d.ts` are unchanged apart from the observability block.

### Validation recorded

- `bun run check`, `bun run build`, `bun test src/worker.test.ts` (5 pass), `bun run deploy:dry-run` (no deploy), and the `lint-js` oxlint command (65 files, 0 errors) passed.
- `observability.issues` is in the Wrangler 4.156.0 config schema. The dry-run bundle does not print observability settings, so the keys were checked against the schema and the Wrangler configuration docs.

## 2026-10-29 Wrangler 4.156.0 Update

### Delivered

- Updated `wrangler` 4.116.0 → 4.156.0 (exact pin) in `package.json` and `bun.lock`. This was an owner decision to take the latest release despite its Miniflare 5 beta dependency (`miniflare@5.20261023.3-beta`).
- Regenerated `worker-configuration.d.ts` with `wrangler types` (workerd 1.20261023.1 runtime types, module declarations). The content changed, so the file is committed.
- No Worker code or config changed. Rate-limit bindings are used only through `limit()`, and both `wrangler.jsonc` and `wrangler.api.jsonc` keep their existing bindings.

### Caveats

- Miniflare 5 is a beta. It runs in `wrangler dev` and the tests. Deploys now upload source maps by default (wrangler 4.150).
- Revert to 4.116.0 if a dev or deploy regression appears.

### Validation recorded

- `bun run check`, `bun run build`, `bun test src/worker.test.ts` (5 pass), `bun run deploy:dry-run` (no deploy; bindings unchanged).
- `wrangler dev --config wrangler.api.jsonc` smoke: `/api/waitlist` returned 400 on a bad body, and `/api/support` returned the 303 form redirect on a valid POST. Then the server was stopped.
- Runtime QA `check` and `test`; convex-backend `test:integration`; repo oxlint command. All passed.
