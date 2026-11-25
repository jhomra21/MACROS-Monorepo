# MACROS scan UI capture

Captured from the Debug app built at `origin/main` commit `e856c6aa` on an
iPhone 17e simulator running iOS 27.0. The requested iPhone Air was locked by
another task, and the first fallback iPhone 17 was also locked, so this capture
uses the next available fallback. All images are full-device 1170 × 2532 PNGs,
light appearance, with the status bar set to 9:41. PNGs use an indexed palette
to keep the five-image set below the repository's 2 MiB evidence limit.

## Files

| File | What it shows |
| --- | --- |
| `screenshots/01-dashboard-before.png` | Seeded Today dashboard before this capture flow logs the label. 1,310 kcal; P95 / C162 / F34; four foods. |
| `screenshots/02-camera-scan.png` | Real camera/scan interface. The simulator has no camera feed; the screen shows the app's camera-unavailable fallback instead of a live preview. |
| `screenshots/03-label-review-oat-crunch.png` | Real editable review panel using the existing Oat Crunch nutrition-label fixture. The name was entered manually, as the OCR did not confidently detect it. One serving (1 cup / 40 g), 190 kcal, P5 / C36 / F3. This is a label scan, not a barcode result. |
| `screenshots/04-log-confirmation.png` | The app's `Logged` confirmation for Oat Crunch Cereal, one serving, 190 kcal. |
| `screenshots/05-dashboard-after.png` | Today dashboard after logging the label. 1,500 kcal; P100 / C198 / F37; five foods. |
| `scan-to-log.mov` | Short H.264 simulator recording of the review → Logged confirmation → updated dashboard sequence, 1170 × 2532, under 1 MB. |

## Barcode product fixture limitation

There is no existing QA hook to inject a barcode lookup response or a product
named “Peak Bar.” The closest existing synthetic fixture product is `Protein
bar`, visible in both dashboard captures: one bar (60 g), 210 kcal, P20 / C22 /
F7. Those are the requested nutrition values, but the app's scan-result screen
could not be populated with that product without adding a new hook, so no
barcode result is represented as if it were captured.

The reusable UI-test fixture seeded the synthetic day and fed the bundled
nutrition-label image to the real camera result flow. The temporary UI test was
removed after capture. No App Store Connect actions, uploads, or app-branch
commits were made.

## Owner bar scan recording

Raw screen recording of the owner scanning a Chocolate Dough Protein Bar
(Barebells, 55 g, 200 kcal) with MACROS. It is the source for the App Store
preview "Scan it." segment.

| Item | Value |
| --- | --- |
| Source | `/Users/juan/.t3/worktrees/cal-macro-tracker/launch-trailer/tools/media/trailer/public/sources/scan.mp4` (git-ignored in that worktree) |
| Duration | 4.0 s |
| Resolution | 496 × 1078, 30 fps, H.264 (smaller than the 1320 × 2868 device takes, but the only clip of this scan) |
| Size | 1.3 MB, not trimmed or re-encoded; SHA-256 matches the source |
| Files | `owner-bar-scan.mp4`, `owner-bar-scan-sheet.jpg` (1 fps contact sheet, frames at 0, 1, 2, 3 s) |

Timestamps in the source clip:

| Event | Time |
| --- | --- |
| Camera opens | 0.1 s (live viewfinder by 0.2 s) |
| Barcode detected (yellow corners appear) | 1.3 s (solid by 1.4 s) |
| Result card appears | 1.8 s (fully shown by 1.9 s) |
| Log tapped (button pressed state) | 2.8 s |
| Logged confirmation | 3.0 s |

Times come from 10 fps frame review, so they are accurate to about 0.1 s. The
Log time is taken from the button's pressed state; the clip has no touch
indicator.
