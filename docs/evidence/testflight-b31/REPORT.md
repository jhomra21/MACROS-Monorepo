# TestFlight 1.0 (31), 2026-11-03

- Baseline: isolated worktree `release-b31`, branch `release/build-31`. Merge `f76a5d8f08feca6a3b832ca2ffd0514d0f0b9a47` has first parent `21921b12cc9d9a2267fbf73c03121f797f32ec04`, the build 30 main baseline.
- Merge validation and push: the original release worker (PID 8283) validated the merge, fast-forwarded main from `21921b1` to `f76a5d8f08feca6a3b832ca2ffd0514d0f0b9a47`, then deleted remote `merge/shared-person-widget`. Remote main reflog records the merge push at 20:35:28 and the bump push at 20:35:57.
- Build bump commit: `d931e5e27e7fd1b0a5754104bf94ca3adaef8fcf` (`chore: bump build 31`), equal to pushed main. The commit changes only all six `CURRENT_PROJECT_VERSION` values from 30 to 31 and includes the requested co-author trailer. Marketing version remains 1.0. Bump diff: 1 file changed, 6 insertions(+), 6 deletions(-). Full `21921b1..d931e5e` diff: 132 files changed, 3557 insertions(+), 195 deletions(-), including existing feature evidence.
- Validation: original worker's format, quality-build, and lint-js checks passed on the merge; Convex integration checks passed 20/20 and the dev deployment already accepted optional `includeFoods`, so no deployment was needed. Full serial iPad suite on `E91B597B-CE57-4C0B-A8A4-51CBDC3386AB` passed with parallel testing disabled, timeouts enabled, and 30/45-second allowances. Independently read `/tmp/macros-b31-merge.xcresult` with `xcresulttool get test-results summary --compact`: total 251, passed 251, failed 0, skipped 0, expected failures 0, no runtime warnings or test failures. Log ends with `** TEST SUCCEEDED **`. As in build 30, `PurchaseStoreStoreKitTests` was explicitly excluded; it is not included in the 251 count. Original worker rebuilt successfully after the build-number-only bump.
- Archive and export: original worker produced `MACROS-1.0-31.xcarchive` and the local App Store export with `/Applications/Xcode-26.4.1.app/Contents/Developer`, using build 30's commands and unchanged export options. App and widget are both 1.0 (31), with valid strict signatures and team `NK3K87K955`. Both have `get-task-allow=false` and App Group `group.juan-test.cal-macro-tracker`; the app also has HealthKit. Both distribution profiles have no provisioned-device list. No `.storekit` or `.xctest` payloads were reported by preflight.
- Shared credentials: source `Shared/SharingWidgetCredentials.swift` uses `group.juan-test.cal-macro-tracker` as `kSecAttrAccessGroup`. This same App Group is signed into both app and widget under `com.apple.security.application-groups`, providing the shared Keychain access mechanism. Neither exported bundle has a separate `keychain-access-groups` entitlement; the required shared group is the App Group, not a team-prefixed group. Independently inspected both exported signatures and the credential source, matching `preflight.json`.
- Export options: automatic signing, team `NK3K87K955`, method `app-store-connect`, `manageAppVersionAndBuildNumber=false`, symbol stripping/upload enabled, not internal-only. Local preflight uses `destination=export`; original upload used `destination=upload`.
- Upload: original worker invoked upload once. Xcode logged `Upload succeeded` and `Uploaded package is processing`; ContentDelivery logged `UPLOAD SUCCEEDED with no errors`, state `PROCESSING`, delivery UUID `30e60d8e-cda0-403b-9554-366036e50aea`. The continuation worker did not archive, export, upload, or retry. Status describes upload completion, not a later App Store Connect processing check.
- IPA SHA-256: independently verified `0b30f48fc3b7a8489bdb8c0cce9212f46988c52cce690cc5a4b67a6cd1a069e8` for `build/testflight-b31/export-local/MACROS.ipa`, matching preflight.
- Owner iPhone Air `844B72D7-D128-4607-AB2E-6C14B024618F`: original worker built Debug successfully from pushed main into isolated `owner-sim-dd`. After the original process exited, the continuation worker acquired the Air lock, uninstalled/reinstalled that Debug app without erasing, opened Simulator and launched it. Recaptured the fully rendered Dashboard as `dashboard.png` and visually checked Today, macro rings, empty food state, Camera, and Add Food. This is simulator evidence, not a physical-device or widget privacy check.
- Ownership and safety: continuation worker waited in the foreground until PID 8283 exited, independently verified its upload, IPA, signatures, commit diff, and live remote SHAs, then completed missing Air capture, this report, and evidence publication. The iPad lock was already released; Air locks were acquired and released around each operation. No prohibited simulator, owner checkout, or `IGNOREDbuild/` was used. No deployment, submission, or review-state action was performed by the continuation worker; build 23's Waiting for Review submission was left alone.

## Contents

Build 31 includes `21921b1..d931e5e27e7fd1b0a5754104bf94ca3adaef8fcf` over build 30:

- Shared-person macro widgets for Home Screen small and medium, plus Lock Screen inline, circular, and rectangular families.
- Person picker in Edit Widget, with shared-person navigation and refresh integration.
- Explicit offline, not-shared, and expired states; shared credential migration and extension access.
- Owner-approved personal widget background behavior.
- Build-number-only release bump to 31.

## Device checks for the owner

These remain owner checks on a physical device, not claims made by the simulator Dashboard capture:

- Locked-with-passcode privacy: verify sensitive widget content is appropriately hidden.
- After restart before first unlock: verify safe unavailable/private behavior.
- Airplane Mode: verify the Offline state.
- Midnight reset: verify the date and daily totals reset correctly.
- StandBy: verify widget appearance and privacy.
- Partner logs food: verify the shared widget updates.
- Partner stops sharing: verify the not-shared state.
- Upgrade from build 30: verify existing sharing is preserved.
