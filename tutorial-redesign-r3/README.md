# Dashboard tutorial redesign, round 3

This is the complete screenshot matrix requested for round 3. The ordinary evidence policy limits a task to five images and 2 MiB; this task intentionally exceeds both limits (48 images, about 11.5 MB) because it requires every tutorial state across two devices and four presentation modes. No videos, logs, or `.xcresult` bundles are tracked.

## Source and environment

- Implementation: `feature/tutorial-redesign` at `8d9daf26943dc5794f09ae499a5728e0d5402e14`
- Devices: iPhone Air (`844B72D7-D128-4607-AB2E-6C14B024618F`) and iPhone 17e (`F976E800-DA1F-4F20-B755-DFD964E33975`)
- Runtime/toolchain: Xcode 26.4.1, iOS Simulator, status bar fixed to 9:41
- Fixture: first-run tutorial, driven by a temporary capture-only UI-test helper; the helper was removed and is not part of either commit
- Raw `.xcresult` bundles and original-resolution exports were stored under `build/evidence/2026-11-24-tutorial-redesign-revision/` in the implementation worktree for validation and are not included here. This transfer contains only PNG exports resized to 1300 pixels tall.

## Matrix

Each device has:

- `light/`: all eight tutorial steps and the recap
- `skip/`: four states from the skip-step flow
- `dark/`: tutorial steps 1 and 4 in dark appearance
- `ax-xxxl/`: all eight tutorial steps and the recap with Accessibility XXXL text

Expected: the two floating controls match the dashboard bar, captions stay clear of the controls, the accessibility macro spotlight advances through Protein, Carbs, and Fat individually, and the recap guidance and full-width Done button remain visible. Observed: the real-gesture, Skip Step, and AX XXXL flows passed in light appearance on both devices; the dark-step flow passed with dark appearance explicitly enabled on both. The flows exercised ring swipes, Sharing Back, Today, ring expansion, each macro tap, and Done. The exported images were reviewed for caption/control overlap, macro targeting, dark appearance, and recap clipping.

## Capture command

The capture-only UI test was temporary and intentionally not committed. To reproduce the matrix, restore a local test helper that drives the first-run tutorial and attaches screenshots, then run each test serially on both listed simulators. For example:

```sh
DEVELOPER_DIR=/Applications/Xcode-26.4.1.app/Contents/Developer \
xcrun simctl ui 844B72D7-D128-4607-AB2E-6C14B024618F appearance light
DEVELOPER_DIR=/Applications/Xcode-26.4.1.app/Contents/Developer \
xcodebuild \
  -project cal-macro-tracker.xcodeproj \
  -scheme cal-macro-trackerUITests \
  -destination 'platform=iOS Simulator,id=844B72D7-D128-4607-AB2E-6C14B024618F' \
  -parallel-testing-enabled NO \
  -test-timeouts-enabled YES \
  -default-test-execution-time-allowance 90 \
  -maximum-test-execution-time-allowance 90 \
  -only-testing:cal-macro-trackerUITests/TutorialCaptureUITests/testCaptureTutorial \
  -only-testing:cal-macro-trackerUITests/TutorialCaptureUITests/testCaptureTutorialSkipStepFlow \
  -only-testing:cal-macro-trackerUITests/TutorialCaptureUITests/testCaptureTutorialAX \
  -resultBundlePath build/evidence/tutorial-light.xcresult \
  test
```

The temporary tests used these selectors: `testCaptureTutorial`, `testCaptureTutorialSkipStepFlow`, `testCaptureTutorialDark`, and `testCaptureTutorialAX`. Run the dark selector after `xcrun simctl ui <UDID> appearance dark`; restore light appearance afterward. The AX selector enabled Accessibility XXXL at launch. Repeat on the other listed simulator and export attachments with `xcrun xcresulttool export attachments`.

No capture cases were blocked. The unit suite excluded StoreKit tests because simulator StoreKit has no account.
