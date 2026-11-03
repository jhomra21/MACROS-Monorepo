# 09. Camera busy cancellation

**Verdict: NOT REPRODUCIBLE as a stuck, reused busy camera instance through the attempted live paths.**

## Repeatable event order and live attempts

The suspect requires busy work → navigation-away cancellation → return to the **same** flow instance, without any phase-resetting event.

1. On iPhone 17 A, open `calmacrotracker://add-food/scan-barcode`. Exercise the still-camera fallback, dismiss its native picker, open More camera options > Choose a Photo, and cancel the library picker. Controls remained usable. A “Reading label…” panel after still-picker cancellation was not sufficient evidence of a busy reducer.
2. On the isolated iPad, add the repository's synthetic `docs/app-store/fixtures/oat-crunch-nutrition-label.png` to Photos using `simctl addmedia`.
3. Set `suspect-camera-delay` to `45`. Open the camera route, expand More camera options, choose that image in the real Photos picker, and begin the existing image-processing path.
4. During the delay, try Back and Home/return. Expand camera options: **Choose a Photo** and the shutter are disabled while busy.
5. Tap **Close camera** before the delay ends. Reopen the camera route. Inspect reducer state and controls, rather than relying on panel wording.

## Observed result and artifacts

[Trace](live-repro.log):

```text
1793705000.584755  camera after phase=readingLabel inactive=false
1793705000.622488  pause camera-delay begin
1793705028.499021  camera after phase=readingLabel inactive=true
1793705029.097193  pause camera-delay end cancelled=true
1793705032.1812901 camera after phase=scanning inactive=false
```

The actual image path entered a busy `readingLabel` phase. Closing canceled work; reopening produced a new scanning flow with usable controls. [Busy UI](busy-ui.log), [disabled library option](busy-options-ui.log), [reopened UI](reopened-ui.log), [reopened screenshot](reopened-camera.png). [Earlier picker-return screenshot](returned-camera.png) is supplementary, not busy-state proof.

## Source and why this does not confirm the suspect

Baseline `cal-macro-tracker/Features/Scan/Camera/FoodCameraFlow.swift:190–202` correctly distinguishes scene inactivity (no work cancellation) from navigation away (cancel work, retain phase). `FoodCameraSheet.swift:169–172` sends scene-active on appearance and navigation-away on disappearance; `565–568` derives busy state.

The retained-phase concern remains plausible only if a supported busy presentation can disappear and return as the same instance. Live Back did not create that path. Busy disables capture/library actions; result/recovery navigation is exposed after processing settles. Ordinary Close/reopen discards that instance, as the trace demonstrates. No fix is proposed from these attempts.

## Exact temporary hook and cleanup

DEBUG before/after reducer logs recorded phase and inactivity. At the beginning of `FoodCameraSheet+Actions.processPendingImage`, immediately after the existing `pendingImage` guard, the hook awaited `SuspectProbe.pause("camera-delay")`. It did not force a reducer phase or cancellation. [Full patch](../temporary-hooks.patch.txt).

The synthetic photo was deleted from the library, leaving its original six sample photos ([cleanup](fixture-photo-deleted.log)); normal Photos deletion retains it in Recently Deleted for 30 days. Hooks were removed and original apps restored. A simulator live-camera limitation did not prevent this real photo-processing attempt; no physical-camera/save-path cancellation test is claimed.
