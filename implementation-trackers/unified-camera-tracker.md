# Unified Food Camera Tracker

## Decisions and file plan

- Replace the dashboard action with equal Camera and Add Food pills; both use the existing expanded/compact display mode and capture the selected day.
- Add `Features/Scan/Camera/` with a full-height sheet, live scanner preview, result panel, and local state for barcode lookup, label recognition, fallbacks, and log-food navigation.
- Reuse `BarcodeLookupResolver`, `BarcodeImageScanner`, `BarcodeScanErrorRecovery`, `NutritionLabelTextRecognizer`, `NutritionLabelParser`, `LogFoodScreen`, and `CameraImagePicker`; do not duplicate nutrition calculation or persistence.
- Route the Add Food barcode and label actions and the quick action to the unified camera. Keep reusable parser/resolver/scanner code.
- Files expected to change: `Features/Dashboard/DashboardScreen.swift`, `App/AppRootView.swift`, `Features/AddFood/AddFoodScreen.swift`, existing barcode scanner view where coordinator reset is needed, new camera view files, this tracker, and `changes-log.md`. Remove obsolete option-list/screen UI only when references are gone.
- The camera result panel is the review surface for both barcode and OCR results; only explicit Details, Edit details, or Enter manually navigation opens `LogFoodScreen` or another editor.

## Apple API facts checked

- `DataScannerViewController.capturePhoto()` is `@MainActor func capturePhoto() async throws -> UIImage`, available from iOS 16, and returns a high-resolution photo of the live video: https://developer.apple.com/documentation/visionkit/datascannerviewcontroller/capturephoto()
- `DataScannerViewController.isSupported` is false on devices below A12; `isAvailable` reflects camera access/restrictions: https://developer.apple.com/documentation/visionkit/datascannerviewcontroller/issupported
- `AVCaptureDevice.torchMode` requires `lockForConfiguration()`, capability checking, and unlocking; setting it without configuration lock can raise an exception: https://developer.apple.com/documentation/avfoundation/avcapturedevice/torchmode-swift.property
- Apple's torch documentation does not establish that an independently obtained `AVCaptureDevice` is the device owned by `DataScannerViewController`. Do not ship an unverified/dead torch toggle; verify on device or omit it and report the limitation.

## Failure-mode handling map

| Failure or race | Required handling |
| --- | --- |
| Lookup timeout/network failure | Set a 30-second `URLRequest` timeout for remote barcode lookup; catch failure, display existing recovery copy and keep retry/label/manual paths available. |
| Duplicate recognition during lookup | One `isProcessing` gate; stop scanner and ignore further events until resolution completes. |
| Barcode during label processing | Scanner stopped while processing; reject barcode callback unless state is scanning. |
| Shutter tapped twice | Guard state is scanning before capture; transition synchronously to label-reading before awaiting. |
| Library pick while scanning | Stop live scanner before PhotosPicker; process selected image once, then resume after result dismissal/action. |
| Permission revoked mid-session | Handle scanner start failure/unavailability; show explanation and Settings link while library remains available. |
| Backgrounding mid-lookup | Keep lookup task state; stop capture on background, don't discard result, restart only after result is acknowledged and active. |
| `capturePhoto()` throws | Show readable capture error with Retake and library alternatives; restore scanner state safely. |
| Dynamic Type overflow | Scrollable result card, vertically stacked product/details controls at accessibility sizes. |
| Day changes while sheet is open | Capture `CalendarDay` at sheet creation and pass it unchanged to logging/editor. |
| Logging same product twice | Each explicit Log tap is a separate user action; disable while save is pending and show logged state without automatic timer. |
| Unsupported/unavailable camera | Use still-image camera picker when available; otherwise keep library picker accessible. |
| Barcode not found in product database | Reuse resolver error text (including WS7 throttling/Retry-After copy); offer retry, remote search if available, and label photo. |
| OCR parse failure | Show failure state with Retake and manual entry; never auto-log OCR. |
| Save failure in camera review | Keep the current unlogged result, including edited label name and servings, and show an alert so Log can be retried. |
| Long camera review result | Keep the result panel scrollable at regular and accessibility sizes, bounded to 440 points. |

