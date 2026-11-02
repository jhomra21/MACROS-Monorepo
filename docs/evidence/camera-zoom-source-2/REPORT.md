# Camera zoom source, round 2

## Outcome

Implementation: `95e0d69183386824cf453dbf5c7f06324d8680a4`, pushed to `fix/add-food-camera-zoom-source`.

The cause is the destination's initial **internal layout animation**, not the bounds of the matched source. The fix enables the existing result-layout animation only when `cameraCardVisible` is true. That flag is already set by the presentation-completion observer. No new state, timer, transition, or measurement rule was added.

The source modifier-order change in `8068072` was reverted. `BottomPinnedActionBar.swift` is byte-for-byte identical to `origin/main`. The cumulative branch diff, `git diff origin/main...HEAD`, is exactly two files, **3 insertions and 2 deletions**:

- `FoodCameraSheet.swift`: replace the layout-animation comment and gate its existing curve with `cameraCardVisible && !reduceMotion`.
- `changes-log.md`: one corrected history entry.

The complete diff is in [cumulative-diff.patch](cumulative-diff.patch). At comparison time, `origin/main` was `f099cb70a7aa2b28cdd5b1e73d53f522cd2325b9`, and the merge base was `67e85adef4bb809121248a05e109270c7ea6dfa2`. Main's separate website screenshot commit is not part of this branch's cumulative changes.

## Mechanism, supported by logs and frames

Temporary, uncommitted probes recorded wall-clock timestamps for the source action, the `GeometryReader` global frame, the viewport global frame before clipping/padding, every result-height measurement, viewport `onAppear`, and presentation completion. All probes were removed before the final build and commit. [instrumented-candidate.patch](instrumented-candidate.patch) preserves the diagnostic edits as an evidence artifact, not shipping code.

The same initial conditions occur for Add Food wide, Add Food compact, and Dashboard Camera:

1. The container initially reports `(0, 0, 0, 0)`.
2. The viewport's provisional layout is `(16, 16, 220, 120)`, not its eventual 370-point width.
3. The wrapped hint initially measures **1250 points**, not its eventual 70 points.
4. The container quickly receives its real width. However, the `VStack`'s value-driven animation applies to the whole subtree, including the viewport's simultaneous frame correction. The rendered viewport interpolates from the narrow, leading-aligned provisional layout while the modal's black background follows the system zoom.
5. Animated width also changes the hint's wrapping and repeatedly feeds intermediate heights back through `onGeometryChange`.

The geometry callbacks report layout values, not every presentation-layer interpolation. The video is the evidence of the interpolated, narrower on-screen viewport after the callback already reports the final width.

### First 600 ms

[first-600ms.log](first-600ms.log) contains tap-relative traces for the requested four cases, plus controls and fixed runs. Raw logs retain their original timestamps.

**Original Add Food wide**, `original-geometry.log`, tap epoch `1793643356.84067`:

```text
+212.81ms viewport (16, 16, 220, 120)
+212.86ms resultHeight 0 -> 1250
+212.88ms container (0, 0, 0, 0)
+213.06ms viewport appear reveal=false resultHeight=1250
+241.44ms container (0, 62, 402, 778)
+295.69ms resultHeight 1250 -> 490
+310.48ms resultHeight 490 -> 230
+327.16ms resultHeight 230 -> 150
+343.59ms resultHeight 150 -> 110
+360.32ms resultHeight 110 -> 90
+426.95ms resultHeight 90 -> 70
```

**Original compact**, same log, tap epoch `1793643362.9033751`: the same provisional viewport and 1250-point hint at +50.64 ms; intermediate heights `590, 250, 150, 110, 90`; final 70 at +280.79 ms.

**Original Dashboard Camera**, `original-dashboard-geometry.log`, tap epoch `1793643442.1018538`: the same provisional viewport and 1250-point hint at +297.92 ms; intermediate heights `370, 190, 150, 110, 90`; final 70 at +582.51 ms.

**8068072 Add Food wide**, `first-fix-geometry.log`, tap epoch `1793643185.731055`: the same provisional viewport at +362.79 ms, zero container at +364.41 ms, and result heights `1250, 590, 250, 150, 110, 90, 70`. Final height arrives at +603.02 ms, just beyond the first-600-ms excerpt. The modifier-order change does not remove the destination-layout cascade.

