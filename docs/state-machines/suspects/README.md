# State-machine suspect investigation results

Live investigation of the 11 follow-ups in [FINDINGS.md](../FINDINGS.md), repeated on 2026-11-03. **No app fixes, deployments, or subagents.** This replaces the earlier blanket tooling-blocked assessment.

Main app baseline: `origin/main` at `da00befaae3d9954c7046f80570bda4936f918d7`. This research branch started at `f7bc3f750272188430652942dbb50ed89e4d584f`; its app sources matched that main revision before instrumentation and match it again after restoring every hook. Widget analysis is separately pinned to `50fa3b90e95d3f5341f4aba7d47fe74e14c855d6`.

## Results

| # | Suspect | Verdict | Severity / one-line evidence |
|---|---|---|---|
| 01 | [Repair stale writeback](01-repair-stale-writeback/REPRO.md) | CONFIRMED, timing hook | Medium. Real quantity edit to 1.25 survived; repair stored 3.1 g fiber instead of 3.875 g. |
| 02 | [Backup/Health reconciliation](02-backup-health-reconciliation/REPRO.md) | CONFIRMED behavior; policy-dependent defect | Medium if ongoing reconciliation is intended. Actual replacement removed the imported Health row; retained anchor and observer restart did not re-import history. |
| 03 | [Health authorization completion](03-health-authorization-completion/REPRO.md) | CONFIRMED transient restart | Low. Completion ran with Pro false and restarted observation for about 41 ms; no sample imported in that interval. |
| 04 | [Backup decode overlap](04-backup-decode-overlap/REPRO.md) | CONFIRMED, actual picker + timing hook | Medium. A's older 11-entry summary replaced B's newer 22-entry selection. |
| 05 | [Two invite creators](05-two-invite-creators/REPRO.md) | CONFIRMED, real dev backend | Medium. Displayed cached invite matched caller 1, rejected by server; caller 2's link was accepted. |
| 06 | [Scope response vs subscription echo](06-scope-subscription-echo/REPRO.md) | CONFIRMED, real dev backend | Medium. Older completion selected Macros + Foods after an `off` echo; fresh authoritative query remained `off`. |
| 07 | [Root deferred deep link](07-root-deferred-deep-link/REPRO.md) | CONFIRMED with widened deferred window | Low. Two queued appends survived replacement; Back exposed obsolete C beneath D. Natural one-turn timing not reproduced. |
| 08 | [Onboarding permission cancellation](08-onboarding-permission-cancellation/REPRO.md) | NOT REPRODUCIBLE in attempted UI paths | Busy hides Back/disables controls; background attempt did not cancel the task; recreated view had fresh state. |
| 09 | [Camera busy cancellation](09-camera-busy-cancellation/REPRO.md) | NOT REPRODUCIBLE in attempted UI paths | Real photo processing was canceled while busy; Close/reopen produced a new scanning flow with usable controls. |
| 10 | [Persisted uploading](10-persisted-uploading/REPRO.md) | NOT REPRODUCIBLE as a user-visible hang | Internal uploading restored, but next upload completed in about 3.4 s; no view consumes that status. |
| 11 | [Widget exchange handle](11-widget-exchange-handle/REPRO.md) | BLOCKED-live; static-only by instruction | Older waiter can clear a newer handle/cache; generation checks prevent inferring a display leak. |

Seven behaviors reproduced, but **02 is a policy question**, **03 demonstrated only a short restart**, and **07 required a deliberately widened scheduling window**. These are not seven equally severe production incidents. NOT REPRODUCIBLE means the reported user-facing failure did not occur in the documented paths, not a universal proof of absence.

## Confirmed impacts and proposed minimal fixes

No fix below was implemented.