## Progress

- [x] Read repository and Swift guidance.
- [x] Verify Apple camera and torch API contracts.
- [x] Implement dashboard bar split.
- [x] Implement unified camera and reuse existing logging/recovery flows.
- [x] Route entry points and remove obsolete scan UI.
- [x] Format and build.
- [x] Extract a pure, synchronous camera-flow reducer and add transition failure-mode tests before implementation.
- [x] Retain/cancel image, OCR, capture, and lookup work; prevent stale results after cancellation.
- [x] Add the guarded AVCaptureDevice torch toggle; device verification remains required.
- [ ] Complete simulator E2E and record evidence; round 3 ran dashboard and camera entry-point smoke checks on the created simulator, but photo picker/result scenarios remain pending.
- [x] Round 4: fix library import, ordered scanner/torch execution, inactive cancellation, terminal dismissal, save validation, and duplicate status/task mutations.
- [x] Round 4: expand exact reducer coverage from 10 to 22 tests and verify label import/review/reselection/cancellation on final implementation.
- [ ] Complete unknown-product lookup dismissal/recovery E2E; supplied QR is outside packaged-food symbologies.
- [x] Accessibility-size dashboard pills use icon-only mode, with VoiceOver labels retained; fallback camera copy wraps.
- [x] Preserve branch history by merging `origin/main` into `56f7e95` instead of rebasing, per owner override.

## Implementation notes

- The single Add Food dashboard button is now the existing dual-action bar with equal Camera and Add Food actions. Both respect the current compact icon display and selected day.
- The shared large-sheet `FoodCameraSheet` embeds a live `DataScannerViewController`; still photos from capture or Photos picker are barcode-scanned first, then passed to the existing label OCR/parser. It uses existing lookup/cache, fallback-draft, logging action, repository, editor, and haptic paths.
- Barcode and label results remain in the camera panel. Label scans can have their name corrected, servings adjusted, and be logged there without automatic logging; missing required nutrients route the prominent action to Edit details. `LogFoodScreen` is reached only through Details, Edit details, or Enter manually.
- Removed the separate Barcode/Label screens and option-list UI after rerouting all entry points. Shared resolver, barcode image scanner, camera picker, parser and fallback draft logic remain.
- `FoodCameraFlow` owns synchronous, sendable state transitions. Its tests cover duplicate barcode delivery, scanning exclusion while processing, shutter re-entry, Photos picker resume rules, lifecycle stop/resume, dismissal cancellation, stale recovery metadata, save gating, and quantity flow.
- The sheet stores one task for capture/photo loading, barcode lookup, and OCR; cancellation is not presented as a recovery error. Barcode serving state is shared by the panel, log action, and Details initial quantity.
- The torch resolves `AVCaptureDevice.userPreferredCamera` only when it is a back camera, otherwise tries a back-position `DiscoverySession` in triple, dual-wide, dual, and wide-angle order. It checks `hasTorch`/`isTorchAvailable`, locks configuration, and turns off when scanning stops. Device-only verification is required: watch for the preview freezing when the independently resolved device torch turns on.
- `MACROS-CAMERA2-2026-10-26` (iPhone 17 Pro, iOS 27.0) was created, shut down, and deleted; a second same-named simulator was later created for the focused test, then shut down by xcodebuild and deleted. The other pre-existing simulator was left untouched. Live scanning and torch remain device-only. A no-result QR and nutrition label fixture were generated under ignored `build/unified-camera-qa-2026-10-26/fixtures/` and added to Photos. The simulator launched the app and verified the default-size dashboard pills. Picker/product-result scenarios could not be completed; exact status and screenshot paths are in the matching QA.md.
- Validation passed after the merge: `make quality-format-check`, `make quality-build`, and `git diff --check origin/main...HEAD`. The 10-case `FoodCameraFlowTests` passed on the same implementation before history restoration; they were not rerun after merging because both simulator slots were booted and neither belonged to this task.
- Round 3 pins exact phase/effect transitions in ten reducer tests. Reducer changes include inactive image completions, shutter capture before scanner stop, post-capture stop/torch-off/read-label order, inactive-safe library cancellation, result-phase preservation during navigation, replacement quantity reset, scanner/import failures, and terminal dismissal effects. The sheet's `send(_:)` now executes scanner, task-cancellation, and torch effects centrally; photo capture and the async actions still perform their operation-specific work after sending reducer events.
- Round 3 failure-mode map: inactive image barcode/OCR completion, shutter effect order/recovery shutter, all-phase scene pause/dismiss, library replacement/cancel quantity, inactive library cancel, and navigation result preservation are covered by reducer tests. Label import, review navigation/back, and Retake were exercised in the simulator. Lookup dismissal during async work, image-import background recovery, Add Food entry-point parity, and largest Dynamic Type remain E2E/device checks.
- Round 3 validation: focused `FoodCameraFlowTests` pass 10/10; `make quality-format-check` and `make quality-build` pass. The new simulator `MACROS-CAMERA3-2026-10-26` was created and used for dashboard, camera fallback, photo picker, label OCR/review, Back, and Retake checks; outstanding checks are in `build/unified-camera-qa-2026-10-26/QA.md`. The sheet's single `send(_:)` executor runs all reducer effects in order; phase, busy, servings, result content, and recovery destination are flow/effect-owned.

