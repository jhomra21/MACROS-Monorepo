# Screenshot set v2

This renderer creates six later-use App Store screenshots with a complete, centered iPhone frame. The 2026-11-25 refresh keeps the existing captions, type, pale background, and order. Each phone sits below its caption with about 7.5% horizontal margins and at least 4% below the frame. The bezel uses a clean graphite-and-silver CSS frame, with all four rounded corners visible.

Five screens were captured on the iPhone Air simulator (iOS 27.0, 9:41) with the DEBUG synthetic-data fixture. The Scan screen reuses its clean build 40 source capture. Captures used build settings 1.1 (40) from app source commit `2da0f08c7991460e27a9880893d30b8b7e00d086`. Goals was captured from a clean top-of-Settings state, avoiding the prior scrolled-through status-bar artifact. Screens are embedded inside the frame without cropping. The renderer checks that captions do not clip or overlap the phone and that the phone remains within the canvas.

It writes opaque, embedded-sRGB PNGs at 1260 × 2736 (iPhone with Dynamic Island, large display) and 1179 × 2556 (medium display) to the ignored `build/evidence/2026-11-25-appstore-screenshots-1.2/screenshots-v2/` directory. It also writes `contact-sheet.png` and `search-result-preview.png`; the latter places the first three screenshots side by side for legibility review.

## Captions and source screens

1. **Scan any label** — Oat Crunch Cereal review after correcting the OCR name; 190 kcal, 5 g protein, 36 g carbs, and 3 g fat.
2. **Your day at a glance** — Home with 1,310 kcal and four synthetic food logs.
3. **No account needed** — on-device Add Food list.
4. **Log the amount you ate** — chicken-and-rice editor with Grams selected and 400 g visible.
5. **See your food history** — real History screen.
6. **Goals built around you** — editable calorie and macro targets with the recalculation entry point; freshly captured from a clean top-of-Settings state.

The share-choice screen is intentionally omitted. The simulator had no linked synthetic participant, and setting one up would make remote sharing writes. The alternative screenshots show existing, verified functionality rather than mock UI.

## Run

From `docs/app-store/`:

```sh
bun install --frozen-lockfile
bun screenshots-v2/render.mjs
```

Captures must exist under `build/evidence/2026-11-25-appstore-screenshots-1.2/captures/`. The input filenames and screenshot captions are declared in `render.mjs`. Apple review, crops, and acceptance remain Apple's decision.
