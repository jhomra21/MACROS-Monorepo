# F2 / F3 reproduction and evidence

Media removed in the repo cleanup; retrieve with `git show 074b10994f1b68d9d7a8d6c54ed7effb90d5f1f5:docs/evidence/state-machine-fixes/f2-e2e/baseline-dashboard.png`.

Review follow-up (2026-11-03): [real SwiftData RED/GREEN simulator E2E](f2-e2e/README.md)
supersedes the original F2 coverage limits below. There are now five migration
tests: the obsolete `InterruptedStoreCopy` test/helper was deleted, and the
destination-preservation assertion checks a post-migration write. The original
six-test red/green artifacts below remain historical evidence.

Worktree: `/Users/juan/.t3/worktrees/cal-macro-tracker/state-fix-f2f3`.
Base: `da00befaae3d9954c7046f80570bda4936f918d7`.
Only disposable dev identities and temporary SQLite fixtures are used.
Each retained artifact is below 5 MB. Raw build logs/results stay in ignored
`build/state-machine-fixes/`; the retained outputs contain the actual test results.

## Simulator ownership

Before booting, installing, testing, or driving a simulator:

```sh
cd /Users/juan/.t3/worktrees/cal-macro-tracker/state-fix-f2f3 && mkdir -p /tmp/macros-sim-locks && while ! mkdir /tmp/macros-sim-locks/E91B597B-CE57-4C0B-A8A4-51CBDC3386AB; do sleep 120; done
```

Use the analogous lock for iPhone B (`F976E800-DA1F-4F20-B755-DFD964E33975`).
Check the four-booted-device budget before booting. Never touch reserved devices
or another worker's lock. Shut down any simulator you booted, then release your
lock with `rmdir /tmp/macros-sim-locks/<UDID>` when done.
Phone B was erased for a fresh app identity (explicitly allowed), then
`simslim on` and `simslim verify` restored/verified the unchanged project profile.
The phone was shut down and its lock released after profile cleanup.

## F2

The test-first commit exposes the existing migration's source/destination URLs
and FileManager without changing its behavior. `InterruptedStoreCopy` copies the
base and throws, reproducing termination before WAL publication. A retry then
opens only the incomplete base. The legacy connection remains open with a
committed, uncheckpointed WAL row throughout the test.
Red commit: `23d259d`. Fix commit: `fde5310`. Red runs six tests with eight
failed assertions across five cases; green runs the same six with zero failures.

```sh
cd /Users/juan/.t3/worktrees/cal-macro-tracker/state-fix-f2f3 && xcodebuild -project cal-macro-tracker.xcodeproj -scheme cal-macro-tracker -derivedDataPath build/state-machine-fixes/DerivedData -destination 'platform=iOS Simulator,id=E91B597B-CE57-4C0B-A8A4-51CBDC3386AB' -parallel-testing-enabled NO -test-timeouts-enabled YES -default-test-execution-time-allowance 30 -maximum-test-execution-time-allowance 45 -only-testing:cal-macro-trackerTests/SharedStoreMigrationTests test
```

The same tests also check a self-contained published base, corrupt-source
rejection/retry, abandoned-staging cleanup, disk-full publication failure/retry,
already-published no-op, source-absent/same-path no-op, and byte-for-byte
preservation of the source base/WAL.
The regression's decisive red assertion is `["base"]` instead of
`["base", "committed WAL"]`. `f2-red.txt` and `f2-green.txt` retain actual
xcodebuild command/result output, not a reconstructed transcript.

Limits: an actual process kill at every machine instruction, physical disk
exhaustion during SQLite backup, and power loss are not simulated. A pre-existing
destination from the old copier cannot safely be distinguished from a legitimate
store with newer app data, so automatic replacement is deliberately excluded.

## F3

