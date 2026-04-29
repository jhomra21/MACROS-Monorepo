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

### Dashboard and History header polish

#### Delivered

- Reworked Dashboard and History date headers to use concise leading toolbar titles without iOS 26 Liquid Glass title capsules.
- Kept native navigation/back behavior, balanced trailing toolbar actions, and non-today date titles that fit the available header space.
- Moved the Dashboard `Today` return action out of the trailing toolbar into a floating under-nav row so the share, history, and settings actions no longer crowd the top-right control group.
- Updated Dashboard and History to share the same `CalendarDay.topBarTitle` formatting, including `Today, Apr 28, 2026` style titles for the current day.
- Standardized Dashboard and History top-bar typography through `AppTopBarStyle`, keeping title and icon sizing tunable from one place.
- Tuned top-bar icon sizing/weight separately from title weight so the toolbar can stay visually aligned with native iOS app conventions.
- Reduced the cold first-share delay on Dashboard by warming the share render and system share-controller setup after the app is ready.
- Kept the Dashboard share preview image visible while avoiding generated PNG caching.
- Updated the generated Dashboard share image and share-sheet metadata to use the selected date as the only title instead of `Daily Summary`.
- Fixed the Dashboard Save Photo payload so Photos receives JPEG data instead of an alpha-bearing `UIImage`.
- Shared JPEG encoding between Dashboard sharing and label-scan preview generation.
- Removed temporary Dashboard share/save timing diagnostics after the Save Photo issue was isolated.

#### Main implementation steps

- `DashboardShareSupport.swift` now keeps only the share, history, and settings actions in the trailing toolbar.
- `DashboardScreen.swift` overlays the conditional `Today` return row above the dashboard list instead of inserting it into the scroll content, so the macro panel and logged-food content do not shift.
- `CalendarDay.swift` now owns the shared top-bar title string used by both Dashboard and History.
- `DashboardScreen.swift`, `DashboardShareSupport.swift`, and `HistoryScreen.swift` now use shared top-bar title/icon styling from `AppTopBarStyle.swift`.
- A simplify pass removed the informal top-bar style comment, centralized repeated title/icon modifiers, renamed the shared date title to the more specific `topBarTitle`, and removed an overly broad selected-day animation from the Dashboard container.
- A defensive-code review found no high-confidence redundant guards or impossible-state branches to remove.
- Added `AppWarmupCoordinator` as a one-shot, after-ready warm-up path so Dashboard can prepay the cold `ImageRenderer` and `UIActivityViewController` setup cost without blocking app launch.
- Updated Dashboard sharing to pass an in-memory image item through `UIActivityItemSource` with `LPLinkMetadata` and thumbnail support, restoring the share-sheet preview while avoiding temporary PNG-file sharing.
- Renamed the share exporter API from PNG-specific wording to image-export wording after the implementation stopped writing temporary PNG files.
- Removed the `Daily Summary` fallback from the share item source so the date-only share title contract cannot regress through preview metadata.
- Added `Shared/ImageJPEGEncoder.swift` as the shared iOS JPEG encoding utility.
- Replaced the scan-only `ScanPreviewImageEncoder` wrapper with `ImageJPEGEncoder` in `LabelScanScreen.swift`.
- Updated `DashboardShareImageItemSource` so `.saveToCameraRoll` receives direct JPEG data while other share activities still receive the original image.
- Cached the encoded Save Photo JPEG data per Dashboard share item source to avoid repeated compression if UIKit asks for the item more than once.
- Added `Shared/ImageJPEGEncoder.swift` to the Xcode synchronized-group exception list so the file is not compiled twice through both the app root and shared groups.
- Overlapped label OCR and preview JPEG encoding with `async let` so scan preview preparation no longer waits until OCR finishes.
- Validated and fixed the review finding that returning a nested `UIActivityItemProvider` from another `UIActivityItemSource` was the wrong UIKit share contract; the Save Photo branch now returns the final cached JPEG `Data` directly.

#### Bugs and implementation findings

- Initial logs showed the share card render was the first cold bottleneck; warming the render path reduced real tap-time image export to single-digit milliseconds.
- Follow-up logs showed the remaining delay was inside `UIActivityViewController` / LaunchServices setup after controller creation, so a one-shot controller warm-up moved that system cost off the tap path.
- Sharing a raw `UIImage` fixed file-provider / LaunchServices file URL work but temporarily caused the share sheet to show the app icon; using `UIActivityItemSource` plus `LPLinkMetadata` restored the image preview.
- Device logs showed the post-reload Save Photo delay was no longer in Dashboard image export or share-sheet presentation; the remaining cost was in the system Save Photo path.
- Photos emitted alpha-channel warnings for the share image (`AlphaPremulLast` / `AlphaLast`), so the Save Photo activity now receives JPEG data to avoid alpha-bearing image payloads.
- Eagerly preparing JPEG data before presenting the share sheet improved Save Photo readiness but made every share action pay the Save Photo cost; the final implementation scopes JPEG work to `.saveToCameraRoll`.
- Returning a `UIActivityItemProvider` from `itemForActivityType` would rely on undocumented recursive provider resolution; the corrected root fix keeps `DashboardShareImageItemSource` as the single owner of activity-specific payload selection.
- A temporary logging pass helped isolate the issue but was removed before the final cleanup so production sharing has no extra lifecycle logging/context plumbing.
- Repeated simplify passes intentionally converged through layers of cleanup: removing diagnostics, sharing JPEG encoding, deleting the scan-specific wrapper, avoiding eager JPEG work, caching Save Photo output, and fixing Xcode synchronized membership for the new shared file.
- Apple docs support the `UIActivityViewController`, `UIActivityItemSource`, thumbnail, and `LPLinkMetadata` pieces; the non-presented controller warm-up is a measured workaround justified by local timing logs, not a general Apple-required pattern.
- A simplify pass caught misleading `exportPNG` naming after the share path became image-based, and a defensive-code review caught the stale `Daily Summary` metadata fallback after the visual title was removed.

#### Validation

- Formatter, macOS debug build, and focused SwiftUI visual validation passed.
- Formatter validation and iOS simulator builds passed for the Dashboard/History toolbar follow-up.
- Simplify and defensive-code review follow-ups passed formatter validation, iOS simulator build, and `git diff --check`.
- Share warm-up and item-source changes passed formatter validation, iOS simulator build, and `git diff --check`.
- Date-only share title and final defensive-code cleanup passed formatter validation, iOS simulator build, and `git diff --check`.
- Save Photo JPEG payload and cleanup passes passed `git diff --check`, formatter validation, repeated simplify review, and iOS simulator builds.
- The nested-provider review fix passed `git diff --check`, formatter validation, iOS simulator build, and a final focused diff review.

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

- iOS simulator builds and the available repo quality checks passed; formatter and dead-code tooling were documented but not locally available at that stage.

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

- The iOS simulator build and available repo quality checks passed; formatter and dead-code validation still depended on tooling that was not installed locally at that stage.

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

- Worker type checks, representative endpoint checks, local Bun validation, iOS simulator builds, and repo quality checks passed.

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

## First-Run Goal Setup Onboarding

### Delivered

