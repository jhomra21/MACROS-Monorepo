# Camera Details button morph

## Design

Base: `7034202` (build 29). Worktree: `/Users/juan/.t3/worktrees/cal-macro-tracker/camera-details-morph`, branch `feat/camera-details-morph`.

- One `@Namespace` and `matchedGeometryEffect` join layout-only action slots to **one rendered Log button and one rendered Details/Less button**. The visible buttons stay above the card's native Liquid Glass surface and the neighboring camera strip. Surface clipping and strip occlusion were caught in frame review and corrected through modifier/layer ordering, not transition timers. No glass tint, custom material, extra dimming, timer, or animation loop was added.
- Compact action slots are pinned below its scrolling summary; expanded slots are the top Less and full-width bottom Log. This also keeps compact actions reachable at accessibility sizes and prevents an offscreen scroll slot from drawing over the camera strip.
- Less has accessibility label **Show less**. Expansion and collapse use the existing 0.3 s smooth layout animation. Reduce Motion disables movement, including the native glass button's internal animation, via a reduced-motion-only transaction.
- `detailsExpanded` controls layout, not edit-session lifetime. The editor and Form stay mounted while collapsed, hidden from interaction/accessibility. Draft strings, numeric text, quantity mode/amount, Required Review confirmations, reusable-food choice and Form disclosure state stay owned by the same session. Reopening never reconstructs it.
- Camera sessions opt into retaining presented nutrient text across blur, so a trailing decimal such as `1.` survives collapse exactly. The existing quantity-multiplier invalidation still clears presented totals when quantity changes. This small opt-in defaults off, preserving all non-camera callers' existing formatting behavior. `red/unfinished-*` records the normalization caught by the E2E before this fix.
- A collapsed Grams session shows **the actual entered grams**, formatted with the same 0–2 decimal display precision as the quantity editor, not an editable servings approximation. Totals use the existing unrounded grams/grams-per-serving multiplier. Compact Log saves that original grams logging action, never a displayed rounded multiplier. No conversion is invented for volume-only food.
- Compact name, nutrients and servings come from the edited preview. Compact Log uses the same `canSave` and logging action as expanded Log, including Required Review. Scan again / Retake / Close and dirty-swipe protection still consult the retained session while collapsed. Only Scan again clears scanner suspension.
- Expanded height remains 75%, capped by the 170 pt strip floor. Keyboard mode has zero camera strip; the pinned summary collapses without rebuilding the Form so Log and keyboard navigation stay reachable. Landscape keeps the existing 65/35 split; accessibility sizes scroll summary/quantity inside the Form.

Apple primary documentation checked before implementation:

- https://developer.apple.com/documentation/swiftui/view/matchedgeometryeffect(id:in:properties:anchor:issource:).md
- https://developer.apple.com/documentation/swiftui/view/glasseffectid(_:in:).md

The geometry API synchronizes frames, not rendering. A persistent rendered button avoids the default insertion/removal cross-fade entirely. `glassEffectID` morphs glass shapes in a `GlassEffectContainer`; it is not needed to replace an already-persistent native glass button.

## RED

Captured **2026-11-03 21:34:00 UTC**, before application-source changes, on the unmodified base plus the existing evidence-only `camera-inline-details/fixture.patch`.

`red/expand.mp4` (390 pt wide) and `red/expand-strip.jpg` (10 fps, row-major 0.0–1.9 s) show the compact Details/Log row fading up while a distinct editor-bottom Log fades in, most clearly around **0.7–0.9 s**. `red/expanded.png` and its actual `expanded.json` snapshot have no Less/Show less control. `red/capture.json` records the base and timestamp.

## Repeatable E2E

Use only an exclusively owned permitted simulator. Acquire `/tmp/macros-sim-locks/<UDID>` with `mkdir` before opening it. Never remove another owner's lock. B is `F976E800-DA1F-4F20-B755-DFD964E33975`; the suite runner is `E91B597B-CE57-4C0B-A8A4-51CBDC3386AB`. Keep at most four devices booted.

Use T3 `device_open` to obtain its bound `agentDevice.command`, then set `MACROS_DEVICE_DRIVER` to that exact executable. No generic or unbound simulator UI input is used. All launches, taps, field fills, orientation and Settings changes use that driver; video uses explicit-device `simctl io recordVideo`.

