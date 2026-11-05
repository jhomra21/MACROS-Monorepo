## 2026-10-27 Camera Inline Results

- Replaced the idle camera spinner with a viewfinder hint and made parsed label results editable and loggable in the camera panel, with the existing editor available only through Edit details. Barcode results remain in place.
- Save failures preserve the editable review and surface a retryable alert; expanded results scroll within a bounded camera panel. Validation: FoodCameraFlowTests 25/25 and BarcodeImageScannerTests 3/3 passed; E2E partially passed (onboarding, dashboard, idle hint), photo-picker scenarios not verified because the device automation daemon was unavailable. Evidence: `build/camera-inline-2026-10-27/QA.md`.
- 2026-10-27 T3 recheck: built the exact branch checkout successfully, but the pinned iPhone 18 Pro's first agent-device interaction failed because the host Xcode could not start its simulator service on this macOS. Scenarios A–D remain unverified; no code change was made. Details: `build/camera-inline-t3-qa-2026-10-27/QA.md`.
- 2026-10-27 follow-up: on one iPhone 18 Pro simulator, idle hint and complete-label Photos import/name editing were verified; empty name disabled Log and entering `test oats` enabled it. The servings stepper reached 1.5 but not the requested 2, so save/totals, incomplete-label, and barcode flows remain unverified after UI automation became unavailable. No code changes or tests were made. Cleanup accidentally deleted the existing shut-down iPhone 18 Pro simulator; a fresh shut-down replacement was created, but its prior local data cannot be restored. The 12-screenshot cap was exceeded; exact capture count is unknown. Evidence: `build/camera-inline-2026-10-27/r2/QA.md`.
- 2026-10-27 device-tool follow-up: confirmed the Xcode `simctl` wrapper version check invokes `xcodebuild -runFirstLaunch`; the installed CoreSimulator `simctl` binary successfully booted and shut down the replacement device. T3 omitted that UUID from its catalog; fresh `agent-device open` failed with `Remote daemon is unavailable`, and one health request to the configured local port was connection-refused. No new UI QA was possible; details are in the r2 report.
- 2026-10-27 native T3 E2E completed the camera paths on the existing iPhone 18 Pro: complete label OCR edited to Test oats and logged at two servings (300 kcal, 10 g protein, 54 g carbs, 6 g fat); incomplete label required-nutrient warnings disabled in-camera logging and Edit details retained two servings; EAN-13 resolved to Thai peanut noodle kit and logged at two servings (400 kcal, 10 g protein, 74 g carbs, 8 g fat). Complete-label Edit details now uses secondary bordered emphasis beside Log. Format and app build passed; see `build/camera-inline-t3-qa-2026-10-27/QA.md`.

## 2026-10-27 Dashboard Dynamic Type Legend

- Replaced the fixed-height macro legend with a horizontal default-size layout and stacked accessibility-size layout so the legend can grow without overlapping dashboard content. Simulator check on the dedicated iPhone 17 Pro: default and XXXL pass with horizontal columns and no Today-header overlap; AX5 shows one macro per row and icon-only bottom pills, with no overlap against the Today navigation title. The simulator could not be scrolled to frame the full legend, streak line, and Today / items header together, so that combined view remains unverified. Evidence: `build/legend-ax-2026-10-27/QA.md`.

## 2026-10-27 Simulator Barcode Detection

- Confirmed the simulator's oldest supported Vision revision decodes the EAN-13 fixture; device behavior is unchanged and all still-image barcode errors continue to label OCR.
- Simulator E2E: EAN `0737628064502` resolved to Thai peanut noodle kit includes stir-fry rice noodles & thai peanut seasoning (Simply Asia / Thai Kitchen), `0.333 PACKAGE (52 g)`, 200 kcal, 5 g protein, 4 g fat, 37 g carbs. At 2 servings it logged 400 kcal, 10 g protein, 8 g fat, 74 g carbs. The all-zero fixture showed the unknown-product recovery actions; dismissing after selecting the real EAN returned to the same one-item dashboard without a crash. The earlier “no product” result came from selecting the all-zero fixture. Screenshots and exact checks: `build/sim-barcode-e2e-2026-10-27/QA.md`.
- Validation: `make quality-format-check`, `make quality-build`, `git diff --check`, BarcodeImageScannerTests (3/3), and FoodCameraFlowTests (21/21) passed.

