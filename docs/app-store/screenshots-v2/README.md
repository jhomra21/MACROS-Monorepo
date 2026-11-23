# Screenshot set v2

This renderer creates six later-use App Store screenshots from fresh build-39 captures. All six share the same layout: a pale solid background, a large bold dark benefit caption at the top, and one nearly full-width app screen below it. The screen bleeds past the bottom edge to keep the UI large and legible. The renderer checks that captions do not clip or overlap the screen and that each screen extends below the canvas.

It writes opaque, embedded-sRGB PNGs at 1320 × 2868 (6.9-inch) and 1179 × 2556 (Dynamic Island medium) to the ignored `build/evidence/2026-11-23-appstore-creative/screenshots-v2/` directory. It also writes `contact-sheet.png` and `search-result-preview.png`; the latter places the first three screenshots side by side for legibility review.

## Captions and source screens

1. **Scan any label** — generic Oat Crunch scan review.
2. **Your day at a glance** — Home with 1,310 kcal and four synthetic food logs.
3. **No account needed** — on-device Add Food list.
4. **Log the amount you ate** — saved-food editor with grams selected.
5. **See your food history** — real History screen.
6. **Goals built around you** — estimated targets review and non-medical disclaimer.

The share-choice screen is intentionally omitted. This simulator had no linked synthetic participant, and setting one up would make remote sharing writes. A current Home Screen widget is separately captured in the raw evidence, but it is not included as a screenshot-set beat. The alternative screenshots show existing, verified functionality rather than mock UI.

## Run

From `docs/app-store/`:

```sh
bun install --frozen-lockfile
bun screenshots-v2/render.mjs
```

Captures must exist under `build/evidence/2026-11-23-appstore-creative/captures/`. The input filenames and screenshot captions are declared in `render.mjs`. Apple review, crops, and acceptance remain Apple's decision.