## Device-only TestFlight checks

### Round-4 evidence classification

| Failure or race | Evidence |
| --- | --- |
| Active picker → background → cancel → foreground | reducer-tested, exact no-start/start effects |
| Barcode during OCR/capture; second shutter | reducer-tested |
| Inactive lookup result; active/inactive Scan again | reducer-tested |
| OCR failure clears barcode manual destination | reducer-tested; nil destination routes to label/manual entry |
| Terminal dismissal, repeated dismissal, late content/events | reducer-tested |
| Invalid quantity; validation logFinished; torch toggle gating | reducer-tested; helper/device behavior device-only |
| Library label import; repeated same-image pick; cancel | simulator-verified |
| Review without auto-log; Back; Retake; swipe dismissal/reopen | simulator-verified; live scanning device-only |
| Background immediately after image selection | simulator-verified smoke (no stuck state); exact overlap with loading not observable |
| Unknown QR → recovery / lookup dismissal | not verified: QR is unsupported; imports reach incomplete label review instead. Supplemental EAN fixture also reached incomplete label review, not lookup. |
| Add Food barcode/label buttons and dashboard Camera | simulator-verified; dashboard Add Food opens its selector as designed |
| Largest accessibility text | simulator-verified: result Review/Retake reachable by scrolling; dashboard pills truncate (FAIL); preview fallback copy clips |
| Live scanner readiness/order, torch/preview stability | reducer-tested effect order; hardware behavior device-only |

Round-4 validation: format/build pass, focused FoodCameraFlowTests 22/22 pass, whitespace check passes. Initial red test run executed 21 tests with five failed assertions in four new cases; the torch API test was added to the test-first commit before implementing its new event/effect. Red xcodebuild teardown stalled after results and was terminated; final green xcodebuild exited successfully. Simulator `MACROS-CAMERA4-2026-10-26` (`E649001E-90B8-4D08-B83E-477D752EB81A`, iPhone 17 Pro/iOS 27.0) was created within the two-booted-device limit; no other simulator was touched. Evidence/commands: ignored `build/unified-camera-qa-2026-10-26/QA.md`, round-4 section and `r4/`.

Accessibility follow-up: `MACROS-AX2-2026-10-26` verified the Camera/Add Food icon-only pills before and after dashboard scrolling and the wrapping still-camera fallback copy at accessibility-extra-extra-extra-large; screenshots and results are in ignored `build/unified-camera-qa-2026-10-26/r4-ax/QA.md`.

- Live barcode recognition and repeated scan behavior.
- Torch availability/behavior and preview stability when it is turned on (watch for preview freeze).
- Shutter capture quality with a nutrition label.
- Label OCR accuracy on a real package and correction in `LogFoodScreen`.
- WS7 HTTP 429 recovery and `Retry-After` messaging.
