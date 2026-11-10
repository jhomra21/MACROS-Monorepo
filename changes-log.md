# Changes Log

Current history. Older records retain their original wording and dated limitations.

See the [app archive index](docs/history/app/README.md) for every archived heading. See [plans](docs/plans/README.md) for current obligations.

## 2026-11-10 Share sheet polish

The "Post an image" sheet now has a system close button instead of "Done", a larger preview (309 pt on iPhone 17e) with the pickers, caption field and Copy caption visible without scrolling, a smooth size and detail change, a success haptic on copy, and a "Caption copied" note that fades in on the Caption header. Native first: no haptic on the pickers, no spinner in the Share button (it is only disabled while rendering) and no style on the toolbar Share Menu. Keyboard overlap is unverified on the simulator. UI 17/17 and unit 263/263 on the 17e; see [evidence](docs/evidence/unified-sharing/README.md#round-3-polish).

## 2026-11-10 Share menu and full height sheet

Owner feedback on build 34: Home's share button now opens a menu with "Post an image" and "Live sharing". "Post an image" opens the Share sheet, which now opens at full height; the "Share with a person" row is gone from it. "Live sharing" opens the Sharing dashboard (Pro with sharing on, subtitle "With N people") or setup. See [evidence](docs/evidence/unified-sharing/README.md#round-2-menu-and-full-height). Shipped as version 1.0 build 35 from `9d476e7` (delivery `bc0cf2fb-44a4-44f4-b396-566ca7978db0`, uploaded 13:43 CST).

## 2026-11-10 TestFlight build 34 and weekly pace labels

Weekly pace labels now show true values: 0.25 / 0.5 / 0.75 kg and 0.55 / 1.1 / 1.65 lb per week. They had been rounded half-to-even to one decimal place (0.2 / 0.5 / 0.8 kg); the pace math was unchanged. Version 1.0 build 34 was archived from `4d274ac` and uploaded to App Store Connect (delivery `cdee4f3d-2ba5-4195-a4a6-6a51e9657af4`). It includes the Share sheet, saved-food delete with Undo, the Pro legal links and the AMDR macro presets. The release build has the HealthKit and app group entitlements and the photo add-only usage string, and it contains no UI-test fixture code. Processing, tester groups and What to Test are still owner steps in App Store Connect.

## 2026-11-10 Share sheet and person row

Home's share button now opens a Share sheet instead of sharing straight away: a live preview, Story (1080x1920), Post (1080x1350) or Square (1080x1080), detail Rings, Macros (default) or Full, and a caption ("My macros today, tracked with MACROS. macrosios.com") that is copied when Share is tapped. A "Share with a person" row opens the Sharing dashboard with the number of connected people (Pro with sharing on), or setup otherwise; offline never blocks the image. Food names never appear. Save Image saved nothing on the simulator until `NSPhotoLibraryAddUsageDescription` was added. Validated with a new XCUITest target on fixtures (7 red, then 11 green) and 262 unit tests; see [evidence](docs/evidence/unified-sharing/README.md).

## 2026-11-08 Website Learn hub

The header's Guides and Blog links are now one Learn link to a new `/learn/` page, which lists published guides and blog posts in two groups with links to each full index. Learn is marked current on `/learn/` and on every guides and blog page; their URLs are unchanged. The guides and blog indexes and every article's closing line now link to the other section, and the footer's Company group adds Learn. The page has its own title, description, sitemap entry, breadcrumb, and social image. Not deployed.

## 2026-11-08 Website brand lockup

The header and footer logos now read "MACROS" with "Nutrition Tracker" beneath it, at the same visible width. A shared inline SVG gives both lines one `textLength`, so the width holds at every text size and zoom without client JavaScript; the subtitle is inset by the wordmark's larger side bearings. Measured ink widths matched to 0.13px or better at 320, 390, and 1280px, 200% text, and light and dark, and stayed within 0.5px across seven installed Windows fonts. The brand links are named "MACROS Nutrition Tracker home". Social images add the subtitle under the wordmark, scaled to the wordmark's ink width (`macros-rings-3`); their final Helvetica look still needs a macOS build. Not deployed.

## 2026-11-07 USDA v1 nutrition basis

v1 USDA search, packaged search, and details now reuse the v2 normalizer. FDC Branded nutrients are per 100 g or per 100 ml by serving unit, and are now scaled to the label's gram or ml serving, so build 23 shows per-serving values (2026852: 519 → 270 kcal per 52 g, matching the printed label). Volume servings (`MLT`, `ml`) never get `gramsPerServing`, so beverages and oils are not gram-loggable at an assumed density of 1. A Branded record with an unknown unit or size keeps its unscaled values on a "100 g or ml" serving without grams, and Foundation, SR Legacy, and Survey records stay "100 g". This also changes v2, which gave volume foods a 100 g serving. `GRM` now counts as grams for v1 and v2, and gram serving text without a household serving renders as "<size> g" whatever the upstream spelling. v1 values are rounded and its names and brands are display-cased like v2, so v1 details now produce the same repair key as v2 search; before, only some v2 foods (100 g servings with values unchanged by rounding) matched. Foods saved by older builds through v1 match only when the new fields happen to agree; otherwise repair marks them not repairable. The USDA v1 cache keys and the v2 USDA source-page key carry a basis version so a deploy does not serve 24 h of stale values; Open Food Facts and barcode keys are unchanged. Worker tests, runtime QA, Convex integration, and lint pass; the round 2 live `DEMO_KEY` check hit the hourly quota, so captured FDC JSON was replayed instead. Not deployed. See [evidence](docs/evidence/usda-v1-basis/README.md).

## 2026-11-07 Saved food Undo: cross-provider duplicates and VoiceOver countdown

Undo now refuses to restore an external saved food when the same product was saved again through the other lookup provider. It matches by external product ID or by barcode across `barcodeLookup` and `searchLookup`, using the existing Open Food Facts barcode aliases, so 12- and 13-digit forms of one barcode match. Before, a USDA food deleted, rescanned through Open Food Facts, then undone was inserted as a duplicate. VoiceOver is now part of the Undo countdown's task identity: turning it on mid-countdown keeps the banner, and turning it off starts a fresh 5-second countdown instead of leaving the banner up for good. E2E ran red then green through a loopback fixture for the lookup proxy and a photo-picked barcode; it also covered AX5 layout and Undo failures on Add Food and the meal picker. Format, build, and 262 iPad tests pass. See [evidence](docs/evidence/delete-saved-foods/README.md).

## 2026-11-07 Undo for deleted saved foods

Deleting a saved food now shows a "Deleted ‹name›" banner with Undo for 5 seconds, on untinted Liquid Glass. Undo re-inserts the exact row (same UUID, every field, timestamps, `searchableText`) and refreshes Add Food, the meal picker (re-selecting the food if it was selected), and Settings. Only the latest delete can be undone. The countdown pauses during error alerts and is off under VoiceOver. Root cause of a crash on a full swipe of the last row: `role: .destructive` deletes the UIKit item before the data changes, so a failed save or empty-state row crashed. The swipe is now a red-tinted plain button. A DEBUG-only launch hook forces delete or restore failures for E2E. The evidence script now hashes every column of every log entry and meal snapshot, preserving NULLs. E2E covered full swipe, last rows, repeated deletes, forced failures on all three surfaces, the VoiceOver Delete action, meal-guard updates, meal history, and re-adding an external food. Format, build, and 262 iPad tests pass; iOS 26 was not run (only the iOS 27 runtime is installed). See [evidence](docs/evidence/delete-saved-foods/README.md).
## 2026-11-07 Delete saved foods

Added a native trailing swipe-to-delete for saved foods in Add Food's On Device list, the meal builder's food picker, and Settings' saved food lists. Common seed foods and foods used by saved meals offer no action; their existing editor still explains the meal block. Log entries and logged meals are snapshots with a plain food ID, so deletion leaves diary history, totals, widgets, Health sync versions, and shared-day data unchanged. E2E store digests matched before and after deletes; format, build, and 262 tests pass. A confirmation-dialog first draft crashed UICollectionView and was replaced. See [failure modes and evidence](docs/evidence/delete-saved-foods/README.md).

## 2026-11-07 AMDR macro presets

Moved the goal calculator presets inside the adult AMDRs (protein 10–35%, carbs 45–65%, fat 20–35%): Balanced 30/40/30 → 20/50/30, High protein 40/30/30 → 31/47/22, and Low carb 35/20/45 → renamed Higher fat at 20/47/33, keeping the stored raw value `lowCarb` so existing profiles and backups decode. The edge presets stop a few points inside the limits because 5 g rounding moves saved shares by up to about 2 points; a replay of every target from 1,200 to 4,500 kcal finds none outside the AMDR. Saved goals change only when the user taps Continue. The macro goals guide, AMDR chart, calculator steps, and launch post now use the new presets and worked example (130/320/85 g); the website needs a separate deploy. See [evidence](docs/evidence/amdr-macro-presets/README.md).

## 2026-11-06 Website feature screenshots

Revised the crops to fill continuous cover frames without letterboxing. Logging extends its sampled app background; Privacy starts at food rows; Portion uses the compact scan-review controls; Widgets shows only the medium personal widget on real wallpaper. Four reduced-motion 2× captures, web checks, nine Worker tests, build and lint pass; desktop AVIFs total 77,398 bytes.

Replaced the six home feature glyphs with deterministic app screenshot crops and responsive AVIF/WebP images, preserving copy and motion. Personal widget crops exclude shared data. Web checks, nine Worker tests, build, lint, and six viewport/theme captures pass; desktop images total 58 KB at 1×. See [crop rectangles and visual evidence](docs/evidence/web-feature-images/README.md).

## 2026-11-05 StoreKit test timing

Stabilized StoreKit test delivery/reset ordering, moved Ask to Buy test IPC off the main actor, and retained cold legacy-refresh coverage without changing app entitlement behavior. Legacy publication timing reproduced; the historical Ask to Buy timeout's blocking site remains unproven. Validation: ten independent 15/15 StoreKit passes, 262/262 remaining tests, formatting, build, and catalog checks pass. See [evidence and same-process stress limitation](docs/evidence/storekit-test-timing/README.md).

## 2026-11-05 Apple configuration paths

Moved the three Info plists and StoreKit catalog to `config/apple/`, updating Xcode, the shared scheme, validation tooling, and active docs without changing configuration contents or source. Validation: build, plist/settings, StoreKit config, lint, formatting, links, bundle parity and 262 tests pass; Xcode 26.4 StoreKit tests execute zero tests because the iPad destination is unavailable, reproduced on unchanged `a12f579`.

## 2026-11-05 Repository cleanup

Corrected tooling/purchase docs, split scoped instructions, moved development guides and status-indexed plans, and archived old history. Removed approved old evidence media while retaining build-33 captures and text reports; untracked personal scheme metadata. Linux-only quality CI and the rule migration checklist are in the [cleanup record](docs/repo-cleanup-plan.md). Native/web and offline checks pass; no release/device gate was closed.
