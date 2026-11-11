# MACROS launch trailer

This Remotion project renders the 30-second vertical MACROS trailer in one bold style: full-screen ring-colour fields, near-black 150 px headlines revealed word by word, small counters taken from the footage, and every app shot inside Apple's unmodified iPhone 18 Pro Max bezel at one fixed size and place. No push-ins, no bezel-free crops. Plan: `docs/plans/active/launch-trailer.md`. Evidence: `docs/evidence/trailer/`.

Two end cards (`coming-soon`, `app-store`). Props: `variant`, `safeZones`.

## Studio and render

Run from `tools/media/trailer/`. Renders go to `build/marketing/trailer/` at the repo root.

```sh
bun install --frozen-lockfile
bun run studio                    # Remotion Studio; set props in the sidebar
bun run render all                # coming-soon.mp4, app-store.mp4, review.mp4, cover.png
bun run render app-store          # one render (coming-soon | app-store | review | cover)
bun run contrast                  # contrast ratios on the three colour fields
```

Each MP4 is 1080 × 1920, 30 fps, 900 frames, h264 yuv420p, stereo AAC (silent). `scripts/render.ts` renders, then remuxes to exactly 900 frames and 30.000 s. Check with ffprobe.

## Shot table

All shots live in `src/shots.ts` as data: time, colour, headline phases, support line, counters and clip. Layout values (sizes, text and bezel positions) live in `src/styles.ts`. Change timings or copy there, not in components.

## Sources

None of these are tracked. Raw takes are native 1320 x 2868 simulator recordings from the media simulator, in `build/marketing/trailer/sources/v3/`. `bun run prepare:sources` cuts them into the clips the composition reads (`tools/media/trailer/public/sources/`, ignored): it normalises to 30 fps, removes idle frames and never speeds a clip up.

| Raw take | Clip | Shot |
| --- | --- | --- |
| `flow-take1.mov` 2.0-4.0 s | `hook.mp4` | Hook: Today before logging |
| `flow-take1.mov` 4.4-5.3, 6.3-7.6, 11.8-12.6, 13.0-13.9 s | `search.mp4` | Search it. |
| `scan-take2.mov` 2.6-3.9, 5.6-6.3, 7.6-8.6, 10.9-11.4, 13.6-14.8, 17.8-19.0 s | `scan.mp4` | Scan it. |
| `flow-take1.mov` 14.0-17.5 s, last frame held 0.5 s | `rings.mp4` | Rings fill as you go. |
| `insights.mov` 1.5-6.3 s | `insights.mp4` | Track it. (1.2x) |
| `flow-take1.mov` 17.6-22.6 s | `home.mp4` | Glance at it. |

The other files are not tracked either. Copy them once:

```sh
cp cal-macro-tracker/Assets.xcassets/AppIcon.appiconset/icon-ios.png tools/media/trailer/public/app-icon.png
ffmpeg -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=48000 -t 30 -c:a pcm_s16le tools/media/trailer/public/silence.wav
curl -L -o tools/media/trailer/public/app-store-badge.svg https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg
```

Bezel: download `https://devimages-cdn.apple.com/design/resources/download/Bezel-iPhone-18.dmg`, accept Apple's license, mount it, and copy `PNG/iPhone 18 Pro Max/iPhone 18 Pro Max - Black - Portrait.png` to `tools/media/trailer/public/bezel.png`. The PNG is 1470 × 3000 with a 1320 × 2868 screen opening at (75, 66). Use it unmodified.

### Recording the takes

Follow `docs/app-store/creative-assets/README.md`: lock the media simulator, build Debug for it, install, Settings > Developer > Load Demo Data, override the status bar to 9:41 with full signal, Wi-Fi and battery, then `xcrun simctl io <udid> recordVideo --codec h264 --force <file>.mov` (stop with SIGINT). Flow take: from Today, Add Food, search "banana", Banana, Log Food, then the Home Screen with only the MACROS icon and widgets. Scan take: Camera, photo picker, a barcode image, Log, Logged. Reload demo data before each take so the totals start at 1310 kcal. Recordings must be full screen with the 9:41 status bar.

## Beat sheet

The grid is 120 BPM, so one beat is 0.5 s. Cuts land on it.

| Time | Beat |
| --- | --- |
| 0.0 | "Log your food." Today before logging, counter 0 to 1310 |
| 1.0 | "Get on with your day." |
| 2.0 | "Search it." Banana search, counter 105 kcal |
| 6.0 | "Scan it." Camera, barcode, result, Logged, counter 539 kcal |
| 12.0 | "Rings fill as you go." Today rolls 1310 to 1415 |
| 16.0 | "Track it." Insights, counter 125.7 g protein |
| 20.0 | "Glance at it." Clean Home Screen, widgets at 1415 |
| 25.0 | "Search." |
| 25.5 | "Scan." |
| 26.0 | "Track." |
| 26.5 | "Done." |
| 27.0 | End card, app icon |
| 27.5 | "MACROS" |
| 28.0 | "Coming soon to iPhone" or the App Store badge |
| 29.0 | `macrosios.com` |
| 30.0 | End |
