# Camera Details morph, fix round 2

Media removed in the repo cleanup; retrieve with `git show 074b10994f1b68d9d7a8d6c54ed7effb90d5f1f5:docs/evidence/camera-details-morph/green/expanded.png`.

Branch `feat/camera-details-morph`; review base **c8edb61**. Build 29 is unchanged.

## Correction

- **Less is now at the top-trailing edge of the persistent header**, beside the title. Only the title row reserves its measured width; the macros and servings keep their full width. At accessibility sizes, and while the keyboard is visible, Less gets a separate reserved header row so it cannot overlap or truncate the food title. Its accessibility label remains **Show less**.
- There is one persistent Details/Less button. Its in-card alignment changes from the compact action row to the header while the single persistent Log expands down to the footer, in the same card transaction. Both remain inside the card's clipping/glass boundary. No matched-geometry copies or duplicate summary were reintroduced.
- **Log is a bottom `safeAreaInset(edge: .bottom, spacing: 0)`**, including its 16 pt bottom padding. The inset propagates through the retained Form, so its last rows can scroll above the footer rather than behind it. In `green/expanded-bottom.png`, the reusable-food row ends at **791.5 pt**, above Log's **811.5 pt** top, a 20 pt gap. The real switch was also toggled off/on through the device driver.
- Native `.glass`, `.glassProminent` and untinted `.glassEffect(.regular)` remain. No tint, dimming, custom blur, timers or motion loops were added. Reduce Motion disables animations in the card transaction, including native control label/layout animation.

Draft ownership, dirty-exit protection, exact Grams logging, Required Review, scanner suspension, keyboard field navigation, the 75% / 170 pt expanded-height rule and landscape 65/35 branch are unchanged. The Form stays mounted while collapsed, clipped and excluded from input/accessibility.

Apple's primary documentation confirms that the inset makes space for the footer and adjusts the modified view's safe area:
https://developer.apple.com/documentation/swiftui/view/safeareainset(edge:alignment:spacing:content:)-4s51l.md

## RED, no new capture

The parent's review of **c8edb61** is the round-2 RED:

