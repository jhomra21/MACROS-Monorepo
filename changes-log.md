# Changes Log

`changes-log.md` is the canonical project history file for implemented work, bugs found, decisions made, and validation results.

## History and Calendar

### Delivered

- Reworked History to feel closer to Apple's Fitness-style flow.
- Replaced the old navigation-title setup with a custom top bar.
- Replaced the old date navigator with a compact week strip.
- Kept calendar expansion inline inside the same card.
- Reused the shared macro ring renderer for compact weekday rings.
- Extended summary plumbing so the week strip uses shared per-day nutrition snapshots.

### Main implementation steps

- `HistoryScreen.swift` now owns the custom header, selected date, and calendar expansion state.
- `HistoryWeekCard`, `HistoryWeekStrip`, and `HistoryWeekdayCell` keep the week selector and inline calendar inside one glass container.
- `LogEntryDaySummary.swift` and `ModelSupport.swift` were extended instead of adding screen-local date logic.
- `LogEntryListSection.swift` was updated so History can hide duplicate header context.

### Bug fixed

- Calendar selection could crash when leaving History after interacting with the iOS inline calendar.
- Cause: the custom `UICalendarView` bridge introduced a UIKit/SwiftUI teardown problem after selection.
- Fix: removed the bridge from `HistoryCalendarView.swift` and used SwiftUI's graphical `DatePicker` on iOS with normalized start-of-day binding.

### Navigation regression: custom History header

#### What went wrong

- We hid the native navigation bar on pushed `HistoryScreen` and replaced it with a custom overlay header.
- That removed SwiftUI's native back-button and back-swipe behavior from the screen that actually needed to pop.
- We then chased the regression with manual fixes that were wrong for this stack setup:
  - custom close callbacks from History back into parent state
  - explicit `dismiss()` coordination
  - a UIKit bridge that manually re-enabled `interactivePopGestureRecognizer` and cleared its delegate
- Those attempts were band-aids. They added complexity without restoring the supported navigation behavior.

#### Root cause

- In this codebase, `HistoryScreen` is a pushed SwiftUI destination inside `NavigationStack`.
- The pushed screen must keep supported SwiftUI navigation semantics if we want reliable native back behavior.
- Hiding the nav bar on that pushed screen and trying to recreate navigation manually broke that contract.
- The real bug was not the calendar view itself, nor root path ownership, but replacing native pushed-screen navigation with a custom header and UIKit gesture hack.

#### Incorrect approach

- Hiding the nav bar on `HistoryScreen` with `.toolbar(.hidden, for: .navigationBar)`.
- Replacing the pushed screen's back affordance with `AppTopHeader`.
- Mutating `interactivePopGestureRecognizer.delegate = nil` from a custom `UIViewControllerRepresentable`.
- Treating parent callbacks or manual dismiss calls as a substitute for native pushed-screen navigation.

#### Correct approach

- Keep native navigation behavior on pushed `HistoryScreen`.
- Use `.navigationTitle(selectedDate.historyNavigationTitle)` and `.inlineNavigationTitle()`.
- Keep the calendar action as a normal toolbar item.
- Reserve custom headers for places where we are not replacing the pushed screen's native back/pop contract, or where we fully own the navigation shell in a supported way.

#### What actually fixed it

- Restored native navigation chrome on `HistoryScreen`.
- Removed the hidden-nav-bar setup from History.
- Removed the custom interactive-pop UIKit bridge entirely.
- Kept the content-spacing fix separately, since the top-offset issue was real but unrelated to the back-navigation failure.

## Scan Flows

### Delivered

- Added barcode scan entry from `AddFoodScreen`.
- Added nutrition label scan entry from `AddFoodScreen`.
- Added live barcode scanning with `VisionKit.DataScannerViewController` where supported.
- Added still-image barcode fallback with `VNDetectBarcodesRequest`.
- Added OCR-based label scanning with `VNRecognizeTextRequest`.
- Kept `FoodDraft` as the only editable contract and `LogFoodScreen` as the only review/logging surface.
- Reused `FoodItemRepository` for local cache lookup and reusable-food persistence.
- Added Settings editing support for scan-derived reusable foods.

### Main implementation steps

- Lowered device targeting to strict iPhone and aligned the project with iOS-first validation.
- Added camera and photo-library usage descriptions.
- Extended `FoodSource`, `FoodItem`, and `FoodDraft` only where scan provenance required it.
- Built local-first barcode resolution: local cache first, then Open Food Facts, then editable review.
- Built conservative nutrition label parsing without inventing hidden gram conversions or nutrients.
- Kept scan capture, recognition, parsing, mapping, and persistence as separate responsibilities.

### Bugs and implementation findings

- iOS 16 deployment target was not viable because the existing app already relied on SwiftData, Observation, and `ContentUnavailableView`; deployment target was corrected to iOS 17.
- A shared `PhotosPickerItem` abstraction added compile friction and unnecessary indirection; picker handling was moved back into the screens.
- Duplicate camera/photo glue between barcode and label flows was reduced by extracting `ScanCameraCaptureSheet.swift`.
- Barcode symbology support initially used unsupported assumptions around `.upca`; the implementation was corrected to `.ean13`, `.ean8`, and `.upce`, and `Vision` imports were fixed.
- Barcode save flow could crash because a temporary SwiftData identifier escaped an isolated context; the repository now returns stable app IDs and reloads in the main context.
- Barcode nutrient mapping originally mixed per-serving and per-100g bases; mapping was changed to use one consistent nutrition basis.
- Label scan originally paused on an unnecessary intermediate review step; the flow now goes straight into `LogFoodScreen`.
- Today-list quick actions were moved onto native list rows so swipe behavior is actually native.

### Validation recorded during scan work

- iOS simulator builds passed.
- Duplicate blocks, tech debt, dependency inventory, and n+1 smoke checks passed.
- At that stage, formatter and dead-code commands were present in the repo but the required local tools were not yet installed, so those scripts skipped cleanly.

## Food Search

### Delivered

- Improved on-device food search quality.
- Added packaged-food text search.
- Kept `AddFoodScreen` as the single search surface.
- Kept `FoodDraft` as the single review contract.
- Kept `LogFoodScreen` as the single review/log destination.
- Kept `FoodItemRepository` as the single reusable-food persistence path.
- Added `FoodSource.searchLookup` for remote text-search provenance.
- Kept remote search rows transient until the user selects and saves/logs a result.
- Kept one saved externally-derived foods area in Settings rather than splitting scan vs search.