**Fixed Add Food wide**, `candidate-geometry.log`, tap epoch `1793643466.667886`:

```text
+76.56ms viewport (16, 16, 220, 120)
+76.62ms resultHeight 0 -> 1250
+76.64ms container (0, 0, 0, 0)
+76.80ms viewport appear reveal=false resultHeight=1250
+94.74ms resultHeight 1250 -> 70
+104.36ms viewport (16.17, 148, 370, 710)
+104.40ms container (0, 62, 402, 778)
```

The provisional layout still exists internally, but it is no longer an animation endpoint. There is no intermediate-height cascade. Fixed compact reaches final layout at +35.56 ms, and fixed Dashboard Camera at +166.95 ms.

Both presentation paths use `.presentationBackground(.clear)` and the same `FoodCameraSheet`. Dashboard does not have a separate initialization policy. The different source geometry and transition timing can conceal the bad internal interpolation, but do not prevent the provisional layout.

The viewport's `cameraRevealVisible` fade/blur and `onAppear` remain unchanged. `revealCameraCard` still runs only at presentation completion (wide diagnostic run: epoch `1793643467.694447`, approximately +1027 ms after tap). This makes the existing card-visible flag the appropriate boundary for enabling later result-layout animation.

Apple's documented `animation(_:value:)` behavior applies an animation to the modified view when the monitored value changes; `nil` disables it: https://developer.apple.com/documentation/swiftui/view/animation(_:value:).md

## Frame findings

### Prior round, independently inspected

The six requested frames were extracted from `origin/docs/asc-review-screenshots`, inspected, and preserved here with `prior-` names.

- `prior-before-wide-frame-02.png`: narrow gray viewport on the left within the growing cover.
- `prior-before-wide-frame-03.png`: black cover is already screen-wide, while the viewport is a small rounded box at the top-left. This confirms the owner's qualitative observation, not a successful full-capsule zoom.
- `prior-first-fix-frame-45.png`: narrow gray viewport remains at the left beneath the wide source capsule. Frames 50 and 55 widen afterward. The first report's success claim was incorrect.

### Fresh before/after comparison

All frame numbers below are zero-based **30 fps timeline indices**, not the native variable-rate indices.

- **Original wide**, `before-wide`: first confidently measurable gray box at frame 35, approximately `x=25…285`, center 155. At frame 36 the gray box is still narrower than the black cover.
- **8068072 wide**, `first-fix-wide`: frame 49 has gray bounds approximately `x=25…262`, center 143.5. The problem remains.
- **Fixed wide, uninstrumented**, `final-wide`: first measurable gray box at frame 27 is approximately `x=25…376`, center 200.5. The viewport stays centered as it expands from the full capsule. There is no separate narrow viewport growing out of the left edge.
- **Fixed compact**, `final-compact`: the source is the right-hand circle. At frame 23 the gray box is right-weighted (`x=154…383`) and moves toward the final viewport bounds as expected.
- **Fixed Dashboard Camera**, `final-dashboard-camera`: the source is the left Dashboard capsule; its zoom remains left-source-to-full-screen, without the independent internal width interpolation. The hint stages in after the zoom.
- **Fixed Dashboard Add Food**, `final-dashboard-addfood`: the sheet grows from the right Dashboard capsule and settles with the full Camera capsule. No source or destination changes were made to that path.
- `final-wide-close` and `final-compact-close` return to the center of the wide capsule and the compact right-hand circle, respectively.

`viewport-frame-bounds.json` contains approximate color-based measurements in 402×874 screen points. These are supporting measurements, not exact view-frame instrumentation; rounded corners, opacity, and compression affect the bounds.

### Contact sheets and crops

- `final-*-native-contact-*.jpg`: **every decoded native frame**, in order, with original presentation timestamps, for the four required open paths. Extracted counts match the videos: wide 107/107, compact 115/115, Dashboard Camera 111/111, Dashboard Add Food 132/132. No native frames were dropped from these sheets.
- `final-*-contact-*.jpg`: complete 30 fps timeline, including source, zoom, staged hint, and settled state. Close paths also have complete 30 fps sheets.
- `wide-same-frame-029.png` through `wide-same-frame-036.png`: before/after crops at exactly the same recording frame indices.
- `wide-onset-relative-00.png` through `03.png`: additional comparisons aligned to each capture's first measurable gray viewport. The captions retain the actual underlying frame indices. Capture lead-in and scheduling differ, so equal absolute indices do not guarantee equal transition phase.

