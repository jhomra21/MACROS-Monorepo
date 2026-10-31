# Dashboard tutorial follow-up

Evidence captured on iPhone Air (iOS 27.0), using the accessibility-extra-extra-extra-large text setting where marked.

- `step1-large-text.png`: tutorial action controls remain reachable at large text.
- `wrong-direction-stays-today.png`: a right swipe on step one leaves the tutorial on Today.
- `step2-previous-day.png` and `step2b-back-to-today.png`: the guided action returns to the Dashboard and then moves to yesterday.
- `step3-ring-collapsed.png`: the next step starts with the macro ring collapsed.
- `step4-large-text-macros.png`: the macro tutorial step at large text.
- `step4-3xl-caption-limited.png` and `step4-3xl-caption-scroll-attempt.png`: at the largest accessibility text size, the Protein hand aligns with the stacked legend, but the caption remains clipped and the attempted scroll did not move it. This remains an open visual verification issue.
- `step1-accessibility-tree.txt`: the tutorial accessibility snapshot; Dashboard content is hidden while tutorial captions and actions remain exposed.

The latest Debug build succeeded and the serial non-StoreKit test suite passed (198 tests, 0 failures). The full step-one opposite-direction and Sharing gestures, the Back to Today flow, and the transition to the collapsed-ring step were exercised on the simulator. Raw build and test logs are retained in the local `build/dashboard-tutorial/` directory.
