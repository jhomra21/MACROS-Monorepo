# F2 review: real SwiftData migration E2E

Run on 2026-11-03, simulator B only:
`F976E800-DA1F-4F20-B755-DFD964E33975`, iPhone 17e, iOS 27.0.
Main baseline: `d53a31380a93d6ad84565bddb92a4cbdc26e3fe6`.
Green production code: `f2d5bd4` (migration commit `487361a`).
No mocks, preview stores, new isolated tests, or production services.

## Results

| Run | Total entries | Today | Sample | Legacy base/WAL |
| --- | ---: | --- | --- | --- |
| Main Debug, Settings > Developer > Load Demo Data | 432 | 4 items, 1,310 kcal | Protein bar, 210 kcal | Fixture source |
| Main, legacy base + WAL, **no SHM**, destination absent | 432 | 4 items, 1,310 kcal | Protein bar, 210 kcal | Unchanged |
| Main, interrupted destination: base exists, WAL removed | **0** | **0 items, 0 kcal** | Missing | Unchanged |
| Branch, legacy base + WAL, **no SHM**, destination absent | **432** | **4 items, 1,310 kcal** | **Protein bar, 210 kcal** | **Unchanged** |

The first main run honestly passes: its old copier works with all committed
sidecar data available. The second main run reproduces skip-if-base-exists:
copy base and WAL to the destination, remove only the destination WAL before
launch, retain the complete legacy fixture. Main skips migration and opens
the empty checkpointed base. This is a simulated interrupted publication, not
an actual process kill mid-copy. The branch's green starts with destination
absent, the supported recovery condition. Neither branch attempts to repair
an already-published ambiguous destination, which could contain newer writes.

`run.log`, `*-result.json`, and `*-legacy-before.json` retain actual counts,
sample values, metadata presence, and SHA-256 comparisons. SQLite verification
opens the destination read-only; the legacy files are hashed, not opened.
The fixture includes `Z_METADATA`, `Z_PRIMARYKEY`, and history tables from the
real app-created SwiftData store. Its base is 114,688 bytes and WAL 2,884,032
bytes. The app was terminated before copying; SHM was deliberately omitted.
SQLite on the iOS simulator recovered the missing-SHM legacy WAL.

`baseline-*`, `red-full-*`, `red-base-only-dashboard.*`, and `green-*` contain
screenshots and accessibility trees. Green history shows all four foods,
including Oatmeal with banana, 350 kcal. Total 432 is a database count, not a
claim that all 432 rows appear simultaneously on screen.

## Exact preparation and commands

All commands run from the named worktree, never the primary checkout.
`store-e2e.py` is the retained executable for exact copy/remove/hash/query
operations; it only targets simulator B's resolved containers and the ignored
fixture directory. It intentionally deletes disposable B store files.

Build the exact main revision, then branch Debug:

```sh
cd /Users/juan/.t3/worktrees/cal-macro-tracker/state-fix-f2f3 && mkdir -p build/review-fixes/main-source && git archive d53a31380a93d6ad84565bddb92a4cbdc26e3fe6 | tar -x -C build/review-fixes/main-source
cd /Users/juan/.t3/worktrees/cal-macro-tracker/state-fix-f2f3 && DEVELOPER_DIR=/Applications/Xcode-26.4.1.app/Contents/Developer xcodebuild -project build/review-fixes/main-source/cal-macro-tracker.xcodeproj -scheme cal-macro-tracker -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath build/review-fixes/MainDerivedData build > build/review-fixes/main-build.log 2>&1
cd /Users/juan/.t3/worktrees/cal-macro-tracker/state-fix-f2f3 && DEVELOPER_DIR=/Applications/Xcode-26.4.1.app/Contents/Developer xcodebuild -project cal-macro-tracker.xcodeproj -scheme cal-macro-tracker -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath build/review-fixes/GreenDerivedData build > build/review-fixes/green-build.log 2>&1
cd /Users/juan/.t3/worktrees/cal-macro-tracker/state-fix-f2f3 && mkdir -p /tmp/macros-sim-locks && while ! mkdir /tmp/macros-sim-locks/F976E800-DA1F-4F20-B755-DFD964E33975; do sleep 120; done
cd /Users/juan/.t3/worktrees/cal-macro-tracker/state-fix-f2f3 && xcrun simctl get_app_container F976E800-DA1F-4F20-B755-DFD964E33975 juan-test.cal-macro-tracker data
cd /Users/juan/.t3/worktrees/cal-macro-tracker/state-fix-f2f3 && xcrun simctl get_app_container F976E800-DA1F-4F20-B755-DFD964E33975 juan-test.cal-macro-tracker groups
cd /Users/juan/.t3/worktrees/cal-macro-tracker/state-fix-f2f3 && xcrun simctl install F976E800-DA1F-4F20-B755-DFD964E33975 build/review-fixes/MainDerivedData/Build/Products/Debug-iphonesimulator/cal-macro-tracker.app
```

