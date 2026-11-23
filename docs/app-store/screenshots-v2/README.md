# Screenshot set v2

This renderer creates six later-use App Store screenshots from fresh Debug build **1.1 (40)** captures. The app was built from `origin/main` commit `2da0f08c7991460e27a9880893d30b8b7e00d086` and captured on the iPhone Air simulator, iOS 27.0, at 9:41. Its six captures are kept separate from the build-39 inputs for the 1.0 header and search creative.

All six share the same layout: a pale solid background, a large bold dark benefit caption at the top, and one nearly full-width app screen below it. The screen bleeds past the bottom edge to keep the UI large and legible. The renderer checks that captions do not clip or overlap the screen and that each screen extends below the canvas.

It writes opaque, embedded-sRGB PNGs at 1260 × 2736 (iPhone with Dynamic Island, large display) and 1179 × 2556 (medium display) to the ignored `build/evidence/2026-11-23-appstore-screenshots-1.1/screenshots-v2/` directory. It also writes `contact-sheet.png` and `search-result-preview.png`; the latter places the first three screenshots side by side for legibility review.

## Captions and source screens

1. **Scan any label** — generic Oat Crunch scan review.
2. **Your day at a glance** — Home with 1,310 kcal and four synthetic food logs.
3. **No account needed** — on-device Add Food list.
4. **Log the amount you ate** — saved-food editor with grams selected.
5. **See your food history** — real History screen.
6. **Goals built around you** — editable Daily Goals in Settings and the recalculation entry point.

The share-choice screen is intentionally omitted. The simulator had no linked synthetic participant, and setting one up would make remote sharing writes. The alternative screenshots show existing, verified functionality rather than mock UI.

## Run

From `docs/app-store/`:

```sh
bun install --frozen-lockfile
bun screenshots-v2/render.mjs
```

Captures must exist under `build/evidence/2026-11-23-appstore-screenshots-1.1/captures/`. The input filenames and screenshot captions are declared in `render.mjs`. Apple review, crops, and acceptance remain Apple's decision.
