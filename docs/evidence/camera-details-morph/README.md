# Camera Details morph, review fix round

Branch `feat/camera-details-morph`; review base `6efc374`, build 29 unchanged.

## Causes and correction

1. **Log escaped the card.** The old button was an overlay *outside* the clipping/glass modifiers. Its matched-geometry source changed from a compact slot to a separately sized editor slot, independently of the card's growing bounds. The rendered button is now inside the card's persistent action container and clipping boundary.
2. **Two headers overlapped.** The outgoing compact ScrollView and incoming editor each rendered a complete summary. There is now one persistent summary ScrollView. Only the retained editor body grows below it. No summary opacity transition or replacement is involved.
3. **Details became “Deta...”.** The overlay used a stretched label whose intrinsic width differed from the hidden Details/Less source slots. Removing the slots and geometry matching removes that stale sizing relationship. A real, intrinsically sized label participates in ordinary layout; there is no fixed button width.
4. **Log landed late.** Its matched-geometry animation was independent of the card layout. `AnyLayout` now switches the same two controls between the compact HStack and expanded VStack footer, in the existing card layout transaction. Less stays directly above full-width Log in the expanded footer, rather than introducing a top overlay.

There is **one rendered Log button** in the camera card, not two cross-faded copies. The result panel's standalone actions remain available to its existing layout tests, but are disabled for an actionable camera card. Removed the unused slot modifier, action namespace, hidden placeholder buttons and duplicate summary.

Native `.glass` / `.glassProminent` button styles and untinted `.glassEffect(.regular)` remain. No custom blur, tint, dimming, timers or animation loops were added. Reduce Motion still disables all animation in the card transaction. Draft/session ownership, exact Grams logging, Required Review gating and dirty-exit logic are unchanged. The Form remains mounted while collapsed, clipped and excluded from interaction/accessibility. At large text and compact vertical size, the persistent summary has its own bounded scroll area; quantity and the editor body scroll in the retained Form. Keyboard mode hides the summary and camera strip while keeping the footer and keyboard toolbar reachable.

Apple primary docs verified with `.md`:

- https://developer.apple.com/documentation/swiftui/anylayout.md (switch layouts without destroying subview state)
- https://developer.apple.com/documentation/swiftui/view/matchedgeometryeffect(id:in:properties:anchor:issource:).md (synchronizes geometry, not rendering)
- https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views.md
- https://developer.apple.com/documentation/swiftui/glasseffectcontainer.md

`glassEffectID` coordinates appearing/disappearing glass shapes. These controls do not appear/disappear when the layout changes, so ordinary persistent native controls and `AnyLayout` are the smaller solution.

## RED

The parent reviewed the old `green/expand-strip.jpg` and `green/collapse-strip.jpg` at **6efc374**:

- Expand row 1 frames 4–5: Log below the compact card, overlapping Scan again.
- Expand/collapse row 2: overlapping copies of the food name, kcal and servings.
- Settled collapse row 3: “Deta...” and displaced Log.
- Log's independent movement finishes after the card resize.

Those historical files remain inspectable in that commit, not as a second purported GREEN set.

The capture device changed because B and A belong to a live crash investigation. A fresh **same-device RED** was therefore recorded from the unmodified 6efc374 application sources plus the existing evidence-only `camera-inline-details/fixture.patch`, before the source fix: `red/ipad-review-cycle.mp4`, `red/ipad-review-{expand,collapse}-strip.jpg`, and `red/ipad-compact.png`. `red/ipad-review-frame-times.json` records offsets. The original task's RED and unfinished-decimal captures remain historical background.

## GREEN frame review

All new captures use the exclusively locked iPad runner `E91B597B-CE57-4C0B-A8A4-51CBDC3386AB`, iOS 27.0, in its actual iPhone compatibility window. Videos crop the captured device image to that window, then encode at 390 px width. No expected frames are synthesized. Each strip contains **25 frames at 30 fps**, row-major, covering 0.8 s. Exact source offsets and observed blue Log raster bounds are in the paired `*-frame-times.json`.