`legacyConfiguration` uses `.none`; `sharedWritableConfiguration` uses
`.identifier("group.juan-test.cal-macro-tracker")`, both unnamed on-disk
`ModelConfiguration`s. Their files are respectively:

- `<data container>/Library/Application Support/default.store`
- `<group container>/Library/Application Support/default.store`

The helper resolves both with the exact `get_app_container` commands above.
For UI, open B with T3 `device_open` and use its returned pinned command.
This run's command is shown below; it is session-specific, so a future run
must obtain a fresh path if it no longer exists.

The following shell setup defines shorthand only; keep it in the same shell
as the commands using it (or repeat the assignments).

```sh
cd /Users/juan/.t3/worktrees/cal-macro-tracker/state-fix-f2f3 && D=/Users/juan/.t3/userdata/device/targets/t3-8a8cdf115bdf66db4b1fd459/agent-device && E=/Users/juan/.t3/worktrees/cal-macro-tracker/state-fix-f2f3/docs/evidence/state-machine-fixes/f2-e2e && "$D" open juan-test.cal-macro-tracker
```

Seed through the actual UI: Open settings, scroll to Developer > Load Demo
Data, confirm Replace Data, Back. The observed refs were `@e7`, `@e27`, and
`@e35`; refs vary, so use fresh snapshots or exact text selectors.

```sh
cd /Users/juan/.t3/worktrees/cal-macro-tracker/state-fix-f2f3 && "$D" press 'text="Open settings"' --settle && "$D" scroll down --until 'text="Load Demo Data"' --max-passes 8 --settle && "$D" press 'text="Load Demo Data"' --settle && "$D" press 'text="Replace Data"' --settle && "$D" press 'text="Back"' --settle
cd /Users/juan/.t3/worktrees/cal-macro-tracker/state-fix-f2f3 && "$D" snapshot -i > "$E/baseline-dashboard.txt" && "$D" screenshot "$E/baseline-dashboard.png" && "$D" press 'text="Open history"' --settle && "$D" screenshot "$E/baseline-history.png" && "$D" snapshot -i > "$E/baseline-history.txt" && "$D" close juan-test.cal-macro-tracker
cd /Users/juan/.t3/worktrees/cal-macro-tracker/state-fix-f2f3 && python3 docs/evidence/state-machine-fixes/f2-e2e/store-e2e.py save-fixture > docs/evidence/state-machine-fixes/f2-e2e/run.log
```

Run main with the crash-left legacy files, no SHM:

```sh
cd /Users/juan/.t3/worktrees/cal-macro-tracker/state-fix-f2f3 && python3 docs/evidence/state-machine-fixes/f2-e2e/store-e2e.py prepare red-full >> "$E/run.log" && "$D" open juan-test.cal-macro-tracker && "$D" snapshot -i > "$E/red-full-dashboard.txt" && "$D" screenshot "$E/red-full-dashboard.png" && python3 docs/evidence/state-machine-fixes/f2-e2e/store-e2e.py verify red-full >> "$E/run.log"
cd /Users/juan/.t3/worktrees/cal-macro-tracker/state-fix-f2f3 && "$D" press 'text="Open history"' --settle && "$D" screenshot "$E/red-full-history.png" && "$D" snapshot -i > "$E/red-full-history.txt" && "$D" close juan-test.cal-macro-tracker
```

Run the interrupted-publication RED variant, then install and run green.
The launch arguments only skip completed onboarding/tutorial UI; they neither
seed nor change database rows.

```sh
cd /Users/juan/.t3/worktrees/cal-macro-tracker/state-fix-f2f3 && xcrun simctl install F976E800-DA1F-4F20-B755-DFD964E33975 build/review-fixes/MainDerivedData/Build/Products/Debug-iphonesimulator/cal-macro-tracker.app && python3 docs/evidence/state-machine-fixes/f2-e2e/store-e2e.py prepare red-base-only >> "$E/run.log" && "$D" open juan-test.cal-macro-tracker --launch-args=-hasCompletedGoalSetup --launch-args=YES --launch-args=-hasCompletedDashboardTutorial --launch-args=YES && "$D" snapshot -i > "$E/red-base-only-dashboard.txt" && "$D" screenshot "$E/red-base-only-dashboard.png" && python3 docs/evidence/state-machine-fixes/f2-e2e/store-e2e.py verify red-base-only >> "$E/run.log" && "$D" close juan-test.cal-macro-tracker
cd /Users/juan/.t3/worktrees/cal-macro-tracker/state-fix-f2f3 && python3 docs/evidence/state-machine-fixes/f2-e2e/store-e2e.py prepare green >> "$E/run.log" && xcrun simctl install F976E800-DA1F-4F20-B755-DFD964E33975 build/review-fixes/GreenDerivedData/Build/Products/Debug-iphonesimulator/cal-macro-tracker.app && "$D" open juan-test.cal-macro-tracker --launch-args=-hasCompletedGoalSetup --launch-args=YES --launch-args=-hasCompletedDashboardTutorial --launch-args=YES && "$D" snapshot -i > "$E/green-dashboard.txt" && "$D" screenshot "$E/green-dashboard.png" && python3 docs/evidence/state-machine-fixes/f2-e2e/store-e2e.py verify green >> "$E/run.log"
cd /Users/juan/.t3/worktrees/cal-macro-tracker/state-fix-f2f3 && "$D" press 'text="Open history"' --settle && "$D" screenshot "$E/green-history.png" && "$D" snapshot -i > "$E/green-history.txt" && "$D" close juan-test.cal-macro-tracker && rmdir /tmp/macros-sim-locks/F976E800-DA1F-4F20-B755-DFD964E33975
```

