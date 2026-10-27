# Camera Inline Results E2E QA (r2)

Date: 2026-10-27
Branch: `feature/camera-inline-results`
Code-under-test HEAD: `9e73abf68ee6943023c0a955261e64f394578b0f`

## Simulator setup

The prior-run simulator `BB220C75-3720-42CF-B7B2-87B9074FCFE0` was absent. Initial CoreSimulator metadata showed every existing simulator shut down. One official iPhone 18 Pro / iOS 27.0 simulator was used: `EEB6F0CC-D69E-41BE-9D29-A0C41B66B523`. It was the only booted simulator during UI checks. The existing Debug app at `~/Library/Developer/Xcode/DerivedData/cal-macro-tracker-emumcxczbimxfpbuxoehjcaqeayy/Build/Products/Debug-iphonesimulator/cal-macro-tracker.app` (bundle `juan-test.cal-macro-tracker`, version 1.0, build 7) was installed, without running a build or tests.

The first `simctl create` and XcodeBuildMCP `boot_sim` requests timed out. Opening Simulator with `open -a Simulator --args -CurrentDeviceUDID EEB6F0CC-D69E-41BE-9D29-A0C41B66B523` brought the selected device up. Thereafter `simctl list devices booted`, screenshots, install, app launch, taps, and AX snapshots worked. The app was launched with `PACKAGED_FOOD_SEARCH_BASE_URL_OVERRIDE=https://cal-macro-tracker-usda-proxy.jhonra121.workers.dev`.

## Scenarios

| Scenario | Expected | Observed | Result | Evidence |
|---|---|---|---|---|
| 1. Dashboard idle camera | Viewfinder hint, no spinner or large blank panel | Hint and viewfinder appeared without spinner. The hint panel was compact above the camera-unavailable preview. | PASS | `idle-hint.png` |
| 2. Complete label | Inline editable OCR result; keyboard and name visible; empty name disables Log; `Test oats` enables Log; servings 2; log remains in camera; dashboard total is twice the fixture | Photos import succeeded. Inline result showed `QA Oats`, serving `1 cup (40g)`, 150 cal, 5 g P, 27 g C, 3 g F. The keyboard opened. Clearing the name showed the placeholder and disabled Log; typing via key sequence entered `test oats` (lowercase) and enabled Log. The stepper was operated from 1 to 1.25 and 1.5, but did not reach 2. No log or dashboard totals were checked. | PARTIAL; log/totals NOT RUN | `label-result.png`, `empty-name-keyboard.png`, `servings-update.png` |
| 3. Incomplete label | Missing Protein and Fat warning; no Log; prominent Edit details; bounded scroll and reachable controls with keyboard; quantity preserved in editor | Not run. | NOT RUN | None |
| 4. Barcode Photos | EAN resolves to Thai peanut noodle kit; servings stepper and log work | Not run. | NOT RUN | None |

Follow-up UI interaction stopped when reloading schemas with `select:XcodeBuildMCP___snapshot_ui,XcodeBuildMCP___tap` and `select:XcodeBuildMCP___type_text` returned `Found 0 tools`. No app bug was demonstrated. Source and tests were not changed.

## Prior test evidence

The prior worker recorded `FoodCameraFlowTests` 25/25 and `BarcodeImageScannerTests` 3/3, plus format, build, and diff-check success. Those were not repeated because source code did not change.

## T3 device workflow follow-up

After this report was written, the owner identified the Xcode `simctl` wrapper mismatch: the launcher expects CoreSimulator `1051.49`, while the installed version differs, so each wrapped call starts `xcodebuild -runFirstLaunch`. The direct installed binary `/Library/Developer/PrivateFrameworks/CoreSimulator.framework/Versions/A/Resources/bin/simctl` worked. The replacement simulator was booted and `bootstatus` completed after Data Migration; direct `simctl list devices booted` confirmed it was the only booted simulator.

Before the direct boot, T3 `device_list` omitted `9843E820-3A2A-4599-9206-D224B3035A47`, and `device_open` returned `No device 9843E820-3A2A-4599-9206-D224B3035A47 on host local. Call device_list for current ids.` The list showed no open devices; local agent `runningVersion` was `null`. After boot, live tool schema searches returned `Found 0 tools`, so T3 could not be refreshed and `device_open` could not be retried. A fresh app-first `agent-device open juan-test.cal-macro-tracker --foreground --platform ios --udid 9843E820-3A2A-4599-9206-D224B3035A47 --config /Users/juan/.t3/userdata/device/hosts/25bf8e1a2393f1108d37029b.json --session camera-inline-r2-fresh-20261027` returned `Remote daemon is unavailable` (diagnostic `mvrb3him-13ce8115`, log `/Users/juan/.agent-device/logs/camera-inline-r2-fresh-20261027/2026-10-27/2026-10-27T23-18-07-753Z-mvrb3him-13ce8115.ndjson`). One `GET http://127.0.0.1:49734/health` returned `curl: (7) Failed to connect to 127.0.0.1 port 49734`; the local agent's host config names that daemon endpoint. Direct `agent-device --help` displayed quick-start guidance, but `help devices`, `help open`, `help logs`, `help commands`, and `devices --platform ios` each returned `Call device_open first and include its --config and --session flags.` Because T3 could not return a session config and the daemon health request failed, bounded diagnostics stopped without global edits, installs, or killing any service. XcodeBuildMCP schema search also returned `Found 0 tools`. No further UI interactions were performed.

## Screenshots and cleanup

**Resource-limit violation:** the 12-capture limit was exceeded. Several duplicate picker/debug captures were removed or overwritten, and I did not reliably count all capture requests. Five full-resolution PNGs remain, plus five downsized copies. No video or recording was made. The small copies are `idle-hint-small.png`, `label-result-small.png`, `empty-name-keyboard-small.png`, `current-small.png`, and `servings-update-small.png`.

The replacement iPhone 18 Pro simulator `9843E820-3A2A-4599-9206-D224B3035A47` was shut down with the installed direct `simctl` binary after the unsuccessful Device panel attempt. A final booted-device listing was empty. No other simulator was booted or modified.