## 2026-10-26 TestFlight Build 8

- Archived merged `main` commit `6d6ce5054eabbe845a739e0fe5f9f1e2b1d6ae3d` as version 1.0; Xcode advanced the duplicate build 7 to build 8 and App Store Connect accepted the upload for processing.
- Formatting, build, StoreKit configuration, and 60 targeted tests passed; simulator camera, seeded Insights, and purchase UI checks remain unverified. Evidence: `build/build8-preflight-2026-10-26/QA.md`.

## 2026-10-26 Unified Food Camera

- Replaced the dashboard's single Add Food action with equal Camera and Add Food pills (icon-only while scrolling and at accessibility text sizes) and routed the barcode and label entry points through one full-height camera sheet: live barcode recognition with a product panel, servings stepper, Log, and Details; shutter or photo-library capture into label OCR that always lands in review; still-camera and library-only fallbacks; a guarded torch toggle. Removed the separate barcode and label screens.
- The flow is a pure `FoodCameraFlow` reducer whose effects (scanner start/stop, torch, work cancellation, content) the sheet executes in order; 21 reducer tests written from the failure-mode map cover duplicate recognition, double shutter, library open/cancel/replace, backgrounding, navigation-away versus dismissal, failures, and quantity.
- Validation: format, build, reducer tests, and simulator QA (library label import to review, Back, Retake, same-image reselection, sheet dismissal and reopen, entry points, accessibility sizes) passed; barcode-from-library lookup, live scanning, torch preview stability, and real-package OCR need an EAN-13 fixture or a device. Evidence in `build/unified-camera-qa-2026-10-26/QA.md`.

## 2026-10-26 Insights Long Ranges

- Added 90D, 1Y, and All Pro ranges with day-accurate summaries, no All-time comparison, weekly/monthly average charts, and an accessibility-friendly native menu picker.
- Validation: format/build and InsightsAnalyticsTests (16/16) passed; simulator QA verified seeded history, All/90D/1Y and free locked-range behavior, with visual evidence in `build/insights-qa-2026-10-26/`.

## 2026-10-26 Insights Review Fixes

- Omitted unlogged days from daily chart points while retaining day-accurate summaries; corrected the All-range six-calendar-month threshold; extended the bounded weight query by seven days for comparison while keeping trend points in range.
- Added five analytics coverage tests and split chart bucketing, chart views, and shared chart components into focused files. Format, simulator build, and InsightsAnalyticsTests (21/21) passed. Review-specific seeded UI checks were not rerun.

## 2026-10-26 JavaScript and TypeScript Dependency Updates

- Updated package manifests and Bun lockfiles across the workers, Astro site, Convex backend, runtime QA, food database, and Oxlint tooling; detailed version changes and migration notes are in [`implementation-trackers/dependency-update-tracker.md`](../../../docs/plans/archive/dependency-update-tracker.md).
- Validation: package checks, tests, integrations, build, dry runs, and lint passed; Convex code generation was run from the configured checkout after the merge.

## 2026-10-26 MACROS Pro Paywall Success Flow

- Opened the Pro paywall at the large detent only and added transition-only success feedback, entitlement details, unlocked benefits, and context-aware dismissal.
- Validation: formatting, app build, and simulator StoreKit purchase QA passed; screenshots and per-check results are in `build/paywall-success-qa-2026-10-26/QA.md`.

## 2026-10-26 StoreKit Test Failure Investigation

- Fixed StoreKit tests to model the documented purchase cancellation outcomes and to wait for transaction-listener publication; sync after `SKTestSession.expireSubscription` so the simulated expiry reaches StoreKit status updates.
- Validation: StoreKit 15/15 and Pro entitlement 18/18 passed on Xcode 26.4/iOS 27.0; format, build, and StoreKit catalog validation passed.

## 2026-10-26 Local StoreKit Simulator Repair