### Main implementation steps

- Improved deterministic on-device ranking: exact match, then prefix, then token containment.
- Preserved durable normalized search terms so edits do not silently weaken local search.
- Extended Open Food Facts text search with explicit submit-driven queries and bounded pagination.
- Reused shared remote-to-`FoodDraft` mapping rather than creating a second edit flow.
- Split supporting Add Food views into `AddFoodComponents.swift` and `AddFoodSearchResults.swift` when `AddFoodScreen.swift` exceeded the repo's file-size guardrail.

### Bugs and implementation findings

- `FoodItemRepository` originally deduped by local ID or barcode but not by `(source, externalProductID)`; that gap was closed so selected remote foods reuse the same saved record.
- `FoodItem.searchableText` had a durability risk around aliases during normalization updates; persistence now retains durable normalized search terms.
- Open Food Facts search constraints required submit-driven UX rather than search-as-you-type.
- Restaurant search was intentionally removed from scope to keep the implementation focused and maintainable.

### Validation recorded during food-search work

- iOS simulator `xcodebuild` passed.
- `make quality-build`, `quality-dup`, `quality-debt`, `quality-deps`, and `quality-n1` passed.
- At that stage, `quality-format-check` and `quality-dead` still depended on tooling that was not yet installed locally.

## USDA Proxy and Unified Remote Search

### Delivered

- Added a Bun-managed Cloudflare Worker under `worker/usda-proxy/`.
- Used Hono as a thin routing layer.
- Added a unified `GET /v1/packaged-foods/search` endpoint.
- Kept `GET /v1/usda/search` for direct validation.
- Moved packaged-food text search behind the Worker while leaving barcode lookup client-side.
- Kept Open Food Facts as the primary provider and USDA as bounded fallback.
- Added worker-side timeout, retry, fallback, and short-lived edge caching.
- Added a thin app-side `PackagedFoodSearchClient.swift`.
- Reused a small shared `RemoteSearchResult` wrapper for OFF and USDA results.
- Persisted selected USDA/OFF results using provider-qualified external IDs.

### Main implementation steps

- Added committed Worker config and source files: `package.json`, `tsconfig.json`, `wrangler.jsonc`, `.dev.vars.example`, `src/index.ts`, `src/openFoodFacts.ts`, `src/packagedFoods.ts`, `src/usda.ts`, and `src/types.ts`.
- Declared `USDA_API_KEY` as a required Worker secret and kept it out of app code and repo files.
- Normalized Worker responses to a small app-facing contract instead of shipping raw provider payloads.
- Kept one app-level request path for remote packaged-food search so the app no longer owns OFF-vs-USDA branching.
- Stored the Worker base URL in one generated Info.plist key, `USDA_PROXY_BASE_URL`.

### Bugs and implementation findings

- Bun was standardized for the Worker to avoid mixed package managers.
- With `nodejs_compat`, Wrangler needed `@types/node`; installing it early avoided a failed first check.
- Cache typing did not behave as the first draft expected with `caches.default`, so the Worker now uses `caches.open("usda-proxy")`.
- `secrets.required` works for this setup but still emits an experimental warning during `wrangler types`.
- Page-2 empty Open Food Facts results originally widened to USDA, which would have created mixed-provider pagination; that regression was fixed so only the right request shapes widen.

### Validation recorded during USDA proxy work

- Worker type checks passed with Bun.
- Invalid query requests returned stable `400` JSON errors.
- Mocked Open Food Facts success returned normalized `openFoodFacts` results.
- Mocked Open Food Facts empty responses widened correctly to normalized USDA results when enabled.
- Local `bun run dev` worked with a real USDA key and real packaged-food queries.
- iOS simulator builds and repo quality commands passed.

### Still open operational follow-ups

- Set the production `USDA_API_KEY` Worker secret.
- Deploy the Worker.
- Record the public `workers.dev` URL used by the app.
- Validate deployed responses, cold-cache behavior, and public cache-hit behavior.

## Settings and General UX Follow-ups

### Delivered

- Fixed Settings macro inputs so a single row tap focuses more reliably.
- Added an iOS trailing-caret numeric input bridge so the insertion point appears at the end instead of the beginning.
- Made the Settings save row fully tappable instead of only the `Save` text.
- Ran a Settings-focused SwiftUI review pass; the result was LGTM.

### Main implementation steps

- Updated `NutrientInputField.swift` to make the whole row tappable and adapt focus handling cleanly.
- Added `TrailingCaretNumericTextField.swift` as a small `UIViewRepresentable` escape hatch for iOS numeric entry.
- Updated `DailyGoalsSection.swift` so the full save row acts as the button target.

### Follow-up: inline Settings editor with shared keyboard flow

#### What went wrong

- We repeatedly tried to fix the Settings numeric-field focus bug locally while leaving the screen on a mixed `List`-based container.
- That was the wrong level of abstraction for this codebase:
  - the food-editing flows already used one shared pattern built around `Form`, shared focus state, and `keyboardNavigationToolbar`
  - Settings kept being treated as a browse list with an inline editor bolted into it
- A separate `DailyGoals` editor screen briefly normalized the architecture, but it added an extra tap and was rejected on product UX grounds.

#### Root cause

- The real mismatch was not just the numeric field implementation.
- In this app, the working editing surfaces (`ManualFoodEntryScreen`, `FoodDraftEditorForm`, `LogFoodScreen`, `ReusableFoodEditorScreen`, and `EditLogEntryScreen`) all run inside a `Form` and attach the shared `keyboardNavigationToolbar`.
- Settings was the outlier: inline numeric editing lived inside `SettingsScreen` while the container stayed a `List`, so the screen did not behave like the rest of the app's editing surfaces.
- The first edit in Daily Goals also changed save-state UI, so keeping the editor inside the wrong container made the focus bug easy to re-trigger.

#### Correct approach

- Keep `Daily Goals` inline on the main Settings screen for fast access.
- Reuse the same shared keyboard-toolbar path as the existing food editors instead of inventing a Settings-only toolbar or another screen-local focus system.
- Move the Settings container itself onto `Form`, which is the Apple-documented SwiftUI container for grouped data entry and settings controls.
- Keep browse/navigation content as sections within that same screen for now, but make the editing path use the same focus contract as the rest of the codebase.

#### What actually fixed it

