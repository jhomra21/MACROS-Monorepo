## 2026-11-04 Macro rings on section headings

- Replaced the horizontal three-color heading bars with the same reusable three-ring SVG used by the header logo. Section rings are 2.25rem square, a modest 0.875rem increase over the 1.375rem logo, and align with left- and center-aligned headings.
- Each section ring set gets independent randomized fills on load. Rings in revealed sections draw when the heading reveals; top-of-page headings draw on load. The header logo keeps its early inline randomization, while reduced-motion users get static final rings.
- Validation: Astro check/build and social-image hash verification pass; the source contains no `macro-bar` references. No deployment.

## 2026-11-04 Inner-page design consistency

- Reused the homepage section-heading and macro-bar in a shared PageHeading across About, support, legal, editorial, and 404 pages. Aligned page spacing and diagram radii, reused FeatureGlyph on About/support, and added existing scroll reveals to below-fold editorial visuals and lists without animating legal text or hiding the support form.
- Fixed wrapped mobile header labels and action-button contrast in both themes. Kept the macro palette, homepage composition, copy, metadata/schema, draft gating, ring script, social renderer, and native transitions unchanged. Removed redundant heading/waitlist CSS and an unused small-button rule.
- Validation: check/build, JS lint, whitespace, SEO/article E2E, social determinism, dark contrast, and motion checks pass. All ten final Lighthouse runs score 100/100/100/100; support accessibility improved from 96. CSS adds 14 decoded bytes and JS is unchanged. Before/after captures for all ten page types, including scratch-only blog publication, and the audit are in `docs/evidence/web-consistency/`, under 5 MB. No deployment.

## 2026-11-04 Content-hashed previews for every public page

- Follow-up: render and expose only the heading before ` | `; full titles still invalidate the hash. Bumped the template version and refreshed the seven-image E2E evidence.
- Replaced the manually generated shared OG asset and article-only endpoint with one build-time 1200 × 630 renderer covering `publicPages()`. Page metadata/frontmatter supplies the title and description; a small map selects real screens for main pages and articles use frontmatter `image`.
- Added deterministic header-ring branding, measured Pango text wrapping, and explicit macOS Helvetica without a dependency or client bundle change. Hashed URLs include page copy, screenshot/font bytes, path-seeded ring fills, renderer versions, and template version. Layout Open Graph/Twitter metadata and Article schema share the same URL helper.
- Kept publication gates, sitemap entries, other schema/meta, header script, and native transitions unchanged. Removed `public/og.png`, its manual generator, and `site.ogImage`; documented template versioning and Mac font requirements.
- Validation: check/build, root JS lint, whitespace checks, and built-output E2E pass for all seven final images; clean/repeat builds are byte-identical, a temporary title edit invalidates only its page, and isolated draft publication adds both blog previews. All final PNGs and repeatable evidence are in `docs/evidence/web-og/` (under 5 MB). No deployment.

## 2026-11-04 Article clarity, calculator visuals, and Astro performance

- Edited the guide, draft launch post, and section descriptions for direct instructions and shorter sentences. Kept the numbers, equations, citations, and link destinations unchanged. The launch post remains a draft.
- Added three static, accessible diagrams for calorie conversion, preset/AMDR comparison, and calculator steps. Placed the existing Settings image and three new real 1320 × 2868 calculator captures beside their instructions. The locked media simulator confirmed 2,565 kcal, 190 g protein, 260 g carbs, and 85 g fat; cleared the status bar and released the device afterward.
- Added a headings-based contents list, approximate reading time, scrollable data tables, responsive lazy AVIF/WebP screenshots, and build-time 1200 × 630 article social images using the already installed sharp dependency. Draft social images stay absent.
- Replaced ClientRouter and its prefetch behavior with native document transitions. The opt-in must arrive inline in the head; an external stylesheet caused intermittent Chromium transition aborts. Existing reveals and forms work after full-document and back navigation. Reduced motion skips transitions.
- Validation: check/build, JS lint, whitespace checks, five existing Worker tests, endpoint/publication E2E, and 390/1440 light/dark captures pass. Home and guide retain 100/100/100/100 on mobile and desktop; decoded executable JS drops by 16,530 bytes on home and 16,483 on the guide. Full-page screenshot transfer and local timing caveats are recorded in `docs/evidence/web-articles/`. No deployment or native source changes.

