# Build 32 website refresh

Source: `7585a8c` (TestFlight build 32). No app code changes or deployments.

## Media

All new app images are real 1320 × 2868 captures from the Debug app on the exclusively locked iPhone 18 Pro Max `D16C3D35-889F-404F-BDD4-C640A6DBC4EF`. Loaded Settings > Developer > Load Demo Data and used a 9:41 status-bar override. Each image is under 5 MB.

| Image | Decision |
| --- | --- |
| `app-add-food.png` | Replaced. Typed `greek yogurt`; shows both On Device matches and live Search Results, with the keyboard dismissed. |
| `app-insights.png` | Replaced. The 30-day Weight card now lines up with the average tiles. |
| `app-scan-review.png` | Replaced. The compact camera card now has the rounded Edit details control and updated serving layout. Used the existing Oat Crunch Cereal photo and real OCR. |
| `app-scan-details.png` | Added. Shows the full editor inside the camera card, Less, and Log in its footer. |
| `app-widgets.png` | Replaced. Shows a real installed shared-person small widget for Alex alongside the personal small and medium widgets. Alex’s dev-backend totals are 1840 kcal, P132/C176/F58, with goals 2100/145/230/65. |
| `app-home.png` | Kept. Fresh build 32 demo capture has the same visible layout and values. The Today fix does not change this screen. |
| `app-history.png` | Kept. Fresh capture differs in calendar date only, not layout or controls. |
| `app-settings.png` | Kept. Fresh capture has the same visible top section. The new shared-widget picker lives inside Sharing settings. |
| `app-sharing.png`, `app-sharing-person.png` | Kept. Compared the existing images with the build 27-to-32 source diff. List and active-person layouts are unchanged; person removal/loading fixes do not change these pictured states. |
| `public/og.png` | Kept because home did not change. |

The old `-sharingUIHarness` was temporary and is absent from main. Instead, created a disposable Alex profile on dev `energized-pigeon-822`, accepted its invite through the app, selected Alex as Default person, and added Shared Macros through SpringBoard. No production backend or other simulator was used. Deleted the disposable profile after capture. Debug Pro supplied the local widget entitlement; no backend entitlement setting changed. This refresh captures the Home Screen widget, not new Lock Screen media.

The first build with both requested command-line overrides produced a malformed `USDA_PROXY_BASE_URL`: Xcode included the conditional key suffix in its value. Rebuilt with only the unconditional `PACKAGED_FOOD_SEARCH_BASE_URL` override. `plutil -extract USDA_PROXY_BASE_URL raw` confirmed `https://cal-macro-tracker-usda-proxy.jhonra121.workers.dev` in the final build’s Info.plist. The search screenshot contains live results from that service.

Left demo data installed, cleared the status-bar override, shut down the simulator, and released its lock.

## Copy and privacy

Marketing now says food search and describes one list. Widgets, sharing, the Pro list, and the Pro FAQ mention shared-person widgets. Screenshot titles and alt text match the new media; README uses the same image set.

Privacy, effective November 4, now states that search text goes to the Worker as you type. It documents per-query/source/page caching: USDA up to 24 hours, Open Food Facts up to one hour, empty results up to five minutes. It distinguishes count/source summary logs from the existing sampled platform request logs. Provider names, sampled request logging, and seven-day log retention remain unchanged. References: `FoodSearchSession.swift`, `unifiedFoods.ts`, `foodSourceRegistry.ts`, and `foodSearchRoute.ts`.

## Validation and browser evidence

- Debug simulator build passed; build number and food-search URL verified in the built plist. This is build evidence, not a native test run.
- `bun install --frozen-lockfile` in `web/` passed.
- `bun run check` and `bun run build` passed, with zero Astro diagnostics.
- `make lint-js` passed, 107 files, zero warnings/errors. The first run lacked dependencies; installed `tools/oxlint/` from its frozen lockfile. Fixed spacing findings in the evidence script and reran.
- `git diff --check` passed.
- Headless Chromium: 390 × 844 and 1440 × 1000, light and dark, 1× scale. `home-*.jpg` captures the full page. `media-*.jpg` captures the gallery at the changed screens. Desktop viewports can contain several cards.
- All gallery images decoded, including off-screen lazy images. Home and privacy have no horizontal overflow, HTTP failures, or page errors in any configuration. See `browser-checks.json`.
- Used reduced motion for static captures. No website styles or screenshot pixels were altered. JPEG encoding keeps this evidence folder below 5 MB.
- The local Astro preview served the built `web/dist/` and stopped after capture. No forms were submitted.

Repeat after building: `bun docs/evidence/web-refresh-build-32/capture.mjs` from the repository root, with Playwright and its Chromium installed in the Bun environment. The script starts and stops its own loopback Astro preview on port 4318.
