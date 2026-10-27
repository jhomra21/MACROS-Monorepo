# Camera Inline Results E2E QA (r2)

Date: 2026-10-27
Branch: `feature/camera-inline-results`
Expected and observed HEAD: `1431fa1a5dbf7fc6ee58d289554b162814ec5669`

## Simulator and blocker

The prescribed simulator `BB220C75-3720-42CF-B7B2-87B9074FCFE0` is absent from this CoreSimulator device set. Before any boot or launch, CoreSimulator metadata showed another device already booted: **iPhone 18 Pro Max**, iOS 27.0, UDID `00F488C0-5DEB-438B-A3FE-B17C4CEF616E` (device state `1`, booted). The required one-simulator limit prohibits booting another simulator or operating on that already-booted device. Therefore no simulator UI actions or new screenshots were captured.

Driver checks attempted:

- `xcrun simctl list devices booted` timed out at 60 seconds and again at 300 seconds.
- XcodeBuildMCP `list_sims` timed out.
- XcodeBuildMCP `snapshot_ui` returned: `Simulator with UDID BB220C75-3720-42CF-B7B2-87B9074FCFE0 not found in set.`
- The device metadata independently confirms the target UUID is absent and the iPhone 18 Pro Max is booted. No simulator was booted, shutdown, deleted, or otherwise modified. The device panel was not opened in this run.

## Scenarios

| Scenario | Expected | Observed | Result | Evidence |
|---|---|---|---|---|
| 1. Dashboard idle camera | Camera opens; viewfinder hint appears without spinner and without a large blank panel | Not rerun because the designated simulator is absent and another simulator is already booted. The prior worker verified only the viewfinder hint/no spinner; blank-space sizing was not measured. | NOT RUN (prior partial evidence only) | Prior `../idle-hint.png`; prior `../QA.md` |
| 2. Complete label flow | Import a real nutrition label; inline editable result; keyboard/name visibility; Log disabled for empty name and enabled for `Test oats`; servings 2; successful log remains in camera; dashboard totals match twice the fixture | Not reached; no Photos picker interaction was attempted. | NOT RUN | None in r2 |
| 3. Incomplete label flow | Missing Protein and Fat remain missing; orange warning; no Log; prominent Edit details; panel remains bounded and controls reachable with keyboard; servings preserved on opening editor | Not reached; no incomplete-label image was generated or imported. | NOT RUN | None in r2 |
| 4. Barcode Photos flow | EAN fixture resolves the Thai peanut noodle kit, servings control works, logging succeeds | Not reached; no Photos picker interaction was attempted. | NOT RUN | None in r2 |

## Prior evidence (unchanged code)

The preceding run recorded 25/25 `FoodCameraFlowTests` and 3/3 `BarcodeImageScannerTests`, plus format, build, and diff-check success. Those passing checks were not repeated because this run made no source changes. The prior `../QA.md` records onboarding/dashboard and the idle hint, but says Photos-based result workflows were not completed.

Existing screenshots: `../dashboard.png`, `../idle-hint.png`, and `../photos-fixtures.png` (prior-run evidence only; none is a new r2 capture). Existing `.xcresult` bundles remain from prior runs.

## Code changes and cleanup

No application code or tests changed. No bug was demonstrated by this run. No build or tests were run. The repository branch was clean before artifact creation; only this QA report and its requested changes-log summary are new. No owned simulator existed to shut down or delete, and the already-booted iPhone 18 Pro Max was left untouched.
