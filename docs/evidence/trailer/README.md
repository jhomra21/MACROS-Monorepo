# Launch trailer v3 render evidence

Plan: `docs/plans/active/launch-trailer.md`. Project: `tools/media/trailer/`. Renders, raw takes, the Apple bezel and the badge stay in ignored folders.

v3 keeps only the bold style. Every app shot is inside Apple's iPhone 18 Pro Max bezel at one fixed size and position. There are no bezel-free close-ups, no square widget crop and no push-ins. The restrained style and its renders were removed.

Toolchain: Bun 1.4.2, Remotion 4.0.543, ffmpeg, macOS. Renders are in `build/marketing/trailer/`: `coming-soon.mp4`, `app-store.mp4`, `review.mp4` (safe-zone outlines), `cover.png`, from `bun run render all`.

## Simulator steps

Media simulator `D16C3D35-889F-404F-BDD4-C640A6DBC4EF` only, under `/tmp/macros-sim-locks/D16C3D35-889F-404F-BDD4-C640A6DBC4EF` (taken by `mkdir`, released by `rmdir`). The v2 Debug build of `origin/main` (`/tmp/macros-trailer-build`) was installed. Settings > Developer > Load Demo Data (Today 1310 kcal), 9:41 status bar override (full cellular, Wi-Fi, charged battery), `simctl io recordVideo --codec h264`. Taps came from `agent-device`. The simulator was shut down once mid-session to clear a stuck recorder (`Host recording is already in progress`) and booted again; the lock was kept. At the end the override was cleared, the simulator shut down and the lock removed. No other simulator was used and nothing was erased.

Raw takes (`build/marketing/trailer/sources/v3/`, 1320 x 2868 native, 9:41 status bar): `flow-take1.mov` (23.3 s), `scan-take2.mov` (19.4 s), `insights.mov` (copied from the v2 take, 6.9 s). `scan-take1.mov` and `home-take1.mov` were rejected earlier takes (the Home Screen one still had other apps).

## Sources per shot

| Time | Shot | Source and in/out | Rate |
| --- | --- | --- | --- |
| 0-2 s | Hook | `flow-take1.mov` 2.0-4.0 s: Today at 1310 before any log | 1.0x |
| 2-6 s | Search | `flow-take1.mov` 4.4-5.3, 6.3-7.6, 11.8-12.6, 13.0-13.9 s (+0.1 s hold): Add Food, "banana" results, Log Food form | 1.0x |
| 6-12 s | Scan | `scan-take2.mov` 2.6-3.9, 5.6-6.3, 7.6-8.6, 10.9-11.4, 13.6-14.8, 17.8-19.0 s (+0.1 s hold): Camera, photo picker, barcode, Nutella result (539 kcal), Logged | 1.0x |
| 12-16 s | Rings | `flow-take1.mov` 14.0-17.5 s (+0.5 s hold): Log Food tapped, sheet dismisses, 1310 to 1415 | 1.0x |
| 16-20 s | Track | `insights.mov` 1.5-6.3 s | 1.2x |
| 20-25 s | Glance | `flow-take1.mov` 17.6-22.6 s: Home Screen right after logging, widgets show 1415 | 1.0x |
| 25-30 s | Type, end card | none | |

Each real moment appears once: the hook is Today before logging, Search ends before the Log tap, Rings starts at the dismissal. Idle time was cut; nothing is sped up except Insights at 1.2x.

## Scan footage chosen

I contact-sheeted the earlier candidates: `dashboard-tutorial-evidence/docs/evidence/camera-card` (1260 x 2736), `camera-zoom-source` and `camera-zoom-source-2` (1206 x 2622, same 0.46 aspect), `addfood-manual`, the App Store clips, and the 720 x 1280 website demo. The `camera-*` clips are UI tests of the card morph, `camera-zoom-source-2` clips are 2 s fragments, and the website demo has a burnt-in pill and is 720 px. None showed the whole barcode to result card to Logged path at native resolution with a 9:41 status bar. I recorded a new native 1320 x 2868 take (`scan-take2.mov`) instead. The simulator has no camera, so the camera preview is a grey placeholder; the barcode comes from the photo picker (an image of a barcode in the simulator's library), which is the app's own "choose photo" path. No UI was painted or faked.

## Home Screen changes (media simulator, undo list)

The Home Screen was cleaned so no third-party content shows. Only long-press > "Remove from Home Screen" was used, so the apps remain in the App Library and nothing was deleted or erased. Reminders and Preview were removed that way (both seen in the menus); I removed the other stock icons the same way, but I did not record the full list. To undo: open the App Library on the media simulator, long-press each app and choose "Add to Home Screen". The first page now has only the MACROS icon, the small MACROS widget and the large MACROS widget (both were already on the page, and show 1415 right after the logging take).

## Contrast (`bun run contrast`)

| Text | Background | Ratio |
| --- | --- | --- |
| `#0A0A0C` | protein `#007AFF` | 4.92:1 |
| `#0A0A0C` | carbs `#FF9F0A` | 9.62:1 |
| `#0A0A0C` | fat `#EF4F87` | 5.78:1 |

All at least 4.5:1. White on these colours would be 4.02, 2.06 and 3.42:1, so it is not used.

## Counters

Values match the recordings. Hook 0 to 1310 kcal (Today's ring). Search 0 to 105 kcal (Banana's Log Food form). Scan 0 to 539 kcal (Nutella result card). Rings 1310 to 1415 kcal. Track 0 to 125.7 g protein 30-day average (Insights). The Track counter starts at the cut (it reads 107.9 about 0.1 s in) and lands within 1 s. Counters stay hidden until counting begins, so none rests at 0.

## Checks run

- ffprobe on all three MP4s: h264, yuv420p, 1080 x 1920, 900 frames (counted), 30.000 s, stereo AAC.
- `bunx tsc --noEmit` and `git diff --check`.
- Contact sheet, review sheet and frames viewed. Headlines are at most two lines at 150 px. Text sits at x 120-960, y 380-860; the bezel runs lower to y 1910 and carries nothing that must be read.
- The bezel is a fixed 0.34 scale, same top, no animation, no overlap.

## Images

- `contact-2fps.jpg`: 10 x 6 at 180 px.
- `review-1fps.jpg`: 10 x 3 with safe-zone outlines.
- `frames-5-10.5-23s.jpg`: full-size frames at 5.0, 10.5 and 23.0 s, side by side.
- `end-cards-29s.jpg`: coming-soon and app-store at 29.0 s.

Total about 0.75 MiB.

## Not verified

- I did not keep a list of every icon removed from the Home Screen; the App Library undo above works per app. I did not test it.
- The Scan clip's photo picker shows other images from the simulator library (landscape photos, nutrition labels). They are not third-party app content, but the owner may prefer a library with only the barcode.
- The camera preview is the simulator's grey placeholder.
- The bezel rules and badge placement were checked by eye, not by Apple.
- No audio beyond silence. The owner adds music.
