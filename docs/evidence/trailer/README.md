# Launch trailer v2 render evidence

Plan: `docs/plans/active/launch-trailer.md`. Project: `tools/media/trailer/`. Renders, raw takes, the Apple bezel and the badge stay in ignored folders.

Toolchain: Bun 1.4.2, Remotion 4.0.543 (all dependencies pinned), ffmpeg, macOS. Renders are in `build/marketing/trailer/`: `restrained-coming-soon.mp4`, `restrained-app-store.mp4`, `bold-coming-soon.mp4`, `bold-app-store.mp4`, `review-restrained.mp4`, `review-bold.mp4` (safe-zone outlines), `cover-restrained.png`, `cover-bold.png`. All come from `bun run render all`.

## Simulator steps

Media simulator `D16C3D35-889F-404F-BDD4-C640A6DBC4EF` only, under its `/tmp/macros-sim-locks/` lock (free on arrival, released after). Built current `origin/main` Debug for it (`PACKAGED_FOOD_SEARCH_BASE_URL` override only, derived data `/tmp/macros-trailer-build`), installed, Settings > Developer > Load Demo Data (Today 1310 kcal, P 95, C 162, F 34), Grant Debug Pro for the Insights charts, 9:41 status bar override (full cellular, Wi-Fi, charged battery). Recorded with `xcrun simctl io <udid> recordVideo --codec h264 --force`, stopped with SIGINT. Takes drove the app with `agent-device` (search "banana", Banana, Log Food). Demo data was reloaded before each take. At the end the override was cleared, the simulator shut down and the lock removed. No other simulator was used.

Raw takes (`build/marketing/trailer/sources/v2/`, 1320 × 2868): `ring-take1`–`5.mov` (11.6–11.9 s each), `insights.mov` (6.9 s), `home-widgets.mov` (single frame, kept as `home-widgets.png`).

## Sources per shot (same in both styles)

| Time | Source and in/out | Cut |
| --- | --- | --- |
| 0–2 s | `ring-take5.mov` 10.3–11.6 s, last frame held 1.5 s, close-up of Today, 1.0× | Dismissal of the Log sheet, rings roll 1310 to 1415 |
| 2–8 s | `ring-take4.mov` 3.2–4.1, 4.6–7.6, 8.2–9.2, 9.7–10.97 s, in bezel, 0.97× | Idle Today before the tap, idle sheet and results, idle form |
| 8–13 s | `macros-demo.d72c87d2.mp4` 6.3–10.6 s, no bezel, 0.86× | Crop x 112, y 222, 496 × 1028 of 720 × 1280, below status bar and "Scan it." pill. Fitted by height: 1.05× in restrained, 0.75× in bold, so never above the 1.5× limit |
| 13–17 s | `ring-take4.mov` 10.3–11.9 s, last frame held 3 s, close-up, 1.0× | Same cut as hook but from the other take |
| 17–21 s | `insights.mov` 1.5–6.8 s, in bezel, 1.2× | Opening idle second |
| 21–25 s | `home-widgets.png` held 5 s, crop of the large MACROS widget | Third-party icons and the small widget are outside the crop |
| 25–30 s | none | Type recap, end card |

Nothing is played faster than 1.2×. Dead time was cut, not sped up.

## Dead time cut

Measured with ffmpeg `freezedetect` on take 4: idle 0–3.0 s (Today before the first tap), 3.5–4.7 s, 5.7–8.2 s (waiting for search results and the form), 8.6–10.2 s. Of 11.9 s recorded, about 3.5 s of idle was removed and the rest kept at real time. The tail after Log is held on the last frame for the Rings shot instead of being sped up.

## Contrast (`bun run contrast`)

| Text | Background | Ratio |
| --- | --- | --- |
| bold `#0A0A0C` | `#007AFF` | 4.92:1 |
| bold `#0A0A0C` | `#FF9F0A` | 9.62:1 |
| bold `#0A0A0C` | `#EF4F87` | 5.78:1 |
| (not used) white | `#007AFF` / `#FF9F0A` / `#EF4F87` | 4.02 / 2.06 / 3.42:1 |
| restrained white | brightest wash centre protein / carbs / fat | 9.86 / 6.36 / 8.95:1 |
| restrained support `#E5E5EA` | same centres | 7.85 / 5.07 / 7.13:1 |

Bold uses near-black text everywhere because white on `#007AFF` is 4.02:1, below 4.5:1 (even at 180 px).

## Counters (bold)

Values match the recordings: 1310 to 1415 kcal and 162 to 189 g carbs (Today before and after logging a banana, 105 kcal), 0 to 105 kcal (Banana's row in the search results), 0 to 200 kcal (the Chocolate Dough Protein Bar result card), 125.7 g protein avg (Insights, 30 days).

## Checks run

- ffprobe on all six MP4s: h264, yuv420p, 1080 × 1920, 900 frames (counted), 30.000 s, stereo AAC.
- `bunx tsc --noEmit` and `git diff --check`.
- Contact sheets and frames viewed. Bezel is unscaled per frame; bold push-in applies only to bezel-free close-ups; text sits inside x 120–960 and y 380–1440 in the review renders.
- Home Screen: raw frame viewed. It contains third-party icons (Fitness, Reminders, Safari, Messages and more), so only the widget crop is used.

## Images

- `contact-restrained-2fps.jpg`, `contact-bold-2fps.jpg`: 10 × 6 at 180 px.
- `contact-bold-review-1fps.jpg`: 10 × 3 with safe-zone outlines.
- `frames-5s-5s-15s.jpg`: restrained 5.0 s, bold 5.0 s, bold 15.0 s.
- `end-cards-29s.jpg`: restrained and bold, coming-soon and app-store, at 29.0 s.

## Not verified

- I could not arrange the media simulator's Home Screen to show only MACROS widgets without moving its other icons, so the shot is a tight widget crop of the large widget, not the whole page.
- The Scan close-up comes from a 720 × 1280 source, so it is softer than the 1320 px footage (upscaled 1.05× in restrained, downscaled in bold).
- The Scan result in the old cut shows 200 kcal for the protein bar; I did not re-record a scan.
- The hook and Rings shots show the same event from two takes.
- The bezel rules and badge placement were checked by eye, not by Apple.
- No audio beyond silence. The owner adds music.
