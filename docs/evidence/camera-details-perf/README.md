# Camera Details lag: failure modes and evidence

Owner report (real iPhone): open the camera (scan or photo), get a result card, tap Details so it expands into the inline editor, tap a macro field. The keyboard appears late and typing and scrolling stutter.

Branch `app/camera-details-perf`, base `origin/main` 5a4c0a9. Raw traces live in ignored `build/evidence/2026-11-10-camera-details-perf/`.

## Failure modes, written before measuring

Each entry names what the code suggests and what evidence would confirm or reject it.

| ID | Hypothesis | Confirm if | Reject if |
|---|---|---|---|
| a | The AVCaptureSession / DataScanner (live Vision barcode processing) keeps running behind the expanded editor | Details does not stop the scanner, or the preview stays mounted | `openDetails` stops scanning and unmounts `FoodCameraPreview` |
| b | `detailsEditor: FoodLogEditorState?` is `@State` on the 937-line `FoodCameraSheet`, so every keystroke re-evaluates the whole sheet body (viewport, glass controls, result panel, geometry readers) and the editor's `Form` | Body-evaluation counts for the sheet grow by 1+ per keystroke | Sheet body count stays flat while typing |
| b2 | Per-body derived work is expensive: `previewDraft` / `previewLoggingAction` / `isDirty` / `canSave` / `displayedResult` recompute many times, `AnyView` in `leadingSections`, `DataScannerViewController.isSupported/isAvailable` read several times per body | Time Profiler shows these under the keystroke stack | Negligible self time |
| c | `ScrollViewReader.scrollTo` / `scrollsToFocusedField` fires on every focus change or keystroke | `scrollTo` invoked per keystroke | Only called from keyboard-toolbar field navigation |
| d | Morph / zoom / `glassEffect` / `.animation(layoutAnimation...)` re-run during edits | Animations fire per keystroke (the animated values change while typing) | The animated values (`detailsExpanded`, `isKeyboardVisible`, `resultContentHeight`, `panelContent.kind`) change only on focus/keyboard, not per keystroke |
| e | `onChange(of: editor.servingsAmount)` → `onQuantityChange` → `send(.servingsChanged)` writes state back and causes extra update cycles | The callback fires per macro keystroke | It fires only when servings change |
| f | Main-thread work (image decoding, JSON, SwiftData fetch, `@Query goals`) triggered by edits | Time Profiler shows decode/fetch under keystrokes | Absent |

## Evidence


Measured on an iPad Air simulator (iOS 27, Debug build) with the photo-import path
(`CameraDetailsPerformanceUITests`, fixture label photo in the test bundle) and Time Profiler.
Body counts come from temporary os_signpost probes, since removed. Raw traces are not tracked.

| Hypothesis | Outcome |
| --- | --- |
| (a) capture/Vision behind editor | Rejected by code: `openDetails()` stops the scanner and unmounts the preview. Hardware check still needed. |
| (b) whole-sheet invalidation per keystroke | **Confirmed.** Each keystroke re-evaluated sheet, panel, editor, Form and all 10 nutrient rows. Cause: the `Binding` setter writes `detailsEditor` several times per key, including identical values, and `FoodLogEditorState` was not `Equatable`, so every write invalidated everything. |
| (c) ScrollViewReader | Rejected: `scrollTo` only runs from toolbar field navigation. |
| (d) morph/animation | Partly confirmed: keyboard show animates card height and re-lays out the Form (~25 Form evaluations, UITextField sizing). Removing the `isKeyboardVisible` animation cut focus main-thread time 878 to 532 ms but changes the visual, so it was not shipped. |
| (e) servings onChange | Rejected: not fired by macro typing. |
| (f) decode/JSON/SwiftData | Not seen in any typing stack. |

Per iteration (mean of 5), baseline then fix (`FoodLogEditorState: Equatable`):

| Metric | Before | After |
| --- | --- | --- |
| Form/editor body evals, typing 5 digits | 5.2 each (all 10 rows each: 52) | 0 |
| Nutrient row body evals, typing 5 digits | 52 | 0 |
| Main-thread busy, typing window | ~350 ms | ~100 ms excluding XCUI snapshot (257 ms total incl. harness vs 437) |
| Main-thread busy, focus window | 878 ms | 803 ms |
| Tap-to-keyboard latency (sim) | 1.70-1.75 s | 1.57-1.63 s |

Not fixed: the keyboard-show relayout remains the largest cost (focus window ~800 ms main thread).
`.equatable()` on the editor view and a no-animation transaction on the editor were tried and rejected
(no further gain, or slower).

The UI test is a measurement harness (clock, CPU metrics); it has no pass/fail threshold, because
simulator timings on a shared machine were too noisy to gate on.

## Device check (owner iPhone)
Keyboard latency, typing and scrolling feel; confirm the camera indicator turns off when Details opens.
