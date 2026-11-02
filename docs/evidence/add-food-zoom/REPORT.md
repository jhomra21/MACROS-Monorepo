# Add Food zoom + paused sharing scope

Branch `feat/add-food-zoom` (base `origin/main` 1cbea61, build 26). Commits: `ca56d91` (zoom), `a462fd6` (paused scope + changes-log).

## 1. Add Food zoom

- Apple docs (`navigationTransition(_:)`): the modifier goes on a view "that appears within a NavigationStack or a sheet, outside of any containers". `matchedTransitionSource(id:in:configuration:)` marks the source; `zoom(sourceID:in:)` takes the same id and namespace. The docs say nothing about detents, so this was checked on device (below): a `.large` detent sheet zooms and reverses correctly.
- New `AppRootSheetDestination.dashboardAddFood(CalendarDay)`, created only by the Dashboard "Add Food" button. `.addFood(entryPoint, day)` stays for deep links, quick actions and scan entry points, so they get the unchanged plain sheet. Both `.addFood(.addFood, ...)` callers (button and quick action/deep link) used the same entry point, which is why a new case was needed.
- `AddFoodScreen.zoomTransitionID = "add-food"` is the source id, passed on the trailing action of `BottomPinnedDualActionBar`.
- The namespace now serves both buttons: `cameraTransition` renamed `dashboardTransition`, `cameraTransitionNamespace` renamed `transitionNamespace`. The Add Food screen's own camera keeps its separate namespace.
- Sheet is built by a shared `navigationStackSheet(for:)`, so detent `.large` and drag indicator are unchanged.
- Tutorial: no tutorial code changed. The bar stays disabled while the tutorial runs, and the overlay hides whenever a sheet is shown. Verified by reading code only, not run.

### Frame findings (iPhone 17, 15 fps contact sheets, `video/`)

- `before-open.png`: the sheet slides up from the bottom edge; no relation to the button.
- `after-open2.png`: frames 2-4 show the sheet growing out of the Add Food button (button label fades into the sheet), then settling at full size with drag indicator.
- `after-close.png`: after tapping Cancel, the sheet shrinks back into the Add Food button's position (frames 11-14), then the button returns to normal.
- `before-close.png`: plain slide down.
- Videos: `before.mp4`, `after.mp4`. `after-open.png` is the earlier window before the sheet appeared (kept for completeness).

## 2. Paused Macros + Foods

- Cause: a segmented Picker ignores per-segment `.disabled`.
- Server: `changeOutgoingScope` in `convex-backend/convex/sharing.ts` accepts `macrosAndFoods` without a pause check, so the guard is client-side. Backend not changed.
- Fix: the "Macros + Foods" segment is omitted while paused, unless it is the current selection (so an existing scope stays visible). `updateScope` returns early for `.macrosAndFoods` while paused.
- Unpaused screen is unchanged: `person-unpaused.png` shows Nothing / Macros (selected) / Macros + Foods. No button was tapped, to avoid writing to dev Convex.
- The paused branch was NOT rendered or run: `sharingRequirePro` was not turned on. It is proven by reading the code only (no SwiftUI preview was rendered).

## Validation

- `make quality-format-check`: clean.
- `make quality-build`: succeeded.
- Full suite on iPad `E91B597B`, serial, AGENTS.md options, `-skip-testing:cal-macro-trackerTests/PurchaseStoreStoreKitTests`: 225 tests, 0 failures, no reruns (`tests.log`).
- Simulators: iPad shut down after tests. iPhone 17 was already booted and is left booted. The owner's iPhone Air (844B72D7) was already booted and was not touched, so three were booted at once.