- Added a first-run goal setup onboarding screen for calorie, protein, carb, and fat targets.
- Gated the onboarding flow behind `@AppStorage("hasCompletedGoalSetup")`, so `false` shows onboarding and `true` shows the dashboard.
- Reused the existing `DailyGoals`, `DailyGoalsRepository`, `DailyGoalsField`, numeric text validation, and shared numeric input components instead of creating a parallel goals model.
- Styled the onboarding screen with the existing iOS 26 Liquid Glass helpers: glass goal rows, `GlassEffectContainer`, and the shared prominent bottom action bar.
- Added a smooth onboarding-to-dashboard opacity transition: onboarding fades out over 150ms and the dashboard fades in over the next 150ms.
- Updated dashboard macro ring-related interactions so ring expansion, compact-summary visibility, and macro legend selection all use `easeOut` timing.
- Fixed the shared bottom pinned action bar so keyboard accessory controls no longer overlap `Continue` / `Log Food` while editing numeric fields.
- Added a code-only onboarding display mode so the setup screen can be forced on launch for regression testing without deleting simulator app data.
- Added a success haptic to the onboarding `Continue` action after goal persistence succeeds.
- Refined the onboarding handoff so the setup screen slides down while the home screen fades in over 200ms.

### Main implementation steps

- Added `Features/Onboarding/GoalSetupScreen.swift` as the first-run setup surface.
- Updated `cal_macro_trackerApp.swift` to route between onboarding and `AppRootView` after launch readiness.
- Made `DailyGoalsNumericText` reusable and added a default initializer so onboarding and Settings share the same goal text/draft conversion path.
- Removed an unnecessary nested `NavigationStack` from onboarding so the shared keyboard toolbar matches the Settings numeric-entry flow.
- Updated `BottomPinnedActionBar.swift` centrally so onboarding and food logging both get keyboard-toolbar clearance from the same component.
- Kept the onboarding transition declarative with SwiftUI opacity transitions instead of using `Task.sleep` for sequencing.
- Replaced the raw force-show boolean with `GoalSetupDisplayMode.normal` / `.forceOnLaunch` so the persisted completion state and the test-only launch override have distinct responsibilities.
- Defaulted the display mode back to `.normal` after review so completed users are not shown onboarding again on every cold launch.
- Added screen-local `.sensoryFeedback(.success)` state to `GoalSetupScreen`, matching the existing successful-save haptic pattern elsewhere in the app.
- Updated the final handoff animation to use an asymmetric onboarding removal transition, `zIndex` layering, a stable grouped background, and a delayed `AppRootView` opacity insertion.
- Removed parent `.animation(..., value:)` modifiers from the app root so transition-specific animations own the route change without competing animation sources.

### Bugs and implementation findings

- Rebuilds do not reset `@AppStorage`; testing the onboarding flow again requires deleting the simulator app, resetting the persisted key, or temporarily changing the storage key.
- Placing the keyboard toolbar too low in the onboarding view tree prevented the up/down/Done accessory controls from matching Settings behavior.
- The first transition implementation felt snappy because the app root swapped views immediately; using matched opacity transitions inside the same root `ZStack` made the handoff smoother.
- A staged delay with `Task.sleep` worked but was not the cleanest SwiftUI approach, so it was replaced with declarative transition animation.
- The keyboard accessory toolbar overlap was not onboarding-specific; `Log Food` had the same bottom action bar conflict, so the fix belonged in `BottomPinnedActionBar`.
- A permanent force-show flag would trap the current app session on onboarding after `Continue`, so `.forceOnLaunch` now uses session-only completion state to show onboarding at launch while still letting `Continue` enter the dashboard.
- Review validation found that leaving `.forceOnLaunch` as the checked-in default would bypass the first-run-only contract on every fresh process; `.normal` is now the default, with `.forceOnLaunch` retained only as a temporary local testing switch.
- Scaling the whole app root during the handoff looked snappy and exposed background-layer mismatches, so the scale transition was replaced with a stable background plus home opacity insertion.
- The final transition sequencing intentionally starts the home fade after a short delay while onboarding slides down first.

### Validation recorded during this work

- Formatter validation passed.
- macOS debug builds passed with `CODE_SIGNING_ALLOWED=NO` because local signing profiles were unavailable.
- The final display-mode fix passed formatter validation, macOS debug build with signing disabled, and a focused diff review.
- The haptic and final transition cleanup passed formatter validation, macOS debug build with signing disabled, and `git diff --check`.

## Branding and App Configuration

### Delivered

- Updated the user-facing app name to `MACROS`.
- Added `CFBundleDisplayName` and updated `CFBundleName` in both `Info-iOS.plist` and `Info-macOS.plist`.

## Quality, Cleanup, and Review

### Delivered

- Ran multiple focused review passes over the working tree and Settings-specific changes.
- Installed Periphery, then upgraded the local CLI to 3.7.2 when Homebrew lagged behind.
- Updated `.periphery.yml` for Periphery 3 compatibility.
- Updated the dead-code validation wrapper and `tools/quality/run_periphery.sh` so Periphery scans the iOS simulator destination.
- Removed genuinely unused code surfaced by Periphery.
- Marked preview-only helpers with `// periphery:ignore` where the code is intentionally retained.

### Bugs and implementation findings

- Periphery initially produced false positives because it scanned the multiplatform scheme without an explicit iOS destination.
- The root fix was to pass `-destination "generic/platform=iOS Simulator"` through the wrapper instead of suppressing warnings.
- After the destination fix, the remaining findings were validated symbol-by-symbol and either removed or intentionally ignored for preview-only usage.

### Final validation state

- Formatter, iOS/macOS builds, Worker TypeScript/Bun checks, Periphery, and focused review all passed.

## Deferred Work

- Forward edge-swipe navigation from Home into History/calendar was analyzed but intentionally deferred to a later commit because iOS does not provide a native forward interactive edge push equivalent to the back swipe.

## Consolidated Source Docs

The following planning documents have been fully consolidated into this file and can be removed safely:

- `scan-implementation-plan.md`
- `food-search-implementation-plan.md`
- `usda-proxy-implementation-plan.md`
- `off-reliability-and-nutrients-plan.md`
- `CODEBASE_IMPROVEMENT_PLAN.md`
- `swift-codebase-audit-plan.md`

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

- Formatter, iOS/macOS builds with local code-signing handling, and focused code review all passed.

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

- Formatter validation passes.
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

- Formatter validation passes.
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

- Formatter validation plus iOS simulator app and widget builds passed.

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

- Ran the usual repo validation `make` commands for this work.

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

- Ran the usual repo validation `make` commands for this work.

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

- Ran the usual repo validation `make` commands for this work.

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

- Ran the usual repo validation `make` commands for this work.

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

- Ran the usual repo validation `make` commands for this work.

## Macro Goal Number Presentation and Small Widget Over-Goal Layout

### Delivered

- Reworked macro number summaries so app surfaces now show the current value plus a baseline goal and optional over-goal delta without the literal `Goal` label.
- Preserved the colored macro dots and restored centered macro summary columns on app surfaces after the first shared-summary pass changed that presentation.
- Kept widgets lighter-weight than the app: over-goal state now appears as an up arrow on the current value, while in-app summaries still show the explicit `+delta`.
- Fixed the small Home Screen widget so decimal-heavy over-goal values such as `194.6 ↑` and `49.1 ↑` can render fully instead of truncating or dropping their indicator.

