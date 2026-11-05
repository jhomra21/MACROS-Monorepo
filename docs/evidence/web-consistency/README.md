# Website consistency evidence

Media removed in the repo cleanup; retrieve with `git show 074b10994f1b68d9d7a8d6c54ed7effb90d5f1f5:docs/evidence/web-consistency/after-404-1440-dark.jpg`.

Baseline: `d1ca467`, November 4, 2026. Local builds only. Nothing deployed.
The homepage is the visual standard. Copy, metadata, schema, publication gates,
social rendering, the header ring script, and native transitions stay unchanged.

## Audit before edits

| Page | Element | Difference from home | Fix |
| --- | --- | --- | --- |
| All, including home | Mobile header | Brand and navigation shrink and wrap at 390px. | Keep labels on one line and use existing small-screen spacing tokens. |
| All | Active buttons | White on action blue is 4.01:1 in light mode. Support scores 96 for accessibility. | Give action backgrounds accessible blue shades, leaving macro accent colors unchanged. |
| About | Page header | No macro accent; header gap differs from section-heading. | Shared page heading built from section-heading and macro-bar. |
| About | Story cards | Surfaces/radii already match home; no conflicting icon family exists. | Keep cards, use existing FeatureGlyph for device, scan, and review. |
| Support | Header and checklist | Missing page accent; cards never reveal, unlike home cards. | Shared heading; existing review glyph on checklist; reveal checklist only, never hide the form. |
| Privacy | Legal header | Separate header grid and spacing, no macro accent. | Shared heading; preserve legal body, dates, and contents navigation without body animation. |
| Terms | Legal header | Same duplicated legal header pattern. | Same shared heading as privacy. |
| Guides index | Header and list | Narrow editorial heading has its own gap; list appears without home's section reveal. | Shared heading with macro accent; reveal list entries. Keep reading measure. |
| Guide article | Header, visuals, related links | No macro accent; diagrams have 12px corners rather than home's 24px cards; below-fold visuals have no reveal. | Shared heading, card radius token, reveal diagrams/screenshots/related links only. |
| Blog index, scratch publication | Header/list | Same editorial differences as guides. | Fix the shared editorial template, never publish source draft. |
| Blog post, scratch publication | Header/screenshot | Same editorial differences; screenshot already responsive and rounded. | Shared heading and visual reveal. Keep image pipeline and readable article body. |
| 404 | Header and page ending | Missing accent and only 16px below its lead before footer. | Shared heading and normal section-space below recovery links. |
| CSS | Duplicate rules | Two waitlist-form rules; page-header, prose-header, editorial-header repeat heading grids; redundant editorial h2 size. | Merge waitlist rules, share heading grid, remove redundant declarations. |
| CSS | Raw values/dead rules | Most raw values define tokens, optical geometry, media breakpoints, focus outlines, or device shapes. No macro-bar--mark remains. button--sm has no source references. | Keep intentional geometry; tokenize repeated page-top spacing and shared rise/reveal durations. Remove unused button--sm and replaced page-header__inner. |

## Capture method

`audit.mjs before` and `audit.mjs after` run against built assets through a local
Wrangler Worker on port 8798. They stop each server in `finally`. Blog checks use
an ignored scratch copy with temporary publication; source stays draft.
Full-page JPEGs capture each page with 390 × 844 and 1440 × 1000 viewports in light
and dark. Desktop captures are downsampled to 720px after rendering at 1440px;
mobile stays at 390px. JPEG quality 28 keeps all 80 captures under the 5 MB budget.
Automated checks decode every image and check full-document overflow. Reduced
motion makes captures deterministic except for the intentionally random logo.
Before/after basenames match. Both full-page contact sheets were opened for review.

Lighthouse uses 13.6.0 and Playwright Chromium. Mobile uses default simulated
throttling. Desktop uses 1440 × 900, 40ms RTT, 10,240 Kbps, 1× CPU.
CSS and JS byte counts are decoded bytes, including inline code/styles and imported
JavaScript modules, excluding JSON-LD. They are per-page totals, not compressed
network transfer. The existing shared validation module accounts for 90,083 bytes
on pages with forms; this pass does not change or add that dependency.

## Results

Scores are Performance / Accessibility / Best practices / SEO. Each row covers
both mobile and desktop, which returned the same scores.