### Coordination and retries

B and the iPad were already booted at start, so this run booted/shut down no
simulators. The first B lock acquisition slept twice for 120 seconds.
Between red-full and red-base-only, another worker acquired B's UI session
while this run's mkdir lock was held, later released/reacquired the directory
lock, and reset the app's preferences. This run never closed that worker's
session or removed its reacquired lock. It coordinated by thread message,
slept, then reacquired the lock with `mkdir` after release. The incomplete
base-only preparation and subsequent retries remain honestly in `run.log`.
Final red-base-only and green were re-prepared from the saved original
fixture under the reacquired lock, with their exact main/branch binaries
reinstalled. Initial retry screenshots hit onboarding; the retained final
screenshots were recaptured with onboarding-only launch defaults above.
Green history was captured on the first successful green after this reset;
the final green retry confirms identical count/sample/hashes and dashboard.
The final branch app remains installed, terminated, with demo data.

## Validation and review decisions

```sh
cd /Users/juan/.t3/worktrees/cal-macro-tracker/state-fix-f2f3 && make quality-format-check
cd /Users/juan/.t3/worktrees/cal-macro-tracker/state-fix-f2f3 && DEVELOPER_DIR=/Applications/Xcode-26.4.1.app/Contents/Developer make quality-build
cd /Users/juan/.t3/worktrees/cal-macro-tracker/state-fix-f2f3 && mkdir -p /tmp/macros-sim-locks && while ! mkdir /tmp/macros-sim-locks/E91B597B-CE57-4C0B-A8A4-51CBDC3386AB; do sleep 120; done && DEVELOPER_DIR=/Applications/Xcode-26.4.1.app/Contents/Developer xcodebuild -project cal-macro-tracker.xcodeproj -scheme cal-macro-tracker -derivedDataPath build/review-fixes/SuiteDerivedData -resultBundlePath build/review-fixes/full-suite.xcresult -destination 'platform=iOS Simulator,id=E91B597B-CE57-4C0B-A8A4-51CBDC3386AB' -parallel-testing-enabled NO -test-timeouts-enabled YES -default-test-execution-time-allowance 30 -maximum-test-execution-time-allowance 45 -skip-testing:cal-macro-trackerTests/PurchaseStoreStoreKitTests test > build/review-fixes/full-suite.log 2>&1; result=$?; rmdir /tmp/macros-sim-locks/E91B597B-CE57-4C0B-A8A4-51CBDC3386AB; exit "$result"
```

All pass: **234 tests, 0 failures**, including the **five** retained migration
tests. `validation.txt` retains actual suite lines; full log/xcresult stay in
ignored `build/review-fixes/`. Existing unrelated compiler warnings are noted
there. Corrected the existing destination assertion before production edits:
insert a post-migration row, migrate again, require the row to survive.
Deleted `testInterruptedArtifactCopyNeverPublishesBaseWithoutCommittedWALRows`
and `InterruptedStoreCopy`, because the backup no longer calls `copyItem`.
No new isolated test cases were added. This E2E covers the real SwiftData and
crash-left-sidecar gaps instead.

Checked Apple's primary documentation before changing durability:

- [fsync(2)](https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man2/fsync.2.html):
  fsync transfers host buffers, but drive cache can survive unflushed;
  databases requiring ordered durability should use `F_FULLFSYNC`.
- [fcntl(2)](https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man2/fcntl.2.html):
  `F_FULLFSYNC` performs fsync then asks the drive to flush buffered data.

The staging file full-sync is required before rename; the parent directory
full-sync after rename is best effort. The simulator E2E cannot prove
physical power-loss durability. Launch errors already surface via
`AppLaunchState.failed` / `AppLaunchErrorView`; the existing AppLaunch logger
now records only NSError domain/code (including raw migration SQLite code),
never descriptions, paths, or database values.
S1/N5/N6 changes were source-reviewed and included in the full suite/build;
no new remote-sharing E2E was run for those small review changes.
Final self-review found no unused helpers, duplicated validation, or broader
abstraction needed. N3/N4/N7 remain the documented, accepted no-change items.