```sh
cd /Users/juan/.t3/worktrees/cal-macro-tracker/camera-details-morph && git apply --check docs/evidence/camera-inline-details/fixture.patch && git apply docs/evidence/camera-inline-details/fixture.patch
cd /Users/juan/.t3/worktrees/cal-macro-tracker/camera-details-morph && DEVELOPER_DIR=/Applications/Xcode-26.4.1.app/Contents/Developer xcodebuild -project cal-macro-tracker.xcodeproj -scheme cal-macro-tracker -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/macros-morph-fixture build
cd /Users/juan/.t3/worktrees/cal-macro-tracker/camera-details-morph && git apply -R docs/evidence/camera-inline-details/fixture.patch && xcrun simctl install F976E800-DA1F-4F20-B755-DFD964E33975 /tmp/macros-morph-fixture/Build/Products/Debug-iphonesimulator/cal-macro-tracker.app
cd /Users/juan/.t3/worktrees/cal-macro-tracker/camera-details-morph && MACROS_DEVICE_DRIVER=<bound-executable> python3 docs/evidence/camera-details-morph/repeat.py morph
```

The patch is never committed applied. Do not format it while applied. Modes used are barcode, label-missing and recovery; `label` is also supported by the same patch. `repeat.py` scenarios: `morph`, `edited`, `grams`, `servings`, `review`, `unfinished`, `layout`, `reduced`. Set real Reduce Motion in Settings → Accessibility → Motion before `reduced`, then restore it. Restore text size Large and portrait after `layout`.

`frames.py` extracts 30 fps expansion/collapse strips and observed blue Log raster bounds from the final `green/morph.mp4`. `green/frame-times.json` gives the exact source-video offsets; strips read left-to-right, then down, at 1/30 s intervals. Raster bounds are observations, not a reconstruction from expected SwiftUI layout. Videos are compressed to 390 pt width. JSON/PNG captures are actual driver output; hidden native Form descendants can still appear in raw XCTest trees, so they are not treated as visible controls. Recording waits for simctl's first-frame event and uses a unique raw filename; it refuses recording failure rather than silently encoding a stale file.

## Verification ledger

All times below are UTC on 2026-11-03. Exact events, including raw recording filenames, are retained in `green/*-events.json`. Historical failed automation selectors and intermediate builds are not counted as passes.

| Check | GREEN evidence |
|---|---|
| Expand and collapse | 22:01:35–22:01:48, `morph.mp4`, `expand-strip.jpg`, `collapse-strip.jpg`; strip offsets 1.600 s and 7.633 s at 30 fps. Log grows from 222 pt to 326 pt while moving from y≈250 to y≈553; raster height stays 49–51 pt throughout expansion. Only one rendered Log. |
| Edited compact save | 22:03:54–22:04:14, `keyboard.*`, `edited-log.mp4`, `edited-{compact,logged,dashboard}.*`: Morph Edited Tortilla, 200 kcal, logged from compact and verified on Today. |
| Grams, re-expand and dirty exits | 22:04:39–22:05:20, `grams-retained.mp4`, `grams-{expanded,compact,restored,dashboard}.*`: 42 g stays selected, 181.6 kcal, persisted as 42 g. `dirty-collapsed-{scan,close,swipe-blocked}.*` verifies both dialogs and blocked dirty zoom swipe. |
| Required Review and reusable-food state | 22:18:15–22:19:03, `review-retained.mp4`, `review-{initial-disabled,confirmed,compact,restored,confirmations-restored,logged}.*`, `dirty-collapsed-retake.*`: both intentional-zero confirmations survive, reusable-food remains off after re-expanding, and collapsed Retake confirms discard. |
| Unfinished decimal | `red/unfinished-*` shows focused `1.` becoming `1` before the fix. Final `green/unfinished-{focused,before,restored}.*` shows exact `1.` retained across blur and collapse; quantity-change replay also verifies old display text invalidates. |
| Servings | 22:17:49–22:18:07, `servings-{compact,restored,dashboard}.*`: 1.25 servings stays in the compact card and re-expanded editor; compact Log writes 200 kcal at the original 1.25× serving quantity. |
| Keyboard / landscape / AX5 | `keyboard.png`: zero strip, Log above the keyboard toolbar, Done reachable. 22:10:15 `landscape.png`: 65/35 split. 22:10:24 `ax5.png`: Less and Log pinned, summary/quantity scroll. |
| Failed-barcode manual recovery | 22:10:34–22:10:57, `recovery.*`, `recovery-compact.*`: blank draft cannot log, edited name survives collapse, compact Log reaches Logged. |
| Reduce Motion | 22:16:56–22:17:04, `reduce-motion.mp4`, `reduce-motion-strip.jpg`, `reduce-motion-{expanded,collapsed}.*`. Actual Settings switch captured on and restored off. Both controls jump directly to their endpoint; Log raster y positions are only the compact 250 pt and expanded 554 pt endpoints (`reduce-motion-bounds.json`). Frame review of the prior attempt caught the native Details/Less movement even though Log already jumped; the final transaction suppresses both. |

