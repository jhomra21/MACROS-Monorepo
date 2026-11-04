# Website SEO evidence

Validated locally on November 4, 2026, from branch `web/seo`, based on `74a0f79`. Nothing was deployed. The launch flag is off and the launch post is a draft in the final build.

## Lighthouse

Scores are Performance / Accessibility / Best practices / SEO. Lighthouse 13.6.0 used Playwright Chromium against the built Worker at loopback port 8796. Mobile uses Lighthouse's default simulated throttling; desktop uses 1440 × 900, 40 ms RTT, 10,240 Kbps throughput, and 1× CPU.

| Page | Mode | Before scores | After scores | LCP before → after | CLS before → after | TBT before → after |
| --- | --- | --- | --- | --- | --- | --- |
| Home | Mobile | 100 / 100 / 100 / 100 | 100 / 100 / 100 / 100 | 0.760 s → 0.759 s | 0 → 0 | 0 → 0 ms |
| Home | Desktop | 100 / 100 / 100 / 100 | 100 / 100 / 100 / 100 | 0.211 s → 0.261 s | 0 → 0 | 0 → 0 ms |
| Guide | Mobile | N/A, new page | 100 / 100 / 100 / 100 | N/A → 0.934 s | N/A → 0 | N/A → 0 ms |
| Guide | Desktop | N/A, new page | 100 / 100 / 100 / 100 | N/A → 0.251 s | N/A → 0 | N/A → 0 ms |
| Privacy | Mobile | 100 / 100 / 100 / 100 | 100 / 100 / 100 / 100 | 0.927 s → 0.928 s | 0 → 0 | 0 → 0 ms |
| Privacy | Desktop | 100 / 100 / 100 / 100 | 100 / 100 / 100 / 100 | 0.205 s → 0.205 s | 0 → 0 | 0 → 0 ms |

`before-lighthouse.json` is the previous run's preserved baseline, corroborated by its `build/seo-baseline.log`. Its guide entries contain zero scores and no metrics because that route did not exist. They are **not valid zero-scoring audits** and are reported as N/A above. `after-lighthouse.json` contains the final measurements and advisory audits. Small local timing differences are noise, not proof of an improvement or regression.

LCP and CLS are laboratory measurements. Field INP and a real Core Web Vitals pass cannot be established from these local loads. TBT is a lab diagnostic, not INP. Home mobile speed index changed from 1.87 s to 0.96 s. Existing small unused-JavaScript and render-blocking advisories remain; all scored categories pass.

## Checks

- `bun run check` and `bun run build` in `web/`: passed, no diagnostics.
- Root `make lint-js`: passed on 120 files, no warnings or errors. The first run found existing spacing errors in `docs/app-store/creative-assets/render.mjs`; only blank lines changed there to satisfy the unchanged gate.
- Existing `bun test src/worker.test.ts`: 5 passed. No native code changed or native tests run.
- `git diff --check`: passed.
- The audit starts `bun run dev:worker --port 8796`, waits for readiness from its output, and terminates its process group in `finally`. No preview server is left running.
- `endpoint-checks.json`: all seven sitemap URLs return 200 without redirects, one matching canonical and H1, 145–160 character descriptions, titles under 60 characters, parsed JSON-LD, and no accidental noindex. Internal page links use final slash URLs and return 200.
- Worker serves sitemap as `application/xml; charset=utf-8`, robots as `text/plain; charset=utf-8`. Robots allows all and points to the sitemap. Article `lastmod` is its updated date.
- `/privacy` redirects to `/privacy/`. `/blog/`, the draft post, `/rss.xml`, and an unknown page return the custom 404 with noindex. Support result fragments share the support canonical; POST-only waitlist text has `X-Robots-Tag: noindex`.
- `publication-checks.json`: temporarily published the draft **locally only**. The blog index, post, nav and RSS discovery appeared; sitemap grew to nine URLs; Article JSON-LD and article dates parsed; feed returned XML, parsed without errors, and contained one item. Restored `draft: true`, rebuilt, and reran the hidden-state checks.
- `browser-checks.json`: home and guide at 390 and 1440 wide in light and dark, no horizontal overflow, exactly one H1, JSON-LD parses. Every page image decoded before capture. Full-page JPEGs are included; evidence totals less than 5 MB.
- Mechanical design detector returned no findings for the new routes, badge, and stylesheet. Screenshots were opened for review.
- `app-store-flag-on.jpg`: temporarily enabled the flag, verified one official badge/link and the Smart App Banner meta, captured locally, then restored `live: false`. Chromium does not display Safari's native Smart App Banner; the actual metadata was checked rather than drawing a fake banner.

## Metadata

