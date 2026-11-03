# TestFlight 1.0 (29), 2026-11-03

- Baseline: fetched `origin/main` and confirmed `c74ae498bb50218d5501389b124f137349f19d22` (`Merge branch 'feat/camera-inline-details'`). Created isolated worktree `release-b29` on `release/build-29`.
- Build bump commit: `7034202b594ea43c819ec7c8b796e4b84213a201` (`chore: bump build 29`), pushed `main` SHA `7034202b594ea43c819ec7c8b796e4b84213a201`. `CURRENT_PROJECT_VERSION` is 29 in all six project configurations; marketing version remains 1.0. Diff against baseline: only `cal-macro-tracker.xcodeproj/project.pbxproj`, 1 file changed, 6 insertions(+), 6 deletions(-).
- Validation: `make quality-format-check` and `make quality-build` passed. The full serial iPad suite passed on `E91B597B-CE57-4C0B-A8A4-51CBDC3386AB` with the 30/45-second test allowances and parallel testing disabled. `xcresulttool get test-results summary --path /tmp/macros-b29.xcresult --format json` reports total 247, passed 247, failed 0, skipped 0, expected failures 0. `PurchaseStoreStoreKitTests` was excluded with `-skip-testing`; no failures or retries occurred. Summary saved as `test-summary.json`.
- Archive and export: `MACROS-1.0-29.xcarchive`; archive and local export succeeded using `/Applications/Xcode-26.4.1.app/Contents/Developer`, matching build 28. Both exported bundles are version 1.0 (29), Apple Distribution signed, and pass strict signature verification with `get-task-allow=false`. App Group `group.juan-test.cal-macro-tracker` is present on both; HealthKit is present on the app. No `.storekit` or `.xctest` payloads. Assertions and SHA are recorded in `preflight.json`.
- Export options are copied unchanged from build 28: automatic signing, team `NK3K87K955`, method `app-store-connect`, `manageAppVersionAndBuildNumber=false`, symbol stripping/upload enabled, and not internal-only. Preflight uses `destination=export`; upload uses `destination=upload`.
- Upload export was invoked exactly once and succeeded. Xcode reported “Upload succeeded” and “Uploaded package is processing.” ContentDelivery reports `UPLOAD SUCCEEDED with no errors`, state `PROCESSING`, and delivery UUID `75f8478a-ec09-47fd-a372-1aaee540c5dd`. Status is the upload completion status, not a later App Store Connect processing check.
- IPA SHA-256 (local App Store export): `b3a2936bb249c08b44eb330f5f3e2d6431a9d6aa2052626e4d1a3654cf522c40` (`build/testflight-b29/export-local/MACROS.ipa`).
- Owner iPhone Air `844B72D7-D128-4607-AB2E-6C14B024618F`: built Debug from the pushed SHA using build 28's command and isolated `owner-sim-dd`; uninstalled and reinstalled without erasing. Opened the Air in Simulator, launched the app, and captured `dashboard.png`. Visually verified the Dashboard, macro rings, empty food state, Camera, and Add Food. No desktop clicks were needed, and no other simulator window was clicked.
- Acquired and released the iPad and Air locks using `/tmp/macros-sim-locks/<UDID>`; neither lock was already held. No prohibited simulator, owner checkout, or `IGNOREDbuild/` was used. No Convex or website deployment occurred. No App Store Connect submission or review state was changed; the existing 1.0 build 23 submission was left alone.

## Contents

Build 29 includes main commits `8ebd989..c74ae49` over build 28:

- Camera result card layout fix across serving changes (`7e9e0ba`).
- State-machine suspects 01–04: recompute repaired nutrients from the current quantity (`b734d19`), recheck Health weight access after authorization (`345a6a6`), reimport Health weight history after backup replacement (`d8cb609`), and serialize backup decode with export preparation (`1366b5f`).
- F2 store migration: publish complete SQLite migrations atomically and preserve launch compatibility and durability (`f0caf52`, `487361a`); F3 removed-person handling: hide stale details immediately and bind actions to live availability (`142472e`, `f2d5bd4`).
- Review prompt timing: defer until Today is idle and dashboard sharing finishes; Settings rate link included in the merged changes (`bd947d7`, `53dc316`, merge `bba7a8b`).
- Inline camera Details with the shared food log editor and edit-session regression coverage (`afd259e`, `577405d`, `bd50b52`, merge `c74ae49`).
- Supporting tests and validation documentation, plus the website label-scan screenshot refresh (`da00bef`); website assets were not deployed by this release job.
