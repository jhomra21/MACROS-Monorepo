# Label Scan Screenshot Retake

- Source: `origin/main` at `8ebd989`; published retake commit: `da00bef`.
- Device: `D16C3D35-889F-404F-BDD4-C640A6DBC4EF` (iPhone 18 Pro Max, iOS 27.0), build 28 Debug, light appearance, default text size, 9:41 status bar.
- Before and after: `before-app-scan-review.png`, `after-app-scan-review.png`; `comparison-before-after.png` places both captures side by side.
- Photo: `label-photo.png`, a generated printed cereal package label with “Oat Crunch Cereal” above a Nutrition Facts panel. The panel says 1 cup (40 g), 190 calories, 5 g protein, 36 g carbs, and 3 g fat.
- Name detection: Vision OCR read the printed product name above the Nutrition Facts block. The parser uses the last readable line before that block as the inferred food name. The camera result showed “Oat Crunch Cereal” without the OCR warning; no text was manually entered and no screenshot pixels were edited.
- Result: the card shows the name, serving, nutrients, servings stepper, Edit details, and Log. The concentric camera frame and back glass control remain visible. The shutter and options controls are hidden by the app while a scan result is frozen (`FrozenHidden`); they cannot be included in this result-state capture without changing app code, which was out of scope.
- Validation: `bun run check`, `bun run build`, and `make lint-js` passed. `web/package.json` defines no `lint` script.
- Deployment: Wrangler version `4.156.0`, Worker version ID `8cc7b030-e31c-4308-93fa-08445bd1b226`. The package `bun run deploy` stopped at its remote D1 migration with Cloudflare authorization error 7403, before deployment; no migration was applied. The built site was then deployed directly with `wrangler deploy`.
- Live check: the homepage served `/_astro/app-scan-review.DUYMjPyC_ZGyNo3.webp`, `/_astro/app-scan-review.DUYMjPyC_ZQjQn2.webp`, and `/_astro/app-scan-review.DUYMjPyC_topt9.webp`; each returned HTTP 200.
- Simulator photo cleanup: two generated label photos remain in Photos. `xcrun simctl addmedia` has no removal operation; no other library items were changed.
