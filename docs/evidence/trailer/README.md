# Launch trailer v3 render evidence

Plan: `docs/plans/active/launch-trailer.md`. Project: `tools/media/trailer/`. Renders, raw takes, the Apple bezel and the badge stay in ignored folders.

v3 keeps only the bold style. Every app shot is inside Apple's iPhone 18 Pro Max bezel at one fixed size and position. There are no bezel-free close-ups, no square widget crop and no push-ins. The restrained style and its renders were removed.

Toolchain: Bun 1.4.2, Remotion 4.0.543, ffmpeg, macOS. Renders are in `build/marketing/trailer/`: `coming-soon.mp4`, `app-store.mp4`, `review.mp4` (safe-zone outlines), `cover.png`, from `bun run render all`.

## Simulator steps

Media simulator `D16C3D35-889F-404F-BDD4-C640A6DBC4EF` only, under `/tmp/macros-sim-locks/D16C3D35-889F-404F-BDD4-C640A6DBC4EF` (taken by `mkdir`, released by `rmdir`). The v2 Debug build of `origin/main` (`/tmp/macros-trailer-build`) was installed. Settings > Developer > Load Demo Data (Today 1310 kcal), 9:41 status bar override (full cellular, Wi-Fi, charged battery), `simctl io recordVideo --codec h264`. Taps came from `agent-device`. The simulator was shut down once mid-session to clear a stuck recorder (`Host recording is already in progress`) and booted again; the lock was kept. At the end the override was cleared, the simulator shut down and the lock removed. No other simulator was used and nothing was erased.

Raw takes (`build/marketing/trailer/sources/v3/`, 1320 x 2868 native, 9:41 status bar): `flow-take1.mov` (23.3 s), `insights.mov` (copied from the v2 take, 6.9 s). `scan-take2.mov` (19.4 s) is no longer used by any shot; it stays on disk. `scan-take1.mov` and `home-take1.mov` were rejected earlier takes (the Home Screen one still had other apps).

## Sources per shot

| Time | Shot | Source and in/out | Rate |
| --- | --- | --- | --- |
| 0-2 s | Hook | `flow-take1.mov` 2.0-4.0 s: Today at 1310 before any log | 1.0x |
| 2-6 s | Search | `flow-take1.mov` 4.4-5.3, 6.3-7.6, 11.8-12.6, 13.0-13.9 s (+0.1 s hold): Add Food, "banana" results, Log Food form | 1.0x |
| 6-12 s | Scan | `web/public/media/macros-demo.d72c87d2.mp4` 6.3-10.2 s (+2.1 s hold of the last frame), body crop x 112, y 222, 496 x 1004, status bar strip x 112, y 148-221 from 10.2 s: camera, barcode, Chocolate Dough Protein Bar (200 kcal), Logged | 1.0x |
| 12-16 s | Rings | `flow-take1.mov` 14.0-17.5 s (+0.5 s hold): Log Food tapped, sheet dismisses, 1310 to 1415 | 1.0x |
| 16-20 s | Track | `insights.mov` 1.5-6.3 s | 1.2x |
| 20-25 s | Glance | `flow-take1.mov` 17.6-22.6 s: Home Screen right after logging, widgets show 1415 | 1.0x |
| 25-30 s | Type, end card | none | |

Each real moment appears once: the hook is Today before logging, Search ends before the Log tap, Rings starts at the dismissal. Idle time was cut; nothing is sped up except Insights at 1.2x. The Scan source ends at 10.2 s, before the "Track it." pill and the crossfade into Insights. Its Logged card holds for 2.1 s to make the shot 6.0 s, so Scan is not sped up either.

## Scan footage chosen

The Scan shot uses the original demo footage, `web/public/media/macros-demo.d72c87d2.mp4` (720 x 1280, 60 fps), the same source v2 used. The native 1320 x 2868 take `scan-take2.mov` is no longer used. The clip is not upscaled: 496 source pixels fit the 449-pixel opening at about 0.9x.

Splice: the body is the crop below the burnt-in "Scan it." pill (x 112, y 222, 496 x 1004). The pill sits over the real status bar until about 10 s, so the status bar strip is taken from 10.2 s, when the pill is gone: rows 148-221 show the recording's own 9:41 status bar and battery. Rows 0-145 are the page's light grey background, not a status bar, so they are not used. The strip stacks above the body to make 496 x 1078. That is the same aspect as the 1320 x 2868 screen opening, so the cover fit crops almost nothing. The seam looks clean at full size (checked at 7.0 s). Nothing is drawn or faked.

Counter: 0 to 200 kcal, the Chocolate Dough Protein Bar result, starting 3.0 s into the shot as the card becomes Logged. It replaces the Nutella 539 kcal of the scan-take2 take. The Device component now sets `objectFit: cover`; the other clips already have the screen's aspect, so their render is unchanged.

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

Values match the recordings. Hook 0 to 1310 kcal (Today's ring). Search 0 to 105 kcal (Banana's Log Food form). Scan 0 to 200 kcal (Chocolate Dough Protein Bar, 1 serving, Logged). Rings 1310 to 1415 kcal. Track 0 to 125.7 g protein 30-day average (Insights). The Track counter starts at the cut (it reads 107.9 about 0.1 s in) and lands within 1 s. Counters stay hidden until counting begins, so none rests at 0.

## Checks run

- ffprobe on all three MP4s: h264, yuv420p, 1080 x 1920, 900 frames (counted), 30.000 s, stereo AAC 48 kHz.
- Scan clip `scan.mp4`: 496 x 1078, yuv420p, 180 frames, 6.000 s.
- `bunx tsc --noEmit` and `git diff --check`: both pass.
- Full-size frames at 7.0, 9.0 and 11.0 s viewed: bezel intact, no pill, real 9:41 status bar, counter 200 kcal logged at 11.0 s.
- Contact sheet and review sheet regenerated from the new renders.

## Images

- `contact-2fps.jpg`: 10 x 6 at 180 px.
- `review-1fps.jpg`: 10 x 3 with safe-zone outlines.
- `frames-7-9-11s.jpg`: full-size frames at 7.0, 9.0 and 11.0 s, side by side. Replaces `frames-5-10.5-23s.jpg`.
- `end-cards-29s.jpg`: coming-soon and app-store at 29.0 s.

Total about 0.84 MiB.

## Not verified

- I did not keep a list of every icon removed from the Home Screen; the App Library undo above works per app. I did not test it.
- The 9.0 s frame shows the original recording's own card cross-fade (ghosted text). It is not edited.
- The bezel rules and badge placement were checked by eye, not by Apple.
- No audio beyond silence. The owner adds music.