### Main implementation steps

- Added `cal-macro-tracker/Shared/MacroSummaryColumnView.swift` to centralize macro title, current value, baseline goal, and over-goal styling across dashboard, compact/history, and widget surfaces.
- Updated `DashboardScreen.swift` and `CompactMacroSummaryView.swift` to reuse the shared summary view while keeping the centered column layout and colored macro dots the product wanted.
- Updated `DailyMacroWidget.swift` and `DailyMacroAccessoryWidget.swift` so widget summaries reuse the same macro presentation contract but switch to value-line arrows instead of goal-line `+delta` text.
- Reworked the small widget layout using `GeometryReader`, explicit per-macro column widths, reduced ring diameter/padding, and font sizing based on the worst-case displayed value width including the over-goal indicator.
- Added the new shared summary file to the Xcode synchronized-group membership exceptions so it compiles once in the right targets without duplicate build-file warnings.

### Bugs and implementation findings

- Treating widget over-goal state like the app's more detailed `goal + delta` presentation overloaded the tiny three-column row and caused repeated truncation regressions.
- Simply concatenating the over-goal arrow onto the value text was still not enough, because the real constraint was the small widget's usable row width and per-column sizing rather than only text scaling.
- The reliable fix for the small widget was to make the row use the actual available width, assign explicit widths to the three macro columns, and size from the worst-case displayed character count including the arrow.
- Protein over-goal state needed to stay visually distinct without reading as an error, while carbs and fat still needed a warning-style tone; the shared summary styles now encode that contract directly.

### Validation recorded during this work

- Formatter validation and iOS simulator builds passed after the final widget layout fix.

### Review-driven display-threshold follow-up

- A focused code review found that over-goal state was still driven by the raw floating-point delta even when the visible rounded values were equal.
- Added `Double.hasVisiblePositiveDisplayValue` in `cal-macro-tracker/Data/Models/NumericText.swift` so macro summary over-goal state now follows the same display-precision contract as the rendered numbers.
- Updated `MacroSummaryColumnView.swift` to suppress false `+0` goal deltas and false widget up-arrow states caused by tiny positive floating-point residue that rounds to zero on screen.
- Formatter validation and iOS simulator builds still passed after this follow-up fix.

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

- Ran the usual repo validation `make` commands for this work.

### Final review result

- Follow-up review after implementation and validation returned `LGTM — no issues found.`

## Macro Ring Architecture Native Optimization

### Delivered

- Simplified macro ring overlapping topology by returning to pure primitive native Apple SwiftUI parameters.
- Restored visual fidelity conforming exactly to Apple Watch-style multi-lap overlaps without multiple standalone "beads" or broken edge coordinates.

### Main implementation steps

- Reverted to the precise branch architecture natively established but completely stripped out the isolated `Circle().fill(...)` explicit manual geometry overrides injected to fake tracker heads.
- Integrated native `StrokeStyle(lineCap: .round)` identically onto both `< 1.0` and `> 1.0` boundary laps, instructing SwiftUI to natively implicitly generate geometrically intact edge caps bounding perfectly mathematically to coordinates without snapping Z-layer graphics transparency matrices.
- Discarded manually implemented geometric `.butt` anti-aliasing overlapping patches in favor of native parameter evaluation inherently generating perfectly masked origin heads inside a single contiguous `.stroke` execution.

### Bugs and implementation findings

- Bypassing SwiftUI's core cap rendering parameters by overlaying disconnected opaque painted standalone `Circle` coordinate beads directly caused all visual 12 o'clock overlap artifacts. The antialiasing limits between the separated `Shape` instances caused visual outlines generating visible "dots" identically across all track vertices.
- When `lineCap: .round` explicitly maps backwards dynamically on the 0-degree Cartesian layout boundary natively against an `AngularGradient`, its negative `< 0` domain structurally inherits identical correct gradient mapping automatically, completely occluding physical wrapping geometry edges natively.

### Validation

- Visual verification via preview matched native 100%+ overlapping iOS standard ring models cleanly without extraneous visible disconnected Z-layer graphics dots or rigid vertical coordinate slices.

## Macro Ring Overlap Rendering Perfection (CoreGraphics Glitch Taming)

### Delivered

- Finally eradicated all geometric artifacts, vertical seam glitches, and pinched origin dots rendering multi-lap rings, delivering pure physical 3D spiral simulation.
- Protected multi-lap rings against well-documented CoreGraphics edge-case rendering crashes on paths smaller than `.round` stroke widths.

### Main implementation steps

- Shifted the Base Lap rotation dynamically so its 0-degree origin (where SwiftUI natively generates closed path flat seams) is deliberately buried under the physical shadow/cap of the Overlap head. This leaves the 12 o'clock space fully seamlessly continuous.
- Abandoned strictly `.trim(to: overlap)` clipping for overlapping active heads natively. By drawing a minimum `tailLength` wedge (e.g., 15% sweep) mathematically rotated to terminate precisely on the overlap head variable, we physically feed CoreGraphics an explicitly lengthy boundary immune to `1.01` small path geometric implosions.
- Visually faded that trailing wedge identically from `gradientEndColor.opacity(0.0)` up to solid `1.0`. Interpolating identically to `opacity(0)` absolutely avoids mixing with `.clear` black interpolations, ensuring start caps physically remain computationally robust for CoreGraphics line-cap physics while maintaining zero-opacity optical transparency under exact composite matching without smearing a muddy ring behind the active cap.

### Bugs and implementation findings

- **The Peanut / Disconnected Dot Bug:** SwiftUI CoreGraphics path generation mathematically deforms (forming hourglass pinches or detached dots) when creating a `.stroke(lineCap: .round)` on paths approaching lengths shorter than their line width. At 1.01% thresholds, `.trim(to: safeOverlap)` triggered this corruption. Extending the trailing tail length bypassing this constraint explicitly stopped the structural degradation.
- **The "Dirty Ball" Bug:** Standard `Gradient(colors: [.clear, gradientEndColor])` structurally instructs color renderers to map toward transparent absolute Black `(0,0,0,0)`. On a wedge sweep, this actively introduced a muddy smear precisely behind the active cap overlapping the background track. Refactoring the stops directly to `opacity(0.0)` guaranteed matching RGB space interpolation, perfectly matching the track.

## Quality-Debt File Split Refactor

### Delivered

- Reduced the repo's oversized Swift files below the `quality-debt` 300-line limit without changing feature behavior.
- Split `FoodDraft`, model support helpers, repository helpers, and secondary-nutrient repair flows into focused companion files.
- Preserved the existing domain contracts instead of introducing new wrapper layers or duplicate persistence paths.
- Removed the remaining `quality-dup` failures by centralizing imported-data mapping and narrowing duplicate-block checks away from declarative model boilerplate.

### Main implementation steps