| Route | Title | Description |
| --- | --- | --- |
| `/` | MACROS: Calorie Counter & Food Diary for iPhone | Track calories and macros on iPhone with MACROS, a food diary with barcode and nutrition label scanners. Log meals on your device with no account required. |
| `/about/` | About MACROS \| No-account calorie and macro tracker | Meet MACROS, a calorie counter and macro tracker for iPhone. Keep a food diary on your device, scan barcodes and nutrition labels, and start with no account. |
| `/support/` | MACROS support \| Food diary and macro tracker help | Get help with the MACROS calorie counter and food diary for iPhone. Contact the developer about barcode scans, nutrition labels, daily goals, or purchases. |
| `/privacy/` | MACROS privacy \| Your iPhone food diary and data | Learn how MACROS stores your food diary on iPhone and handles food search, barcode scans, optional sharing, Apple Health, purchases, and website form data. |
| `/terms/` | MACROS terms \| Calorie counter and food diary | Read the terms for the MACROS calorie counter and food diary for iPhone, including optional Pro purchases, subscriptions, sharing, and nutrition information. |
| `/guides/` | Macro tracking guides for iPhone \| MACROS | Learn how to set protein, carb, and fat goals with plain-language macro tracking guides. See the math, primary sources, and how to enter targets in MACROS. |
| `/guides/how-to-set-macro-goals/` | How to set protein, carb, and fat goals | Set daily macro goals with calorie-to-gram math, adult reference ranges, and a worked example. Learn how the MACROS goal calculator estimates your targets. |
| `/blog/`, hidden | MACROS blog \| Calorie counter news and updates | Read updates from the developer of MACROS, the no-account calorie counter and food diary for iPhone, with barcode scanning and nutrition label scanning. |
| `/blog/macros-launch/`, draft | MACROS 1.0: a calorie counter without an account | Meet MACROS for iPhone, a calorie counter and food diary with barcode and nutrition label scanning, editable daily macro goals, and no account required. |
| Custom 404 | Page not found \| MACROS | This page could not be found. Return to MACROS or browse the macro tracking guides. |

Home has MobileApplication, Organization, WebSite, FAQPage. About, support, privacy, terms, and guides index have BreadcrumbList. Guide and published blog articles have BreadcrumbList and Article. Published blog index has BreadcrumbList. The noindex 404 has no structured data. FAQ answers exactly match the visible shared data; no ratings or reviews were added.

## Sources and product verification

Verified the source pages on November 4, 2026, before completing the guide:

- [National Academies, AMDR report, Table 3-1](https://www.nationalacademies.org/read/27957/chapter/5): adults, protein 10–35%, carbohydrate 45–65%, fat 20–35%; ranges guide planning, not a personalized prescription.
- [National Academies DRI summary tables](https://www.nationalacademies.org/read/25353/chapter/28), total water/macronutrient table footnote b: “for adults 0.8 g/kg body weight for the reference body weight.”
- [FDA, 21 CFR 101.9(c)(1)(i)(B)](https://www.ecfr.gov/current/title-21/chapter-I/subchapter-B/part-101/subpart-A/section-101.9): “general factors of 4, 4, and 9 calories per gram for protein, total carbohydrate, and total fat.”
- [Mifflin et al., 1990](https://pubmed.ncbi.nlm.nih.gov/2305711/): simplified equation is 10 × kg + 6.25 × cm − 5 × years, +5 for males or −161 for females; study included healthy adults aged 19–78.

Compared the guide with `GoalCalculator.swift` and `BodyProfileFormScreen.swift`, including unspecified-sex midpoint, activity factors, calorie offsets/floors, separate weight and height units, presets, and rounding. The example resolves to 2,565 kcal, 190 g protein, 260 g carbs, 85 g fat. The guide explicitly notes that none of the three shipped presets meets every adult AMDR.

Reused the existing real Settings screenshot, which visibly shows Daily Goals and Recalculate Targets with demo values and a 9:41 status bar. No simulator was modified. The simulator lock directory was empty.

## Performance details

Astro produces WebP from real screenshots. Hero has explicit dimensions, responsive 280/320/560/640/840/960 widths, eager loading, synchronous decoding, and high fetch priority. The added 320px source avoids a 560px download on a 1× desktop display. The guide's lazy screenshot has 320/640/960 widths and explicit intrinsic dimensions; its separate 1200px WebP is the article social image. Hero 320px output is about 17 KB; guide display images are about 11/29/46 KB, and its social image about 60 KB. System fonts require no font downloads or font-display swap. CLS was zero in all final runs.

## Single-origin proof and domain move

Run from the repository root:

```sh
rg -n 'macros-web\.jhonra121\.workers\.dev' web/src web/public web/astro.config.mjs web/wrangler.jsonc
```

Exactly one website-source match: `web/src/data/site.ts:15`, `site.url`. Generated evidence/build output naturally contains derived absolute URLs. A wider repository grep also finds pre-existing native legal links, auth-worker configuration, App Store notes, trackers, and the root README; those are outside this website change and must be considered separately when moving the whole product.

Domain checklist: configure the new host/TLS, change `site.url`, rebuild, add host-specific 301 redirects from workers.dev preserving paths/queries, verify Search Console properties, use Change of Address if eligible, resubmit the sitemap, and monitor indexing. Keep redirects at least a year. See `web/SEO.md` for static-asset routing and Search Console property caveats.

## Repeat the audit

No production dependencies were added. Optional audit packages live only under ignored `build/seo-tools/`.

```sh
mkdir -p build/seo-tools
cd build/seo-tools
bun add lighthouse@13.6.0 playwright@1.64.1
bunx playwright install chromium
cd ../..
bun docs/evidence/web-seo/audit.mjs after
```

The audit uses port 8796. `launch` mode requires temporarily setting `site.appStore.live` to true; `published` mode requires temporarily making the launch post non-draft. Always restore both and run `after` before committing. Baseline scores are preserved evidence, not reproducible by auditing the changed pages.