| # | User impact | Minimal proposed fix |
|---|---|---|
| 01 | Edited quantity can have stale secondary-nutrient totals marked current. | Compare captured entry revision/source/quantity at writeback; skip/retry changed rows or recompute current-quantity totals after validating source. |
| 02 | Previously imported Health history stays absent after backup replacement while reading remains enabled. | First decide replacement policy. If history should reconcile, reset/reconcile the anchor after commit and restart with Health-UUID deduplication. Otherwise document the reset boundary. |
| 03 | An old authorization completion briefly starts observation after Pro access is revoked. | Re-read effective entitlement and the current read setting after authorization, before restart. No unauthorized-read claim. |
| 04 | Summary can represent an older backup, risking wrong-dataset replacement if confirmed. | Gate import decoding or reject stale operation generations; serialize import/export presentation ownership. |
| 05 | A cached invitation offered to the user can already be revoked. | Share one service-wide in-flight create operation through remote commit/local save; prevent older publication and reconcile uncertain results. |
| 06 | Picker misstates actual sharing scope. The server remained more restrictive in this run. | Order write completion against authoritative server echoes, preferably with a revision; reconcile rather than overwrite a newer observed value. |
| 07 | Back navigation can reveal an obsolete invitation screen. | Check the captured request token inside the deferred append and invalidate it for superseding replacement routes. |

## Test environment and safety

- Worktree: `/Users/juan/.t3/worktrees/cal-macro-tracker/state-suspects`; no work in the main checkout or any `IGNOREDbuild/`.
- Preferred B (`F976E800-DA1F-4F20-B755-DFD964E33975`) was locked by another worker. The required 120-second wait/retry did not acquire it; it was not driven, booted, installed on, or erased in this retry.
- Owned fallback A: iPhone 17 `918D29B9-97D3-42C0-9C47-00605E01E8DB`, used for camera/deep links. Its existing data and identity were preserved.
- Owned iPad: `E91B597B-CE57-4C0B-A8A4-51CBDC3386AB`, iOS 27.0 test runner, iPhone compatibility mode. Used synthetic demo data, backup files, a Health weight, a label photo, and fresh dev-sharing fixtures.
- Both devices were protected by `mkdir /tmp/macros-sim-locks/<UDID>` ownership. No new simulator was created, the four-boot budget was respected, and reserved devices were not touched.
- The T3 Device panel supplied a working `agent-device` CLI. Windowed iPad AX coordinates required calibration and some native pickers needed screenshot-based taps. These were recoverable limitations, not a reason to mark all tests blocked.
- XcodeBuildMCP snapshot calls required session defaults despite explicit-device attempts. No session/default/profile configuration was used. UI testing continued through the working device driver.
- Backend mutations used only `https://energized-pigeon-822.convex.cloud`, authenticated through `https://macros-auth.jhonra121.workers.dev`, with two newly generated profiles. There was no deployment or production backend access.
- Real invite tokens, hashes, profile credentials, and JWTs stayed in private temporary files or app Keychain. Evidence contains only safe call ordinals/states. Route C/D inputs were dummy nonsecret strings.

## Repeating the investigation

The artifacts below are **archived investigation fixtures**, not app changes. Obtain device locks, use disposable data, calibrate UI geometry, and confirm the dev endpoint before repeating.

1. Build the unmodified Debug simulator app:

   ```sh
   cd /Users/juan/.t3/worktrees/cal-macro-tracker/state-suspects && xcodebuild -project cal-macro-tracker.xcodeproj -scheme cal-macro-tracker -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/state-suspects-build build
   ```