## 2026-11-04 Search metadata, guides, and launch gates

- Added typed guides/blog collections, a sourced macro-goal guide matching the native calculator, and a launch announcement held as a draft. Blog routes, nav, sitemap entries, and RSS appear only after publication.
- Centralized page metadata and origin-derived canonical/social/schema URLs; added sitemap and robots endpoints, Article/BreadcrumbList markup, and home MobileApplication/Organization/WebSite/visible FAQ markup without ratings.
- Added noindex 404 handling, consistent trailing slashes, correct static XML/text MIME types, and noindex for POST-only waitlist text results. Fixed a hidden RSS MIME override that mislabeled its HTML 404.
- Prepared the official, unchanged Apple badge and Smart App Banner behind `site.appStore.live`, verified a local flag-on preview, then left it off. Documented launch/publication/domain-switch operations in `SEO.md`.
- Reused the real Settings screenshot, added readable article styles, and right-sized the hero's desktop WebP. No native changes, new production dependencies, simulator use, or deployment.
- Validation: check/build, five Worker tests, root JS lint, diff checks, endpoint/publication E2E, and 390/1440 light/dark captures pass. All six final Lighthouse runs score 100/100/100/100; evidence and baseline caveats are in `docs/evidence/web-seo/`. Existing creative-renderer lint errors received whitespace-only fixes.

## 2026-11-04 Build 32 Media And Food Search Copy Refresh

- Retook Add Food for build 33 with brand lines beneath clean food names and whole-number calories; updated website and README alt text.
- Replaced Add Food with a typed search showing On Device and Search Results, and retook Insights with the aligned Weight card. Retook the compact label-review card and added an inline Details editor image.
- Replaced the widget image with personal small/medium widgets beside a real installed shared-person widget for Alex. Used a disposable profile on dev `energized-pigeon-822`, then deleted it. No production sharing data, app source changes, or deployments.
- Kept home, history, settings, Sharing list, person sharing, and `public/og.png`: pictured layouts are unchanged. History’s date alone differs.
- Marketing says food search, not online packaged-food search. Added shared-person widgets to sharing and widget descriptions, the Pro list, and the Pro FAQ. Updated changed-image titles, alt text, and README images.
- Privacy now explains search-as-you-type requests, per-query/source/page cache durations, and count/source summary logs. Existing provider names, sampled platform logging, and seven-day retention are unchanged.
- Validation: Debug media build and plist verified; web check/build, repository JS lint, and diff whitespace check passed. Headless 390/1440 light/dark captures, decoded-image and overflow checks, and capture notes are in `docs/evidence/web-refresh-build-32/` (under 5 MB). Simulator demo data retained; status-bar override cleared and lock released.

## 2026-11-02 Label Scan Screenshot Retake

- Replaced the label-review screenshot with a 1320 × 2868 iPhone 18 Pro Max capture showing the OCR-detected “Oat Crunch Cereal,” its 1 cup (40 g) serving, 190 calories, 5 g protein, 36 g carbs, 3 g fat, and the Log/Edit details actions without the missing-name warning.
- Used a generated cereal-label photo with the product name printed above its Nutrition Facts panel. OCR identified the name from the printed title; no app code or screenshot pixels were edited.
- Updated the screenshot title and alt text in `src/data/site.ts`, and kept the README image description in sync.

## 2026-11-02 Build 27 App Screenshot Refresh

- Replaced the home, Add Food, label review, history, Pro Insights, settings, and Sharing list screenshots with iPhone 18 Pro Max captures from the build 27 Debug app.
- Added the new Alex person-sharing screen to the website and README. Sharing uses the temporary `-sharingUIHarness` Debug-only fixture with Alex and Sam; no Convex production data or disposable server profiles were used.
- Compared a fresh Home Screen capture from build 27 with the October 30 widget image. The small and medium widget appearance is unchanged, so kept `app-widgets.png`.
- Updated screenshot titles and alt text to describe the screens, aligned README images with the website set, removed unused calendar, share-sheet, sharing-settings, and Full Unlock images, and regenerated `public/og.png` from the new home screenshot.

