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
