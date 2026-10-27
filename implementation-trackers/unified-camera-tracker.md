# Unified Food Camera Tracker

## Decisions and file plan

- Replace the dashboard action with equal Camera and Add Food pills; both use the existing expanded/compact display mode and capture the selected day.
- Add `Features/Scan/Camera/` with a full-height sheet, live scanner preview, result panel, and local state for barcode lookup, label recognition, fallbacks, and log-food navigation.
- Reuse `BarcodeLookupResolver`, `BarcodeImageScanner`, `BarcodeScanErrorRecovery`, `NutritionLabelTextRecognizer`, `NutritionLabelParser`, `LogFoodScreen`, and `CameraImagePicker`; do not duplicate nutrition calculation or persistence.
- Route the Add Food barcode and label actions and the quick action to the unified camera. Keep reusable parser/resolver/scanner code.
- Files expected to change: `Features/Dashboard/DashboardScreen.swift`, `App/AppRootView.swift`, `Features/AddFood/AddFoodScreen.swift`, existing barcode scanner view where coordinator reset is needed, new camera view files, this tracker, and `changes-log.md`. Remove obsolete option-list/screen UI only when references are gone.

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
- [ ] Complete simulator E2E and record evidence; initial isolated simulator checks and screenshots are complete, but picker/product-result scenarios remain pending.

## Implementation notes

- The single Add Food dashboard button is now the existing dual-action bar with equal Camera and Add Food actions. Both respect the current compact icon display and selected day.
- The shared large-sheet `FoodCameraSheet` embeds a live `DataScannerViewController`; still photos from capture or Photos picker are barcode-scanned first, then passed to the existing label OCR/parser. It uses existing lookup/cache, fallback-draft, logging action, repository, editor, and haptic paths.
- Removed the separate Barcode/Label screens and option-list UI after rerouting all entry points. Shared resolver, barcode image scanner, camera picker, parser and fallback draft logic remain.
- `FoodCameraFlow` owns synchronous, sendable state transitions. Its tests cover duplicate barcode delivery, scanning exclusion while processing, shutter re-entry, Photos picker resume rules, lifecycle stop/resume, dismissal cancellation, stale recovery metadata, save gating, and quantity flow.
- The sheet stores one task for capture/photo loading, barcode lookup, and OCR; cancellation is not presented as a recovery error. Barcode serving state is shared by the panel, log action, and Details initial quantity.
- The torch resolves `AVCaptureDevice.userPreferredCamera` only when it is a back camera, otherwise tries a back-position `DiscoverySession` in triple, dual-wide, dual, and wide-angle order. It checks `hasTorch`/`isTorchAvailable`, locks configuration, and turns off when scanning stops. Device-only verification is required: watch for the preview freezing when the independently resolved device torch turns on.
- `MACROS-CAMERA2-2026-10-26` (iPhone 17 Pro, iOS 27.0) was created, shut down, and deleted; a second same-named simulator was later created for the focused test, then shut down by xcodebuild and deleted. The other pre-existing simulator was left untouched. Live scanning and torch remain device-only. A no-result QR and nutrition label fixture were generated under ignored `build/unified-camera-qa-2026-10-26/fixtures/` and added to Photos. The simulator launched the app and verified the default-size dashboard pills. Picker/product-result scenarios could not be completed; exact status and screenshot paths are in the matching QA.md.
- Validation passed: `make quality-format-check`, `make quality-build`, `git diff --check origin/main...HEAD`, and the 10-case `FoodCameraFlowTests`.

## Device-only TestFlight checks

- Live barcode recognition and repeated scan behavior.
- Torch availability/behavior and preview stability when it is turned on (watch for preview freeze).
- Shutter capture quality with a nutrition label.
- Label OCR accuracy on a real package and correction in `LogFoodScreen`.
- WS7 HTTP 429 recovery and `Retry-After` messaging.