## 2026-10-30 Final App Store Captures

- Replaced the showcase screenshots with final App Store captures, added label-review, sharing, and widget screens, and regenerated `public/og.png` from the updated dashboard.

## 2026-10-30 Full Design Pass And Sharing Copy Correction

### Delivered

- Copy: the sharing card, the FAQ answer about what leaves the phone, and the privacy sharing paragraph no longer say foods are never shared. They state what this version sends (daily totals). Card title: "Share your day with your people."
- Hero phone: `DeviceFrame` now passes Astro's `priority` (eager, sync decode, high fetch priority) instead of separate loading props, so the frame is filled at every width. Added a floating glass badge with three macro rings that draw in once (900 ms, staggered, static under reduced motion).
- Type scale: display, page title (h1 on about, support, legal), headline, subhead and title, lead, body, small, caption, one `.eyebrow` style. Body line-height 1.58, measure capped at 65ch, tabular prices.
- Spacing and surfaces: `--section-space` clamp(4rem, 9vw, 7.5rem), `--heading-gap`, 24px card radius, a darker `--band` for alternating sections in dark mode, tighter hero-to-section gap.
- Components: bento hover lift and stronger glow, showcase edge fade with snap on every width, featured plan gradient hairline with trial badge and macro-color checks, FAQ animated open with chevron and hover, glass 60px header with a macro-bar mark, full product name in the footer.
- Not changed: no deploy, no new dependencies, legal meaning, palette.

## 2026-10-30 Illustrated Feature Cards And Copy Pass

### Delivered

- Feature cards: each `features` entry in `site.ts` now has `eyebrow`, `glyph`, and `accent`. New `FeatureGlyph.astro` draws one inline SVG per card (rings, barcode and label, phone with local dot, review checklist, sharing rows, widget mock) in the macro palette. Cards alternate blue, orange, and pink, with a soft corner glow (0.10 light, 0.16 dark) and an accent eyebrow. Eyebrow text uses darker light-mode shades for AA contrast. No new animation.
- Copy: unslop pass over feature cards, plan summaries, FAQ, support checklist, About, and component strings. Facts, prices, and the privacy and terms pages are unchanged.
- Validation: check, build, worker tests, oxlint, and `git diff --check` pass; headless Edge screenshots at 390 and 1440, light and dark, reviewed.

## 2026-10-29 Design-Craft Pass (impeccable, emil-design-eng)

### Delivered

- Focus ring (impeccable/emil): removed `border-radius: 4px` from the global `:focus-visible`. It squared off pill buttons and inputs when focused; the outline now follows each element's own radius.
- Footer (break-ui): `.site-footer a` was `display: flex`, which pulled the inline "Email us at" mailto out of its sentence and left it without an underline. Flex and the 44px target now apply only to `.site-footer nav a` and the brand; the inline link is underlined.
- Hover lift removed (animate/animation-performance): `.card-lift` moved non-clickable bento and plan cards on hover, which implied a click. Class and CSS deleted.
- Browser surfaces (impeccable craft floor): themed `::selection` and `caret-color` from `--link`; links get a 0.06em underline thickness.
- Text (impeccable): `p { text-wrap: pretty }` to avoid orphaned last words.
- Touch (mobile-native): `user-select: none` on `.button` and FAQ summaries; viewport adds `interactive-widget=resizes-content`.
- Reduced motion (emil): button press scale and FAQ icon rotation are off under `prefers-reduced-motion: reduce`.
- Copy (unslop): about and support copy shortened, passive and "built to surface" phrasing replaced, rule-of-three dropped from the about lead. Legal text unchanged; the support storage disclosure keeps its meaning.
- Not changed: macro-bar motif, hero rise and scroll reveal (one-time, transform and opacity only, reduced-motion gated), device frame, plans, FAQ, legal layout.