| Strip | Assertions checked visually |
|---|---|
| `green/expand-strip.jpg`, from `morph.mp4` | (1) Log never leaves the card; (2) one stationary header, no duplicate; (3) the eventual collapsed row matches the starting compact row in the paired collapse strip/comparison; (4) Log follows the card bottom and arrives with the card, not afterward. |
| `green/collapse-strip.jpg`, from `morph.mp4` | (1) Log never leaves the card; (2) no duplicate header; (3) settled Details and Log return to the exact pre-expand frames and full labels; (4) Log arrives with the card. |
| `green/reduce-motion-expand-strip.jpg`, from `reduce-motion.mp4` | (1) Log stays in the card; (2) no duplicate header; (3) the paired collapsed endpoint matches the pre-expand compact row; (4) Log and card jump to the endpoint together, without spatial interpolation. |
| `green/reduce-motion-collapse-strip.jpg`, from `reduce-motion.mp4` | (1) Log stays in the card; (2) no duplicate header; (3) the compact row returns unchanged; (4) Log arrives immediately with the card. |

![Before expansion (left), after collapse (right)](green/compact-before-after.png)

`green/compact-row-bounds.json` asserts exact equality of raw settled frames: Details `(32, 235.5, 92, 50.5)`; Log `(136, 235.5, 242, 50.5)` in app points, before **and** after. The side-by-side image is cropped from actual screenshots. Both match the same-device RED compact row, with full “Details”, not “Deta...”.

`green/compact-row-pixels.json` also verifies **zero pixel difference** between the pre-expand and post-collapse action-row crops. Versus RED, positions match; the native-glass raster's mean absolute RGB-channel difference is 0.1365/255 (maximum 5), not a layout shift.

## Retained-state and layout rechecks

- `green/edited-{compact,logged,dashboard}.{png,json}`: edit the name to **Morph2 Edited Tortilla**, change calories to **200**, collapse and use compact Log; Today contains that exact edited food and 200 calories.
- `green/grams-{expanded,compact,restored,dashboard}.{png,json}`: select Grams, change 37 to **42 g**, collapse and re-expand; the selected mode and 42 g persist. Compact summary shows **181.6 kcal**, and compact Log persists **42 g**, not a rounded servings conversion.
- `green/dirty-collapsed-scan.{png,json}`: changing grams makes the retained session dirty; collapsed Scan again presents **Discard changes? / Keep Editing**. Keep Editing preserves the session, then compact Log succeeds.
- `green/keyboard.{png,json}`: edited Calories field focused, Log and Less above the keyboard toolbar, Done/field navigation reachable, no camera strip.
- `green/landscape.{png,json}`: actual device landscape orientation, retained editor and both actions remain reachable. **Limit:** iPad's compatibility window stays portrait-shaped and uses regular vertical size class. This is not evidence of the iPhone's 65/35 compact-size-class branch; that unchanged branch needs a free iPhone for a fresh hardware-shaped capture.
- `green/ax5.{png,json}`: actual accessibility-extra-extra-extra-large setting; summary scrolls separately, body scrolls, Less and Log remain pinned and distinct from Scan again.
- `green/reduce-motion-setting-{on,restored}.{png,json}`: actual system switch on for capture, restored off afterward.

The earlier review/unfinished-input/servings E2Es are recorded at 6efc374. They were not silently counted as rerun evidence here; superseded GREEN artifacts were removed instead of keeping multiple competing passes.

## Repeat

Acquire the iPad lock with `mkdir /tmp/macros-sim-locks/E91B597B-CE57-4C0B-A8A4-51CBDC3386AB`. Never remove another owner's lock. B's existing lock belongs to the crash worker and was left untouched. The user explicitly authorized closing only the stale iPad driver session `t3-ec61bd84b4c37dacbdc24bcc`, without shutdown.

Open the iPad with T3 `device_open`; set `MACROS_DEVICE_DRIVER` to its returned bound executable. `repeat-ipad.py` drives every launch, tap, text input, setting, orientation, screenshot and recording through that CLI. Raw XCTest coordinates and screenshots expose the iPad window offset; the script documents its explicit compatibility-window coordinate correction. Focused text is cleared from the end and read back exactly, rather than accepting appended digits. The 1200 ms settle quiet window avoids capturing provisional native-button geometry. Failed selector/input/runner attempts are not counted as passes.