- `SettingsScreen.swift` now uses `Form` instead of `List` while keeping `Daily Goals` inline.
- `SettingsScreen.swift` owns the shared `@FocusState` for `DailyGoalsField`.
- `SettingsScreen.swift` now attaches `.keyboardNavigationToolbar(focusedField: $focusedField, fields: DailyGoalsField.formOrder)`, reusing the existing shared keyboard accessory implementation.
- `DailyGoalsSection.swift` now exposes `DailyGoalsField.formOrder` and consumes the shared focus binding passed from the container, instead of owning a separate screen-local focus path.
- The save action remains in its own section, so the first edit no longer mutates the same input section structure while someone is actively typing.
- This kept the UX inline, removed the extra navigation step, and reused existing shared keyboard behavior instead of duplicating it.

## Branding and App Configuration

### Delivered

- Updated the user-facing app name to `MACROS`.
- Added `CFBundleDisplayName` and updated `CFBundleName` in both `Info-iOS.plist` and `Info-macOS.plist`.

## Quality, Cleanup, and Review

### Delivered

- Ran multiple focused review passes over the working tree and Settings-specific changes.
- Installed Periphery, then upgraded the local CLI to 3.7.2 when Homebrew lagged behind.
- Updated `.periphery.yml` for Periphery 3 compatibility.
- Updated `make quality-dead` and `tools/quality/run_periphery.sh` so Periphery scans the iOS simulator destination.
- Removed genuinely unused code surfaced by Periphery.
- Marked preview-only helpers with `// periphery:ignore` where the code is intentionally retained.

### Bugs and implementation findings

- Periphery initially produced false positives because it scanned the multiplatform scheme without an explicit iOS destination.
- The root fix was to pass `-destination "generic/platform=iOS Simulator"` through the wrapper instead of suppressing warnings.
- After the destination fix, the remaining findings were validated symbol-by-symbol and either removed or intentionally ignored for preview-only usage.

### Final validation state

- `make quality-format-check` passes.
- iOS simulator build passes.
- macOS build passes.
- Worker TypeScript/Bun checks pass.
- `make quality-dead` reports `No unused code detected.`
- Focused review pass on the Periphery cleanup returned LGTM.

## Deferred Work

- Forward edge-swipe navigation from Home into History/calendar was analyzed but intentionally deferred to a later commit because iOS does not provide a native forward interactive edge push equivalent to the back swipe.

## Consolidated Source Docs

The following planning documents have been fully consolidated into this file and can be removed safely:

- `scan-implementation-plan.md`
- `food-search-implementation-plan.md`
- `usda-proxy-implementation-plan.md`
- `off-reliability-and-nutrients-plan.md`

## Macro Ring Architecture Refinement

### Delivered

- Locked in the current macro-ring overlap rendering that the product now considers correct.
- Preserved a single continuous-looking ring with one visible rounded head while a lap overlaps itself.
- Avoided the regressions we hit during iteration: restart seams, detached balls, extra mini-rings, thick overlap bands, and headless full-circle overflow.

### Main implementation steps

- For `progress <= 1`, the ring is a single trimmed arc with a `.round` line cap and a controlled angular gradient from start color to end color.
- For `progress > 1`, the renderer intentionally stops treating the ring as one closed stroke and instead composes four layers:
  1. a nearly full first lap rendered as the base gradient ring
  2. a tiny isolated shadow caster positioned at the active overlap point
  3. a second-lap tail rendered as a solid `gradientEndColor` stroke with a `.butt` start cap
  4. a separate circular tip at the active head to restore the rounded end cap visually
- The tiny `startTrim` offset and `safeOverlap` clamp are part of the contract; they prevent visible restart slices and cap bleed at 12 o'clock.
- `dynamicSingleLapGradient` is tuned so the physical origin stays pinned to the start color while the tip remains brightest at the actual head position.

### Guidelines for Future Architecture Updates

- **Do not collapse the overlap case back into one closed `Circle` stroke.** A closed circle has no real path end, so the rounded head disappears and future fixes tend to reintroduce fake blobs or secondary arcs.
- **Do not add a separate highlight arc on top of the overlap.** That is what created the “extra little ring” / thickened segment regressions.
- **Do not give the second-lap tail a `.round` start cap.** The backward cap shows up as a false restart at 12 o'clock.
- **Keep the head as its own tip circle.** That separate tip is what preserves the same curved head feel the single-lap case already has.
- **If this ever needs visual changes, preserve the contract first:** one continuous ring, one head, no visible restart line, no detached dot, no extra overlap band.

## Daily Macro Widget, Home Screen Shortcuts, and App Entry

### Delivered

- Added a `CalMacroWidget` extension with a daily macro widget.
- Added home screen quick actions for Add Food, Scan Barcode, Scan Label, and Manual Entry.
- Added shared snapshot/value types so the widget and app use the same daily macro representation.
- Reused the shared macro ring renderer instead of maintaining separate app and widget ring implementations.
- Added app-open routing so widget taps and quick actions land in the right app flow.

### Main implementation steps

- Added `DailyMacroWidget.swift`, `CalMacroWidgetBundle.swift`, widget entitlements, and `Info-Widget.plist`.
- Added shared cross-target types and loaders: `AppOpenRequest`, `NutritionSnapshot`, `MacroGoalsSnapshot`, `DailyMacroSnapshotLoader`, `SharedAppConfiguration`, and `SharedModelContainerFactory`.
- Moved the app's persistent container creation onto the shared app-group-backed container so the widget can read the same data.
- Added `WidgetTimelineReloader.swift` so app launches and mutations can refresh widget timelines.
- Updated `AppRootView.swift`, `ContentView.swift`, and `cal_macro_trackerApp.swift` so app-open requests can route into add-food sheets and the dashboard from native entry points.
- Added `HomeScreenQuickActionSupport.swift` and the corresponding iOS shortcut item configuration.

### Bugs and implementation findings

- The widget needed read access to the same persisted data as the app; the real fix was a shared app-group-backed model container rather than a second persistence path.
- Home screen shortcuts and widget URLs are both just app-entry surfaces, so they now map into the same `AppOpenRequest` contract instead of inventing separate routing models.
- Macro ring rendering had already gone through heavy iteration, so the widget work reused the shared renderer rather than cloning another visual implementation.

## Scan Navigation Stability and Root-Level Cleanup

### Delivered

- Stabilized scan result navigation after photo imports.
- Kept `BarcodeScanScreen` and `LabelScanScreen` as stable containers while still routing into `LogFoodScreen`.
- Moved add-food data ownership down to the add-food feature instead of the app shell.
- Centralized day-based `LogEntry` query construction for app and widget callers.
- Reduced quick-action decoding duplication and narrowed scan photo-import sharing to the smallest useful helper.

