# Website articles and Astro performance evidence

Media removed in the repo cleanup; retrieve with `git show 074b10994f1b68d9d7a8d6c54ed7effb90d5f1f5:docs/evidence/web-articles/blog-og.png`.

November 4, 2026. Branch `web/articles`, based on `cca0518`. No deployment, production form submission, new dependency, or native source change.

## Copy review

Applied the supplied unslop rules to both Markdown articles and the guides/blog descriptions in `seo.ts`. Rules without a matching pattern did not need a rewrite. Kept the health caveats and primary-source attribution. A direct comparison with `git show cca0518:web/src/content/guides/how-to-set-macro-goals.md` confirms that the guide's numeric tokens and Markdown link destinations are unchanged.

| Rule applied | Before | After |
| --- | --- | --- |
| 10, forced three-part closing list | “See the feature and pricing details, privacy policy, or contact me for app help.” | “See the feature and pricing details and the privacy policy. For app help, contact me.” All destinations remain. |
| 15, excessive bold | “**None of these presets falls within all three adult AMDRs.**” | The same sentence without bold. Also removed bold from the RDA, equation, and example totals. |
| 16, inline list labels | “Resting estimate: 10 × 70…” | “The resting estimate is 10 × 70…” |
| 27, name the mechanism | “Set goals you understand” | “Check how the calculator sets goals” |
| 28, split dense sentences | “If the resulting calories fall outside the requested total through 2% above it, the app replaces carbs…” | “It accepts a calorie total between the requested total and 2% above it. Outside that range, the app replaces carbs…” |
| 29, active voice | “Actual weight change is not guaranteed to follow these settings.” | “These settings do not guarantee a particular weight change.” |
| 30, cut unnecessary adverbs | “The saved goal can differ slightly…” | “The saved goal can therefore differ…” |
| 31, plain word | “It initially rounds carbs…” | “It first rounds carbs…” |
| 32, remove stock framing | “You do not need a perfect macro split… You do need to know where the numbers came from.” | “Start with a calorie estimate and convert your chosen macro percentages to grams.” |
| 33, complete sentences | “Activity estimate: 1,648.75 × 1.55…” | “The activity estimate is 1,648.75 × 1.55…” |

The index descriptions now name the calculator math, cited ranges, saving targets, and release changes rather than describing the writing as “plain-language.” Meaningful numerical ranges and the equation's name retain their original punctuation. No new nutrition claims were added.

## Visuals

- `CalorieFlow.astro`: the 2,000-calorie, 20/50/30 example, with shares divided by 4/4/9 to get 100/250/about 66.7 g. Its actual table is readable at 390 px without scrolling.
- `AMDRChart.astro`: a 0–100% chart with adult protein 10–35%, carbs 45–65%, and fat 20–35% bands. Distinct marker shapes plot all three app presets. An accessible data table repeats every value and scrolls on mobile.
- `CalculatorSteps.astro`: resting estimate, activity multiplier, Maintain offset, Balanced split, rounding and carb adjustment. The final total is 2,565 kcal.
- The existing Settings screenshot sits beside Daily Goals. Fresh body-profile, activity/direction, and review screenshots sit beside their corresponding instructions.
- `guide-og.png`, 1200 × 630, shows the guide title and the real review screenshot. `blog-og.png` demonstrates the draft's social image from the temporary local publication check. It is evidence only, not a public asset.

All diagrams are static Astro HTML/CSS with captions and actual text or tables. They inherit system type, light/dark tokens, and the site macro colors. They add no client JavaScript. Screenshots have intrinsic dimensions and responsive sources; all measured CLS values are zero.

### Calculator capture protocol

Used only App Store media simulator `D16C3D35-889F-404F-BDD4-C640A6DBC4EF`, under an exclusive directory lock in `/tmp/macros-sim-locks/`. The lock was available immediately. No other simulator was modified.