```sh
cd /Users/juan/.t3/worktrees/cal-macro-tracker/camera-details-morph && git apply --check docs/evidence/camera-inline-details/fixture.patch && git apply docs/evidence/camera-inline-details/fixture.patch
cd /Users/juan/.t3/worktrees/cal-macro-tracker/camera-details-morph && DEVELOPER_DIR=/Applications/Xcode-26.4.1.app/Contents/Developer xcodebuild -project cal-macro-tracker.xcodeproj -scheme cal-macro-tracker -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/macros-morph2-fixture build
cd /Users/juan/.t3/worktrees/cal-macro-tracker/camera-details-morph && git apply -R docs/evidence/camera-inline-details/fixture.patch && xcrun simctl install E91B597B-CE57-4C0B-A8A4-51CBDC3386AB /tmp/macros-morph2-fixture/Build/Products/Debug-iphonesimulator/cal-macro-tracker.app
cd /Users/juan/.t3/worktrees/cal-macro-tracker/camera-details-morph && MACROS_DEVICE_DRIVER=<T3-bound-executable> python3 docs/evidence/camera-details-morph/repeat-ipad.py morph
cd /Users/juan/.t3/worktrees/cal-macro-tracker/camera-details-morph && python3 docs/evidence/camera-details-morph/frames.py
```

Other scenarios: `edited`, `grams`, `layout`, `reduced`. Enable real Reduce Motion through Settings → Accessibility → Motion before `reduced`, then restore it. `layout` restores portrait and Large text. The fixture patch is removed before formatting, required validation and commit; it is never shipped applied.

One runner process exited while switching back from Settings (XCTest connection timeout, not an application assertion). Reopening the bound device session recovered it; the final Reduce Motion replay passed. No shared runner caches or other device sessions were modified.

## Validation and cleanup

Required format/build/JS lint gates pass. JS lint: **94 files, 0 warnings, 0 errors**.
Final full serial suite: **247 total, 247 passed, 0 failed, 0 skipped, 0 expected failures**, no xcresult runtime warnings. PurchaseStoreStoreKitTests were intentionally excluded by selector. CameraCardLayoutTests passed; all **960** measurements are byte-identical to baseline, SHA-256 `039dbf6f5903af507dc29abf64768813b01a34ba4c435ea3a6a57133555e23a6`.

The first suite attempt was killed before establishing the test-host connection, with no test case run (`validation/bootstrap-failure.json`, original bundle `/tmp/macros-morph2-bootstrap-failure.xcresult`). The locked iPad's slim profile verified correctly. A normal retry, with no source or simulator reset, passed at **23:41:59.382–23:42:16.745 UTC** and occupies the required `/tmp/macros-morph2.xcresult`. The benign missing slimmed-system-service console message also appears in the passing run; it is not counted as a test failure.

```sh
cd /Users/juan/.t3/worktrees/cal-macro-tracker/camera-details-morph && make quality-format-check
cd /Users/juan/.t3/worktrees/cal-macro-tracker/camera-details-morph && DEVELOPER_DIR=/Applications/Xcode-26.4.1.app/Contents/Developer make quality-build
cd /Users/juan/.t3/worktrees/cal-macro-tracker/camera-details-morph && make lint-js
cd /Users/juan/.t3/worktrees/cal-macro-tracker/camera-details-morph && DEVELOPER_DIR=/Applications/Xcode-26.4.1.app/Contents/Developer xcodebuild -project cal-macro-tracker.xcodeproj -scheme cal-macro-tracker -destination 'platform=iOS Simulator,id=E91B597B-CE57-4C0B-A8A4-51CBDC3386AB' -derivedDataPath /tmp/macros-morph2-dd -parallel-testing-enabled NO -test-timeouts-enabled YES -default-test-execution-time-allowance 30 -maximum-test-execution-time-allowance 45 -skip-testing:cal-macro-trackerTests/PurchaseStoreStoreKitTests -resultBundlePath /tmp/macros-morph2.xcresult test
cd /Users/juan/.t3/worktrees/cal-macro-tracker/camera-details-morph && DEVELOPER_DIR=/Applications/Xcode-26.4.1.app/Contents/Developer xcrun xcresulttool get test-results summary --path /tmp/macros-morph2.xcresult --compact
```

Durable summaries live in `validation/`; the manifest records sizes and SHA-256 hashes. All files are under 5 MB. No new unit tests were written after implementation. Final source review found no duplicate summary, hidden slot controls or dead transition bookkeeping.

Cleanup is recorded in `green/cleanup.json`. No merge, version bump, upload, project change, owner's checkout access, forbidden simulator mutation or shared XcodeBuildMCP defaults/profile change. Real camera/torch/scanner lifecycle, full VoiceOver traversal and iOS 26 remain outside simulator evidence.