### Main implementation steps

- Updated `BarcodeScanScreen.swift` and `LabelScanScreen.swift` to drive `LogFoodScreen` through destination state instead of replacing the whole screen body after a successful import/scan.
- Added `Shared/LogEntryQuery.swift` so History, shared snapshot loading, and other day-based readers use the same fetch descriptor construction.
- Trimmed `LogEntryDaySummary.swift` back to snapshot aggregation responsibilities after query construction moved into the shared helper.
- Moved the `FoodItem` query into `AddFoodScreen.swift` and removed that data plumbing from `AppRootView.swift`.
- Added `AppOpenRequest+QuickActions.swift` and simplified `HomeScreenQuickActionSupport.swift` so shortcut items decode once into the shared request model.
- Added a narrow `ScanImageLoading.loadUIImage(from: PhotosPickerItem)` helper while keeping barcode-specific and label-specific orchestration local to their screens.

### Bugs and implementation findings

- The scan navigation regression was not a parsing or OCR problem; the real issue was replacing the scan screen's root body with `LogFoodScreen`, which made the photo-import path less stable inside the surrounding navigation/sheet flow.
- The earlier broad shared `PhotosPickerItem` abstraction was still the wrong level of sharing, but a tiny loader helper was acceptable because it only removes duplicated image-decoding glue and does not hide feature-specific scan behavior.
- Day-based query construction had started to split between app-only history logic and the shared/widget snapshot path; the fix was to centralize descriptor construction in one cross-target helper instead of re-copying date-range logic.
- `AppRootView` had started carrying feature data it did not own; moving the `FoodItem` query back into `AddFoodScreen` restored the intended boundary where the app shell routes and the feature reads its own data.

### Validation recorded during this follow-up

- `make quality-format-check` passes.
- iOS simulator build passes.
- macOS build passes when code signing is disabled for local CLI validation.
- Focused code review on the cleanup diff returned LGTM with no high-confidence findings.

## Shared Draft / Macro / Scan Cleanup

### Delivered

- Added `Shared/MacroMetric.swift` to centralize macro labels, colors, and value access across dashboard and widget surfaces.
- Added `FoodDraftImportedData.swift` so imported food values can be mapped once and reused across barcode, USDA, label-scan, and edit-entry flows.
- Added `FoodQuantitySection.swift` so log/edit quantity controls share one quantity-mode section and one gram-logging guard.
- Added `HTTPJSONClient.swift` to centralize JSON request construction, HTTP response validation, and decoding for network clients.
- Added `ScanStillImageImport.swift` to share the tiny still-image photo-import path between barcode and label flows.

### Main implementation steps

- Replaced repeated protein/carbs/fat view code in `DailyMacroWidget.swift`, `CompactMacroSummaryView.swift`, `DashboardScreen.swift`, and `MacroRingSetView.swift` with `MacroMetric.allCases`.
- Refactored `FoodDraft.swift` so `FoodItem`, `LogEntry`, USDA, barcode, and label parsers all build drafts through shared imported-data initialization instead of repeating field assignment blocks.
- Moved manual food entry onto `FoodDraftEditorForm` so it uses the same form container, keyboard toolbar, and error-banner path as the other food editors.
- Replaced duplicated quantity pickers and gram-mode fallback logic in `LogFoodScreen.swift` and `EditLogEntryScreen.swift` with `FoodQuantitySection`.
- Replaced duplicated request/header/response/decode glue in `PackagedFoodSearchClient.swift` and `OpenFoodFactsClient.swift` with `HTTPJSONClient`.
- Replaced duplicated still-image import handling in `BarcodeScanScreen.swift` and `LabelScanScreen.swift` with `ScanStillImageImport`.

### Code removed / deduplicated

- Removed hand-written macro rows/cards from widget and dashboard surfaces that only differed by macro type.
- Removed repeated `var draft = FoodDraft()` mapping blocks from USDA, barcode, label-scan, and log-entry conversion paths.
- Removed duplicated quantity-section lifecycle code (`onAppear` / `onChange` mode normalization) from both logging screens.
- Removed duplicated photo-import `defer` / `do-catch` glue from barcode and label scan screens.
- Removed duplicated `URLRequest` header setup and ad-hoc `JSONDecoder` call sites from both network clients.

### Validation recorded during this cleanup

- `make quality-format-check` passes.
- iOS simulator build passes.

## Apple Project Folder Reorganization

### Delivered

- Moved the Apple shared/widget source folders under `cal-macro-tracker/` so the native app area now reads more clearly in the repo:
  - `cal-macro-tracker/Shared/`
  - `cal-macro-tracker/CalMacroWidget/`
- Updated `cal-macro-tracker.xcodeproj/project.pbxproj` so the synchronized root groups point at the new folder locations.
- Updated the widget entitlements path to `cal-macro-tracker/CalMacroWidget/CalMacroWidget.entitlements`.
- Added a short `AGENTS.md` note to prefer primary docs or public repo examples when Xcode project behavior is unclear.

### Main implementation steps

- Moved the root-level `Shared/` and `CalMacroWidget/` directories into `cal-macro-tracker/`.
- Updated the Xcode synchronized-group paths from `Shared` / `CalMacroWidget` to `cal-macro-tracker/Shared` / `cal-macro-tracker/CalMacroWidget`.
- Added a `PBXFileSystemSynchronizedBuildFileExceptionSet` on the app target's `cal-macro-tracker/` synchronized root group so widget files are excluded from the app target and shared files are not double-included through both the app root group and the dedicated shared group.
- Narrowed those membership exceptions to explicit relative file paths after validating that folder-level exclusions were not sufficient for this Xcode 16 synchronized-group setup.

### Bugs and implementation findings

- The first naive move was structurally correct on disk but not yet correct in Xcode target membership: once `Shared/` and `CalMacroWidget/` lived under `cal-macro-tracker/`, the app target's synchronized root group started implicitly seeing those files too.
- That produced two concrete symptoms:
  - widget files were pulled into the app target, causing the duplicate `@main` error from `CalMacroWidgetBundle.swift` and `cal_macro_trackerApp.swift`
  - shared files were seen through both the app root group and the dedicated shared group, causing duplicate build-file warnings
- Public examples of Xcode 16 synchronized groups showed that the safe pattern is an explicit `PBXFileSystemSynchronizedBuildFileExceptionSet` with relative file-path entries in `membershipExceptions`, attached through the root group's `exceptions = (...)` list.

### External references used during debugging

