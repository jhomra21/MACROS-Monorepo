# Add Food Camera Zoom Source

## Root cause

The wide/compact mode-change hypothesis is ruled out. Temporary tap-time diagnostics showed `isScanActionBarCompact == false` for the expanded tap and `true` for the compact tap, with no mode flip during presentation. The expanded source’s global frame was `(20, 778, 362, 60)`; the compact source frame was `(322, 778, 60, 60)`.

The matched source was attached to an inner `GlassEffectContainer`, then the resulting view was clipped and sized afterward. The layout diagnostics showed the source frame equal to the visible button, so this was not a mode or coordinate race. The modifier order instead left the zoom source attached before the final clipped, explicitly sized view. In the pre-fix wide recording, frame 42 still shows the full capsule and frame 44 is the first camera reveal, with only a partial camera surface visible. The compact recording shows the existing circle-to-camera zoom from frame 35. Moving the source modifier after clipping and sizing keeps the full expanded capsule visible as the source while preserving compact bounds.

The temporary geometry and tap logging was removed before the final build and capture.

## Frame findings

All recordings are 30 fps, captured on iPhone 17 / iOS 27.0.

- **Before, expanded open:** `before-wide.mp4`, first reveal at frame 44. `before-wide-frame-01.png` is frame 42 (full capsule); `before-wide-frame-02.png` is frame 44; `before-wide-frame-03.png` is frame 46.
- **Before, compact open:** `before-compact-open-clean.mp4`, circle is visible through frame 30; camera reveal begins at frame 35. `before-compact-onset.png` shows the transition frames.
- **After, expanded open:** `after-wide-open-clean.mp4`, the partial camera reveal begins around frame 45 while the full-width capsule remains visible at the bottom. By frame 55 the camera interface has expanded to nearly the full viewport. `after-wide-clean-frame-45.png`, `after-wide-clean-frame-50.png`, and `after-wide-clean-frame-55.png` are extracted from this clean capture.
- **After, compact open:** `after-compact-open-clean.mp4`, the circle remains the source; the camera reveal begins around frame 35. `after-compact-onset.png` shows the unchanged compact transition.
- **After, close paths:** `after-wide-close-clean.mp4` and `after-compact-close-clean.mp4` return to their respective source buttons. The dismiss direction and compact behavior were not changed.
- **Dashboard regression:** `dashboard-camera-clean.mp4` and `dashboard-addfood-clean.mp4` confirm the dashboard Camera and Add Food buttons still present from their own sources.

## Validation

- `make quality-format-check`: passed.
- `make quality-build`: passed.
- `FoodCameraFlowTests`: 25/25 passed on iPad Air 11-inch simulator `E91B597B-CE57-4C0B-A8A4-51CBDC3386AB`, with serial execution and the repository’s per-test time limits.
- No Add Food-specific test class exists in `cal-macro-trackerTests`.
- Visual open/close checks and dashboard regressions were captured on iPhone 17 simulator `918D29B9-97D3-42C0-9C47-00605E01E8DB`. The simulator reports “Camera unavailable”; camera hardware behavior was not tested.

## Artifacts

Videos: `before-wide.mp4`, `before-compact-open-clean.mp4`, `after-wide-open-clean.mp4`, `after-wide-close-clean.mp4`, `after-compact-open-clean.mp4`, `after-compact-close-clean.mp4`, `dashboard-camera-clean.mp4`, and `dashboard-addfood-clean.mp4`.

Frames/contact sheets: `before-wide-frame-01.png`, `before-wide-frame-02.png`, `before-wide-frame-03.png`, `before-wide-onset-contact.png`, `before-compact-onset.png`, `after-wide-clean-frame-45.png`, `after-wide-clean-frame-50.png`, `after-wide-clean-frame-55.png`, `after-wide-source-frame.png`, `after-compact-source-frame.png`, `after-wide-onset.png`, `after-compact-onset.png`, `after-wide-close-full-sheet.png`, and `after-compact-close-full-sheet.png`. `geometry-diagnostics.txt` preserves the temporary measurements used to rule out a mode change; its logging code was removed.