2. If the normal window is too short, apply [temporary-hooks.patch.txt](temporary-hooks.patch.txt) locally with `git apply`, build with a different derived-data directory, and install on the claimed device. The archived patch is never part of the shipped app.
3. [fixture-inspection.py.txt](fixture-inspection.py.txt) records delay arming, synthetic backup generation, read-only SwiftData inspection, safe preference inspection, and filtered trace collection. Copy to a scratch `.py` file and adjust the device if needed. It resolves the current app container after each installation.
4. [ui-driver.py.txt](ui-driver.py.txt) records the CLI/session wrapper and token-scrubbed UI capture. Driver paths/session IDs are session-specific. Its last iPad offset is `466`; earlier captures used `410` (twice the window's horizontal origin). Recalibrate rather than assuming either value is portable. `fill` types at the focused insertion point, it is not replacement.
5. The DEBUG helper reads `--suspect-<flag> <seconds>` or a numeric file at `<app-container>/tmp/suspect-<flag>`. Active delays were: repair 90 s, Health authorization 60 s, backup 45 s, invite caller 1 60 s, scope 45 s, root route 10 s, onboarding 30/15 s, and camera image work 45 s. Upload used 60 s before termination. Without a positive delay the timing hook does not pause.
6. For backup tests, export the app's synthetic demo backup, save it privately as `/tmp/suspects-demo-backup.json`, then use the fixture helper's `backup-files` action. Select the generated files through Files, not by directly invoking the importer.
7. For sharing, copy [backend-repro.ts.txt](backend-repro.ts.txt) into a temporary `convex-backend/scripts/stateSuspectsRepro.ts` so its existing relative API import resolves. Create the target app `Documents` directory first, then supply its absolute path via `SUSPECT_DOCS`:

   ```sh
   cd /Users/juan/.t3/worktrees/cal-macro-tracker/state-suspects && CONVEX_URL=https://energized-pigeon-822.convex.cloud SUSPECT_DOCS="<isolated-app-container>/Documents" bun convex-backend/scripts/stateSuspectsRepro.ts setup
   ```

   `setup` creates exactly two profiles and a reciprocal relationship. If setup fails after creating them, use `attach` with the existing private state; **do not run setup again**. `scope` performs the newer same-owner write; `check-scope` queries authoritative state; `check-invites` uses privately copied hashes. None prints credentials.
8. Execute each numbered REPRO's real UI event order. Collect only filtered nonsecret traces and synthetic screenshots. For suspect 08, the launch-argument onboarding override is not evidence of normal completion behavior; it was used only to reach the permission screen.
9. Run the backend helper's `cleanup` mode before deleting its private state. Clear the fixture-owned local invite token and metadata, remove the identity override, delay/hash/trace files and picker fixtures, restore app sources with an explicit file list, and reinstall the original app. Do not clear an unrelated device identity.
10. Restore services using `simslim on <owned-UDID> --profile tools/sim/macros-slim.json`, verify the same profile while booted, shut down only owned boots, close the Device panel entry, and release owned lock directories.

## Hooks and cleanup record

[The exact final DEBUG patch](temporary-hooks.patch.txt) documents the 13 modified app files. It contains delay/logging points, repair fixtures, the private identity-file loader, and a fixture-scoped local-token cleanup. The replacement-backup and onboarding-reset Developer buttons were added but not successfully used as evidence. No hook or fix remains in app source.

- [Backend cleanup](backend-cleanup.log): **2/2 fresh profiles deleted**, and both existing sessions rejected by the dashboard afterward.
- [Local fixture cleanup](local-fixture-cleanup.log): the fixture invite token was absent after scoped Keychain cleanup. Final preferences: Sharing `false`, upload status `idle`, Health weight reading `false`.
- Fresh credentials/private hashes, simulator identity override, all numeric delay files, probe traces, and Files-picker JSON copies were removed. The temporary backend `.ts` source was removed; only its documentation archive remains.
- The synthetic Health sample was deleted. After reinstalling the original app, the [native Health Apps access list](02-backup-health-reconciliation/health-permissions-after-reinstall.log) was empty; no MACROS grant was listed. Health/Photos first-run setup remains completed on the test runner. The synthetic photo was deleted from Photos, leaving its original six sample photos; normal Recently Deleted retention applies.
- Original uninstrumented apps were reinstalled on both devices. No existing A identity was deleted.
- iPad temporarily enabled the five-service `search` category for Files. Health/photos/store were already enabled by the committed profile and feature checks passed. The iPad's final `simslim on` restored those five overrides; both A and iPad then matched the committed profile.
- Owned A and iPad boots were shut down, Device entries closed, and both locks released. Other devices/locks were left alone.
- [Service restoration and cleanup checks](environment-cleanup.log).

## Validation and evidence boundaries

- Uninstrumented Debug build: passed. Temporary instrumented Debug builds: passed. These are builds, not XCTest runs.
- Live UI attempts: suspects 01–10. Widget 11: fetched branch/static analysis only, by instruction.
- Final app source comparison to the pinned `origin/main`: clean; no backend source change remains.
- Documentation/link/size validation and diff checks are recorded in [validation.log](validation.log).
- No unit tests, full XCTest suite, StoreKit expiry test, production incident reproduction, or physical-device run is claimed. No app fix was requested or implemented.
- Inherited `onboarding-state.png`, `openurl-attempt.png`, and `live-attempt.log` files are historical artifacts of the earlier blocked attempt. They are preserved for provenance, **not** evidence for the current verdicts. Each REPRO links its new evidence explicitly.