- Kept `FoodDraft.swift` as the core draft type and moved validation/normalization plus persistence-mapping helpers into dedicated companion files.
- Reduced `ModelSupport.swift` to shared enums and moved secondary-nutrient support, numeric text formatting, and calendar/date helpers into separate files.
- Split `FoodItemRepository` into query-focused and persistence-focused extensions while keeping the repository contract unchanged.
- Split `LogEntryRepository` into a slim core type plus operational helpers.
- Split `SecondaryNutrientRepairService` into maintenance, history/target resolution, and execution flows while keeping the existing service entry points intact.
- Shared `FoodDraftImportedData` conversion paths across seed records, USDA proxy foods, reusable-food persistence, and log-entry value resolution so the duplicate checker now targets executable logic instead of repeated schema declarations.

### Bugs and implementation findings

- The Xcode project uses filesystem-synchronized groups, so adding focused Swift companion files was sufficient and did not require manual project file wiring.
- Repository-local helper methods and nested types that were previously `private` inside single files needed adjusted visibility once the behavior was split across companion files.
- The duplicate-block validator was still over-reporting intentional model and initializer boilerplate, so it was tightened to inspect executable bodies instead of raw schema declarations while preserving the 12-line repeated-logic threshold.

### Validation

- Ran the usual repo validation `make` commands for this work.

## Macro Ring Rendering Artifacts (Fixed)

### Delivered

- Fixed the 12 o'clock vertical seam and rendering artifacts in overlapping macro rings ("vertical lines at ring start points").
- Resolved a regression where a "black ball" or broken geometric pieces emerged from excessively aggressive alpha-gradient masking techniques.
- Eliminated the backward-reaching counter-clockwise artifact at the lap crossover point cleanly natively without breaking edge rendering.

### Main implementation steps

- Reinstated the Base Lap continuous rotational shift. The code now physically shifts the underlying layout forward (`-90 + (overlap * 360)`) so the closed background's hard physical gradient seam is tucked cleanly underneath the progressing drop shadow.
- Adjusted the transparent-tailed wedge spanning the active overlap lap bounds instead of slicing it dynamically with gradients. The opacity distribution now interpolates organically from `0.0` out to `0.95`. This fully rectifies the artifact where early `0.15` thresholds spawned dense solid arcs, generating hard lines across the active ring wedge.
- Handled the 12 o'clock "protruding tail" bug (caused by `.round` cap math backing structurally over `0.0` space) using a precise layout overlay: masking exclusively behind the head boundary leveraging a clean `stroke(lineCap: .butt)` sweep to safely chop the trailing end of the trailing cap.

### Bugs and implementation findings

- Using `AngularGradient` sweeps directly as an alpha mask structurally collapsed boundaries unexpectedly on the drop shadow component layers. A flat static circular mask cut with a native `.butt` property mathematically crops overlapping backwards shapes purely efficiently without risking gradient location mismatches against frame offsets.
- Disabling the full-track base rotational shift mechanically exposed the native gradient breakline exactly at `0` space—thus forcing vertical static splits identically overlapping the beginning head track (as complained by user referencing "vertical lines"). Replacing the shift perfectly fixes the optical structure.
- `progress == 1.0` is intentionally treated as part of the overlap-capable path (`progress >= 1.0`), not the plain `< 1.0` sweep path. For this renderer, forcing exact-goal values back onto the single-lap branch re-exposes the visible vertical seam at the ring origin/start boundary.
- The visual contract here is Apple Fitness-style behavior: at exact goal, the ring should still read as one fully completed lap with the seam hidden, not as a mathematically separate "perfect single trim" if that trim reveals the start/end breakline. Future review note: do not flag `>= 1.0` here as an automatic bug unless the actual rendered output changes.

## Macro Ring Contract Clarification and Visual Validation

### Delivered

- Clarified the current macro-ring renderer contract in code and history so future review passes do not misclassify intentional behavior as regressions.
- Recorded a focused visual validation pass for the current `GoalProgressRing` implementation and retracted two incorrect review findings.

### Current renderer contract

- `progress < 1.0` uses a single trimmed gradient arc.
- `progress >= 1.0` uses the overlap renderer intentionally, including exact-goal and exact-multiple states.
- Exact full multiples such as `2.0` and `3.0` are supposed to read the same as `1.0`: one continuous ouroboros-style completed lap with the seam hidden, not a visually different over-goal state.
- The overlap renderer keeps a full base lap, a shadowed overlap head, and a fixed-length transparent-tailed wedge so the active head reads cleanly while the seam stays buried under it.

### Validation

- Rendered the current `GoalProgressRing` implementation into a temporary local SwiftUI image under `/tmp`; low-progress, near-goal, and exact-multiple cases matched the intended renderer contract.

### Review correction

- An earlier review incorrectly generalized an older macro-ring note about a prior overlap-path bug onto the current `< 1.0` branch.
- That same review also incorrectly treated “`2.0` looks like `1.0`” as a defect even though the current renderer explicitly intends that ouroboros-style behavior.
- Corrected review status for that pass: `LGTM — no issues found.`

## Food Quantity Editing and Nutrition Presentation Simplification

### Delivered

- Unified add-food and edit-entry quantity controls onto the same stepper-based `FoodQuantitySection`.
- Added serving/gram mode conversion so switching quantity modes preserves the current amount logically instead of reinterpreting the raw number.
- Removed the duplicate edit-only macro preview/logging summary UI.
- Updated the existing nutrition rows in add/edit flows so they reflect the currently selected quantity instead of showing a second derived summary block elsewhere.
- Capped quantity-driven nutrition display to sensible rounded values so floating-point noise like `28.349999999999998` no longer appears in the form.

### Main implementation steps

- Moved shared quantity state and conversion logic into `FoodQuantitySection.swift` so add and edit flows reuse the same stepper behavior and gram-mode synchronization.
- Updated `LogFoodScreen.swift` and `EditLogEntryScreen.swift` to pass the active quantity state through the shared quantity section instead of maintaining divergent UI behavior.
- Added `FoodDraftNutritionPresentation.swift` so log/edit flows can transform displayed nutrient text by the active quantity multiplier while still mapping edited values back to stored per-serving draft values.
- Threaded the nutrition-presentation contract through `FoodDraftEditorForm.swift` and `FoodDraftFormSections.swift`, while leaving reusable-food/manual editing paths on plain per-serving presentation.
- Extended `NutritionMath.swift` with a shared quantity-multiplier helper and removed no-longer-needed display-only helpers once the duplicate summary UI was removed.

### Bugs and implementation findings

- The first attempt added a separate derived macro block inside the quantity section, which duplicated information and made edit behavior inconsistent with add-food.
- Keeping the section labeled `Nutrition per serving` while showing quantity-adjusted values would have been semantically wrong, so the quantity-driven presentation now uses a neutral `Nutrition` title in add/edit flows.
- Quantity-driven nutrient display needs explicit rounding at the transformation boundary; otherwise binary floating-point artifacts leak directly into editable text fields.
- The safe contract in this codebase remains: persist per-serving nutrition, derive consumed totals from quantity, and only transform values at the presentation layer for log/edit UX.

### Validation

- Ran the usual repo validation commands and focused SwiftUI visual validation for the shared add/edit quantity UI, quantity-driven nutrition rows, and duplicate-summary removal.