- `insidegui/WWDC`:
  - public repo used to inspect a real `project.pbxproj` with `PBXFileSystemSynchronizedBuildFileExceptionSet`
  - https://github.com/insidegui/WWDC
- `tuist/XcodeProj` issue `#838`:
  - useful for confirming the Xcode 16 synchronized-group exception object names and shape
  - https://github.com/tuist/XcodeProj/issues/838

### Validation recorded during this reorganization

- `make quality-format-check` passes.
- iOS simulator build passes.

## Lock Screen Daily Macro Widget

### Delivered

- Added a dedicated Lock Screen daily macro widget alongside the existing Home Screen widget.
- Kept the current Home Screen widget unchanged for `.systemSmall` and `.systemMedium`.
- Added Lock Screen support for `.accessoryInline`, `.accessoryCircular`, and `.accessoryRectangular`.
- Reused the existing shared app-group-backed widget data path and deep-link routing instead of introducing a second widget data model.

### Main implementation steps

- Added `DailyMacroAccessoryWidget.swift` under `cal-macro-tracker/CalMacroWidget/`.
- Updated `CalMacroWidgetBundle.swift` so the widget extension now exports both `DailyMacroWidget()` and `DailyMacroAccessoryWidget()`.
- Added `SharedAppConfiguration.dailyMacroAccessoryWidgetKind` so the Lock Screen widget has its own WidgetKit kind.
- Updated `WidgetTimelineReloader.swift` so data changes refresh both the Home Screen and Lock Screen widget timelines.
- Updated the Xcode synchronized-group exception list so the new widget file stays out of the app target and only compiles in the widget extension.

### Bugs and implementation findings

- The current widget setup already supported the Home Screen; the actual missing surface was the Lock Screen, because the existing widget only declared `.systemSmall` and `.systemMedium`.
- The widget architecture already had the right shared contracts (`DailyMacroSnapshotLoader`, `SharedModelContainerFactory`, `AppOpenRequest`), so the correct implementation was a new accessory widget presentation layer rather than a new persistence or routing path.
- Adding a second widget kind required timeline reload coverage for both kinds; otherwise the new Lock Screen widget could lag behind the Home Screen widget after log-entry or goal changes.
- A dedicated accessory widget kept the implementation simpler than folding Lock Screen families into the existing Home Screen widget file, which would have increased family-specific branching and tracing complexity.

### Validation recorded during this widget follow-up

- `make quality-format-check` passes.
- iOS simulator app build passes.
- iOS simulator widget build passes.

## Open Food Facts Reliability, Secondary Nutrients, and Historical Repair

### Delivered

- Reworked packaged-food Worker reliability so default search gives Open Food Facts a bounded, rate-aware chance to recover before falling back to USDA.
- Fixed cache behavior so transient Open Food Facts failures do not pin repeated default queries onto cached USDA fallback results.
- Added background Open Food Facts cache warming plus lightweight, query-free search telemetry around attempts, cache hits, resolved provider, and degraded fallback reasons.
- Added the first explicit secondary nutrient batch end-to-end across Worker contracts, app models, barcode/search ingestion, OCR parsing, persistence, and shared food-entry editors:
  - `saturatedFatPerServing`
  - `fiberPerServing`
  - `sugarsPerServing`
  - `addedSugarsPerServing`
  - `sodiumPerServing`
  - `cholesterolPerServing`
- Hardened the root barcode/OCR implementation after review so Open Food Facts mixed-basis nutrient data and Nutrition Facts OCR edge cases map correctly.
- Added repair/backfill support for existing foods and log entries, including bundled common foods, legacy reusable OFF/USDA foods, and historical entries linked through optional `foodItemID`.
- Added a USDA food-details Worker route and app client for reusable-food repair.

### Main implementation steps

- Updated `worker/usda-proxy/` to use explicit Open Food Facts outcome handling, bounded retries with `Retry-After`/backoff behavior, degraded fallback metadata, and provider-safe cache policies.
- Split packaged-food cache-key and write-policy behavior into `worker/usda-proxy/src/packagedFoodSearchCache.ts` so default, OFF-pinned, and USDA-pinned cache behavior stays explicit and traceable.
- Added focused Worker tests for retry behavior, fallback behavior, pagination safety, cache-key behavior, and representative OFF/USDA nutrient payload mapping.
- Extended explicit nutrient fields through `FoodDraft`, `FoodItem`, `LogEntry`, imported-data helpers, repositories, and `NutritionMath` instead of introducing a generic nutrient container.
- Kept food-entry UX progressive: macros stay visible by default, secondary nutrients expand inline in the shared editor, and the `Show more` / `Show less` row now responds to taps across the whole row.
- Fixed `BarcodeLookupMapper.swift` so required macros and optional nutrients can resolve from different OFF bases when that reflects the real payload.
- Tightened `NutritionLabelParser.swift` and `NutritionLabelParserSupport.swift` so OCR parsing now handles comma-formatted numbers, explicit `g` / `mg` units, split added-sugars lines, safer multi-line serving-size blocks, and packaging-copy rejection.
- Added `SecondaryNutrientRepairService.swift`, extended `CommonFoodSeedLoader.swift`, and updated bootstrap planning so installs with older local data can detect and repair missing secondary nutrients.
- Kept historical entry editing snapshot-only by detaching stale `foodItemID` links when an edited log entry no longer matches its reusable-food source.
- Added `worker/usda-proxy/src/index.ts` support for `/v1/usda/foods/:fdcId` and `USDAFoodDetailsClient.swift` on the app side so USDA-backed reusable foods can refresh against the correct details contract.

### Bugs and implementation findings

- The old provider-agnostic default cache key could let one transient Open Food Facts failure suppress the very next OFF retry by re-serving USDA fallback.
- Worker configuration now requires `OPEN_FOOD_FACTS_USER_AGENT` alongside `USDA_API_KEY`; `.dev.vars.example`, `wrangler.jsonc`, and generated worker runtime types were updated so local/dev validation matches the deployed contract.
- Open Food Facts mapping originally chose one nutrition basis too early, which could drop valid optional secondary nutrient values even when the payload contained them.
- OCR parsing originally misread several realistic label forms:
  - comma-formatted nutrient amounts
  - `%DV`-only sodium/cholesterol lines
  - split `Includes ... Added Sugars ...` lines
  - serving-size continuations that accidentally swallowed packaging copy
