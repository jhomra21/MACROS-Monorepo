# Camera result card layout shift

Media removed in the repo cleanup; retrieve with `git show 074b10994f1b68d9d7a8d6c54ed7effb90d5f1f5:docs/evidence/camera-card-layout-shift/red-label-contact-sheet.jpg`.

## Confirmed cause

The camera reused `FoodNutritionRow` beside a 44 pt ring. Its title and nutrition
column competed for horizontal space. Fractional macro strings changed that
allocation and wrapped differently. The label name was also a single-line text
field, so it could become unreadably clipped. The serving description changed
from a short singular description to an `each · … g total` string.

On the 390 pt iPhone 17e the barcode title already occupies two lines at all
sampled amounts, so that particular red card is consistently tall. This does
**not** mean a narrower phone always reproduces the barcode shift more strongly:
at 402 and 440 pt the original barcode panel varies by 22 pt. The label card
varies by 16 pt on the actual 390 pt phone. Accessibility render heights vary by
as much as 128 pt before the fix.

## Fix

Only `FoodCameraResultPanel.swift` changes shipping behavior:

- Name/brand have their own stable-width row beside the ring. Nutrition values
  no longer take width away from the name.
- Calories and the three macro values use an intrinsic-size horizontal layout,
  or separate vertical lines at accessibility text sizes. No number truncation,
  scaling, cached measurements, fixed card heights, or new tint is introduced.
- The editable label name supports up to two lines, as does the barcode title.
- Per-serving text stays constant. Total grams always have their own line,
  including at one serving. The serving stepper moves below its label at
  accessibility sizes so growing digits cannot compress the controls.
- The shared `FoodNutritionRow` is unchanged.

## Evidence

- [Heights table](heights.md): actual sheet geometry plus all 960 per-phase
  render measurements, every 0.25 step from 0.25 through 20, both result kinds,
  widths 390/402/440, Large and accessibility3 text.
- Red label contact sheet and
  green label contact sheet.
- Red barcode contact sheet and
  green barcode contact sheet.
- `red/` and `green/`: original full-screen PNGs, accessibility node/frame JSON,
  and `sheet-heights.json`. On the iPhone 17e the safe area is 47 pt; the table
  excludes it from card height. The button y is its top screen coordinate.
- `green-accessibility/`: actual camera sheet at Accessibility Extra Large.
  The visible card is capped by the existing 45%-of-viewport rule, at
  **343.333 pt** for both result kinds; the button stays at **422.333 pt**.
  The bottom capture confirms the serving controls/actions remain scrollable.
  Uncapped content height is separately checked in the render CSVs.
- `comparison-*.jpg`: real Add Food and dashboard before/after screenshots,
  with a long synthetic food name, at Large and Accessibility Extra Large.
- `red/rendered/` and `green/rendered/`: four isolated shared-row images
  (with/without dashboard-style subtitle, normal/`isStacked` accessibility path)
  are **pixel-identical**. Each directory also contains its complete
  `heights.csv`. Actual Add Food/dashboard callers do not currently opt into the
  shared row's `isStacked` path; their pre-existing cramped accessibility layout
  is unchanged, not silently presented as fixed here.
- Original photo import: the real PhotosPicker →
  Vision OCR → label result path, including the original clipped editable name.
- `photo-import-green-*.png` and `photo-import-green-heights.json`: final,
  uninstrumented PhotosPicker → OCR result. Actually pressing the stepper from
  1 through 2 in quarter steps keeps its visible card at **316 pt** and Retake at
  **395 pt**. Its extra OCR warning explains the larger height than the fixture.

All food data is synthetic. Every evidence file is smaller than 5 MB.

## Reproduce

Use an exclusively locked iPhone 17e simulator. Do not use an owner's fixture.
The simulator cannot capture camera frames. The real import path is:

1. Build/install the Debug app and launch it.
2. Add `docs/app-store/fixtures/oat-crunch-nutrition-label.png` with
   `xcrun simctl addmedia <udid> <absolute-png-path>`.
3. Dashboard → Camera → More camera options → Choose a Photo → imported label.
4. Enter a food name and use the servings stepper.

There was no existing barcode debug launch fixture. Barcode and deterministic
same-food label sheet captures therefore use the **temporary, opt-in**
[`fixture.patch`](fixture.patch). It sets only local camera presentation/flow
state, skips camera/network lookup, and does not seed or modify stored data.
It is evidence tooling, **not applied to the committed app source**. It does not
validate barcode recognition or remote lookup.

To repeat deterministic captures:

1. `git apply docs/evidence/camera-card-layout-shift/fixture.patch`
2. Build/install Debug on the locked simulator.
3. Open that device using T3's device tools and use its returned bound
   `agent-device` executable as `<driver>`.
4. From the repository root:
   `python3 docs/evidence/camera-card-layout-shift/capture-fixtures.py <driver> green`
5. For accessibility, set the device to `accessibility-extra-large`, run the
   script with `green-accessibility barcode,label 1,1.25,20`, then restore Large.
6. `git apply -R docs/evidence/camera-card-layout-shift/fixture.patch`
7. Rebuild/reinstall the uninstrumented app.

The sheet captures relaunch at each amount, while the integration assertion
checks all 80 quarter-serving values directly against the real SwiftUI panel.
For caller captures, log one synthetic long-name food and run
`capture-callers.py <driver> <red-or-green>`. Remove that food/log afterward.
`contact-sheets.py` uses Pillow to regenerate the camera contact sheets.

## Validation

- Red, before implementation: the prewritten height assertion failed in
  11 of 12 layout configurations.
- Final targeted test: `testServingChangesKeepBarcodeAndLabelCardHeight` passed,
  including 960 height measurements.
- `make quality-format-check`: passed.
- `make quality-build`: passed.
- Full serial iPad suite on the iPad test runner, excluding
  `PurchaseStoreStoreKitTests`: **229 tests passed, 0 failures**.

The initial screenshot driver timed out during exploratory captures; those runs
are not claimed as complete. Two red render runs finished their test assertions
but hung in Xcode teardown and were stopped after the artifacts were saved.
The final targeted run exited successfully.

## Simulator cleanup

The temporary launch fixture was removed and the clean app reinstalled. Large
text size was restored. The synthetic logged entry and saved custom food were
deleted through the app; the added photo was removed from Photos (the original
six-photo library remains). It is retained only in iOS Recently Deleted.

Opening Photos for cleanup required dismissing its first-run introduction and
declining its notification prompt. Resetting that permission was attempted, but
this runtime reports `UNSUPPORTED_OPERATION` for notification resets, so Photos
notifications remain declined. No owner's simulator or sharing state was used.
