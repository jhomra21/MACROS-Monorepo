# Sharing paused-state live test, attempt 3

Dev Convex `energized-pigeon-822` only. Branch `fix/sharing-ui-ring-polish`, head `309939a` (`git pull --ff-only`: already up to date). Debug build, Xcode 26.4.1, installed on A (iPhone 17 `918D29B9`, "Test A") and B (iPhone 17e `F976E800`, "Test B"). No app code changed, no Convex code deployed. Prod was never touched.

## Result

The paused state works end to end on two devices. With `sharingRequirePro` on and neither person holding server-side Pro, both people's person screens show the paused copy and Upgrade link, A's list row reads "Paused, needs MACROS Pro" in orange, and reopening shows no flash of cached rings or foods. After the flag was removed, A's rings and foods returned on their own. One UI bug: the scope control is not disabled while paused (see Bugs).

## Flag windows

The settings table was empty before (`settings-before.txt`) and after (`settings-after.txt`, `cmp` identical). ON appends `{"sharingRequirePro":true}` with `convex import --append --table settings`. OFF is `convex import --replace --table settings` with an empty file, which deleted 1 of 1 rows. Both commands are in `flag-commands.txt`; per-run logs in `import-logs.txt`; times in `window-times.txt`.

Three windows were run, because the first two had no usable video:

| Run | Flag row created (ON done) | Row deleted (OFF done) | Duration | Notes |
| --- | --- | --- | --- | --- |
| 1 | 2026-11-02T02:40:27Z | 02:40:49Z | ~22 s | Stills and snapshots only. The recorder had died when its tool call ended, so the `.mov` was 0 bytes. |
| 2 | 02:41:51Z | 02:42:23Z | ~32 s | Stills and snapshots only. A stale CoreSimulator recording lock from run 1 blocked the recorder. |
| 3 | 02:45:23Z | 02:46:08Z | ~45 s | Full recording. All evidence files here are from run 3. |

Total time with the flag on: about 99 s across the three runs. Table confirmed empty at 02:40:59Z and 02:46:26Z. The OFF step ran from an EXIT trap in `window.sh`, so it would have run even if a capture failed.

Recorder lock: `simctl io recordVideo` left the host-recording lock held on A after being killed uncleanly. I cleared it by shutting down and rebooting A (no erase). I did not restart the CoreSimulator stream service, since that would affect the other simulators on the host. The recorder must be started and stopped (SIGINT) in the same shell call.

## Pairing (phase 1)

- B erased while shut down, then onboarded (custom targets 2200 kcal / P 160 / C 220 / F 70, notifications denied, tutorial skipped).
- A had an old Test B connection from an earlier attempt. Removed via person screen > Remove Test B > Remove Person.
- B: the Sharing switch did not flip with an accessibility press or long press; a coordinate press (328, 162 pt) flipped it. Display name set to "Test B".
- A: DEBUG "Grant Debug Pro" (local only; the server still sees no Pro), then + > Create Invite. Invite link read from A's Sharing settings and opened on B with `xcrun simctl openurl`. B accepted via "Start Sharing".
- A lists Test B ("Not sharing with you"); B lists Test A ("You don't share with Test A").
- B logged Yogurt, Soy (153 kcal) and Yuca Fries (376.6 kcal), then set what A sees to Macros + Foods.

## Baseline

- `01-baseline-person-A.png`: A's Test B screen with rings (529.6 kcal, P 10.0, C 69.5, F 24.0) and the 2 foods.
- `02-baseline-list-A.png`: A's list row "Test B, 529.6 kcal, P 10.0g, C 69.5g, F 24.0g, Sees your macros".

## Paused screens (run 3)

- `03-paused-person-A.png`: A's Test B screen. Card "Sharing is paused because neither person has MACROS Pro." with an "Upgrade to MACROS Pro" link, and a "Today" card reading "Sharing is paused" with a pause icon. No rings, no Foods section. Scope control "What Test B sees from you" still shows Nothing / Macros (selected) / Macros + Foods.
- `04-paused-list-A.png`: A's list row "Test B / Not sharing with you / Paused, needs MACROS Pro", the last line in orange, pause icon in place of rings.
- `05-paused-reopen-A.png`: A's Test B screen reopened from the paused list row, 3 s after the tap. Same paused screen.
- `06-paused-person-B.png`: B's view of Test A. Same paused card, Upgrade link and "Sharing is paused" card. Scope control shows Macros + Foods selected.
- `08-reopen-1-contact-sheet.png`, `09-reopen-2-contact-sheet.png`: 10 fps frames from the video around two reopens (tap on the paused list row). Every frame, including the push transition, shows the paused card. No rings or foods appear at any point. Read left to right, top to bottom.
- `10-paused-window-A.mov`: 60 s screen recording of A (3.2 MB). Video t is roughly seconds since 02:45:16Z: ON done ~t7, person screen, list, reopen 1 tap ~t32, reopen 2 tap ~t43, OFF done ~t52, recovered ~t60.
- `snapshot-*.txt`: accessibility trees for the captured screens.

Not covered: B's list row for Test A while paused (only B's person screen was captured).

## Recovery (phase 3)

- `07-recovered-person-A.png`: 6 s after OFF with no relaunch or navigation, A's Test B screen shows rings (529.6 kcal, P 10.0 of 160 g, C 69.5 of 220 g, F 24.0 of 70 g) and both foods (Yogurt, Soy 153 kcal; Yuca Fries 376.6 kcal).
- `CONVEX_URL=https://energized-pigeon-822.convex.cloud bun scripts/sharingSmoke.ts` (from `convex-backend`): "Sharing smoke passed." (`smoke.txt`).
- `bunx convex insights` (dev): "No issues found. The deployment is healthy over the last 72 hours." (`convex-insights.txt`).

## Bugs

1. **Scope control is not disabled while paused.** On both paused person screens the "What X sees from you" segmented control looks enabled and its Nothing / Macros / Macros + Foods buttons carry no disabled state in the accessibility tree (`snapshot-paused-person-A.txt`, `snapshot-paused-person-B.txt`). The brief expected Macros + Foods to be disabled. I did not tap it, to avoid changing relationship data. Attempt 2 (`build/sharing-paused-live-2/REPORT.md`) saw the same.

## Notes and discrepancies

- The brief said attempts 1 and 2 stopped before the flag window. The local `build/sharing-paused-live-2/REPORT.md` instead records a completed window (ON 02:15:03Z, OFF 02:16:29Z, ~88 s) with paused captures. I ran attempt 3 as instructed and did not rely on that report.
- Tooling: the SwiftUI Sharing switch on B flipped only with a coordinate press. The `agent-device` AX snapshot circuit-disabled on A after a while and refs became unreliable; coordinates were used for navigation on A. ffmpeg here has no `drawtext`, so stills are labelled by file name.
- Side effects left behind: A has local Debug Pro and sharing on; both are paired in dev Convex (A <-> B) with B's two foods; B's scope for A is Macros + Foods; A's scope for B is Macros. A was rebooted twice, B was erased once. The dev settings table is empty, as at the start.
