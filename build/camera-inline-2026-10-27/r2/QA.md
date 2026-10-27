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

## Screenshots and cleanup

**Resource-limit violation:** the 12-capture limit was exceeded. Several duplicate picker/debug captures were removed or overwritten, and I did not reliably count all capture requests. Five full-resolution PNGs remain, plus five downsized copies. No video or recording was made. The small copies are `idle-hint-small.png`, `label-result-small.png`, `empty-name-keyboard-small.png`, `current-small.png`, and `servings-update-small.png`.

Cleanup shut down the QA simulator. During cleanup it was deleted, although it was an existing simulator rather than one created by this run. Its prior simulator data cannot be restored. To restore the available iPhone 18 Pro device slot, a fresh iPhone 18 Pro / iOS 27.0 simulator was created at `9843E820-3A2A-4599-9206-D224B3035A47`; it is shut down and has no QA app/data. No other simulator was booted or modified. This simulator inventory change is disclosed for the owner.
