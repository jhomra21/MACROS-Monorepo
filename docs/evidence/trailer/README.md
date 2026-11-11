# Launch trailer render evidence

Plan: `docs/plans/active/launch-trailer.md`. Project: `tools/media/trailer/`.
Renders, sources, the Apple bezel and the badge stay in ignored folders.

Toolchain: Bun, Remotion 4.0.543, ffmpeg, macOS. Renders are in
`build/marketing/trailer/`: `coming-soon.mp4`, `app-store.mp4`, `review.mp4`
(safe-zone outlines) and `cover.png`.

## Sources per shot

| Time | Source (interval) | Notes |
| --- | --- | --- |
| 0–2 s | `raw.mp4` 0–2 s | Today ring close-up, no bezel |
| 2–8 s | `a1-log.mov` 7–13 s | Search for banana, in bezel |
| 8–14 s | `scan-review.png` (still, held 6 s) | Real nutrition-label scan review screen, in bezel |
| 14–17 s | `a1-log.mov` 18–21 s | Today ring close-up after logging |
| 17–21 s | `b2-insights.mov` 2–6 s | Insights, in bezel |
| 21–25 s | `widgets-only.mp4` | `raw.mp4` 53–57 s cropped to the single MACROS widget |
| 25–27 s | none | Type cards, 0.5 s each |
| 27–30 s | none | App icon, MACROS, end copy or badge, `macrosios.com` |

`scan-review.png` is `docs/evidence/web-scan-retake/after-app-scan-review.png`
from the `dashboard-tutorial-evidence` worktree, a native 1320 × 2868 capture.

## Apple assets

- Bezel: `Bezel-iPhone-18.dmg`, `PNG/iPhone 18 Pro Max/iPhone 18 Pro Max - Black - Portrait.png`. The file is 1470 × 3000.
- Measured screen opening (alpha scan, largest transparent region from the centre): x 75, y 66, 1320 × 2868. This matches the recordings exactly. The corner radius is about 220 px at this size.
- The bezel is drawn at 0.36 scale, centred, over the recording. It has no tint, crop, shadow, tilt, or motion.
- Badge: official `download-on-the-app-store.svg` from developer.apple.com, black, 240 px wide, static.
- The DMG license prompt was accepted non-interactively as the owner asked.

## Checks run

- ffprobe on all three MP4s: h264, yuv420p, 1080 × 1920, 900 frames, 30.000 s, stereo AAC.
- Contact sheets at 2 fps (coming-soon) and 1 fps (review) viewed.
- Every frame of `widgets-only.mp4` sampled at 2 fps: only the MACROS widget and wallpaper, no other icon or label.
- `bunx tsc --noEmit` and `git diff --check`.

## Images

- `contact-coming-soon-2fps.jpg`: 10 × 6, 180 px per frame.
- `contact-review-safe-zones-1fps.jpg`: 10 × 3 with safe-zone outlines.
- `device-5s-closeup-15s.jpg`: device shot at 5.0 s and close-up at 15.0 s.
- `end-cards-29s.jpg`: both end cards at 29.0 s.

## Not verified

- No clip shows a barcode scan through to Logged. None exists in the sources. The Scan shot holds a real label-scan review screen, so it is a still, not motion.
- The ring does not visibly fill in any take.
- The hook ring and the 14–17 s ring show different totals (1310 and 1790 kcal). Both are real recordings.
- Headlines longer than 14 characters use 84 px instead of 128 px so they fit on one line.
- The `macrosios.com` line fades in at about 29.0 s and is faint in the 29.0 s frame.
- The bezel rules and badge placement were checked by eye, not by Apple.
- The 21–25 s widget shot shows the widget tight on its wallpaper, not on a device.
- No audio track beyond silence. The owner adds music.
