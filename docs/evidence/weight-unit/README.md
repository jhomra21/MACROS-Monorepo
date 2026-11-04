# Weight unit verification

## Failure modes (written before implementation)

1. No profile + US or UK region: Log Weight must default to lb, not kg.
2. No profile + metric region: Log Weight must default to kg.
3. Existing imperial profile: migrate to lb without changing stored weights.
4. Existing metric profile: migrate to kg regardless of region.
5. Switching units mid-entry: preserve the same physical weight, including repeated switches.
6. Entering 180 lb: save 81.6466266 kg (81.65 kg rounded), not 180 kg.
7. Old backup without the setting: restore successfully and derive the unit from its profile, otherwise region.
8. New backup: restore the chosen unit independently of height.
9. Goal calculator: ft/in height and kg weight must coexist; weekly pace uses the weight unit.
10. HealthKit-imported entries: display in the chosen unit without modifying canonical kg.
11. AX5 sheet: field, unit control, date, Cancel and Save remain readable and reachable.

## Evidence and results

All captures use simulator/demo data on iPhone 17e B, `F976E800-DA1F-4F20-B755-DFD964E33975`. Baseline is unmodified main `7585a8c`; GREEN is this branch. Evidence is under 1 MB.

| Failure mode | Check and evidence | Result |
| --- | --- | --- |
| No profile + US/UK | RED: `red-us-no-unit-control.png` and `.txt`, `red-clean-store.txt` (0 profiles, 0 weights, en_US). GREEN: `green-us-region.*`, `green-gb-region.*`; lb selected. Also `WeightUnitTests.testRegionDefaultsAndLegacyProfilePrecedence`. | Passed |
| No profile + metric region | Changed AppleLocale to de_DE, removed the preference, relaunched with 0 profiles: `green-de-region.*`, `green-de-no-profile.txt`; kg selected. | Passed |
| Existing imperial profile | Removed only the preference with the demo imperial profile intact, then relaunched: `green-health-lb.*`, `green-imperial-migration.txt`. The prewritten region/profile test also checks imperial beats de_DE. | Passed |
| Existing metric profile | Changed only the synthetic profile to metric, removed the preference and relaunched in en_US: `green-metric-profile-us.txt`; kg selected. Restored the demo profile afterward. | Passed |
| Switch mid-entry | Typed 180 lb, switched to kg: 81.6466266; switched back: 180. `green-mid-entry-kg.*`, `green-mid-entry-lb.txt`. Final-binary replay: `replay-converted.*`, `replay-round-trip.txt`. Prewritten conversion test repeats 100 round trips. | Passed |
| Enter lb, store kg | Saved 180 lb through the UI; read canonical SwiftData value with SQLite: `green-stored-kg.txt`, `replay-stored-kg.txt` = 81.6466266 kg. | Passed |
| Restore old backup | Prewritten `BackupRoundTripTests.testOldBackupWithoutWeightUnitRestoresLegacyImperialPreference` removes the JSON field, decodes and replaces a real in-memory SwiftData container and isolated defaults. DEBUG Load Demo Data also exercises the existing importer with a nil unit and imperial profile; see `green-insights-rate-lb.*`. | Passed |
| Restore new backup | Prewritten `BackupRoundTripTests.testNewBackupRestoresWeightUnitSeparatelyFromHeight` encodes/decodes/restores kg with imperial height into isolated SwiftData/defaults. The existing full backup round-trip test now includes the preference. Not separately driven through the Files picker. | Passed (integration) |
| Independent height/weight | `green-calculator-ft-kg.*`: height 5 ft 10 in and weight 81.9 kg; `green-calculator-rate-kg.*`: kg/week. `BodyProfileDraftTests.testWeightUnitIsIndependentOfHeightAndKeepsCanonicalWeight` checks canonical precision. | Passed |
| All weight displays/rates | `green-log-lb.*`, `green-log-kg.*`, `green-insights-lb.*`, `green-insights-kg.*`; demo trend rate -0.47 lb/week vs -0.21 kg/week in `green-insights-rate-{lb,kg}.*`. Searched all app/widget Swift kg/lb/pounds references; the widget has no body-weight display. Remaining GoalCalculator conversion API delegates to WeightUnit. | Passed |
| HealthKit-imported display | Set the latest synthetic demo row's source to healthKit while the app was closed. `green-health-source-store.txt` records its canonical kg; `green-health-lb.*` and `green-health-kg.*` show Apple Health with 180.6 lb / 81.9 kg. Restored synthetic sources afterward. This checks imported-row rendering, not authorization or live Health ingestion. | Passed (source fixture) |
| AX5 sheet | `green-ax5.*` and `green-ax5-filled.*`: unit control stacks below the field, Date wraps, Cancel/Save remain visible. Typed 180, converted, dismissed keyboard, saved successfully. | Passed |