- Historical nutrient support needed a temporary repair path rather than only improving new-entry flows, because older reusable foods and stored log-entry snapshots were already missing the new fields.
- USDA food-details responses do not match the USDA search payload shape; the final Worker mapping handles the real details nutrient schema (`amount` plus nested nutrient number) instead of assuming `nutrientId` / `value`.
- Running all external-food repairs during launch created startup risk on offline or slow connections, so the network-backed repair pass now runs after the app reaches ready state.

### Validation recorded during this work

- `cd worker/usda-proxy && bun run check`
- `cd worker/usda-proxy && bun test`
- `make quality-format-check`
- `xcodebuild -project /Users/juan/Documents/xcode/cal-macro-tracker/cal-macro-tracker.xcodeproj -scheme cal-macro-tracker -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build`
- `xcodebuild -project /Users/juan/Documents/xcode/cal-macro-tracker/cal-macro-tracker.xcodeproj -scheme cal-macro-tracker -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`
- `git diff --check`

### Review-driven hardening follow-up

- After five review passes on this uncommitted work, the remaining high-confidence fixes were no longer in OCR parsing or provider mapping but in the repair-state contract and Worker retry policy.
- `FoodDraft` and `FoodDraftImportedData` now carry `secondaryNutrientBackfillState` so legacy `.needsRepair` / `.notRepairable` state is preserved through log, log-again, and edit flows instead of being dropped during draft conversion.
- `SecondaryNutrientBackfillPolicy` now centralizes:
  - legacy state inference from persisted `FoodItem` / `LogEntry` records
  - new-record state resolution when a draft already carries repair provenance
  - update-time transitions when someone changes serving or macro data without explicitly resolving secondary nutrients
- After another root-cause validation pass, `SecondaryNutrientBackfillPolicy` now also returns a shared update resolution for reusable-food and log-entry edits, so basis-changing records with existing secondary nutrients no longer stay `.current` when those secondary fields were left untouched.
- `LogEntryRepository.swift` no longer hard-codes new entries to `.current`; logging now preserves carried repair state when a draft originates from legacy data that still needs repair.
- `FoodItemRepository.swift` now uses the same shared transition rules as `LogEntryRepository.swift`, so reusable-food edits and log-entry edits no longer drift in how they mark `.current`, `.needsRepair`, or `.notRepairable`.
- `FoodDraftEditorForm.swift` now expands the secondary nutrient section by default whenever a draft already has secondary values, so editing an existing food or entry no longer hides the fields whose basis could be invalidated.
- `LogEntryRepository.swift` now keeps historical entry edits snapshot-only; when an edited log entry no longer matches its linked reusable food, the entry detaches from `foodItemID` instead of mutating shared reusable-food state.
- `SecondaryNutrientRepairService.swift` now uses entry-owned provenance first and then unambiguous saved external-food matches as a legacy fallback, so historical barcode/search entries can still be repaired even when older snapshots predate explicit external IDs.
- `SecondaryNutrientRepairService.swift` now validates the reusable food's repair key before overlaying remote secondary nutrients; if a user-edited external food no longer matches the provider's serving/macro basis, the repair pass marks it `.notRepairable` instead of silently mixing user-edited macros with provider-derived secondary nutrients.
- `SecondaryNutrientRepairTarget` now centralizes which saved external records are actually refreshable for secondary-nutrient repair, so repair state inference and repair execution no longer treat every stored external identifier as a valid remote lookup target.
- `SecondaryNutrientRepairService.swift` now normalizes stale `.needsRepair` OFF/USDA records that do not have a real repair target to `.notRepairable` before network repair runs, preventing repeated launch-time retries for records that can never refresh successfully.
- `OpenFoodFactsIdentity` was moved into shared model code so barcode normalization and qualified OFF identity rules stay consistent across the app, widget target, persistence, and repair logic instead of being redefined inside one client file.
- `worker/usda-proxy/src/packagedFoods.ts` now treats `Retry-After` as a real lower bound; if the requested delay exceeds the local retry budget, the Worker stops retrying Open Food Facts and falls back instead of shortening the wait and re-hitting the provider early.
- `worker/usda-proxy/src/index.ts` telemetry now only records operational metadata; raw packaged-food search queries are intentionally excluded from log payloads.
- `worker/usda-proxy/src/packagedFoodSearchCache.ts` now keeps empty default Open Food Facts responses scoped to the `fallbackOnEmpty`-specific default cache key instead of sharing them through the generic `openFoodFacts` cache entry, and `worker/usda-proxy/tests/packagedFoods.test.ts` covers that regression explicitly.
- `worker/usda-proxy/package.json` now installs `@types/bun`, and `worker/usda-proxy/tsconfig.json` now loads Bun types plus `tests/**/*.ts`, so editor/typecheck diagnostics resolve `bun:test` instead of treating the Bun test files as missing-module errors.
- Worker fetch injection now uses a small `HTTPFetcher` call-signature type instead of `typeof fetch`, so Bun's extra static `fetch` properties do not leak into unit-test doubles while keeping the mocked HTTP tests type-safe.

### Review findings validated and rejected

- Confirmed bug: legacy repair state could be lost because the draft contract did not preserve it.
- Confirmed bug: reusable external-food repair could overlay provider secondary nutrients onto user-edited serving/macro data without verifying the basis still matched.
- Confirmed bug: Worker retry logic could shorten large `Retry-After` delays instead of respecting them as a minimum wait.
- Confirmed bug: basis-changing edits with existing secondary nutrient data could still remain `.current` because the shared update policy did not distinguish hidden untouched secondary values from explicitly revalidated ones.
- Confirmed bug: the shared Open Food Facts cache key could replay an empty `fallbackOnEmpty=false` default response into later `fallbackOnEmpty=true` requests, suppressing USDA widening for the same query.
- Confirmed bug: historical Open Food Facts search results stored as `openfoodfacts:<_id>` could be marked repairable and later re-fetched through the barcode repair path even though `_id` is not a valid OFF barcode lookup target in this codebase.
- Rejected candidate: fresh imported remote drafts defaulting to `.current` was not a bug in this codebase. The repair pipeline exists to backfill historical local foods and entries that predate secondary-nutrient support, not to mark newly imported provider payloads as stale on creation.
- Rejected candidate: basis-changing edits should automatically clear already-present secondary nutrient fields. The root fix in this codebase is to stop hiding those fields during edits and to downgrade unresolved mismatches to `.notRepairable`, not to silently delete user-visible nutrient data.
- Final follow-up review result: after introducing the shared repair-target contract and re-running validation, no new high-confidence actionable bugs were found in the resulting diff.

### Validation recorded during this review follow-up

