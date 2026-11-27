# Screenshot set v2

This renderer creates seven App Store iPhone screenshots with the existing captions, font, and pale background, using Apple's official iPhone bezel. The captures come from the DEBUG synthetic-data fixture on a light-mode simulator with the default text size.

## Capture provenance

- App source: `release/1.2` at `eedbe624b12d2d75f39e31e03777f29eddfe0caf`, plus temporary uncommitted capture-only edits (below)
- Simulator: iPhone 17e, iOS 27.0, 1170 × 2532 pixels, status bar overridden to 9:41, discharging, 100%, 4 cellular and 3 Wi-Fi bars (no charging bolt), cleared afterwards
- Bezel: [Apple Design Resources, Product Bezels](https://developer.apple.com/design/resources/), iPhone 17, Black, portrait
- Bezel source PNG: `build/evidence/2026-11-27-appstore-frames2/official-bezel/iphone-17-black-portrait.png` (ignored; not committed)
- Raw captures: `build/evidence/2026-11-27-appstore-frames2/captures/` (ignored)

Apple does not provide an iPhone 17e bezel, so the iPhone 17 bezel is used as the closest matching display aspect ratio. The measured transparent screen opening is `x=72, y=69, width=1206, height=2622` in the bezel's 1350 × 2760 PNG, with an approximately 194 px corner radius.

Apple's download is a DMG (`https://devimages-cdn.apple.com/design/resources/download/Bezel-iPhone-17.dmg`, linked from the Product Bezels page). Mount it read-only, accept the Apple Design Resources license, and copy `PNG/iPhone 17/iPhone 17 - Black - Portrait.png` to the ignored path above. Do not add the DMG or extracted bezel PNG to Git. The composites are Apple-platform UI mock-ups; recipients must be made aware of the Apple Design Resources restrictions and must not extract or reuse the bezel artwork.

## Captions and source screens

1. **Scan any label**: Oat Crunch Cereal label review (190 kcal, P 5, C 36, F 3). A still of the fixture label, shrunk and centered on a dark canvas, is fed through `MACROS_FIXTURE_CAMERA_IMAGE`, so the Retake button and round back button sit on empty background and never touch the label or the "Nutrition Facts" heading. The name was entered in the editable review because OCR does not identify it.
2. **Snap a photo of your meal**: Add Food, Scan a meal, with the DEBUG `-MealPhotoMockResponse typical-plate` response trimmed to two matched items (grilled salmon 120 g, brown rice 180 g, total 469 kcal). The review screen does not show the photo. No error banner, oil alert, or prices.
3. **Your day at a glance**: Today with the demo logs.
4. **No account needed**: Add Food list with on-device foods.
5. **Log the amount you ate**: chicken-and-rice food editor with Nutrition rows, Quantity set to Grams, 400 g. The navigation bar is made opaque for this capture so scrolled content does not ghost behind it.
6. **See your food history**: History with the synthetic day's logs.
7. **Goals built around you**: Settings, Daily Goals, from the top.

Temporary capture-only source edits (never committed, saved as `temporary-source-edits.diff` next to the persistent captures): an opaque toolbar background and extra bottom scroll margin in `LogFoodScreen`, and the mock fixture trimmed to two items. A temporary UI test drove the app and saved `XCUIScreen.main.screenshot()`.

## Render

The renderer writes seven 1260 × 2736 and seven 1179 × 2556 PNGs, `contact-sheet.png`, `search-result-preview.png` (first three shots side by side), and a `screenshots.json` manifest to the ignored `build/evidence/2026-11-27-appstore-frames2/out/` directory.

From `docs/app-store/`:

```sh
bun install --frozen-lockfile
bun screenshots-v2/render.mjs
```

The caption sits at 2.6% of the canvas height. The phone starts 3.5% of the height below the caption and is enlarged until it hits a 5% side margin or a 2% bottom margin, whichever comes first (the side margin binds). It is centered on the visible phone frame within 1 px, upright, and fully visible. The renderer also checks canvas bounds, opaque output, and six sample points near the top corner arcs, side edges, and lower edge, where the capture must match the composite. The PNGs are converted to embedded sRGB.