### Baseline setup caveat

Manual onboarding on this main revision actually inserts an empty metric BodyProfile (`GoalSetupScreen.saveGoals`), even without calculator input. The first erased-simulator/manual-onboarding pass therefore also checked preservation of that existing metric record. To test the requested **true no-profile** case, the app was closed and only the synthetic empty profile row was deleted before recapturing RED and upgrading the same store to GREEN. `red-clean-store.txt` verifies the resulting empty profile/weight tables and US region. No owner data or other simulators were modified.

### Storage and review

The single persisted setting is standard UserDefaults `weightUnit`, observed through native `@AppStorage`. Launch initializes it once from the active legacy BodyProfile, otherwise `Locale.current.measurementSystem` (US/UK → lb). Later height/profile changes cannot overwrite it. Backups carry optional `settings.weightUnit`; absent fields decode normally and restore via the legacy profile/region rule. WeightEntry and BodyProfile measurements remain kg. No SwiftData schema or model-container structure changed, and baseline stores opened after upgrading.

Reviewed the complete production diff after validation: duplicate per-view symbols/conversions and unused profile queries are removed; the helper is shared with the widget target without depending on app-only types. No further simplification was needed.

### Validation

- Failure modes, six new pure/integration tests, and updates to existing affected tests were written **before production code**. No unit tests were added afterward.
- `make quality-format-check`: passed.
- `make quality-build`: passed (app + widget, not a test run).
- Full serial iPad suite with Xcode 26.4.1, specified 30/45-second allowances, and `PurchaseStoreStoreKitTests` excluded: **262 passed, 0 failed, 0 skipped**, six more than main's 256. The excluded class is not counted as skipped by xcresulttool. `xcresult-summary.json` is the final tool output; full bundle: `/tmp/macros-weight-unit.xcresult`.
- Initial compile caught an app-only AppStorageKeys reference from shared/widget code. Fixed by keeping the preference key and initialization on the shared WeightUnit; final build and full suite both rerun and passed.
- Final-binary `replay.sh`: passed. `sh -n` and `git diff --check`: passed.
- Build/test logs: `/tmp/macros-weight-build.log`, `/tmp/macros-weight-format-check.log`, `/tmp/macros-weight-tests.log`; replay log: `/tmp/macros-weight-e2e-replay.log`.
- Restored AppleLocale en_US and text size large. Released both simulator locks. The iPhone remains usable with demo data and the final binary. No macOS build or real-device Health import is claimed.

### Repeat the focused E2E check

1. Open B with T3 `device_open({deviceId:"F976E800-DA1F-4F20-B755-DFD964E33975",hostId:"local"})`.
2. Install this branch's Debug app. Keep at least one demo weight entry so Insights offers “View weight log”. Use DEBUG Settings → Developer → Load Demo Data if needed.
3. Set `AGENT_DEVICE` to the exact pinned command returned by device_open and run:

```sh
cd /Users/juan/.t3/worktrees/cal-macro-tracker/weight-unit && AGENT_DEVICE="<pinned-command>" sh docs/evidence/weight-unit/replay.sh
```

The script acquires B's lock without taking an existing lock (120-second retries, two-hour limit), enters 180 lb, asserts kg conversion and round-trip text, saves, asserts the log value and canonical SQLite kg, writes `replay-*` artifacts here, and releases its lock. It changes today's synthetic weight and the chosen unit.

The required full regression command was:

```sh
cd /Users/juan/.t3/worktrees/cal-macro-tracker/weight-unit && DEVELOPER_DIR=/Applications/Xcode-26.4.1.app/Contents/Developer xcodebuild \
  -project cal-macro-tracker.xcodeproj -scheme cal-macro-tracker \
  -destination 'platform=iOS Simulator,id=E91B597B-CE57-4C0B-A8A4-51CBDC3386AB' \
  -parallel-testing-enabled NO -test-timeouts-enabled YES \
  -default-test-execution-time-allowance 30 -maximum-test-execution-time-allowance 45 \
  -skip-testing:cal-macro-trackerTests/PurchaseStoreStoreKitTests \
  -resultBundlePath /tmp/macros-weight-unit.xcresult test
```

Acquire the iPad lock first with the same protocol; delete an existing generated result bundle before rerunning and release the lock afterward.