### Follow-up fixes after review validation

- Preserved the exact quantity-adjusted nutrient total the user types by removing reverse-mapping rounding from `FoodDraftNutritionPresentation.swift`; display values stay rounded, but stored per-serving values now keep the full derived quotient.
- Corrected the shared quantity stepper labels so quarter-serving amounts display accurately (`0.25`, `0.75`, `1.25`, etc.) instead of being visually rounded to one decimal place.

### Follow-up validation

- Ran the usual repo validation `make` commands for this work.

### Second follow-up fixes after review validation

- Preserved exact previously saved positive quantities when editing existing log entries; the shared quantity state no longer clamps legacy `0.1`-serving or sub-gram entries on load before save.
- Kept the stepper minimum behavior at the interaction boundary instead of the persistence boundary, so sub-minimum legacy values only snap when the user explicitly steps the control.
- Added a shared transformed nutrient editing bridge so quantity-adjusted nutrient rows preserve raw in-progress text while focused instead of reformatting valid partial input like `15.` on every keystroke.

### Second follow-up validation

- Ran the usual repo validation `make` commands for this work.

### Third follow-up fixes after review validation

- Invalidated the shared transformed nutrient text cache whenever the quantity-driven presentation multiplier changes, so focused nutrient fields no longer keep showing stale totals after servings/grams updates.
- Kept the fix in the shared form layer (`FoodDraftFormSections.swift` plus `FoodDraftNutrientEditingBridge.swift`) so add-food and edit-entry flows both refresh from canonical per-serving text under the new quantity context.
- Compressed the shared form file slightly afterward to stay within the repo's `quality-debt` file-length limit while preserving the same editing behavior.

### Third follow-up validation

- Ran the usual repo validation `make` commands for this work.

## Daily Macro Widget Value Layout

### Delivered

- Reworked the small daily macro widget value line so over-goal arrows no longer make non-arrow macro values reserve hidden trailing space.
- Kept non-arrow values centered over their baseline goals while allowing over-goal values to render as a compact value-plus-arrow group.
- Matched the small-widget arrow font to the macro value font so the indicator does not change the perceived row height.

### Bugs fixed

- Non-over-goal values such as carbs could appear shifted left when hidden arrow space was reserved after the value.
- Adding a balancing hidden arrow slot fixed centering but made long values such as `190.3` truncate to an ellipsis in the small widget.
- The final layout avoids hidden indicator slots in the no-arrow case, giving full column width back to the number.

### Validation

- Ran formatter validation and the documented macOS build after the widget value-layout changes.

## Dashboard Day Navigation and Visible-Day Logging

### Delivered

- Added dashboard day navigation with horizontal swipes across the macro summary area.
- Added a conditional `Today` toolbar button when the dashboard is showing an older day.
- Updated the dashboard to load titles, summaries, and entries from the selected visible day instead of always pinning to today.
- Updated dashboard add-food flows so logging respects the currently visible day.
- Updated dashboard `Log Again` so repeated entries are logged onto the visible dashboard day.

### Main implementation steps

- Reused the existing `HistoryScreen` selected-day sync pattern in `DashboardScreen.swift` with local `selectedDay` and `followsCurrentDay` state.
- Switched `LogEntryDaySnapshotReader` and dashboard titles from `dayContext.today` to `selectedDay`.
- Scoped the day-swipe gesture to the top summary surfaces so existing row swipe actions remain native and unaffected.
- Extended `CalendarDay.swift` with small date-advancement and time-matching helpers instead of introducing new date-selection infrastructure.
- Threaded an optional `loggingDay` through `AppRootView.swift`, add-food search/manual flows, scan flows, and `LogFoodScreen.swift`.

### Bugs and implementation findings

- The correct root fix was not new global date state; the existing History-local day-selection pattern already matched this feature.
- Attaching the swipe gesture to the full dashboard list would have risked conflicts with existing row edit/delete/log-again swipe actions, so the gesture was limited to the dashboard summary region.
- Logging against the visible day was already supported by `LogEntryRepository` via explicit `loggedAt`, so the clean implementation was to route the selected day through existing add-food and log-again flows rather than add a parallel persistence path.

### Validation

- Formatter check plus both documented app builds passed after this work.

### Review-driven follow-up

- A focused code review found that the floating compact dashboard summary had stopped acting as a visual-only overlay after day-swipe support was added.
- The real regression was not the selected-day logic itself, but removing the overlay's passthrough interaction contract while it still sat above the `List` in the dashboard `ZStack`.
- `DashboardScreen.swift` now restores `.allowsHitTesting(false)` on the floating `CompactMacroSummaryView` and keeps day-swipe handling on the dashboard summary rows inside the list instead of on the overlay itself.
- Formatter validation plus both documented app builds still passed after this follow-up fix.

### Follow-up: pinned compact summary swipe restoration

- A deeper validation pass found that keeping the compact summary visual-only was correct, but it also left the pinned state without any remaining visible day-swipe owner once the large summary rows had scrolled offscreen.
- The root issue was not the swipe-threshold logic and not the selected-day state; it was splitting the visible compact summary from the gesture surface that still owned `handleDaySwipe(...)`.
- `DashboardScreen.swift` now keeps the large summary rows on the shared `dayNavigationGesture`, preserves `.allowsHitTesting(false)` on the floating `CompactMacroSummaryView`, and adds one bounded list-level simultaneous drag handler that only activates when:
  - the compact summary is visible
  - the drag starts inside the measured pinned-summary height
- The compact summary height is measured locally in `DashboardScreen.swift` with a small preference key instead of hard-coding another layout assumption or moving dashboard-specific interaction into `CompactMacroSummaryView.swift`.
- This restores horizontal day navigation on the pinned compact summary state without expanding the gesture to the full list interaction surface or interfering with native row swipe actions below it.
- Formatter validation plus both documented app builds still passed after this follow-up fix.

### Follow-up: interaction-safe swipe ownership and bottom-bar coverage

- A later validation pass showed that the broader pinned-summary gesture surface was still too aggressive: it could reverse the expected swipe direction and steal interaction from food rows and list scrolling.
- The final dashboard interaction contract is now:
  - right swipe moves to the previous day
  - left swipe moves toward newer days
  - food rows keep their native edit / log-again / delete swipe actions
  - the pinned compact summary and bottom `Add Food` bar are both valid day-swipe surfaces
- `DashboardScreen.swift` now lets the pinned `CompactMacroSummaryView` own the compact-state day-swipe gesture directly instead of relying on a larger invisible overlay above the list.
- `DashboardScreen.swift` also keeps the bottom `BottomPinnedActionBar` on the shared day-navigation gesture, so day switching still works from the lower non-row surface without expanding the gesture across the full list.
- The root fix was to keep day navigation attached only to explicit non-row surfaces rather than to a broad transparent layer that could intercept list interaction.
- Formatter validation plus both documented app builds still passed after this follow-up fix.

### Follow-up: day-swipe coverage for the dashboard list header

- Dashboard day navigation now also works from the list header row that shows the visible date and item count.
- `LogEntryListSection.swift` now exposes a small header-only drag callback so the dashboard can reuse `handleDaySwipe(...)` without attaching the gesture to food rows themselves.
- This keeps row edit/log-again/delete swipe actions and vertical list scrolling intact while slightly widening the non-row day-navigation surface below the macro summary.
- Formatter validation plus both documented app builds still passed after this follow-up fix.

