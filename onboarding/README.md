# Onboarding and Dashboard tutorial captures

Twenty numbered PNG screenshots cover the onboarding paths and Dashboard
tutorial, including a settled light-mode finish, a dark-mode finish, and the
known-targets route. They were captured on the iPhone 17 simulator
(iOS 27.0), using the in-memory UI fixture for tutorial screens. All images
were inspected; the checkmark is visible in both settled finish screenshots.

`17-tutorial-finish-recap.png` was captured shortly after the final tutorial
action, but the transition had settled by the time XCUITest produced its
screenshot. It is an additional recap view, not a mid-morph frame.

This is a screenshot transfer set, not an App Store listing set. The 20-image
count intentionally exceeds the usual evidence limit because every numbered
screen is part of the requested walkthrough. The complete set is 3.6 MB; each
image is reduced with `sips -Z 1300`.

## Capture provenance

- Integration source: `d9daf7a` (tutorial finish checkmark fix merged).
- Simulator: iPhone 17, `918D29B9-97D3-42C0-9C47-00605E01E8DB`, iOS 27.0.
- UI capture tests: `OnboardingPreviewCaptureTests`, 4 tests passed, 0 failures
  (3 light/onboarding, 1 dark finish).
- App build: `make quality-build` passed.
- Swift formatting: `make quality-format-check` passed.
- Light onboarding and tutorial: `/tmp/onboarding-preview-iphone17-light2.xcresult`.
- Dark finish: `/tmp/onboarding-preview-iphone17-dark.xcresult`.
- Detailed flow: [flow.md](flow.md).

The iOS notification authorization alert is not included. The captured
reminders screen is before Continue; the capture test avoids invoking a system
permission prompt. The light capture suite emitted an XCUITest invalid-frame
warning while editing the profile; all three tests passed.