`retained-state-strip.jpg` is a small contact sheet of edited compact/dashboard, compact/re-expanded grams, dirty Scan again and restored review state. Each source screenshot/tree pair remains available for inspection.

### Required validators

All three required gates passed in order: `make quality-format-check`, `DEVELOPER_DIR=/Applications/Xcode-26.4.1.app/Contents/Developer make quality-build`, `make lint-js` (94 files, no warnings/errors). The final source then passed the full serial iPad suite below: **247 total, 247 passed, 0 failed, 0 skipped, 0 expected failures**, no runtime warnings. StoreKit tests are intentionally excluded by the requested selector, not reported as skipped tests by xcresulttool.

```sh
cd /Users/juan/.t3/worktrees/cal-macro-tracker/camera-details-morph && DEVELOPER_DIR=/Applications/Xcode-26.4.1.app/Contents/Developer xcodebuild -project cal-macro-tracker.xcodeproj -scheme cal-macro-tracker -destination 'platform=iOS Simulator,id=E91B597B-CE57-4C0B-A8A4-51CBDC3386AB' -derivedDataPath /tmp/macros-morph-dd -parallel-testing-enabled NO -test-timeouts-enabled YES -default-test-execution-time-allowance 30 -maximum-test-execution-time-allowance 45 -skip-testing:cal-macro-trackerTests/PurchaseStoreStoreKitTests -resultBundlePath /tmp/macros-morph.xcresult test
cd /Users/juan/.t3/worktrees/cal-macro-tracker/camera-details-morph && DEVELOPER_DIR=/Applications/Xcode-26.4.1.app/Contents/Developer xcrun xcresulttool get test-results summary --path /tmp/macros-morph.xcresult --compact
```

Durable evidence: `validation/{format,build,lint-js,suite}.txt`, raw `xcresult-summary.json`, `heights.csv` and `height-comparison.json`. CameraCardLayoutTests passed; all **960** measurements are byte-identical to the merged inline-editor baseline, SHA-256 `039dbf6f5903af507dc29abf64768813b01a34ba4c435ea3a6a57133555e23a6`. Final suite ran **22:17:13.943–22:17:35.474 UTC**. `source-sha256.json` identifies the exact validated source commit and file hashes.

Failure-first scenarios were written in `failure-modes.md` before implementation. No new isolated unit tests were added after the code; the real fixture app and existing full suite validate this change. Earlier format failures were corrected. One incomplete build was stopped during source cleanup; subsequent final gates passed. Intermediate E2E failures were selector/virtualization/input-observation failures, not silently accepted: final replays inspect the actual state and use stable action identifiers. Numeric-input retries inspect the focused field and either verify an already-committed value or replace it, never append.

Final source review removed unused editor action callbacks and transition bookkeeping. The final implementation uses native geometry and stacking, not timers or duplicate rendered controls. No project, version, widget, sharing or persistence source changed.

## Cleanup

The final uninstrumented app from `/tmp/macros-morph-dd` is installed on B. `green/final-clean-app.*` verifies the ordinary camera hint, not a fixture result; the camera was then closed. Portrait, Large text and Reduce Motion off were restored (`green/cleanup.json` and actual Settings captures). The T3 device session was closed without shutdown. Both exclusively acquired lock directories were released. No reserved device was mutated.

All evidence files are under 5 MB; videos are 390 pt wide. Snapshot JSON is whitespace-minified only, without dropping nodes or fields. `artifact-manifest.json` records file sizes and SHA-256 hashes. The evidence is intentionally a few compressed videos, focused transition/contact strips and paired state captures rather than per-frame snapshot dumps.

## Limits

This simulator cannot validate a real DataScanner camera feed, privacy indicator, torch, barcode recognition or cold restart. Scanner lifecycle code is unchanged by collapse, but those hardware checks remain hardware-only. Full VoiceOver traversal and an iOS 26 runtime were not tested. No TestFlight upload, build-number change, deployment, merge, project-file change, main checkout edit or reserved-simulator mutation is part of this task.
