# 09. Camera busy cancellation

**Verdict: BLOCKED (live).** No app change or temporary hook.

## Trigger order and expected user impact

1. Open the camera flow and begin capture, lookup, OCR, or save so the reducer is in a busy phase.
2. Navigate away (not ordinary scene inactivity), which sends `navigationAway`.
3. Return to the same camera-flow instance.

If that instance is reused without a completion event, it can remain in its busy phase and the user may see a stuck scanner/progress state.

## Evidence and live attempt

- `cal-macro-tracker/Features/Scan/Camera/FoodCameraFlow.swift:196–202` handles navigation-away by stopping scanning and canceling work without resetting `phase`/`isSaving`; only `.dismissed` sets a terminal phase.
- A clean app was launched and `calmacrotracker://add-food/scan-barcode` was attempted with `simctl openurl`; screenshot: `openurl-attempt.png`. The link remained behind first-run onboarding; no camera work or navigation occurred.
- This needs touch navigation and a controllable capture/lookup delay to hit the window. No delay hooks were added.