- `cd worker/usda-proxy && bun run check`
- `cd worker/usda-proxy && bun test`
- Reload the editor TypeScript server after adding Bun types if stale `bun:test` diagnostics remain open in an existing workspace.
- `make quality-format-check`
- `xcodebuild -project /Users/juan/Documents/xcode/cal-macro-tracker/cal-macro-tracker.xcodeproj -scheme cal-macro-tracker -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build`
- `xcodebuild -project /Users/juan/Documents/xcode/cal-macro-tracker/cal-macro-tracker.xcodeproj -scheme cal-macro-tracker -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`
- `git diff --check`

## Haptics and Food Entry Save Interaction

### Delivered

- Added haptic feedback for successful food logging, entry updates, reusable-food saves, reusable-food deletes, dashboard entry deletes, and successful scan-to-review transitions.
- Added a matching success haptic for the dashboard `Log Again` action.
- Fixed the bottom `Log Food` action so it no longer competes as directly with active keyboard focus dismissal.
- Kept the haptics implementation local to the relevant SwiftUI screens instead of introducing a new global feedback service.

### Main implementation steps

- Updated `LogFoodScreen.swift` so the primary save action clears focus, resigns the iOS first responder, and persists on the next main-loop turn before dismissing.
- Added local `.sensoryFeedback(..., trigger: ...)` state to `LogFoodScreen.swift`, `EditLogEntryScreen.swift`, `CustomFoodEditorScreen.swift`, `DashboardScreen.swift`, `BarcodeScanScreen.swift`, and `LabelScanScreen.swift`.
- Kept scan success feedback tied to the point where a usable `FoodDraft` / log-food destination becomes available, instead of firing on intermediate camera or OCR events.
- Reused SwiftUI sensory feedback directly at the screen boundary so the behavior stays close to the user action that owns it.

### Bugs and implementation findings

- The existing Settings goals save flow remained the best local precedent for the food-entry fix: clear focus first, then defer persistence one run-loop turn.
- `FoodDraftEditorForm.swift` had become a more shared editing surface after the recent secondary-nutrient work, so the safer change was to keep the save-interaction fix inside `LogFoodScreen.swift` rather than changing shared form behavior globally.
- A global haptics manager was not necessary for this scope; screen-local triggers kept the diff smaller and reduced tracing complexity.
- Scan feedback is best attached to destination readiness, because those scan flows already rely on destination-state navigation for stability.
- A follow-up review of Apple's public haptics guidance kept the completed-action semantics on `.success`; `Log Food`, edit saves, reusable-food saves, scan-to-review, and `Log Again` all stay on the same success pattern instead of switching those flows to a generic impact.

### Validation recorded during this work

- `make quality-format-check`
- `xcodebuild -project /Users/juan/Documents/xcode/cal-macro-tracker/cal-macro-tracker.xcodeproj -scheme cal-macro-tracker -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build`
- `xcodebuild -project /Users/juan/Documents/xcode/cal-macro-tracker/cal-macro-tracker.xcodeproj -scheme cal-macro-tracker -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`

## Small Daily Macro Widget Value Sizing Follow-up

### Delivered

- Fixed the small Home Screen daily macro widget so side macro values no longer truncate when one or more values include decimals.
- Kept the row visually balanced by using one shared value size for all three macro columns in the small widget.
- Reviewed the final implementation and removed unnecessary index-coupled lookup code after the sizing fix was proven out.

### Main implementation steps

- Updated `cal-macro-tracker/CalMacroWidget/DailyMacroWidget.swift` so the small widget uses a deterministic shared font size for the `P / C / F` value row.
- Chose the shared font size from the longest rendered macro value string in the current snapshot instead of letting each value size independently.
- Kept the small widget row compact with the existing equal-width three-column layout and a tighter horizontal spacing value.
- Simplified the final row rendering by replacing the temporary enumerated array/index lookup with a direct `smallMetricValue(for:)` helper.

### Bugs and implementation findings

- Independent per-value sizing made shorter values look louder than longer values, which felt visually unbalanced in the compact three-column row.
- A shared `ViewThatFits` row-level approach was still not reliable here because equal-width columns could report a row that fit while the side values still truncated inside their own columns.
- The more reliable solution in this widget was a simple deterministic mapping from widest rendered value length to one shared font size for the whole row.
- After the cleanup pass, no redundant code, dead code, or simpler high-confidence implementation remained for this widget behavior.

### Validation recorded during this work

- `make quality-format-check`
- `xcodebuild -project /Users/juan/Documents/xcode/cal-macro-tracker/cal-macro-tracker.xcodeproj -scheme cal-macro-tracker -configuration Debug -destination 'generic/platform=iOS Simulator' build`

## Small Daily Macro Widget 3-Digit Value Fit Fix

### Delivered

- Fixed the small Home Screen daily macro widget so 3-digit macro totals like `102` render fully instead of truncating to `1…`.
- Kept the existing three-column `P / C / F` layout and solved the issue with a minimal sizing adjustment rather than changing the widget structure.

### Main implementation steps

- Updated `cal-macro-tracker/CalMacroWidget/DailyMacroWidget.swift` so 3-character macro values use a slightly smaller shared font size in the small widget.
- Tightened the small metric row spacing from `6` to `4` to preserve a bit more room for each equal-width column.
- Added a `minimumScaleFactor(0.75)` to the small metric value text so compact layouts can shrink before falling back to ellipsis.

### Bugs and implementation findings

- The previous small-widget row could still truncate integer values even after the earlier shared sizing work because the text was allowed to ellipsize but not scale down.
- The underlying snapshot data was correct; this was a widget layout constraint issue in the compact equal-width row.
- The final implementation stayed clean and focused: no duplicate logic, no structure changes, and no broader widget refactor was needed.

### Validation recorded during this work

- `xcodebuild -project "/Users/juan/Documents/xcode/cal-macro-tracker/cal-macro-tracker.xcodeproj" -scheme "CalMacroWidget" -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /tmp/cal-macro-tracker-derived-data CODE_SIGNING_ALLOWED=NO build`

## Legacy Open Food Facts Identity Recovery and Manual Nutrient Refresh

### Delivered

- Expanded legacy secondary-nutrient repair so older Open Food Facts-backed barcode/search records can recover a repair target from any surviving OFF identity, including canonical product-page `sourceURL`.
- Normalized newly mapped OFF scan results onto canonical barcode-based OFF identity so future cache reuse and repair targeting stay consistent.
- Backfilled recovered OFF identity onto repaired reusable foods and historical log-entry snapshots instead of only overlaying nutrient fields.
- Added a manual `Refresh Nutrients` action for old external log entries and reusable external foods when secondary nutrients are still missing and the record is still refreshable.
- Kept the manual refresh path on the existing edit screens instead of creating a separate repair flow or settings surface.

