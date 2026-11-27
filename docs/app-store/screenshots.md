# App Store screenshot plan

The refreshed screenshot set is for a later Custom Product Page / Product Page Optimization test and as a candidate 1.1 default. Do not change the approved 1.0 default screenshots while the app is Pending Developer Release; that would restart review.

Apple's current [screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications) accept these portrait iPhone sizes:

- iPhone with Dynamic Island, medium display: **1179 × 2556** or **1206 × 2622**
- iPhone with Dynamic Island, large display: **1260 × 2736**, **1290 × 2796**, or **1320 × 2868**

The refreshed set uses 1179 × 2556 for medium and 1260 × 2736 for large. All six share a pale background, large bold dark benefit caption, and a complete, centered iPhone with all four rounded corners visible. The phone uses Apple's official black iPhone 17 portrait bezel and sits below the caption with comfortable side and bottom margins. On 2026-11-27, all six screens were recaptured from `release/1.2` commit `b0b099e77ea1c259c50349320cc21d587c106ab4` using the DEBUG synthetic-data fixture on an iPhone 17e simulator (iOS 27.0, light mode, 9:41). See [the renderer README](screenshots-v2/README.md) for the bezel source, measured opening, and capture details. The separate 1.0 header and search creatives remain based on build 39.

## Screenshot order

Full-size PNGs, `contact-sheet.png`, and `search-result-preview.png` are in ignored `build/evidence/2026-11-27-appstore-frames/out/`. Renderer source is [screenshots-v2/render.mjs](screenshots-v2/render.mjs).

| # | Caption | Screen | Reason |
| --- | --- | --- | --- |
| 1 | **Scan any label** | Oat Crunch label review | Leads with the one-camera scan flow and reviewable OCR result. The generic label name was entered manually because OCR did not identify it confidently. |
| 2 | **Your day at a glance** | Home | Shows 1,310 kcal, macro rings, logged foods, and goals from synthetic demo data. |
| 3 | **No account needed** | Add Food | Logging works without an account; the screen shows generic on-device foods and no branded remote results. |
| 4 | **Log the amount you ate** | Grams quantity editor | Shows the editable food details and grams quantity mode. |
| 5 | **See your food history** | History | Replaces the old Insights beat with a freshly captured synthetic log history. |
| 6 | **Goals built around you** | Daily Goals in Settings | Shows editable daily targets and the recalculation entry point. |

The former seven-beat plan is retired. It included a priced paywall; Apple guideline 2.3.7 prohibits prices and pricing terms in screenshots and previews. These six images contain no paywall or pricing.

The original proposed sharing-choice image was replaced: the media simulator had no synthetic connected person, and making one would require remote sharing writes. No such write was authorized or made. A Home Screen widget was available and is captured separately in the 1.0 raw evidence, but History is the fifth screenshot-set beat. If the owner wants a share-choice screenshot later, capture it from an isolated demo profile and confirm its source and state before submission.

## Review notes

- Use synthetic food and goal data only. Do not use real names, health data, or user stores.
- No third-party brands or logos are shown. Add Food uses on-device generic saved foods.
- Captions are benefit-led and avoid unsupported medical claims. The goal calculator itself says estimates are not medical advice.
- No Apple, competing-platform, price, discount, subscription, free-trial, or paywall claims appear.
- Apple's live screenshot rules require iPad screenshots if this app is configured to run on iPadOS. This capture set covers only the requested iPhone sizes; confirm the supported-device configuration and add iPad media if needed before upload.
- Review every final crop in App Store Connect before future release. Do not upload or change listing state as part of this task.