`f3-e2e.ts` uses the auth worker and public app APIs, fixed to dev
`energized-pigeon-822`. It creates no production data. It saves its temporary
credentials in ignored `build/state-machine-fixes/f3-private.json` with mode 0600;
never print or commit that file. It prints only nonsecret checkpoints.

```sh
cd /Users/juan/.t3/worktrees/cal-macro-tracker/state-fix-f2f3/convex-backend && bun install --frozen-lockfile
cd /Users/juan/.t3/worktrees/cal-macro-tracker/state-fix-f2f3 && bun docs/evidence/state-machine-fixes/f3-e2e.ts setup
```

Install a Debug app on claimed iPhone B. Complete onboarding if needed.
In Sharing settings, enable a fresh disposable profile, named `State Fix Viewer`.
Do not use an existing real profile. Then:

```sh
cd /Users/juan/.t3/worktrees/cal-macro-tracker/state-fix-f2f3 && bun docs/evidence/state-machine-fixes/f3-e2e.ts open-invite
```

Confirm **Start Sharing**. Do not capture a screenshot or UI tree containing the
invite token. Wait for the script's `check` to report one relationship before
navigating back. Do not use `--settle` or snapshots while leaving the invite
screen: navigation diffs can echo its input even after the dialog disappears.
Back to Today, swipe left on the rings, then open `State Fix Partner`. Confirm
**1,234 kcal, P 87 g, C 146 g, F 33 g** on detail. Leave it open:

```sh
cd /Users/juan/.t3/worktrees/cal-macro-tracker/state-fix-f2f3 && bun docs/evidence/state-machine-fixes/f3-e2e.ts remove
```

The script asserts zero relationships from the authoritative server dashboard.
Capture detail after delivery. On base, stale totals remain. On the fixed build,
they must disappear and a removed-person state must appear.

For green, reinstall the fixed app without uninstalling, reopen the same invite
to reconnect, reopen detail, and repeat `remove`.
The script setup took place before the implementation; red used the exact base
Debug binary. Green used the same viewer/partner, reconnected with the same link.
No mock, preview, seeded dashboard, or backend deployment was used.

Exact base preparation/build (run before claiming the phone):

```sh
cd /Users/juan/.t3/worktrees/cal-macro-tracker/state-fix-f2f3 && mkdir -p build/state-machine-fixes/base-source && git archive da00befaae3d9954c7046f80570bda4936f918d7 | tar -x -C build/state-machine-fixes/base-source
cd /Users/juan/.t3/worktrees/cal-macro-tracker/state-fix-f2f3/build/state-machine-fixes/base-source && xcodebuild -project cal-macro-tracker.xcodeproj -scheme cal-macro-tracker -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /Users/juan/.t3/worktrees/cal-macro-tracker/state-fix-f2f3/build/state-machine-fixes/BaseDerivedData build
cd /Users/juan/.t3/worktrees/cal-macro-tracker/state-fix-f2f3 && xcrun simctl install F976E800-DA1F-4F20-B755-DFD964E33975 build/state-machine-fixes/BaseDerivedData/Build/Products/Debug-iphonesimulator/cal-macro-tracker.app
```

Cleanup, including after a failed run:

```sh
cd /Users/juan/.t3/worktrees/cal-macro-tracker/state-fix-f2f3 && bun docs/evidence/state-machine-fixes/f3-e2e.ts cleanup
```

Also delete `State Fix Viewer` using the app's **Delete Sharing Profile** action.
The script and app both use `sharing.deleteMySharingProfile`.
Cleanup evidence confirms partner deletion, removal of the ignored private state,
and the viewer's Sharing toggle returning to off after successful deletion.
An automation navigation diff accidentally echoed the disposable invite during
green setup; that profile/link is now deleted. No retained artifact contains it,
and no JWT or profile secret was emitted. Avoid navigation diffs on token inputs.

## Evidence inventory

