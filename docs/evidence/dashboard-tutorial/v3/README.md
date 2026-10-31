# Dashboard tutorial v3 simulator evidence

Captured on iPhone 17 (iOS 27.0), using the Debug build from commit `8938fd4`.

- `v3-step1.png`: step 1, sharing-circle prompt on Today.
- `v3-step2.png`: step 2, yesterday prompt before its gesture was completed.
- `v3-back-to-today.png`: step 2's Today return prompt, with yesterday's three logged sample entries visible.
- `v3-step3.png`: step 3, ring expansion prompt.
- `v3-step4.png`: step 4, Protein prompt and macro legend.
- `v3-done.png`: completed tutorial.
- `v3-3xl-step1.png`: step 1 at the largest accessibility text size; the caption is scrollable but its content is visibly cut off.
- `v3-touch-blocking-failed.png`: the attempted streak-row blocking check; it shows Sharing opened, not a blocked tap.
- `v3-a11y-step1.txt`: captured step-1 accessibility snapshot.

Verification gaps:

- The accessibility snapshot contains dashboard collection rows, “No food logged yet”, Camera, and Add Food. The expected tutorial-only accessibility tree was not achieved.
- Tapping the streak row during step 1 opened Sharing, so touch blocking did not pass.
- The Full walk reached Sharing, yesterday, Today, ring expansion, Protein, Carbs, Fat, and Done. Captures for all requested intermediate states are not present.
- The 3XL step-4 placement and caption-scroll checks were not run. Step 1 at 3XL was captured, and its caption visibly overflows the allotted viewport region.
- Camera-card photo picker stalled at “Loading…” on iPhone 17; no camera-card screenshots were captured.

The bounded non-StoreKit suite passed on the iPad Air (198 tests, 0 failures) on retry. The camera branch remained at `d1dc54e` and built successfully; no camera code was changed.
