# Website de-slop pass

Design pass on macrosios.com (`web/`) to remove template "AI-slop" patterns while keeping the brand: the SF system font stack, light and dark themes, the macro ring colours and logo, the #0066cc / #0070e0 buttons, the hero, real screenshots, view transitions, section order, and every price and fact.

`sheet.png` shows before (origin/main `ba8613b`) on the left and after on the right. The top row is the Pro pricing section and the bottom row is the full home page, both at 1440 px in light mode.

## What changed

- Pro pricing: the three equal cards, featured gradient card, badge pill, and coloured check lists are gone. "Your food diary is free." leads. Pro is one offer with its three prices in an iOS-style grouped list. The plans note and a quieter compare table stay.
- Feature bento: no accent glow, eyebrow labels, or hover lift. Same images and layout.
- No scroll-reveal fade on every section, so the site ships less client JS. The hero entrance and the ring draw stay.
- About and support: glyph-topped cards became plain text columns and lists. `FeatureGlyph.astro` was deleted.
- Showcase cards lost their card surface and hover scale. The filler lead was removed.
- Radii are now 16, 12, and 8 px. Button hover darkens the fill instead of lifting it. Section bands alternate. The closing waitlist block is left-aligned with no box. Breadcrumb links have 24 px targets.

## Checks

Captured with Playwright (Chromium) against `wrangler dev` on the built site, with reduced motion and DPR 1. On all eight routes (home, about, support, guides index, guide, privacy, terms, 404):

- axe found 0 `color-contrast`, `target-size`, or `link-in-text-block` violations in light or dark.
- There's no horizontal scroll at 320 px.
- No interactive element outside running text is under 24 px.
- The browser logged no page errors.

The other checks pass: `bun run check`, `bun test src/worker.test.ts` (9 pass), `bun run build`, root oxlint (0 warnings, 0 errors), `git diff --check`, and `impeccable detect` on the changed files (0 findings).

Raw captures, the audit, and the scripts are in ignored `build/evidence/2026-11-07-web-deslop/` and `build/deslop-tools/`.
