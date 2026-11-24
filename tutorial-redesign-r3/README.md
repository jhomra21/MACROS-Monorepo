# Dashboard tutorial redesign, round 3

This is the complete screenshot matrix requested for round 3. The ordinary evidence policy limits a task to five images and 2 MiB; this task intentionally exceeds both limits (48 images, about 11 MiB) because it requires every tutorial state across two devices and four presentation modes. No videos, logs, or `.xcresult` bundles are tracked.

## Source and environment

- Implementation: `feature/tutorial-redesign` at `bbb0f72e7a9f832c20fa314398adb8bdc6ea265a`
- Devices: iPhone Air (`844B72D7-D128-4607-AB2E-6C14B024618F`) and iPhone 17e (`F976E800-DA1F-4F20-B755-DFD964E33975`)
- Runtime/toolchain: Xcode 26.4.1, iOS Simulator, status bar fixed to 9:41
- Fixture: fresh app install and first-run tutorial, driven by a temporary capture-only UI-test helper; the helper was removed and is not part of either commit
- Raw `.xcresult` bundles and original-resolution exports were used for validation, then removed during cleanup. This transfer commit contains the 1300-pixel screenshot exports only.

## Matrix

Each device has:

- `light/`: all eight tutorial steps and the recap
- `skip/`: four states from the skip-step flow
- `dark/`: tutorial steps 1 and 4 in dark appearance
- `ax-xxxl/`: all eight tutorial steps and the recap with Accessibility XXXL text

Expected: tutorial captions stay above the fixed action bar, the accessibility macro spotlight advances through Protein, Carbs, and Fat individually, and the recap guidance remains visible above Done. Observed: all eight capture tests passed, and the exported images were reviewed for caption/action-bar overlap, macro targeting, dark appearance, and recap clipping.

## Capture command

The capture-only UI test was temporary and intentionally not committed. To reproduce the matrix, restore a local test helper that drives the first-run tutorial and attaches screenshots, then run each test serially on both listed simulators. For example:

```sh
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
  -resultBundlePath build/evidence/tutorial-light.xcresult \
  test
```

The temporary tests used these selectors: `testCaptureTutorial`, `testCaptureTutorialSkip`, `testCaptureTutorialDark`, and `testCaptureTutorialAX`. Change appearance to dark for the dark run and enable Accessibility XXXL for the AX run. Export attachments with `xcrun xcresulttool export attachments`.

No capture cases were blocked. The unit suite excluded StoreKit tests because simulator StoreKit has no account.