| File | Observation |
| --- | --- |
| `f2-red.txt` | Base-only retry opens with missing committed WAL row; other unsafe cases fail. |
| `f2-green.txt` | Same six migration tests pass, legacy bytes unchanged. |
| `f3-e2e.ts`, `f3-setup.txt` | Repeatable dev partner setup via public app APIs; no stored credentials. |
| `f3-red-before.png` | Base app displays expected partner totals before removal. |
| `f3-red-server.txt` | Server mutation/query confirms zero relationships. |
| `f3-red-after.png`, `.txt` | Person query rejects the removed relationship while stale totals remain. |
| `f3-red-stale.png`, `.txt` | Dismissed query error; stale 1234/P87/C146/F33 still visible. |
| `f3-red-roster.txt` | Same app's live roster is already empty, excluding a delivery-delay explanation. |
| `f3-green-before.png` | Fixed build displays identical totals after reconnect. |
| `f3-green-server.txt` | Same remote removal confirmed. |
| `f3-green-after.png`, `.txt` | “Person removed”; no calories, macros, foods, or editing controls. |
| `f3-partner-cleanup.txt`, `f3-viewer-cleanup.txt` | Both disposable identities deleted through app API. |
| `simulator-profile.txt` | Phone B profile restored/verified before shutdown. |
| `verify-evidence.py` | Repeatable secret-pattern, size, cleanup, and red/green transcript checks. |

```sh
cd /Users/juan/.t3/worktrees/cal-macro-tracker/state-fix-f2f3 && python3 docs/evidence/state-machine-fixes/verify-evidence.py
```

F3's existing paused/notShared guards remain in place. The new availability
boundary is optional roster membership, not a second state enum. The captured
person is used only for identity/name and initial scope selection, never data.
The task key includes roster membership, so removal cancels the person stream.
Dashboard loading and failure remain distinct from confirmed removal.
Pause/notShared variants were source-reviewed and covered by existing tests;
they were not separately exercised in this live two-person E2E.

## Full validation

```sh
cd /Users/juan/.t3/worktrees/cal-macro-tracker/state-fix-f2f3 && make quality-format-check
cd /Users/juan/.t3/worktrees/cal-macro-tracker/state-fix-f2f3 && make quality-build
cd /Users/juan/.t3/worktrees/cal-macro-tracker/state-fix-f2f3 && make lint-js
cd /Users/juan/.t3/worktrees/cal-macro-tracker/state-fix-f2f3 && xcodebuild -project cal-macro-tracker.xcodeproj -scheme cal-macro-tracker -derivedDataPath build/state-machine-fixes/DerivedData -destination 'platform=iOS Simulator,id=E91B597B-CE57-4C0B-A8A4-51CBDC3386AB' -parallel-testing-enabled NO -test-timeouts-enabled YES -default-test-execution-time-allowance 30 -maximum-test-execution-time-allowance 45 -skip-testing:cal-macro-trackerTests/PurchaseStoreStoreKitTests test
```

Format, app build, and JS lint passed. Full serial iPad suite passed: 234 tests,
0 failures; `PurchaseStoreStoreKitTests` was skipped as requested. The iPad
shut down and its lock was released after the run. Raw output:
`build/state-machine-fixes/full-suite.log`.

## Scope and remaining risks

- F1, F4, Q1 policy, and the 11 unconfirmed suspects are untouched.
- Both changed Swift files are outside the widget branch's changed-file list.
  Only the required short `changes-log.md` history entry overlaps.
- Existing ambiguous destinations from the old copier require deliberate
  recovery; blindly replacing them could destroy newer shared-store writes.
- Actual power loss, every crash boundary, and real disk exhaustion are not
  runtime-tested. Tests simulate copy interruption, corrupt staging/source, and
  disk-full publication failure. Widget staging exclusion follows its unchanged
  final-path-only open; no concurrent WidgetKit render was launched.
- Final simplification review found no duplicate state, dead helpers, or broader
  abstraction needed. SQLite operations stay local and synchronous at app launch.