Built Debug from this worktree into `/tmp/macros-web-articles-build` with only the unconditional `PACKAGED_FOOD_SEARCH_BASE_URL=https://cal-macro-tracker-usda-proxy.jhonra121.workers.dev` override. `plutil` confirmed that exact URL in `USDA_PROXY_BASE_URL`. The existing installation already had demo food logs. Used the T3 device tool's pinned agent-device CLI for every app action and screenshot, with a 9:41 simctl status-bar override.

Entered Male, age 30, 70 kg, 175 cm, Moderate, Maintain, Balanced. The app's accessibility tree and review screenshot both confirmed **2,565 kcal, 190 g protein, 260 g carbs, 85 g fat**. All three source PNGs are 1320 × 2868. Cleared the status-bar override, shut down the media simulator, and released the lock. The demo diary remains installed; no goals were applied.

## Astro 7 audit

Consulted current official Astro documentation through the Astro docs connector. Direct FetchUrl requests to the `.md` variants and `llms.txt` returned 404, so the connector's official `docs.astro.build` excerpts supplied the references below. The installed version is Astro 7.4.4.

| Feature and documentation | Before | Decision | Measured effect or search need |
| --- | --- | --- | --- |
| [Responsive images and layout](https://docs.astro.build/en/guides/images/#responsive-image-behavior) | Explicit widths/sizes and site CSS, no layout prop | Use constrained layout on guide images, keep tailored 320/640/960 widths and accurate 320px display sizes. Existing CSS already handles responsive styling; no global styles switch. | Four guide images total 35,475 transferred bytes at 1×. All images decode; no page overflow or CLS. |
| [Image formats](https://docs.astro.build/en/reference/modules/astro-assets/) | WebP only | AVIF source with WebP fallback for new guide screenshots. Keep the already optimized home hero unchanged. | Review image at 640px: WebP 25,888 B, AVIF 16,094 B, 37.8% smaller. Comparison also recorded home, 40,452 B vs 27,460 B. |
| [Image priority](https://docs.astro.build/en/reference/modules/astro-assets/#priority) | Hero already priority, eager/sync/high; guide image lazy | Keep. Do not promote below-fold guide screenshots. | Hero priority check passes; the guide's initial LCP is text. |
| [Static endpoints](https://docs.astro.build/en/guides/endpoints/) and [OG example](https://docs.astro.build/en/guides/fonts/#accessing-font-data-programmatically) | Article OG was a 1200px-wide portrait screenshot | Build 1200 × 630 title/screenshot PNGs under `/social/`; reuse Astro's already installed sharp, no Satori or font dependency. | Search/social need. Open Graph, Twitter and Article image URLs agree. Images decode at 1200 × 630. Draft image returns 404 until publication. |
| [Fonts API](https://docs.astro.build/en/guides/fonts/) | System font stack | Keep it. No custom font registration or preload. | Zero font requests before and after. |
| [ClientRouter vs native transitions](https://docs.astro.build/en/guides/view-transitions/#differences-between-browser-native-view-transitions-and-astros-clientrouter) | Router plus SPA lifecycle listeners on every page | Native document transitions; initialize existing scripts on load. Inline the tiny CSS opt-in before external CSS loads. Reduced motion opts out; unsupported browsers use ordinary navigation. | Home total executable JS falls 16,530 B; guide falls 16,483 B. Actual incoming native transition verified. Forms and reveals pass after navigation. |
| [Prefetch](https://docs.astro.build/en/guides/prefetch/#using-with-view-transitions) | ClientRouter enabled prefetch-all implicitly | Explicit `prefetch: false`. No speculative page downloads or new prefetch script. | Included in the router byte savings. No separate measured navigation benefit justifies reintroducing it. |
| [build.inlineStylesheets](https://docs.astro.build/en/reference/configuration-reference/#buildinlinestylesheets) | Default `auto`, small styles inline, large shared CSS external | Keep `auto`. The transition opt-in alone must be inline for correctness. | Existing shared CSS remains cacheable. No Lighthouse rendering failure or measured benefit justifies inlining the whole stylesheet. |
| [compressHTML](https://docs.astro.build/en/reference/configuration-reference/#compresshtml) | Already true by default | Keep default. | Compressed HTML confirmed in built output. No config churn. |
| [trailingSlash](https://docs.astro.build/en/reference/configuration-reference/#trailingslash) | `always` | Keep. | All seven sitemap page URLs return their canonical 200; slash redirect check passes. |
| [Collection render/headings](https://docs.astro.build/en/reference/modules/astro-content/#render), [reading time](https://docs.astro.build/en/recipes/reading-time/) | Typed collections, visible dates and sitemap lastmod; no contents list | Add seven-link contents list using render headings. Approximate reading time from raw Markdown word count at 200 words/minute, no dependency. Keep dates/lastmod. | Search/reading utility, no client JS. All seven target IDs exist. Reading estimate includes Markdown syntax and is explicitly approximate. |
| [Markdown heading IDs](https://docs.astro.build/en/guides/markdown-content/#heading-ids) and [external links](https://docs.astro.build/en/recipes/external-links/) | Automatic IDs, same-tab citation links, normal tables | Use existing IDs. Keep same-tab links, which need no `noopener`; no `nofollow` on sources. Add keyboard-focusable horizontal table regions. | Anchors work, no new dependency, no page overflow at 390/1440 in either theme. |
| [security.csp](https://docs.astro.build/en/reference/configuration-reference/#securitycsp) | No Astro CSP configuration | Recommend a separate policy pass, not adoption here. This is stable since Astro 6, not experimental. | Need to cover JSON-LD, existing scripts and inline styles, API/form destinations, and reporting. Not an SEO/byte win. |
| [Sitemap integration](https://docs.astro.build/en/guides/integrations-guide/sitemap/) and [RSS package](https://docs.astro.build/en/recipes/rss/) | Small custom, tested static endpoints with explicit draft gating and dates | Keep. Reconsider packages if content volume or feed requirements grow. | Both draft and local published checks pass; migration adds dependencies without a current search or byte benefit. |

Native transitions initially failed intermittently when their opt-in lived in the external stylesheet, with Chromium reporting `ViewTransition opt-in disabled`. The final inline-head rule fixes the load-order problem. Browser checks assert an actual incoming transition, not merely the absence of errors. Unsupported browsers intentionally have no animation fallback.

## Lighthouse and bytes

Lighthouse 13.6.0, Playwright Chromium, local built Worker on port 8797. Mobile uses the default Lighthouse simulated throttling. Desktop uses 1440 × 900, 40 ms RTT, 10,240 Kbps and 1× CPU. All four categories, Performance / Accessibility / Best practices / SEO, scored **100 / 100 / 100 / 100 before and after in every row**.

| Page | Mode | LCP before → after | Initial transfer before → after | Total executable JS before → after |
| --- | --- | --- | --- | --- |
| Home | Mobile | 0.760 → 0.756 s | 89,632 → 84,143 B | 119,603 → 103,073 B |
| Home | Desktop | 0.268 → 0.209 s | 124,129 → 118,632 B | 119,603 → 103,073 B |
| Guide | Mobile | 0.935 → 0.755 s | 20,337 → 16,446 B | 17,019 → 536 B |
| Guide | Desktop | 0.253 → 0.206 s | 20,337 → 16,446 B | 17,019 → 536 B |

Total executable JS means decoded external script bytes plus inline executable script text; JSON-LD is excluded. Home external JS falls from 119,024 to 102,537 B; guide external JS falls from 16,440 B to **zero**. A shared 536 B inline reveal initializer remains on the guide, so the page is not literally JavaScript-free. The new article visuals add none. Before, that initializer was 579 B.

Initial transfer comes from Lighthouse total-byte-weight. Its measurements include response overhead and local compression, so small byte variations between loads are expected. External JS transfer after compression falls from about 38.3 KB to 32.5 KB on home and 5.8 KB to zero on the guide.

For a complete reading session, a separate cold browser context at 1× loads and decodes **every** page image, including off-screen lazy images:

| Page | Width | Complete transfer before → after |
| --- | --- | --- |
| Home | 390 | 169,006 → 163,459 B |
| Home | 1440 | 171,816 → 166,269 B |
| Guide | 390 | 49,323 → 50,429 B |
| Guide | 1440 | 31,421 → 50,429 B |

The illustrated guide costs 1,106 B more at mobile 1× and 19,008 B more at desktop 1× when fully read, despite smaller initial transfer. That is the deliberate cost of replacing one screenshot with four; the static diagrams themselves need no image requests. Higher-density devices select larger sources.

CLS and TBT are zero before and after in all final runs. Local timing changes are lab observations, not field Core Web Vitals or proof of a reliable LCP improvement. The unchanged 100 scores already indicated a fast site. The byte reduction, not a noisy timing difference, supports removing ClientRouter.

## Validation and artifacts

- `bun run check` and `bun run build`, zero Astro errors/warnings/hints.
- `make lint-js`, 128 files, zero warnings/errors. Initial implementation spacing findings were fixed, not suppressed.
- `git diff --check`, clean.
- Five existing Worker tests pass. No native tests were needed; the Debug build and real UI capture verify the calculator behavior.
- Existing `../web-seo/verify.mjs` checks rerun against `bun run dev:worker`: sitemap, robots MIME, canonicals, JSON-LD, visible FAQ, slash redirects, draft/404/noindex gates and local honeypot result states.
- Temporary local publication check verifies blog index/post/nav, Article metadata, RSS XML, nine sitemap entries, and the blog social PNG. Restored `draft: true`, rebuilt, and reran the hidden-state checks. `publication-checks.json` records the temporary state.
- Additional browser checks verify all images, contents links, schema/social image agreement, four screenshot placements, no horizontal page overflow, normal/reduced motion navigation, back navigation, reveal initialization and both forms. Form responses are intercepted inside the browser, so no request writes to a database.
- Full guide JPEGs at 390 × 844 and 1440 × 1000 in light/dark. Twelve diagram JPEGs capture each diagram in all four configurations. Diagram images use document-coordinate clips so the sticky header cannot cover their labels. No styles or pixels were altered.
- Opened the rendered guide and diagrams for review, including both themes, and opened both social images. Mechanical design detector returned no findings. Fixed the mobile calorie-flow table so its grams remain visible without scrolling.
- Evidence folder is under 5 MB. The source app screenshots live in `web/src/assets/app-images/`, outside this evidence budget.
- Every local Worker/Chromium process started by the audit stops in `finally`. The simulator lock and status override were cleared.

## Repeat

Install website and isolated audit dependencies from the repository root:

```sh
bun install --cwd web --frozen-lockfile
mkdir -p build/seo-tools
bun add --cwd build/seo-tools lighthouse@13.6.0 playwright@1.64.1
bun run --cwd build/seo-tools playwright install chromium
bun docs/evidence/web-articles/audit.mjs after
```

The foreground audit starts `bun run dev:worker --port 8797`, builds, runs the existing endpoint checks and added article checks, records Lighthouse and full-reading transfer data, captures images, and stops the server. `verify` skips metrics/captures; `screens` skips Lighthouse but refreshes screenshots. For `published`, temporarily set the launch post's draft flag false locally, run the audit, restore the exact file, then run `verify` again. Never deploy or leave the publication flag changed.

`before-*.json` measures the original tracked site files at `cca0518`, rebuilt locally with the same browser/tool versions. The baseline is not the older `web-seo` measurement, whose guide did not yet exist. Keep this baseline rather than measuring changed files and calling them “before.”
