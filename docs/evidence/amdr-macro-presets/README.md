# AMDR macro presets

## Scope

The goal calculator (Settings → Recalculate Targets, and onboarding's "Calculate my targets") offers three macro presets in the "Macro balance" picker on the Your targets screen. `GoalCalculator.macroGrams` turns calories into rounded grams from each preset's protein/carb/fat percentages. Presets appear nowhere else in the app: widgets, Settings Daily Goals, and the dashboard show saved grams only. The chosen preset is stored as `BodyProfile.macroPresetRaw` and in backups.

Adult AMDRs: protein 10–35%, carbohydrate 45–65%, fat 20–35% of energy ([National Academies, DRI for Energy and Macronutrients, 2005](https://nap.nationalacademies.org/read/10490); the guide also cites the 2024 Table 3-1).

## Mapping

| Preset (stored raw value) | Old P/C/F % | New P/C/F % | Name |
| --- | --- | --- | --- |
| `balanced` | 30 / 40 / 30 | 20 / 50 / 30 | Balanced (owner decision) |
| `highProtein` | 40 / 30 / 30 | 31 / 47 / 22 | High protein. Protein as high as rounding allows while every saved share stays inside the AMDR. |
| `lowCarb` | 35 / 20 / 45 | 20 / 47 / 33 | Renamed **Higher fat** (Swift case `higherFat`, raw value unchanged). Carbs cannot go below 45%, so "Low carb" would be untrue. Its defining trait was the most fat; 33% is the most fat of the three. |

Why not the exact range edges (35/45/20 and 20/45/35)? `GoalCalculator.macroGrams` rounds each macro to 5 g and then raises carbs so the grams cover the calorie target. That moves the saved energy shares by up to about 2 points. At the edges, 2,846 of 3,301 whole-kcal targets (1,200–4,500 kcal) for High protein and 1,524 for Higher fat would save grams with a share outside the AMDR. With 31/47/22 and 20/47/33, none do. The same reason is in the `GoalMacroPreset` doc comment.
## Failure modes (written before implementation)

1. A preset definition falls outside any adult AMDR, or its percentages do not total 100%.
2. 5 g rounding and the carb calorie adjustment push the saved grams' real energy shares outside the AMDR more than the definition implies, and docs claim more precision than the app delivers.
3. A preset keeps a name its numbers no longer support ("Low carb" at 45% carbs).
4. Existing users' saved Daily Goals change without them saving: on launch, when opening Settings, or when opening Recalculate Targets without tapping Continue.
5. Renaming breaks decoding: a stored or backed-up `lowCarb` profile falls back to Balanced or fails to restore.
6. Reopening Recalculate Targets does not preselect the user's saved preset under its new name.
7. Another surface (onboarding, Settings, widgets) still shows old names or percentages.
8. The website guide, AMDR chart, calculator steps, screenshot alt text, or launch post still quote old percentages or say presets fall outside the AMDR.
9. The guide's worked example (Male, 30, 70 kg, 175 cm, Moderate, Maintain, Balanced) shows grams the app no longer produces.
10. Existing calculator tests (sum to 100%, totals within 2%) fail.

## Evidence and results

Raw artifacts are in the ignored folder `build/evidence/2026-11-07-amdr-macro-presets/`. The tracked replay script is `preset-shares.py` in this folder.

E2E device: iPhone 17e simulator (F976E800), iOS 26. The baseline was the app build already installed from `origin/main`, with demo data. The branch Debug build was installed over it as an upgrade, without erasing. Store rows were read read-only from the App Group `default.store` with `sqlite3`.

| # | Verification | Result |
| --- | --- | --- |
| 1 | `preset-shares.py` asserts each definition sums to 100% and sits inside every AMDR. | Pass for all three presets. |
| 2 | `preset-shares.py` replays `macroGrams` (Swift half-away-from-zero rounding) for every whole kcal target from 1,200 to 4,500 and checks the saved shares. | 0 of 3,301 targets outside the AMDR for each preset. Realized ranges: Balanced P 19.05–20.65, C 48.25–52.38, F 28.12–31.52; High protein P 29.92–31.62, C 45.76–49.62, F 20.30–23.25; Higher fat P 18.97–20.58, C 45.80–49.66, F 31.03–34.35. The guide says presets stop short of the range limits because of rounding; it makes no exact-share claim. |
| 3 | Picker shows the new names. | `preset-menu.png`: Balanced, High protein, Higher fat. No "Low carb" anywhere in app or web source (`rg`). |
| 4 | Baseline build: Recalculate, choose Low carb, Continue. Then upgrade, launch, open Settings, open Recalculate, change presets, and Cancel. | Baseline saved goals 2,755/240/145/135, profile `lowCarb`. After upgrade, Settings, and Cancel, goals, profile, and both `ZUPDATEDAT` timestamps were byte-identical (`store-0`, `store-1`, `store-2`). |
| 5 | Stored `lowCarb` decodes after the rename; Continue stores it again. | Upgraded app preselected Higher fat from the stored `lowCarb` row. Continue saved 2,740/135/325/100 with raw value still `lowCarb` (`store-3`). Backups encode the same raw value; the existing `BodyProfileDraftTests` save/restore tests pass with `.higherFat`. |
| 6 | Reopening Recalculate preselects the saved preset under its new name. | `upgrade-higher-fat.png`: "Higher fat" preselected, 2,740 kcal, 135/325/100 g. |
| 7 | Other surfaces. | The preset appears only in `TargetReviewScreen`, which onboarding and Settings both use. Widgets, Settings Daily Goals, and the dashboard show saved grams only. |
| 8 | Website text. | Guide table, paragraph, worked steps, sources; `AMDRChart`; `CalculatorSteps`; screenshot alt text; launch post updated. `rg` finds no old names or percentages. `bun run check` (0 errors) and `bun run build` pass. |
| 9 | Worked example in the app: Male, 30, 175 cm, 70 kg, Moderate, Maintain. | Balanced 2,565 kcal, 130/320/85 g (`worked-balanced.png`); High protein 2,560 kcal, 200/305/60 g (`worked-high-protein.png`); Higher fat 2,575 kcal, 130/300/95 g (`worked-higher-fat.png`). All match the replay script and the guide. Cancel left the store unchanged (`store-4`). |
| 10 | Full suite on iPad E91B597B, serial. | 262 passed, 0 failed (`PurchaseStoreStoreKitTests` skipped as instructed); includes the existing calculator tests for 100% sums and totals within 2%. |

Notes: during E2E the iPhone's weight unit was switched to kilograms through the app's Log Weight picker (no weight was logged) so the worked example could use 70 kg exactly. Screenshots are 390×844 agent-device captures.

Guide screenshot: `web/src/assets/app-images/app-calculator-review.png` was replaced with a 1320×2868 capture from the media simulator D16C3D35 (iPhone 18 Pro Max, demo data). The status bar was overridden to 9:41 with Wi-Fi and a full battery, then cleared. It shows the worked example: Balanced, 2,565 kcal, 130/320/85 g. The branch Debug build was installed over the device's existing app (also version 1.0 build 33, installed Nov 4) for the capture and left installed. Goals were never saved: the store (goals 2,200/150/240/70, profile, 432 entries) was identical before and after. The Nov 6 demo day still totals 1,310 kcal. `src/lib/social.ts` uses this image for `/guides/` social cards, so that card's image hash changes on the next site build.
