# Feature card screenshots

Verified locally November 6, 2026. No deployment or simulators.

`sheet.png` (under 180 KB) shows element captures of `#why`: 1440 × 900 light and dark, 390 × 844 light, and 768 × 1024 light. All use device scale 2, reduced motion, decoded lazy images and completed reveals. JPEGs use quality 82 and maximum width 1440. Raw captures and browser measurements are in ignored `build/review/`; the four JPEGs are published on `tmp/feature-images-review`.

## Crops

Deterministic rectangles in `tools/media/feature-crops.mjs`, from original 1320 × 2868 screenshots. Coordinates: left, top, width, height.

| Card | Source | Rectangle | Output ratio |
| --- | --- | --- | --- |
| Logging | app-home.png | 0, 350, 1320, 1140; extend 460 px each side | 2240:1140, 1.965:1 |
| Scanning | app-scan-review.png | 48, 160, 1224, 834 | 1.468:1 |
| Privacy | app-history.png | 20, 1110, 1280, 956 | 1.339:1 |
| Your portion | app-scan-review.png | 96, 470, 1128, 574 | 1.965:1 |
| Sharing | app-sharing.png | 58, 432, 1204, 730 | 1.649:1 |
| Widgets | app-widgets.png | 0, 880, 1320, 690 | 1.913:1 |

Logging's extension uses the source edge colour, #f2f2f7. Other crops remain unaltered. Frame backgrounds use sampled source corner colours, not theme surfaces. All images use cover with centered positioning. Desktop frames remain 304 px high; smaller breakpoints retain the crop ratio so text and rings stay intact.

The expanded scan-details screenshot spreads the controls too far apart for readable wide framing. Portion therefore uses scan-review's Servings stepper, “1 cup (40 g) each”, “40 g total”, and footer buttons. This compact source does not show the Servings/Grams segmented control; alt text describes the visible controls only.

The source places Alex beside the small widget above the medium personal widget. Following the user's clarification, Widgets uses only the medium personal widget, with real wallpaper around its rounded corners. No repainting, compositing, or shared widget fragments.

## Validation

Frozen Bun installation, web check (48 files, zero diagnostics), nine Worker tests, production build, root Oxlint (135 files, zero findings), and `git diff --check` pass. The build has a nonfatal Fontconfig default-config warning. The design detector reports no findings.

At 1440 px and 2×, selected AVIF bytes are Logging 11,284; Scanning 10,925; Privacy 17,837; Portion 7,683; Sharing 15,769; Widgets 13,900. Total: **77,398 bytes**, identical in light and dark.

All four JPEGs and the contact sheet were opened and visually inspected: no letterboxing, no isolated wallpaper slivers or Alex fragments, readable desktop portion stepper and serving summary, and food rows at Privacy's top edge. Browser assertions confirm six decoded cover images fill their frames and no horizontal overflow. Picture, AVIF/WebP, responsive sizes, lazy loading, reveal animation, and card text are preserved. The final diff was reviewed for redundant code.

## Repeat

Install `web/` dependencies with `bun install --frozen-lockfile`. Install `playwright@1.65.0` in ignored `build/feature-tools/`. From the root run `bun tools/media/feature-crops.mjs`, then build the website. Start `cd web && bunx wrangler dev --port 8790`, run `bun tools/media/capture-feature-images.mjs` from the root, and stop the server afterward.