- [`green/expanded.png` at c8edb61](https://github.com/jhomra21/MACROS-Monorepo/blob/c8edb61/docs/evidence/camera-details-morph/green/expanded.png): bottom-left Less obscures Protein.
- `green/morph.mp4` at c8edb61, approximately **2.07–2.21 s**: Less crosses Nutrition/Calories during expansion.

Those files are historical, not the current GREEN. Earlier RED files remain background evidence for the original duplicate-header/escaping-Log defects. No additional RED was recorded for this round.

## Current GREEN

All current captures use the exclusively locked iPad runner **E91B597B-CE57-4C0B-A8A4-51CBDC3386AB**, iOS 27.0, in its actual iPhone compatibility window. Superseded GREEN files are replaced in place.

| File | What to inspect |
|---|---|
| `green/morph.mp4` | Fresh expansion/collapse: Details moves up into the header as Log moves down; collapse reverses both inside the card. |
| `green/expand-strip.jpg` | **25 real frames**, 30 fps, row-major, six columns, **300 px per frame**. Fixed crop encloses the card's largest bounds; no reconstructed frames. One stationary summary; no form-row/Log overlap from Less. |
| `green/collapse-strip.jpg` | Same 25-frame format. Controls and card settle together; full Details label returns. |
| `green/expanded.png` | Expanded top: Less beside the title, all visible nutrition rows unobscured by Less. |
| `green/expanded-bottom.png` | Real Form scrolled to its bottom: the entire reusable-food toggle clears Log. |
| `green/ax5.png` | Actual AX5 system text size: Less occupies its own top row, full food title below it, no overlapping controls. Collapse was tapped successfully at AX5. |
| `green/reduce-motion.mp4` | Real Reduce Motion enabled in Settings; card and controls jump to their endpoints, without movement. |
| `green/reduce-motion-{expand,collapse}-strip.jpg` | 25 real frames each, six columns, 300 px/frame. Both Details/Less and Log have no intermediate spatial positions. |
| `green/compact-before-after.png` | Actual compact action-row crops before expansion and after collapse. |

`green/*frame-times.json` records exact source offsets and observed blue Log raster bounds. The final row of each six-column strip contains one source frame and five empty tiles, not five repeated frames.

`green/compact-row-bounds.json` verifies equal raw action frames: Details **(32, 235.5, 92, 50.5)** and Log **(136, 235.5, 242, 50.5)** before and after. `green/compact-row-pixels.json` records **zero pixel difference** for that paired retained-session comparison. The script first opens/closes the unedited editor so both endpoints compare the same retained session. A separate first-mount comparison had identical geometry with a maximum native-glass raster difference of 1/255 (mean 0.0071/255); that rendering quantization is not described as pixel-identical.

Expanded header
Scrolled to the final row
Compact actions before and after

## Retained-state checks

- `green/edited-{compact,logged,dashboard}.{png,json}`: rename to **Morph3 Edited Tortilla**, change Calories to **200**, collapse and compact Log; Today contains the edited food and 200 calories.
- `green/grams-{expanded,compact,restored,dashboard}.{png,json}`: change **37 g to 42 g**, collapse and re-expand; Grams and 42 g persist. Compact summary shows **181.6 kcal**, and Log persists **42 g**, not rounded servings.
- `green/dirty-collapsed-scan.{png,json}`: collapsed dirty Scan again presents **Discard changes? / Keep Editing**. Keep Editing retains the session, then compact Log succeeds.
- `green/keyboard.{png,json}`: Calories focused, top Less and footer Log remain available; Done and field navigation work. **Limit:** this iPad compatibility session exposes the 64 pt keyboard accessory toolbar with the software-key rows offscreen; the camera strip remains visible. The unchanged full software-keyboard strip-hiding branch is not newly proven by this capture.
- `green/landscape.{png,json}`: actual landscape device orientation, reachable editor/actions. **Limit:** the iPad compatibility window remains portrait-shaped with regular vertical size class. The unchanged iPhone compact-size-class 65/35 branch is not newly hardware-shaped E2E evidence.
- `green/reduce-motion-setting-{on,restored}.{png,json}`: actual system setting enabled for capture and restored off.

Real camera/torch/scanner lifecycle, full VoiceOver traversal and iOS 26 remain outside this simulator evidence.

## Repeat and isolation

Acquire the lock atomically with `mkdir /tmp/macros-sim-locks/E91B597B-CE57-4C0B-A8A4-51CBDC3386AB`. Never take or remove another owner's lock. Only the iPad runner was opened or driven. No forbidden devices, crash-worker devices, owner's checkout, `IGNOREDbuild/`, shared XcodeBuildMCP defaults/profiles, project settings, merge, build-number change or upload.

Open the iPad through T3 `device_open`, then use its exact bound executable for `MACROS_DEVICE_DRIVER`. `repeat-ipad.py` drives all app launches, input, settings, orientation, screenshots and recording through that CLI.

The script documents the compatibility window's raw-coordinate correction. Gestures must also fit its physical x=232...642 window; x=620 reaches the Form after the driver's correction. XCTest reports false `hittable` values for some windowed controls even when they accept input, so actual switch input and geometry validate bottom reachability. Focused text is cleared and read back exactly, not accepted with appended digits.

```sh
cd /Users/juan/.t3/worktrees/cal-macro-tracker/camera-details-morph && git pull --ff-only
cd /Users/juan/.t3/worktrees/cal-macro-tracker/camera-details-morph && git apply --check docs/evidence/camera-inline-details/fixture.patch && git apply docs/evidence/camera-inline-details/fixture.patch
cd /Users/juan/.t3/worktrees/cal-macro-tracker/camera-details-morph && DEVELOPER_DIR=/Applications/Xcode-26.4.1.app/Contents/Developer xcodebuild -project cal-macro-tracker.xcodeproj -scheme cal-macro-tracker -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/macros-morph3-fixture build
cd /Users/juan/.t3/worktrees/cal-macro-tracker/camera-details-morph && git apply -R docs/evidence/camera-inline-details/fixture.patch && xcrun simctl install E91B597B-CE57-4C0B-A8A4-51CBDC3386AB /tmp/macros-morph3-fixture/Build/Products/Debug-iphonesimulator/cal-macro-tracker.app
cd /Users/juan/.t3/worktrees/cal-macro-tracker/camera-details-morph && MACROS_DEVICE_DRIVER=<T3-bound-executable> python3 docs/evidence/camera-details-morph/repeat-ipad.py morph
cd /Users/juan/.t3/worktrees/cal-macro-tracker/camera-details-morph && python3 docs/evidence/camera-details-morph/frames.py
```

Other scenarios: `edited`, `grams`, `layout`, `reduced`. Run `motion_on` before `reduced` and `motion_off` afterward to change/restore the actual system Reduce Motion switch. If switching from Settings causes a runner timeout, close only this bound CLI session and reopen the app before replaying `reduced`; do not change shared runner caches. `layout` restores portrait and Large text. The evidence-only fixture patch is removed before required validators and commit; it is never shipped applied. Failed driver setup/coordinate/selector attempts are not counted as passing scenarios.

## Validation

Formatting, quality build, and JS lint passed. JS lint: **94 files, 0 warnings, 0 errors**. The full serial iPad suite passed: **247 passed, 0 failed, 0 skipped** (PurchaseStoreStoreKitTests excluded). The result bundle is `/tmp/macros-morph3.xcresult`; durable suite and summary files are in `validation/`. A clean fixture compile reports existing unrelated concurrency warnings in SharingRemoteClient and DashboardTutorialOverlay; no camera-source warning was introduced.

```sh
cd /Users/juan/.t3/worktrees/cal-macro-tracker/camera-details-morph && make quality-format-check
cd /Users/juan/.t3/worktrees/cal-macro-tracker/camera-details-morph && DEVELOPER_DIR=/Applications/Xcode-26.4.1.app/Contents/Developer make quality-build
cd /Users/juan/.t3/worktrees/cal-macro-tracker/camera-details-morph && make lint-js
cd /Users/juan/.t3/worktrees/cal-macro-tracker/camera-details-morph && DEVELOPER_DIR=/Applications/Xcode-26.4.1.app/Contents/Developer xcodebuild -project cal-macro-tracker.xcodeproj -scheme cal-macro-tracker -destination 'platform=iOS Simulator,id=E91B597B-CE57-4C0B-A8A4-51CBDC3386AB' -derivedDataPath /tmp/macros-morph3-dd -parallel-testing-enabled NO -test-timeouts-enabled YES -default-test-execution-time-allowance 30 -maximum-test-execution-time-allowance 45 -skip-testing:cal-macro-trackerTests/PurchaseStoreStoreKitTests -resultBundlePath /tmp/macros-morph3.xcresult test
cd /Users/juan/.t3/worktrees/cal-macro-tracker/camera-details-morph && DEVELOPER_DIR=/Applications/Xcode-26.4.1.app/Contents/Developer xcrun xcresulttool get test-results summary --path /tmp/macros-morph3.xcresult --compact
```

The final source review checks for duplicate controls, dead transition state and unnecessary guards. No new unit tests were written after implementation. Every evidence file must remain below 5 MB; `artifact-manifest.json` records sizes and SHA-256 hashes.