- Captured real-price light and dark Pro paywall screenshots and recorded the Xcode/runtime probe matrix plus StoreKit test outcomes in `build/storekit-repair-2026-10-26/QA.md`.
- Validation: Xcode 26.4 + iOS 27.0 catalog activation passed; 18/18 Pro entitlement tests passed, while four StoreKit cases failed or timed out.

## 2026-10-26 TestFlight Upload (WS10)

- Archived commit `44e9551b66c90418b30de76e70d24377900a3ebf` and uploaded version 1.0/build 7 to App Store Connect; archive signing includes HealthKit and the app group.
- Validation: preflight formatting, build, StoreKit config, Release settings, device archive, and App Store Connect upload passed; physical-device QA remains with the owner.

## 2026-10-26 WS7 Close-out

- Audited Add Food spacing and Pro entry points; fixed paywall plan rows at the largest accessibility text size. Barcode `429` camera verification remains assigned to TestFlight.
- Validation: format, build, 18 Pro entitlement tests, and simulator entry-point/layout QA passed; evidence is in `build/ws7-qa-2026-10-26/closeout/QA.md`.

## 2026-10-26 Backup Export and Import (WS6)

- Added versioned JSON backup and log CSV export, validated DTO import with Merge/Replace, common-food preservation, settings restore, summary review, and Pro-gated Settings controls.
- Follow-up: imports now validate before one atomic background-context save, restore bundled-food references by source identifier, and use pinned destructive Replace/primary Merge actions. Stable rows plus a single Backup-header presentation host fix the iOS 27 duplicate-presenter failure; both the sheet and parent clear successful presentation.
- Review fixes validate profile bounds, all reminder times, ring hex through the palette parser, and every DTO date before mutation; settings round-trip tests now use separate destination defaults and failed Replace checks use different incoming settings.
- Validation: formatting, quality build, 15 backup tests and 1 migration test pass; prior simulator Files export, uninstall/reinstall Replace, overlapping Merge, automatic dismissal, full document parity, and Dashboard/History/Insights/Settings comparisons pass (`build/ws6-qa-2026-10-26/QA.md`).

## 2026-10-25 Bundled Common Food Database (WS4 follow-up)

- Follow-up: use stable FNDDS food-code identifiers, deterministic single-claim reconciliation, and capped collision-safe names. Regenerated 3,283 foods from the October 2024 archive; manifest `fndds-2024-10-31-43e9e747b198`.
- Stable FNDDS/legacy source identifiers now reconcile renamed common foods in place, remove stale unreferenced foods while retaining meal-linked rows, and cap display qualifiers at three segments while preserving the complete source description as an alias.
- Final follow-up bundle: 3,281 foods, manifest `fndds-2024-10-31-442a6db2598e`; additively migrated `FoodItem.sourceIdentifier` and validated stale-row retention against the existing pre-meal store fixture.
- Review follow-up: deduplicate by full food identity before display-name capping and retain extra qualifiers only when needed to distinguish variants; restored both dry and reconstituted instant-coffee variants. Bundle: 3,283 foods, manifest `fndds-2024-10-31-4807bc73432b`.
- Expanded the USDA FNDDS bundle to 3,199 foods (October 2024 release; public domain, 17 U.S.C. § 105), preserving legacy serving/nutrient values and recording source archive provenance. Added deterministic common-name aliases and plural-insensitive, phrase-aware local ranking with explicit match tiers and stable ordering.
- Follow-up: curated 112 everyday query mappings (97 unique exact food targets), included their aliases and ordered priorities in the rebuilt manifest, and applied priorities before stable within-tier tie-breakers in local food search.
- Validation: food pipeline checks/tests (8 tests, 61 assertions), JS lint, Swift format, N+1 smoke, quality build, `FoodItemLocalSearchTests` (8/8), `LogEntryQueryTests` (3/3), and `MealSchemaMigrationTests` (1/1) passed. The final live in-app 50-query audit scored 50/50; captured top-three results and the updated bundle version/size are in ignored `build/ws4-qa-2026-10-25/final-build/QA.md`. Earlier bootstrap/search timings are unchanged measurements from the previous bundle, not remeasured here. Earlier two `LocalConfidenceTests` Vision/inference failures remain as documented in the QA report.
