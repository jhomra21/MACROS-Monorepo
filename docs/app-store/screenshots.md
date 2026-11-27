# App Store screenshot plan

The refreshed screenshot set is for a later Custom Product Page / Product Page Optimization test and as a candidate 1.1 default. Do not change the approved 1.0 default screenshots while the app is Pending Developer Release; that would restart review.

Apple's current [screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications) accept these portrait iPhone sizes:

- iPhone with Dynamic Island, medium display: **1179 × 2556** or **1206 × 2622**
- iPhone with Dynamic Island, large display: **1260 × 2736**, **1290 × 2796**, or **1320 × 2868**

The refreshed set uses 1179 × 2556 for medium and 1260 × 2736 for large. All seven share a pale background, large bold dark benefit caption, and a complete, centered iPhone with all four rounded corners visible. The phone uses Apple's official black iPhone 17 portrait bezel and sits just below the caption with equal 5% side margins. On 2026-11-27, all seven screens were captured from `release/1.2` commit `eedbe624b12d2d75f39e31e03777f29eddfe0caf` using the DEBUG synthetic-data fixture on an iPhone 17e simulator (iOS 27.0, light mode, 9:41). See [the renderer README](screenshots-v2/README.md) for the bezel source, measured opening, and capture details. The separate 1.0 header and search creatives remain based on build 39.

## Screenshot order

Full-size PNGs, `contact-sheet.png`, and `search-result-preview.png` are in ignored `build/evidence/2026-11-27-appstore-frames2/out/`. Renderer source is [screenshots-v2/render.mjs](screenshots-v2/render.mjs).

| # | Caption | Screen | Reason |
| --- | --- | --- | --- |
| 1 | **Scan any label** | Oat Crunch label review | Leads with the one-camera scan flow and reviewable OCR result. The name was entered manually because OCR does not identify it. |
| 2 | **Snap a photo of your meal** | Meal photo review | Shows matched foods, grams, and a calorie total from the DEBUG mock response. |
| 3 | **Your day at a glance** | Home | Shows 1,310 kcal, macro rings, logged foods, and goals from synthetic demo data. |
| 4 | **No account needed** | Add Food | Logging works without an account; the screen shows generic on-device foods and no branded remote results. |
| 5 | **Log the amount you ate** | Grams quantity editor | Shows the editable nutrition rows and grams quantity mode. |
| 6 | **See your food history** | History | Shows a synthetic log history. |
| 7 | **Goals built around you** | Daily Goals in Settings | Shows editable daily targets and the recalculation entry point. |

The former seven-beat plan is retired. It included a priced paywall; Apple guideline 2.3.7 prohibits prices and pricing terms in screenshots and previews. These seven images contain no paywall or pricing.

The original proposed sharing-choice image was replaced: the media simulator had no synthetic connected person, and making one would require remote sharing writes. No such write was authorized or made. If the owner wants a share-choice screenshot later, capture it from an isolated demo profile and confirm its source and state before submission.

## Review notes

- Use synthetic food and goal data only. Do not use real names, health data, or user stores.
- No third-party brands or logos are shown. Add Food uses on-device generic saved foods.
- Captions are benefit-led and avoid unsupported medical claims. The goal calculator itself says estimates are not medical advice.
- No Apple, competing-platform, price, discount, subscription, free-trial, or paywall claims appear.
- Apple's live screenshot rules require iPad screenshots if this app is configured to run on iPadOS. This capture set covers only the requested iPhone sizes; confirm the supported-device configuration and add iPad media if needed before upload.
- Review every final crop in App Store Connect before future release. Do not upload or change listing state as part of this task.