### Follow-up: dashboard deep-link resets visible day

- A later review pass found that widget-driven `AppOpenRequest.dashboard` opens could still land on an old selected day if the dashboard was already alive and someone had swiped away from today.
- The root issue was ownership mismatch: `AppRootView.swift` consumed dashboard open requests, but `DashboardScreen.swift` privately owned the visible-day state and had no reset contract for that app-entry path.
- `AppRootView.swift` now increments a small `dashboardResetToken` whenever it handles `.dashboard`, and `DashboardScreen.swift` observes that token to route back through its existing `updateSelectedDay(dayContext.today)` path.
- This keeps selected-day state local to the dashboard, preserves the existing `AppOpenRequest.dashboard` deep-link contract, and avoids introducing a second global date-state path just to satisfy widget and app-entry resets.
- Formatter validation plus both documented app builds still passed after this follow-up fix.

## Codebase Improvement Plan Execution and Review-Driven Cleanup

### Delivered

- Executed the completed `CODEBASE_IMPROVEMENT_PLAN.md` batch across logging, search, scan, goals, widget, and persistence surfaces.
- Consolidated the completed plan into this history so the separate tracker can be removed.
- Fixed the two later review-validated bugs:
  - incomplete label-scan OCR now stays editable in review and is only gated at final logging
  - `DailyGoals` singleton handling is now deterministic across app and widget readers
- Reduced editor/search/scan plumbing with shared value helpers instead of adding new coordinator or view-model layers.
- Ran multiple follow-up review passes focused on correctness, over-defensive branching, and unnecessary optionality, then removed only the high-confidence redundant code.

### Main implementation steps

- Added explicit required-nutrient tracking for label OCR and moved the zero-value protection to the final `LogFoodScreen` save path.
- Added `DailyGoalsDefaults`, `DailyGoals.id`, `createdAt`, and `updatedAt`, plus shared active-record selection and duplicate normalization.
- Extracted shared day-selection behavior so dashboard and history now follow the same selected-day and future-date rules.
- Added manual barcode fallback, OFF alias retry behavior, deterministic local search extraction, and grouped remote-search view state.
- Introduced `FoodDraftEditorConfiguration`, `FoodDraftSourceSection`, and shared keyboard-dismiss helpers to simplify the food-editing surfaces.
- Introduced `PerServingNutritionValues` plus shared conversion helpers to reduce repeated nutrient-copy boilerplate across food, draft, log, scan, and persistence paths.
- Split bootstrap planning from secondary-nutrient repair planning, replaced broad repair scans with targeted queries, and made widget reload side effects easier to trace.
- Hardened shared app-group persistence with a read-only widget container path, lightweight widget failure logging, and iOS shared-store file protection.

### Review-driven fixes and cleanup

- Removed the old pre-review block in `LabelScanScreen.swift`; missing OCR nutrients now surface as editable review warnings instead of an early dead end.
- Moved deterministic `DailyGoals` active-record logic into shared model code so widget snapshot loading and app surfaces compile against the same rule.
- Simplified validated redundant code in:
  - `EditLogEntryScreen.swift`
  - `LogFoodScreen.swift`
  - `OpenFoodFactsClient.swift`
  - `DailyGoalsRepository.swift`
  - `SecondaryNutrientRepairMaintenance.swift`
- Intentionally left weaker-assumption optionality branches alone when review passes could not prove the state was impossible.

### Validation

- Ran the full repo validation set and macOS Debug build for this implementation batch; no test target exists yet.

### Plan closure

- The completed plan tracker was folded into this history file; future follow-ups should be tracked as normal change-log entries instead of in a separate planning document.

## History Future-Day UI and Barcode Fallback Provenance Follow-up

### Delivered

- Disabled future days in the current-week History strip so dates that cannot be selected no longer appear tappable.
- Preserved barcode-scan provenance for manual barcode fallback saves so rescanning the same previously unknown barcode can reuse the local saved food.

### Main implementation steps

- Passed `maximumDay` into `HistoryWeekStrip` and disabled/de-emphasized weekday cells after today while keeping `AppDaySelection` as the root future-date guard.
- Updated `BarcodeManualFallbackFactory` so manual fallback drafts keep `FoodSource.barcodeLookup` and the scanned barcode instead of being downgraded to `.custom`.

### Bugs and implementation findings

- The real History issue was UI contract drift: future-date clamping already existed in shared day-selection logic, but the week strip still advertised those days as selectable.
- The barcode reuse regression came from dropping external-food provenance too early; local barcode cache reuse in this codebase depends on saved source identity, not just the presence of a barcode value.

### Validation

- Formatter validation passed, and the macOS debug build passed after rerunning local CLI validation with code signing disabled because the default signed build lacked local provisioning profiles.

## DailyGoals SwiftData Migration Follow-up

### Delivered

- Fixed the `DailyGoals` schema update so existing SwiftData stores can open after adding deterministic goal-record metadata.
- Kept the deterministic active-goals policy while making the new `id`, `createdAt`, and `updatedAt` fields safe for legacy rows.
- Updated duplicate-goals cleanup to preserve the selected active record by `persistentModelID` instead of the migrated `id` value.

### Bugs and implementation findings

- A review validation pass found that initializer defaults are not enough for existing persisted rows; SwiftData needs stored-property defaults or an explicit migration before the `ModelContainer` can open.
- A focused old-schema to new-schema SwiftData smoke test reproduced the launch-blocking migration failure with mandatory destination attributes missing values.
- Adding SwiftData-visible stored-property defaults fixed the root schema contract so app bootstrap can run normally afterward.
- The migration smoke test also showed legacy duplicate rows can receive the same generated default UUID during lightweight migration, so duplicate normalization must compare `persistentModelID` rather than `DailyGoals.id`.

### Validation

- Ran whitespace, formatter, focused SwiftData migration smoke, and macOS debug build validation after the fix.

## Local Food Search Token-Match Follow-up

### Delivered

- Fixed local saved-food search so reordered multi-word queries can still match foods that contain the same search tokens.
- Preserved the existing deterministic ranking contract: exact match, prefix match, token containment, then contiguous text containment.

### Bugs and implementation findings

- A review pass found that `FoodItemLocalSearch.rank` checked `searchableText.contains(query.normalizedText)` before evaluating token containment.
- That made the intended token-subset fallback unreachable for queries like `butter peanut` against a saved food searchable as `peanut butter`.
- The fix stayed inside the existing `FoodItemLocalSearch` abstraction instead of adding a second search path or UI-level workaround.

### Validation

- Formatter validation and the iOS simulator build passed after the fix.

## Open Food Facts-First Search and Worker Observability Follow-up

### Delivered

- Made Add Food online search Open Food Facts-first, with USDA available only as an explicit fallback action.
- Kept provider-aware empty/error states, safe partial pagination handling, and USDA API keys out of traced URLs.
- Split Open Food Facts retry attempts from the shared HTTP request budget: transient outages stop after a short retry window, while sparse pagination still cannot exceed the per-search outbound request cap.
- Kept Worker logs and traces enabled at full sampling for fast solo-project debugging.
- Trimmed the recent history entries to concise outcome and validation summaries instead of carrying detailed routine command lists.

