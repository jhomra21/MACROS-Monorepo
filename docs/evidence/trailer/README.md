# Launch trailer v5 render evidence

Plan: `docs/plans/active/launch-trailer.md`. Project: `tools/media/trailer/`. Renders, raw takes, the Apple bezel and the badge stay in ignored folders.

v5 adds transitions and retimes the hook (below). v4 applied the owner's review to v3: Track it shows the act of opening Insights, Rings fills with real entries one after another, Scan loses its frozen hold, and the length is now 29.0 s. Everything else is unchanged: one bold style, Apple's iPhone 18 Pro Max bezel at one fixed size and position, no crops or push-ins.

Toolchain: Bun 1.4.2, Remotion 4.0.543, ffmpeg, macOS. Renders are in `build/marketing/trailer/`: `coming-soon.mp4`, `app-store.mp4`, `review.mp4` (safe-zone outlines), `cover.png`, from `bun run render all`.

## Simulator steps

Media simulator `D16C3D35-889F-404F-BDD4-C640A6DBC4EF` only, under `/tmp/macros-sim-locks/D16C3D35-889F-404F-BDD4-C640A6DBC4EF` (taken by `mkdir`, released by `rmdir`). The earlier Debug build of `origin/main` (`/tmp/macros-trailer-build`) was already installed and was reused. 9:41 status bar override (full cellular, Wi-Fi, charged battery). Taps and swipes came from the `axe` binary bundled with XcodeBuildMCP, run with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` because the MCP's own Xcode path lacked SimulatorKit. Recording: `simctl io recordVideo --codec h264 --force`, stopped with SIGINT. At the end the override was cleared, the simulator shut down and the lock removed. No other simulator was used and nothing was erased or reset. The Home Screen was not touched.

Raw takes (`build/marketing/trailer/sources/v4/`, 1320 x 2868 native):

- `rings-take1.mov` (25.4 s): Today first trimmed by swipe-deleting four of the five demo entries (350 kcal left, Oatmeal with banana). Then four times: Add Food, tap a recent food chip, Log Food.
- `insights-take1.mov` (9.6 s): Today at 1310 kcal, tap the Insights button, rest on the top of Insights. Debug Pro was granted first (Settings > Developer), after reloading demo data. Demo data was reloaded again after the rings take, so Today read 1310 kcal.

## Sources per shot

| Time | Shot | Source and in/out | Rate |
| --- | --- | --- | --- |
| 0-3.5 s | Hook | `v3/flow-take1.mov` 0.5-3.5 s (Today only), then the last Today frame held 0.5 s | 1.0x |
| 3.5-7.5 s | Search | `v3/flow-take1.mov` 4.4-5.3, 6.3-7.6, 11.8-12.6, 13.0-13.9 s (+0.1 s hold); ends on the Log Food form, before the Log tap | 1.0x |
| 7.5-11.5 s | Scan | `web/public/media/macros-demo.d72c87d2.mp4` 6.6-10.2 s (+0.4 s hold of the last frame), same crop and status bar strip as v3; starts on the camera | 1.0x |
| 11.5-16.5 s | Rings | `v4/rings-take1.mov` 2.4-3.0, 7.2-8.3, 13.4-14.5, 19.1-20.2, 25.267-25.44 s (last moment holds its final frame 0.933 s) | 1.0x |
| 16.5-20.5 s | Track | `v4/insights-take1.mov` 4.2-8.2 s: Today, tap, push, rest on the top of Insights | 1.0x |
| 20.5-24 s | Glance | `v3/flow-take1.mov` 17.6-21.1 s (clip is 5 s; first 3.5 s used) | 1.0x |
| 24-29 s | Type, end card | none | |

Rings moments start only after the Camera and Add Food buttons stop moving (raw frame diff; was 6.43, 12.23, 18.13, 24.13 s). The last moment has 0.17 s of footage because the take ends at 25.44 s.

## v5: transitions and timing

- Colour change, every cut (0.5 s, 15 frames, centred on the cut): the next ring colour grows as a disc from the centre of the phone, eased cubic-bezier(0.65, 0, 0.35, 1). The disc is always behind the phone. When the next shot has no phone (type recap, end card), the phone hard-cuts out at the cut frame and the disc keeps growing full-frame behind where it was. No colour shape is ever drawn over the product screen.
- Hook to Search is app to app (both have the phone), so it keeps the phone and cross-fades the screen instead of covering it; a cover would hide the phone and bring it back.
- Between app shots only the recording inside the bezel cross-fades (0.3 s); the bezel is solid, same size and place. Clips rest on first/last frame around the cut, so no footage moves.
- Text, support and counter fade out and drift up 24 px over the 0.25 s before the cut. Word stagger is 0.06 s (was 0.2 s). Counters count after their headline lands (hook counter now starts at 0.45 s).
- Timing: hook 3.5 s ("Log your food." 0-1.5 s, "Get on with your day." 1.5-3.5 s, fully readable 1.39 s), Glance cut from 5.0 s to 3.5 s, type recap words every 0.375 s so "Done." can be read before it leaves (0.5 s). Total unchanged at 29.0 s; every cut is on the 0.5 s grid. Other shots, footage, counters and the end card are unchanged.
- Fixes in this revision: the hook clip stops at 3.5 s of the take, before the Add Food sheet rises, and holds its last Today frame, so the 3.5 s hook stays on Today; the Search clip already ended on the Log Food form, and the 1725 kcal Today seen in the Scan cross-fade was the demo's opening frames, so the Scan clip now starts on the camera at 6.6 s. The Search-to-Scan cross-fade runs form to camera only.
- Known: the Hook-to-Search cross-fade is unchanged (0.3 s, centred on 3.5 s), so Search fades in from 3.33 s and a faint Search sheet shows over the Today frame at 3.4 s. The hook footage itself is Today the whole time.
- Readable (all words at 90% opacity, before the exit starts): Search, Scan, Track 89% of the shot, Rings 88%, Glance 86%; hook line 1 is 1.01 s of its 1.5 s.

## Images (4, about 0.72 MiB)

- `contact-2fps.jpg`: 10 x 6 at 180 px.
- `review-1fps.jpg`: 10 x 3 with safe-zone outlines.
- `transitions.jpg`: frames cut-8, -4, 0, +4, +7 for hook to Search (3.5 s), Search to Scan (7.5 s) and Glance to type recap (24 s, cover).
- `end-cards-28.5s.jpg`: coming-soon and app-store at 28.5 s.

## Checks run

All three MP4s: h264, yuv420p, 1080 x 1920, 30 fps, 870 frames (counted), 29.000 s, stereo AAC 48 kHz. Contrast is unchanged (4.92, 9.62, 5.78:1); text is near-black on both colours at every transition frame, and only fades toward transparent while leaving. Frames for the three fixes were checked by eye on `coming-soon.mp4`.

## Not verified

- No audio beyond silence; the owner adds music.
- The bezel rules were checked by eye, not by Apple.
- The Scan footage's own card cross-fade (ghosted text) is original and not edited.