| Page | Before | After |
| --- | --- | --- |
| Home | 100 / 100 / 100 / 100 | 100 / 100 / 100 / 100 |
| About | 100 / 100 / 100 / 100 | 100 / 100 / 100 / 100 |
| Support | 100 / 96 / 100 / 100 | 100 / 100 / 100 / 100 |
| Privacy | 100 / 100 / 100 / 100 | 100 / 100 / 100 / 100 |
| Guide | 100 / 100 / 100 / 100 | 100 / 100 / 100 / 100 |

The requested all-100 baseline was not true for support. Lighthouse identified
the submit label at 4.01:1 on #007aff. Action blue is now #0066cc in light and
#0070e0 in dark. The decorative protein accent remains #007aff.
Lighthouse is a lab check, not a guarantee of WCAG conformance or field speed.
Existing unused-JavaScript and render-blocking advisories remain unscored warnings.

| Page | CSS before | CSS after | JS before | JS after |
| --- | ---: | ---: | ---: | ---: |
| Home | 27,419 | 27,433 | 103,206 | 103,206 |
| About | 27,419 | 27,433 | 103,206 | 103,206 |
| Support | 27,419 | 27,433 | 93,770 | 93,770 |
| Privacy | 27,419 | 27,433 | 669 | 669 |
| Terms | 27,419 | 27,433 | 669 | 669 |
| Guides index | 27,419 | 27,433 | 669 | 669 |
| Guide | 27,419 | 27,433 | 669 | 669 |
| Blog index, scratch | 27,419 | 27,433 | 669 | 669 |
| Blog post, scratch | 27,419 | 27,433 | 669 | 669 |
| 404 | 27,419 | 27,433 | 669 | 669 |

### Validation

- `bun run check`, `bun run build`, `make lint-js`, and `git diff --check` pass.
- `verify.mjs` and `verify-articles.mjs` run through this audit. Seven public
  routes, canonical/meta/schema, FAQ agreement, hidden drafts/feed, real 404,
  seven contents anchors, three diagrams, four screenshots, and mocked form
  submissions after navigation pass. No real request is stored.
- `verify-og.mjs` passes clean/repeat builds, isolated title invalidation, and
  scratch publication. All seven social image names, bytes, and hashes match the
  baseline. The social generator and metadata source files have no changes.
- Eight public/missing routes and two scratch blog routes pass all 40 after
  viewport/theme checks. The same 40 baseline captures are included.
- Axe color-contrast checks pass in dark mode on every captured route, including
  scratch blog pages. Lighthouse supplies the light-mode scored checks above.
- Normal-motion article screenshot reveals settle to opacity 1 and remove their
  reveal attributes. The existing navigation/reveal E2E also passes. Reduced-motion
  captures show complete content. Legal text bodies have no reveal attributes.
- The Impeccable detector returns `[]`. JS lint initially flagged evidence-script
  spacing and an array filter/map chain; both were fixed without suppressions.
- No production dependencies, new client JS, native edits, or deployment. Every
  audit Worker and browser is closed in cleanup. Evidence is about 4.5 MB.

### Intentionally unchanged

- Homepage sections, marketing copy, legal meaning, article content, and SEO stay
  as supplied. No copy rewrite means no new health or product claims. The unslop
  guidance was read; moved copy retains its original words.
- Editorial reading widths and smaller legal/article h2 sizes serve long-form
  reading. They already use the type tokens and should not become display headings.
- Article screenshots retain their responsive AVIF/WebP pipeline and original app
  chrome rather than receiving a second decorative device bezel.
- Raw black in the device island is physical artwork; black in masks is opacity,
  not theme color. Hairlines, focus outlines, SVG geometry, Apple badge clear space,
  and small motion offsets remain literal measurements. Equal light surface values
  stay separate semantic tokens because their dark-mode values differ.
- The homepage comparison table's existing checkmarks and FAQ chevron are outside
  this inner-page pass. No new emoji or text-glyph icons were introduced.

### Repeat

From the isolated worktree root, install with `bun install --cwd web` and put
Lighthouse 13.6.0 / Playwright 1.64.1 in ignored `build/seo-tools/`. Then run
`bun run --cwd web build` and `bun docs/evidence/web-consistency/audit.mjs after`.
The optional third argument selects an archived baseline web directory;
`--screens` skips Lighthouse without replacing its preserved baseline report.
Run `bun docs/evidence/web-og/verify-og.mjs` separately for social determinism.
Never treat auditing the changed site as a fresh baseline.

Open question for the owner: approve the shared darker action blue and the reused
FeatureGlyph illustrations on About/support. Deployment remains a separate review.