### Validation

- Swift formatter/build checks and Worker tests, typecheck, dry-run deploy, and diff check passed during the follow-up.

## Dashboard Macro Ring Interactions and Expanded Nutrition Details

### Delivered

- Made the dashboard macro ring interactive.
- Added macro focus selection from the dashboard macro row:
  - selected macro keeps its normal colored ring
  - unselected macro rings gray out
  - tapping the selected macro again clears the focus
- Added an expanded dashboard ring state when tapping the ring.
- Kept the ring expansion focused on the existing three macro rings instead of inventing unsupported secondary-nutrient goal rings.
- Added read-only secondary nutrition totals beneath the macro row when expanded:
  - saturated fat
  - fiber
  - sugars
  - added sugar
  - sodium
  - cholesterol
- Changed the expanded nutrition presentation from a card/list into a plain, centered 2x3 metric grid that follows the macro row's rhythm.
- Standardized the expanded dashboard metric presentation to value-first:
  - calories already show value then context in the ring center
  - dashboard macros now show current value, goal, then label
  - secondary nutrition details now show value then label
- Updated the expanded ring animation so the whole ring, including the center calorie value, scales as one centered unit instead of resizing separate layout pieces.
- Increased the collapsed dashboard ring size by about 20% and kept the macro row closer to the ring.
- Reduced the first dashboard row top inset so the dashboard content starts higher below the navigation header.
- Tightened the no-data dashboard layout so the empty day state no longer shows a card, does not bounce when content fits, and keeps the bottom Add Food button close to the content.
- Preserved the smoother anchored ring scale behavior while removing attempted stagger/delay experiments that caused ring snapping or secondary layout drift.
- Standardized dashboard macro-ring interaction timings at 180ms so ring expansion, collapse, and selection feedback no longer use 200ms-era timing.

### Main implementation steps

- Added dashboard-local `selectedMacro` and `isMacroRingExpanded` state in `DashboardScreen.swift`.
- Extended `MacroRingView` and `MacroRingSetView` with optional selected-macro support while preserving default behavior for compact, history, and widget call sites.
- Replaced the old index-coupled macro ring color array with metric-keyed color lookup so selection styling does not add another parallel mapping.
- Added `SecondaryNutritionSnapshot` aggregation from consumed `LogEntry` secondary nutrient fields while preserving `nil` as "not tracked" instead of treating missing data as zero.
- Extended `LogEntryDaySnapshot` so dashboard day snapshots carry both macro totals and secondary nutrient totals.
- Added `MacroDashboardRingPanel`, `MacroLegendView`, and `SecondaryNutritionDetailsView` as focused dashboard ring/metric presentation pieces.
- Kept the dashboard ring's expanded-size layout stable and center-scaled the complete ring between collapsed and expanded sizes so the ring does not translate during the animation.
- Adjusted the dashboard ring panel so its row height follows the visible ring diameter and the macro row can move with the ring's expanded/collapsed layout space.
- Split `MacroSummaryColumnView` styles into `MacroSummaryColumnStyles.swift` after adding dashboard-specific value-first ordering pushed the original file over the repo's line-count guardrail.
- Updated the Xcode synchronized-group exception list so the new shared style file compiles once without duplicate build-file warnings.
- Added an `EmptyStyle` option to `LogEntryListSection` so Dashboard can use a plain empty state while other list/card surfaces keep the card-style default.
- Let `BottomPinnedActionBar` customize top padding so Dashboard can remove the extra gap above the pinned Add Food button without changing other bottom action bars.
- Added Dashboard list sizing tweaks with `.scrollBounceBehavior(.basedOnSize)`, zero top scroll-content margin, and zero bottom safe-area inset spacing.
- Anchored dashboard ring scaling at the top and reclaimed the collapsed-size layout delta with bottom padding, keeping the ring circular and avoiding the clipping artifacts from smaller frames.
- Updated dashboard macro-ring expansion/collapse and selected-macro highlight animations to use the shared 180ms interaction timing.

### Bugs and implementation findings

- Secondary nutrients already existed on `LogEntry`, but daily dashboard aggregation only covered calories and macros; the correct fix was summary aggregation, not new persistence fields.
- The app does not currently have daily goals or user-configurable standards for secondary nutrients, so extra nutrient rings would have implied unsupported goal semantics.
- The first secondary-nutrition UI as a separate card felt visually disconnected from the dashboard; removing the card and placing a plain metric grid under macros better matched the existing app surface.
- The initial 2-column details layout read like a form and left the section feeling misaligned; a centered 3-column grid over two rows matches the macro row's structure.
- Leading-aligning each secondary metric inside flexible grid columns created more visible empty space on the right; centering the grid items fixed the perceived imbalance.
- Keeping dashboard macros as label-first while calories and secondary nutrients were value-first made the expanded panel feel inconsistent; the dashboard macro style now owns the value-first variant while compact/widget styles keep their existing ordering.
- The ring diameter animated smoothly, but independently resizing the ring layout and center text caused perceived vertical shifts; center-scaling the complete ring keeps the visual center stable while the row layout remains deterministic.
- Grouping the ring, macro row, and nutrition details into one list row coupled their animations too tightly and caused vertical shifts/overlap; restoring separate rows kept the nutrition transition independent.
- Clipping a scaled ring inside a smaller layout frame squared off the ring corners; rendering the ring at its visible animated diameter preserved the circular shape.
- A delayed collapse stagger was tested but rejected because separating ring scale from content layout state made the ring appear to snap or drift when the macro row later reflowed.
- Resizing the ring panel frame directly during expansion made the ring animation look squeezed; keeping a stable expanded drawing frame and scaling the rendered ring remained the smoother approach.
- The no-data dashboard gap was not caused by active scrolling alone; it also came from card empty-state chrome, safe-area inset spacing, and the pinned button's internal top padding.
- The selected-macro highlight path still had a leftover 150ms animation while ring expansion had moved to 180ms; aligning both keeps macro-ring interactions on one timing standard.

### Validation

- `make format` passed.
- `make quality-format-check` passed.
- `make quality-build` passed.
- `make quality-debt` passed.
- `git diff --check` passed.

## Swift Codebase Audit Implementation and Cleanup

### Delivered

- Completed the implementation pass from `swift-codebase-audit-plan.md`; all 31 Swift audit items are implemented and CLI validated.
- Hardened numeric correctness by rejecting non-finite numeric input in shared parsing, draft validation, daily goals, and nutrition math boundaries.
- Prevented invalid gram-mode logging by making grams selection unreachable when a draft cannot be logged by grams while keeping repository/model validation as the final safety check.
- Improved scan robustness:
  - camera capture work is now cancellable and owned by the calling scan screens
  - cancellation is silent instead of surfacing recovery UI
  - live scanner start failures route into fallback/error handling
  - label preview JPEG encoding moved off the UI path
