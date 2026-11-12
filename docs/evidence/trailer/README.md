# Launch trailer v4 render evidence

Plan: `docs/plans/active/launch-trailer.md`. Project: `tools/media/trailer/`. Renders, raw takes, the Apple bezel and the badge stay in ignored folders.

v4 applies the owner's review to v3: Track it shows the act of opening Insights, Rings fills with real entries one after another, Scan loses its frozen hold, and the length is now 29.0 s. Everything else is unchanged: one bold style, Apple's iPhone 18 Pro Max bezel at one fixed size and position, no crops or push-ins.

Toolchain: Bun 1.4.2, Remotion 4.0.543, ffmpeg, macOS. Renders are in `build/marketing/trailer/`: `coming-soon.mp4`, `app-store.mp4`, `review.mp4` (safe-zone outlines), `cover.png`, from `bun run render all`.

## Simulator steps

Media simulator `D16C3D35-889F-404F-BDD4-C640A6DBC4EF` only, under `/tmp/macros-sim-locks/D16C3D35-889F-404F-BDD4-C640A6DBC4EF` (taken by `mkdir`, released by `rmdir`). The earlier Debug build of `origin/main` (`/tmp/macros-trailer-build`) was already installed and was reused. 9:41 status bar override (full cellular, Wi-Fi, charged battery). Taps and swipes came from the `axe` binary bundled with XcodeBuildMCP, run with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` because the MCP's own Xcode path lacked SimulatorKit. Recording: `simctl io recordVideo --codec h264 --force`, stopped with SIGINT. At the end the override was cleared, the simulator shut down and the lock removed. No other simulator was used and nothing was erased or reset. The Home Screen was not touched.

Raw takes (`build/marketing/trailer/sources/v4/`, 1320 x 2868 native):

- `rings-take1.mov` (25.4 s): Today first trimmed by swipe-deleting four of the five demo entries (350 kcal left, Oatmeal with banana). Then four times: Add Food, tap a recent food chip, Log Food.
- `insights-take1.mov` (9.6 s): Today at 1310 kcal, tap the Insights button, rest on the top of Insights. Debug Pro was granted first (Settings > Developer), after reloading demo data. Demo data was reloaded again after the rings take, so Today read 1310 kcal.

## Sources per shot

| Time | Shot | Source and in/out | Rate |
| --- | --- | --- | --- |
| 0-2 s | Hook | `v3/flow-take1.mov` 2.0-4.0 s | 1.0x |
| 2-6 s | Search | `v3/flow-take1.mov` 4.4-5.3, 6.3-7.6, 11.8-12.6, 13.0-13.9 s (+0.1 s hold) | 1.0x |
| 6-10 s | Scan | `web/public/media/macros-demo.d72c87d2.mp4` 6.3-10.2 s (+0.1 s hold of the last frame), same crop and status bar strip as v3 | 1.0x |
| 10-15 s | Rings | `v4/rings-take1.mov` 2.4-3.0, 6.43-7.53, 12.23-13.33, 18.13-19.23, 24.13-25.23 s | 1.0x |
| 15-19 s | Track | `v4/insights-take1.mov` 4.2-8.2 s: Today, tap, push, rest on the top of Insights | 1.0x |
| 19-24 s | Glance | `v3/flow-take1.mov` 17.6-22.6 s | 1.0x |
| 24-29 s | Type, end card | none | |

## What was cut

- Scan: the 2.1 s frozen hold is gone. The footage (3.9 s) now ends the shot at 4.0 s, the nearest 0.5 s grid point (0.1 s hold).
- Rings: all sheets, the Add Food and Log Food screens and idle time. Each Today moment starts as the Log Food sheet leaves and lasts 1.1 s, long enough for the ring animation to finish. The first 0.6 s is Today at 350 kcal.
- Track: no scrolling. The "Nutrients / No Fiber Data" section never appears; the shot ends on the top of Insights.
- The total went from 30.0 s to 29.0 s. Later shots moved 1 s earlier to fit the 0.5 s grid.

## Rings kcal steps

Counter above the phone follows the real value on Today: 350 (start) then 740 (Turkey sandwich, +390), 1340 (Chicken and rice bowl, +600), 1620 (Pasta with tomato sauce, +280), 2080 (Salmon fillet, +460). Macro totals on Today: protein 38, 86, 95, 145 g; carbs 104, 174, 226, 226 g; fat 19, 33, 37, 65 g. Food list grows from 2 to 5 items. Each step counts over 0.45 s. No invented numbers; Salmon fillet has no carbs value in the app, so carbs stays at 226.

Other counters are as in v3: Hook 0 to 1310, Search 0 to 105, Scan 0 to 200, Track 0 to 125.7 g protein (30-day average, from the Insights screen).

## Contrast (`bun run contrast`)

Near-black `#0A0A0C` on protein `#007AFF` 4.92:1, carbs `#FF9F0A` 9.62:1, fat `#EF4F87` 5.78:1. Unchanged; all at least 4.5:1.

## Checks run

All three MP4s: h264, yuv420p, 1080 x 1920, 30 fps, 870 frames (counted), 29.000 s (frames / 30), stereo AAC 48 kHz. The `render.ts` remux now takes its length from `TOTAL_FRAMES` in `src/shots.ts`, so any whole-frame duration gives an exact frame count. `bunx tsc --noEmit` and `git diff --check` pass. Clips (`prepare:sources`): hook 60, search 120, scan 120, rings 150, insights 120, home 150 frames. Text stays inside x 120-960, y 380-1440 as in v3 (layout unchanged).

## Images (5, about 0.85 MiB)

- `contact-2fps.jpg`: 10 x 6 at 180 px.
- `review-1fps.jpg`: 10 x 3 with safe-zone outlines.
- `rings-steps.jpg`: Rings shot at 11.5, 12.6, 13.7 and 14.8 s: 740, 1340, 1620, 2080 kcal.
- `insights-17.5s.jpg`: Insights shot, top of the screen.
- `end-cards-28.5s.jpg`: coming-soon and app-store at 28.5 s, with the rings mark on a white tile (replaces the app icon).

## Not verified

- No audio beyond silence; the owner adds music.
- The bezel rules and badge placement were checked by eye, not by Apple.
- The Scan footage's own card cross-fade (ghosted text) is original and not edited.