## Later result sizing and staged reveal

The layout curve remains `.smooth(duration: 0.3)` after the presentation finishes.

A real photo-library import used the repository's synthetic `oat-crunch-nutrition-label.png` fixture, not a mocked result:

- `candidate-photo-result.mp4` and its contact sheets show OCR resolving to a 190 kcal label result.
- The log records result height `70 -> 52 -> 268` after presentation, with the viewport moving to `y=346`, height 512.
- `candidate-retake.mp4` and sheets show the card/viewport smoothly returning to the hint layout after Retake.
- `candidate-dashboard-geometry.log` retains those measurements.

The clean final videos show the result hint arriving after the zoom, with its existing offset/blur staging intact.

## Validation

- `make quality-format-check`: passed, `quality-format-check.log`.
- `make quality-build`: passed, `quality-build.log`. This is build evidence, not test evidence.
- Final uninstrumented simulator build: passed, `final-clean-build.log`.
- `FoodCameraFlowTests`: **25 passed, 0 failed, 0 skipped** on iPad Air 11-inch `E91B597B-CE57-4C0B-A8A4-51CBDC3386AB`, iOS 27.0. `test-summary.json` is extracted from the result bundle; `FoodCameraFlowTests.log` retains the test output. Serial execution and 30/45-second per-test allowances were used.
- `ps -axo pid,etime,command | grep xcodebuild` was checked immediately before testing. No actual xcodebuild process targeted the iPad. `ipad-availability.txt` records the result; raw preflight output remains local to avoid publishing unrelated jobs.
- `git diff --check`: passed for the implementation. Self-review found no duplicate state, dead diagnostics, or additional production changes. The evidence-wide whitespace check flags spaces naturally present in raw Xcode output and patch context; those artifacts were preserved verbatim. Authored evidence documents/scripts are checked separately.

The local `.xcresult` remains in `build/camera-zoom-source-2/FoodCameraFlowTests.xcresult`; the docs commit contains its compact summary and test log instead.

## Capture details and limits

- Visual capture: iPhone 17 `918D29B9-97D3-42C0-9C47-00605E01E8DB`, iOS 27.0, 402×874 points. No simulator was erased.
- `simctl recordVideo` exposes no fixed-FPS option on this installation. Original variable-rate recordings are preserved unchanged. Explicit `final-*-30fps.mp4` files provide the 30 fps fallback; the native-frame sheets additionally preserve every original decoded frame. Do not interpret the container's `r_frame_rate=600/1` metadata as a 600 Hz display.
- `capture.py`, `sheets.py`, `compare.py`, and `log-summary.py` preserve repeatable capture/extraction steps. Pillow was installed only in the ignored evidence build directory's virtual environment.
- XcodeBuildMCP's exposed input schemas require shared simulator defaults, and changing those defaults was prohibited. Device-specific AXe commands used an explicit allowed UDID instead; no XcodeBuildMCP configuration/profile tool was called.
- **Reduce Motion visual verification is incomplete.** Settings taps/swipes did not produce a verified enabled state; the switch and `ReduceMotionEnabled` still read 0. No attempted “reduce-motion” recordings are presented as enabled evidence. The existing `!reduceMotion` layout gate and fade/staging branches are preserved by source inspection only.
- Real camera hardware, a denied-camera-permission presentation, and an interactively cancelled dismiss gesture were not tested. Normal close transitions were captured. Simulator preview reports Camera unavailable, although its still-camera fallback UI can open.
- The iPhone was booted for this work and shut down afterward. The iPad was already booted by another job when the boot attempt ran, so it was left booted for its owner. Reserved simulators were not operated.
- No merge, version bump, or upload was performed.

## Evidence publication

This folder is copied to `docs/evidence/camera-zoom-source-2/` on `docs/asc-review-screenshots`. Only that folder is staged for the evidence commit. Each published file is smaller than 5 MB. The implementation worktree's full ignored build directory also retains intermediate captures that were not selected for publication.
