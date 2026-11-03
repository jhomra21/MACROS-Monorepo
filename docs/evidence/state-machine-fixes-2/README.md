# State-machine fixes 01–04

Live RED/GREEN runs on 2026-11-03, using iPhone 17e B (`F976E800-DA1F-4F20-B755-DFD964E33975`, iOS 27.0). Baseline: `da00befaae3d9954c7046f80570bda4936f918d7`. Only synthetic app/Health data was used. No unit tests were added.

| Bug | Result and evidence |
|---|---|
| [01](01/README.md) | Quantity remains 1.25 servings; consumed fiber changes from stale 3.1 to correct 3.875 g. |
| [02](02/README.md) | Replacement replays Health history; repeated merges retain one Health weight. |
| [03](03/README.md) | Authorization completing after Pro revocation no longer restarts observation. |
| [04](04/README.md) | Decode now owns the existing busy gate, preventing another import/export until completion. |

## Repeating the runs

1. Claim a permitted simulator with `mkdir /tmp/macros-sim-locks/<UDID>`. Reuse existing devices, respect the four-boot limit, and use an isolated worktree.
2. The original reports, timing hooks, UI wrapper, and read-only store inspector are archived on `origin/docs/state-machine-suspects` under `docs/state-machines/suspects/`. The report directories are `01-repair-stale-writeback`, `02-backup-health-reconciliation`, `03-health-authorization-completion`, and `04-backup-decode-overlap`.
3. Extract `temporary-hooks.patch.txt`, `fixture-inspection.py.txt`, and `ui-driver.py.txt` from that branch to scratch files. Apply only the hooks named in each numbered README. Put the [helper used here](probe-helper.swift.txt) inside the existing DEBUG-only `DeveloperSettingsSection.swift`, not the unrelated sharing files. Do not apply any other archived suspect hooks.
4. Set the inspector's `U` to the owned device. Open it through the T3 Device panel and update the UI wrapper's `CLI` and `SESSION` to the returned device-bound command/session. These runs used iPhone coordinates (`PHONE = True`). Use fresh snapshots when native picker geometry changes.
5. Build/install with:

   ```sh
   cd /Users/juan/.t3/worktrees/cal-macro-tracker/state-fix-health && DEVELOPER_DIR=/Applications/Xcode-26.4.1.app/Contents/Developer xcodebuild -project cal-macro-tracker.xcodeproj -scheme cal-macro-tracker -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/state-fix-health-build build
   cd /Users/juan/.t3/worktrees/cal-macro-tracker/state-fix-health && xcrun simctl install F976E800-DA1F-4F20-B755-DFD964E33975 /tmp/state-fix-health-build/Build/Products/Debug-iphonesimulator/cal-macro-tracker.app
   ```

6. Arm a delay with the inspector's `arm <flag> <seconds>`. This writes `<app-data>/tmp/suspect-<flag>`. Launch and drive the real app through the device-bound CLI. Use `db`, `prefs healthWeightAnchor healthWeightReadEnabled`, and `save-trace <path> <filter>` to capture the same store/preference/trace artifacts.
7. For RED, use the baseline without that bug's fix. For GREEN, repeat the same action order after applying the fix, keeping the timing hook. For 04, the second selection is intentionally blocked by serialization; select B after the first operation finishes.
8. Remove every hook before committing, rebuild/reinstall the uninstrumented app, remove scratch picker/delay files and synthetic Health samples, restore services with the unedited `tools/sim/macros-slim.json`, verify, shut down owned boots, and release locks.

## Evidence interpretation

The resumed worker preserved 01/03 artifacts and commits from the cancelled worker, inspected its transcript and actual diffs, and read the screenshots/store/trace artifacts. Later runs completed 02/04. Traces are cumulative snapshots, so GREEN files include earlier RED events; each numbered README identifies the decisive timestamps.

Some native picker taps initially used stale accessibility bounds, and two delayed summaries were assigned in the trace without appearing onscreen. Those attempts were retried after stabilization and are not claimed as successful imports. The successful replacement is demonstrated by its stop/restart/replay trace and stored/UI weight; 04's gate is demonstrated by the disabled-action screenshot and unchanged second-tap result.

Validation: [validation.txt](validation.txt), [primary XCTest summary](ipad-test-summary.json), [test output](ipad-tests.log). Both full serial iPad runs passed 228 tests; the second run used the final observer-restart hunk. StoreKit tests were excluded, not counted as executed or runner-skipped. Builds are not test evidence.

Final source review found no duplicate abstraction or unused state: 01 reuses the existing food-data value snapshot, 02 reuses Health query lifecycle cancellation and UUID dedupe, 03 adds one post-await guard, and 04 reuses the existing busy flag.

Widget comparison against `origin/main...origin/feat/shared-person-widget`: no app source file in this change overlaps. Only the required short `changes-log.md` entry overlaps.
