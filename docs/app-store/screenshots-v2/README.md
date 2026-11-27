# Screenshot set v2

This renderer creates six App Store iPhone screenshots with the existing captions, font, pale background, and order, using Apple's official iPhone bezel. The six screenshots are captured from the DEBUG synthetic-data fixture on a light-mode simulator with the default text size.

## Capture provenance

- App source: `release/1.2` at `b0b099e77ea1c259c50349320cc21d587c106ab4`
- Simulator: iPhone 17e, iOS 27.0, 1170 × 2532 pixels, 9:41 status bar
- Bezel: [Apple Design Resources, Product Bezels](https://developer.apple.com/design/resources/), iPhone 17, Black, portrait
- Bezel source PNG: `build/evidence/2026-11-27-appstore-frames/official-bezel/iphone-17-black-portrait.png` (ignored; not committed)

The iPhone 17 simulator was locked by another task. The iPhone 17e was the requested fallback. Apple does not provide an iPhone 17e bezel in this bundle, so the iPhone 17 bezel was used as the closest matching display aspect ratio. The measured transparent screen opening is `x=72, y=69, width=1206, height=2622` in the bezel's 1350 × 2760 PNG, with an approximately 194 px corner radius.

The simulator was set to light appearance. The camera review itself uses the app's intentionally dark camera presentation, so screenshot 1 is dark while the other five screens are light.

Apple's download is a DMG that presents the Apple Design Resources license on first mount. After accepting the license, download the DMG from the official Product Bezels page, mount it read-only, and copy `PNG/iPhone 17/iPhone 17 - Black - Portrait.png` to the ignored path above. Do not add the DMG or extracted bezel PNG to Git. The composites are Apple-platform UI mock-ups; recipients must be made aware of the Apple Design Resources restrictions and must not extract or reuse the bezel artwork.

## Captions and source screens

1. **Scan any label** — Oat Crunch Cereal label review; 190 kcal, 5 g protein, 36 g carbs, and 3 g fat. The name was corrected in the editable review because OCR did not identify it confidently.
2. **Your day at a glance** — Home with demo logs and no decimal-format artifacts.
3. **No account needed** — on-device Add Food list, without branded remote results.
4. **Log the amount you ate** — chicken-and-rice food editor with Grams selected and 400 g visible.
5. **See your food history** — History with the synthetic day's logs.
6. **Goals built around you** — Settings → Daily Goals, captured from the top of Settings.

The share-choice screen remains intentionally omitted. Creating a synthetic connected participant would require remote sharing writes.

## Render

The raw UI-test captures belong under `build/evidence/2026-11-27-appstore-frames/captures/`. The renderer writes six 1260 × 2736 and six 1179 × 2556 PNGs, `contact-sheet.png`, `search-result-preview.png`, and a `screenshots.json` manifest to the ignored `build/evidence/2026-11-27-appstore-frames/out/` directory.

From `docs/app-store/`:

```sh
bun install --frozen-lockfile
bun screenshots-v2/render.mjs
```

The renderer measures the screen opening and corner radius from the bezel alpha, fits each capture into that opening, centers the visible phone within 2 px, and checks caption spacing, canvas bounds, opaque output, and six sample points near the top corner arcs, side edges, and lower edge. The PNGs are converted to embedded sRGB. Apple's review and acceptance remain Apple's decision.