### Main implementation steps

- Extended `OpenFoodFactsIdentity.swift` so OFF barcode recovery now supports:
  - direct barcode aliases
  - qualified OFF external IDs
  - canonical OFF product-page URLs
- Tightened OFF identity recovery so only digit-shaped identifiers can become barcode repair targets; non-barcode OFF `_id` values no longer flow into the barcode refresh path.
- Updated `SecondaryNutrientRepairTarget.resolve(...)` so `.barcodeLookup` and OFF-backed `.searchLookup` records can derive repair targets from `sourceURL` as well as barcode/external ID.
- Updated `BarcodeLookupMapper.swift` so OFF-backed saved foods persist a canonical OFF product URL derived from the normalized barcode instead of depending on nullable API `product.url`.
- Extended `BarcodeLookupMapper.swift` again so code-less OFF search results also recover and persist the normalized barcode from qualified OFF identity or product URL, which keeps later barcode-scan cache reuse working for those saved foods.
- Updated `OpenFoodFactsClient.swift` so OFF search results now expose recovered barcode-based lookup aliases alongside the original raw external ID, keeping saved-result reuse aligned with the newer canonical OFF identity written during import.
- Refined `OpenFoodFactsIdentity.swift` again so shared OFF barcode recovery now prefers the canonical product-page URL over raw qualified external IDs and only accepts external-ID fallback values when they match supported barcode lengths.
- Updated repair-time backfill in `FoodDraft.swift` and `SecondaryNutrientRepairService.swift` so successful external-food and historical-entry repair persists recovered barcode, external ID, source name, and source URL alongside refreshed secondary nutrients.
- Added manual refresh helpers to `SecondaryNutrientRepairService.swift` that reuse the existing remote refresh contracts while preserving the current draft as the editable source of truth.
- Added `Refresh Nutrients` affordances to:
  - `EditLogEntryScreen.swift`
  - `ReusableFoodEditorScreen.swift`
- Kept the button gated to records that:
  - are external barcode/search items
  - still have missing secondary nutrients
  - still match the original repair key
  - are not already known `.notRepairable`
- Updated `FoodDraftEditorForm.swift` so a successful refresh automatically reveals the additional-nutrition section when new secondary values arrive.
- Disabled the edit forms while a refresh is in flight so fetched nutrient values cannot race with manual edits or be lost behind an immediate save/delete.

### Bugs and implementation findings

- Some historical OFF search results persisted only a product-page URL even when barcode/external ID fields were absent; without URL-based recovery, those records stayed outside the repairable set.
- Open Food Facts `product.url` is nullable in real API responses, so canonical URL generation from the normalized barcode is more reliable than persisting the raw response field.
- Worker-side OFF search results can persist `openfoodfacts:<_id>` when no OFF `code` exists; those `_id` values are not valid barcode refresh targets in this codebase and must not be treated as such.
- Canonical OFF identity needs to be written back during successful repair, otherwise repaired legacy records can keep stale OFF IDs and drift away from later cache reuse and lookup behavior.
- Preserving only `sourceURL` was not enough for code-less OFF search imports: if the recovered barcode was not also persisted onto the saved food, a later live barcode scan could miss the local cache and fall back to a remote fetch.
- Canonicalizing saved OFF search results without also widening the search-result lookup aliases created a second reuse regression: reopening the same code-less OFF search hit could miss the saved reusable food because the UI still searched only by the original raw `_id`-based alias.
- The first shared OFF identity fallback order still let a digit-shaped `openfoodfacts:<_id>` override the real barcode embedded in a canonical OFF product URL, and the initial fallback guard was still too loose for arbitrary numeric IDs; the final helper now prefers URL recovery and restricts external-ID fallback to supported barcode lengths.
- A manual refresh button must be stricter than “target exists”: it also has to respect the same repair-key contract as automatic repair so edited records do not advertise a refresh that can only fail.
- The refresh flow initially allowed save/delete while the async request was in flight; the final implementation disables the whole edit surface during refresh so fetched values cannot overwrite in-progress edits or be dropped after dismissal.

### Validation recorded during this work

- `make quality-format-check`
- `xcodebuild -project "/Users/juan/Documents/xcode/cal-macro-tracker/cal-macro-tracker.xcodeproj" -scheme "cal-macro-tracker" -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build`
- `xcodebuild -project "/Users/juan/Documents/xcode/cal-macro-tracker/cal-macro-tracker.xcodeproj" -scheme "cal-macro-tracker" -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`

### Final review result

- Follow-up review after implementation and validation returned `LGTM — no issues found.`

## Web Waitlist Client Bundle Split

### Delivered

- Kept the shared waitlist validation rules intact while removing the Zod-backed submit contract from the homepage client bundle.
- Preserved the Worker as the authoritative waitlist submit boundary.
- Reduced the built landing-page waitlist script from roughly `71 KB` to `13.5 KB`.

### Main implementation steps

- Added `web/src/lib/waitlist-validation.ts` to hold the pure waitlist normalization, syntax, domain-label, TLD, and status-message helpers used by the homepage.
- Reduced `web/src/lib/waitlist.ts` to the Worker/shared submit contract layer that wraps the existing Zod schema around the shared pure helpers.
- Updated `web/src/pages/index.astro` so the inline homepage script imports only the lightweight waitlist validation helpers instead of the mixed Zod contract module.

### Bugs and implementation findings

- The homepage had started importing its live waitlist helpers from a mixed-use module that also defined the Worker submit schema, so Astro bundled Zod internals into the landing-page script.
- The right fix was to split module responsibilities, not to duplicate a second browser-only regex or weaken the shared validation contract.
- The bundled IANA TLD snapshot intentionally remains in the client path because local-first waitlist validation still depends on it; only the accidental Zod/server-contract shipment was removed.

### Validation recorded during this work

- `cd "/Users/juan/Documents/xcode/cal-macro-tracker/web" && bun run check`
- `cd "/Users/juan/Documents/xcode/cal-macro-tracker/web" && bun run build`
- Built asset inspection confirmed the landing-page client chunk dropped to `13,500` bytes and no longer contains Zod internals.

### Final review result

- Follow-up review after implementation and validation returned `LGTM — no issues found.`
