# Plain app screens instead of a CSS device frame

Branch `web/no-device-frames`, based on `origin/main` `1aad16e`. No deployment.

## Decision

Apple's [App Store marketing guidelines](https://developer.apple.com/app-store/marketing/guidelines/) forbid any simulation of an Apple product. They also say to show apps only inside Apple-provided product bezels. The official bezels are licensed under the App Store Marketing Artwork License Agreement. Section 1 of that agreement covers only apps "available for download on the App Store", and only while the developer is in the Apple Developer Program. MACROS is not live yet (`site.appStore.live` is `false`), so the owner chose not to download or use the bezels. The owner did not accept the agreement.

Instead, `AppScreen.astro`, formerly `DeviceFrame.astro`, shows each real screenshot as a plain rounded screen:

- The corner radius is `9% / calc(9% * 1320 / 2868)`, a circular corner about 9% of the width on the 1320 × 2868 capture.
- A 1px `--hairline` overlay keeps white and black screens distinct on both page backgrounds.
- No shadow, tilt, hover, or animation is applied. The hero image no longer uses the `rise` entrance, so it is static whether or not reduced motion is set.
- The CSS bezel, ring, side buttons, island, and `--device-*` tokens were removed. The image pipeline and its byte cost are unchanged (no new assets: 0 bytes added).

The social-image generator composites the plain screenshot and draws no device, so it was left unchanged. `web/SEO.md` now records the rule and when bezels may be added.

## Repeat

From `web/`: `bun install --frozen-lockfile && bun run check && bun test src/worker.test.ts && bun run build`. Then run `bunx wrangler dev --port 8792` and capture `/` (hero) and `#showcase` at 1440 × 900 and 390 × 844, in light and dark (`agent-browser set media light|dark`).

`contact-sheet.jpg`, top row: 1440 hero light/dark, then showcase light/dark. Bottom row: the same at 390. Raw PNGs are in ignored `build/evidence/2026-11-06-no-device-frames/`.
