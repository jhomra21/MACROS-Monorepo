# App Store screenshot plan

The refreshed screenshot set is for a later Custom Product Page / Product Page Optimization test and as a candidate 1.1 default. Do not change the approved 1.0 default screenshots while the app is Pending Developer Release; that would restart review.

Apple's current [screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications) accept these portrait iPhone sizes:

- iPhone with Dynamic Island, medium display: **1179 × 2556** or **1206 × 2622**
- iPhone with Dynamic Island, large display: **1320 × 2868** (also 1260 × 2736 or 1290 × 2796)

The generated set uses 1179 × 2556 for medium and 1320 × 2868 for large. Each image has a short benefit-led caption and a real app screen, scaled inside the canvas with rounded screen corners. No device bezel artwork is used. Both sizes come from real 9:41 captures of Debug build 1.0 (39), commit `dc6b2bf0b374b0e273ba18acf3675fb2026ce104`; small-device outputs are scaled from the same native media-simulator captures.

## Screenshot order

Full-size PNGs and a contact sheet are in ignored `build/evidence/2026-11-23-appstore-creative/screenshots-v2/`. Renderer source is [screenshots-v2/render.mjs](screenshots-v2/render.mjs).

| # | Caption | Screen | Reason |
| --- | --- | --- | --- |
| 1 | **Scan any label** | Oat Crunch label review | Leads with the one-camera scan flow and reviewable OCR result. The generic label name was entered manually because OCR did not identify it confidently. |
| 2 | **Your day at a glance** | Home | Shows 1,310 kcal, macro rings, logged foods, and goals from synthetic demo data. |
| 3 | **No account needed** | Add Food | Logging works without an account; the screen shows generic on-device foods and no branded remote results. |
| 4 | **Log the amount you ate** | Grams quantity editor | Shows the editable food details and grams quantity mode. |
| 5 | **See your food history** | History | Replaces the old Insights beat with a screen freshly captured from build 39. |
| 6 | **Goals built around you** | Goal Calculator review | Shows editable estimated targets and the non-medical disclaimer. |

The former seven-beat plan is retired. It included a priced paywall; Apple guideline 2.3.7 prohibits prices and pricing terms in screenshots and previews. These six images contain no paywall or pricing.

The original proposed sharing-choice image was replaced: this media simulator had no synthetic connected person, and making one would require remote sharing writes. No such write was authorized or made. A Home Screen widget was available and is captured separately in the raw evidence, but History is the fifth screenshot-set beat. If the owner wants a share-choice screenshot later, capture it from an isolated demo profile and confirm its source and state before submission.

## Review notes

- Use synthetic food and goal data only. Do not use real names, health data, or user stores.
- No third-party brands or logos are shown. Add Food uses on-device generic saved foods.
- Captions are benefit-led and avoid unsupported medical claims. The goal calculator itself says estimates are not medical advice.
- No Apple, competing-platform, price, discount, subscription, free-trial, or paywall claims appear.
- Apple's live screenshot rules require iPad screenshots if this app is configured to run on iPadOS. This capture set covers only the requested iPhone sizes; confirm the supported-device configuration and add iPad media if needed before upload.
- Review every final crop in App Store Connect before future release. Do not upload or change listing state as part of this task.