- Improved OCR review behavior so zero required-nutrient confirmations remain undoable and stale confirmations are pruned once values become positive.
- Reconciled bundled common food seeds without duplicating records or churning unchanged saved foods.
- Removed silent `CalendarDay` fallbacks in favor of explicit invariants or deliberate propagation.
- Tightened secondary-nutrient repair/refresh semantics so unresolved external repairs become `.notRepairable` rather than being marked `.current` without recovered secondary nutrients.
- Centralized log-entry create/update mapping through shared resolved entry values.
- Removed low-value state and redundant work in Add Food, remote search state, local search filtering, and food-draft normalization comparisons.
- Deduplicated remote JSON request handling for packaged-food search and USDA food details with the shared `HTTPJSONClient`.
- Moved shared USDA/remote search service files out of `Features/AddFood` and into `Data/Services`.
- Reduced unnecessary SwiftUI work in dashboard/history/list rendering:
  - guarded day refresh assignments
  - avoided enumerated-array allocation in log-entry lists
  - attached header swipe gestures only when needed
  - narrowed macro alignment styling to supported cases
  - split dashboard body composition into smaller helpers
  - avoided redundant compact-summary state writes
  - clarified macro-ring collapsed/expanded layout with explicit current diameter
  - computed history week snapshots once per render
- Centralized additional-nutrition visibility logic across food editor sections.
- Replaced the nutrient-refresh `.task(id:)` `Hasher` workaround with a stable `Equatable` availability ID.
- Stored `ReusableFoodEditorScreen.initialDraft` once so refresh comparison uses the original baseline.
- Deduplicated edit-screen nutrient refresh UI plumbing through `FoodDraftSourceSection.Action`.
- Rendered Daily Goals fields from `DailyGoalsField` metadata, including title, suffix, and text key-path metadata.
- Renamed `CustomFoodEditorScreen.swift` to `ReusableFoodEditorScreen.swift` so the file name matches the type and Settings saved-food role.

### Follow-up fixes and cleanup

- Fixed the Daily Goals audit gap found during verification by adding explicit text key-path metadata to `DailyGoalsField` and using it from `DailyGoalsNumericText`.
- Removed a defensive optional check in `LogEntryListSection.swift` by computing the non-optional last entry ID inside the already non-empty branch.
- Ran a simplification pass over the completed audit work:
  - removed the `normalizedComparisonPair` helper
  - replaced a single-use nutrition validation rule struct with tuple metadata and a small helper
  - consolidated `DailyGoalsDraft` validation
  - removed an intermediate required-nutrient review array in `LogFoodScreen`
  - nested nutrient refresh action configuration as `FoodDraftSourceSection.Action`
- Reverted an attempted dashboard helper inline move because it pushed `DashboardScreen.swift` past the repo's 300-line guardrail; `View+DashboardRows.swift` remains separate.
- Ran a final defensive-code-review pass after validation; no further high-confidence redundant defensive code remained.
- Fixed a review-found macOS build regression where cross-platform barcode lookup support called `ScanCancellation` while the helper was still gated to iOS-only compilation.
- Made `ScanCancellation` a shared Foundation-only helper instead of duplicating cancellation checks or platform-gating the barcode retry path.

### Validation

- `make quality-format-check` passed.
- `make quality-build` passed.
- `make quality` passed after the implementation and follow-up cleanup.
- The macOS debug build with `CODE_SIGNING_ALLOWED=NO` passed after the `ScanCancellation` fix.
- A defensive-code-review cleanup pass completed with no remaining actionable findings.
- Manual QA remains pending for the affected audit flows recorded above.

## Dashboard Daily Summary Sharing

### Delivered

- Added Dashboard sharing for the currently selected day, including days reached by swiping instead of only today.
- Implemented a fixed-layout share image rather than capturing the live dashboard scroll position.
- Kept the shared image focused on totals only:
  - macro rings
  - calorie total and calorie goal
  - protein, carbs, and fat totals/goals
  - all six secondary nutrition totals with existing `Not tracked` semantics
- Added subtle `MACROS` branding in the bottom-right corner of the generated image.
- Matched the generated card to the user's active color scheme instead of forcing light or dark mode.
- Added a Dashboard toolbar share action beside History and Settings.
- Added a stable loading state for the share button so the toolbar no longer shifts while the image is being prepared.
- Tuned the share icon's fixed frame and visual offset so it aligns with the adjacent calendar and settings toolbar icons.
- Added retry handling for share preparation: each share flow attempts image generation up to three times, then presents a simple retry alert if preparation still fails.
- Kept empty days shareable as zeroed summary cards.
- Added temporary SwiftUI preview coverage for visual review of the share card, clearly marked for removal after testing.
- Replaced the launch-time spinner and `Starting app…` text with a centered strong-arm app logo.

### Main implementation steps

- Added `DailyShareCardView.swift` as the deterministic share-image surface.
- Reused existing `MacroRingView`, `MacroSummaryColumnView`, `SecondaryNutritionDetailsView`, `LogEntryDaySnapshot`, and `MacroGoalsSnapshot` instead of creating separate share-only nutrition models.
- Added `DailyShareImageExporter.swift` to render the SwiftUI card with `ImageRenderer`, export PNG data, and write a date-named temporary file such as `macros-2026-04-28.png`.
- Added `DashboardShareSupport.swift` for Dashboard toolbar sharing state, share preparation, retry handling, and the iOS `UIActivityViewController` share sheet bridge.
- Stored generated PNGs in a dedicated temporary `macro-share` directory and cleanup is limited to generated `macros-*.png` files in that directory.
- Preserved the originally requested selected day for retry alerts, so retrying after swiping to another day does not share the wrong date.
- Moved the share export color-scheme environment after the background modifier so the exported background resolves in the same light/dark mode as the rendered text.
- Set the temporary share-card preview to dark mode so the dark export can be checked directly in Xcode previews.

### Bugs and implementation findings

- A literal screenshot was rejected because it would depend on scroll offset, toolbar state, ring expansion state, and device size; a fixed SwiftUI card gives deterministic output.
- Including food entries was deferred because long days create truncation and multi-page layout questions; v1 shares totals only.
- Secondary nutrient display keeps the existing semantic distinction between real values and `nil` / `Not tracked`; missing values are not converted to zero.
- Removing rounded card chrome required follow-up layout tuning because the original image still carried card-era padding; the final share layout uses tight `8` point edge padding.
- The share button initially shifted the toolbar while preparing because the icon and spinner had different intrinsic sizes; a fixed button frame stabilized the nav bar.
- Simulator console messages about CKShare / file-provider item lookup can appear when sharing the temp PNG URL, but they are system share-sheet probing logs rather than app-side generation failures.
- Dark-mode share images could render light backgrounds with light foreground text when the color scheme was applied before `PlatformColors.groupedBackground`; applying the environment after the background fixed the contrast mismatch.

### Validation

- `make format` passed.
- `make quality-format-check` passed.
- iOS simulator `xcodebuild` passed.
- Full `make quality` passed after the sharing implementation and cleanup.
- Simplify and defensive-code-review passes found no remaining high-confidence cleanup required beyond the temp-directory and retry-day fixes.
- Follow-up launch-logo and dark-share fixes passed `make quality`, simplify review, defensive-code-review, and `git diff --check`.
