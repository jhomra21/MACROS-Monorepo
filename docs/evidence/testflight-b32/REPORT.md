# TestFlight 1.0 (32), 2026-11-03

- Baseline: isolated worktree `release-b32`, branch `release/build-32`. Merge `87c020100ec3a5edebb48e6b2f33cc1549edc07f` has first parent `48ebd2ae87d29127df415a05994875194f4ac6a9`, matching remote main immediately before the merge push. Fast-forwarded main to the merge, then deleted remote `merge/unified-food-search`.
- Build bump commit: `7585a8c655866d9739ca3e52e82582c5555ed9a0` (`chore: bump build 32`), equal to pushed main. Only all six `CURRENT_PROJECT_VERSION` values changed from 31 to 32, with the requested co-author trailer. Marketing version remains 1.0. Bump diff: 1 file changed, 6 insertions(+), 6 deletions(-). Full `d931e5e..7585a8c` diff over build 31: 99 files changed, 2908 insertions(+), 753 deletions(-), including feature evidence.
- Validation: prior merge worker passed format, quality-build, lint-js (0 warnings/errors, 106 files), USDA Worker tests (83/83, 278 expectations), and Worker check. Continuation independently read `/tmp/macros-b32-merge.xcresult`: 256 passed, 0 failed, 0 skipped, 0 expected failures, no runtime warnings. Serial iPad `E91B597B-CE57-4C0B-A8A4-51CBDC3386AB`, parallel testing disabled, timeouts enabled, 30/45-second allowances. `PurchaseStoreStoreKitTests` was explicitly excluded from that count. `make quality-build` passed again after the build-number-only bump.
- Smoke PASSED: installed the corrected Debug build on iPhone 17e `F976E800-DA1F-4F20-B755-DFD964E33975`, opened Add Food using T3 device tools, typed `greek yogurt`, and waited for remote Search Results. Scrolled to expose the rows above the keyboard; verified multiple nutrition rows without source names and captured `smoke-search.png` plus `smoke-search-ui.txt`. No search-submit tap was required.
- Smoke-run correction: the initial failure used the intentional Debug simulator local Wrangler URL `http://127.0.0.1:8787`, not a merge defect. Rebuilt using command-line `PACKAGED_FOOD_SEARCH_BASE_URL=https://cal-macro-tracker-usda-proxy.jhonra121.workers.dev`. Passing both plain and SDK-qualified CLI forms initially made Xcode misparse the conditional argument; discarded that install and rebuilt with only the plain override. `plutil` confirmed the final built Info.plist `USDA_PROXY_BASE_URL` exactly equals `https://cal-macro-tracker-usda-proxy.jhonra121.workers.dev`. No project configuration changed other than the six build-number values.
- Archive/export: Release archive `MACROS-1.0-32.xcarchive` and local App Store export succeeded with `/Applications/Xcode-26.4.1.app/Contents/Developer`, using build 31's commands and unchanged export options. Archive and exported app/widget are both 1.0 (32), with valid strict signatures and team `NK3K87K955`. The archive is development-signed (`get-task-allow=true`); the distribution export re-signs both bundles with `get-task-allow=false`. Both exported profiles have no provisioned-device list. No `.storekit` or `.xctest` payloads exist in either archive app or exported app.
- Entitlements/shared credentials: app has HealthKit; app and widget both have App Group `group.juan-test.cal-macro-tracker`. Source `Shared/SharingWidgetCredentials.swift` uses this App Group as the Keychain access group. Neither distribution bundle has a separate `keychain-access-groups` entitlement, matching build 31's shared Keychain mechanism. `preflight.json` records both archive and export entitlements.
- Compiler warnings: Release archive succeeded with concurrency warnings in `DashboardTutorialOverlay.swift` and `SharingRemoteClient.swift`; the prior test build also noted a concurrency warning in `SharingReliabilityTests.swift`. No source edits were made during this release continuation.
- Archived base URL: archived app Info.plist `USDA_PROXY_BASE_URL=https://cal-macro-tracker-usda-proxy.jhonra121.workers.dev`; also verified in the exported app.
- Export options: automatic signing, team `NK3K87K955`, method `app-store-connect`, `manageAppVersionAndBuildNumber=false`, symbol stripping/upload enabled, not internal-only. Local preflight uses `destination=export`; the single upload uses `destination=upload`.
- Upload: invoked exactly once, guarded by `upload-attempted`. Xcode exited 0 with `Upload succeeded` and `Uploaded package is processing`. ContentDelivery reports `UPLOAD SUCCEEDED with no errors`, delivery UUID `805b2a1d-2b6a-4c01-888f-32aa7a857597`, upload state `PROCESSING` at 21:36:48 local time. This is upload completion, not a later App Store Connect processing check. No retry or submission/review-state action occurred.
- IPA SHA-256: `b69c7273f4e7d84a536832d248c45e6b0ae0f2ee8b89243b8718b7f003596dcf`, independently checked for `build/testflight-b32/export-local/MACROS.ipa`.
- Owner iPhone Air `844B72D7-D128-4607-AB2E-6C14B024618F`: built Debug from pushed main into isolated `owner-sim-dd`, with the same command-line workers.dev override; confirmed the exact built plist value. Acquired the Air lock, uninstalled/reinstalled without erasing, closed a pre-existing T3 agent session, and opened the app in this thread's device session. Captured and visually checked fully rendered Dashboard (`dashboard.png`): Today, macro rings, empty food state, Camera, and Add Food. This is simulator evidence, not a physical-device or widget privacy check.
- Ownership/safety: did all continuation work directly, without subagents. All commands ran from named worktrees. Acquired simulator locks using atomic mkdir without taking existing locks; released both locks and closed both T3 device panels without shutdown. No prohibited simulator, owner checkout, `IGNOREDbuild/`, XcodeBuildMCP defaults/profile change, Worker deploy, Convex deploy, or App Store Connect submission/review-state change was used. All builds, archive, export and upload ran in the foreground and completed before handback.
- Evidence publication: pulled `dashboard-tutorial-evidence` with `git pull --ff-only` before copying this report and the smoke/Dashboard screenshots into `docs/evidence/testflight-b32/`. The evidence commit contains only that folder.

## Contents

Build 32 includes `d931e5e..7585a8c655866d9739ca3e52e82582c5555ed9a0` over build 31:

- Insights weight card aligned with the tiles.
- Unified food search: every source searched at once in one list, without source names.
- Results while typing after a 700 ms pause; Try again on errors.
- Camera Search button; meal picker uses the same search.
- Build-number-only release bump to 32.

## Device checks for the owner

These remain physical-device checks, not claims made by the simulator captures:

- Locked-with-passcode and after-restart-before-first-unlock widget privacy.
- Airplane Mode, midnight reset, and StandBy behavior.
- Shared widget updates when a partner logs food or stops sharing.
- Upgrade from build 31 preserves existing sharing and food data.
