# Onboarding and Dashboard tutorial captures

Twenty numbered PNG screenshots cover the onboarding paths and Dashboard
tutorial, including a settled light-mode finish, a dark-mode finish, and the
known-targets route. They were captured on the disposable iPhone 17e simulator
(iOS 27.0) using the in-memory UI fixture where applicable. All images were
inspected; the checkmark is visible in both settled finish screenshots.

This is a screenshot transfer set, not an App Store listing set. The 20-image
count intentionally exceeds the usual evidence limit because every numbered
screen is part of the requested walkthrough. The complete set is 4.1 MB; each
image is reduced with `sips -Z 1300`.

## Capture provenance

- Integration source: `d9daf7a` (tutorial finish checkmark fix merged).
- Simulator: iPhone 17e, `F976E800-DA1F-4F20-B755-DFD964E33975`, iOS 27.0,
  slim profile verified.
- UI capture tests: `OnboardingPreviewCaptureTests`, 4 tests passed, 0 failures.
- App build: `make quality-build` passed.
- Swift formatting: `make quality-format-check` passed.
- Light onboarding and tutorial: `/tmp/onboarding-preview-onboarding.xcresult`
  and `/tmp/onboarding-preview-tutorial.xcresult`.
- Dark finish: `/tmp/onboarding-preview-dark.xcresult`.
- Detailed flow: [flow.md](flow.md).

The iOS notification authorization alert is not included. The captured
reminders screen is before Continue; the capture test disables the default
reminder to avoid invoking a system permission prompt.
