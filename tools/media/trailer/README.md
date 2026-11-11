# MACROS launch trailer

This Remotion project renders the 30-second vertical MACROS trailer in two styles from one composition. Plan: `docs/plans/active/launch-trailer.md`. Evidence: `docs/evidence/trailer/`.

- `restrained`: near-black background with a visible colour wash, 150 px headlines, one idea at a time, device static in Apple's bezel.
- `bold`: full-screen colour fields in the ring colours, 180–200 px headlines revealed word by word, counters that match the footage, slow push-in on bezel-free close-ups only.

Each style has two end cards (`coming-soon`, `app-store`). Props: `style`, `variant`, `safeZones`.

## Studio and render

Run from `tools/media/trailer/`. Renders go to `build/marketing/trailer/` at the repo root.

```sh
bun install --frozen-lockfile
bun run studio                                   # Remotion Studio; set props in the sidebar
bun run render all                               # 4 MP4s, 2 review MP4s, 2 covers
bun run render bold app-store                    # one style x variant
bun run render restrained coming-soon --review   # safe-zone outlines
bun run render cover bold                        # cover PNG (frame 30)
bun run contrast                                 # contrast ratios for both styles
```

Each MP4 is 1080 × 1920, 30 fps, 900 frames, h264 yuv420p, stereo AAC (silent). `scripts/render.ts` renders, then remuxes to exactly 900 frames and 30.000 s. Check with ffprobe.

## Shot table

All shots live in `src/shots.ts` as data: time, colour, headline phases, support line, counters, clip and crop. Style values (sizes, colours, bezel scale) live in `src/styles.ts`. Change timings or copy there, not in components.

## Sources

None of these are tracked. Raw takes are full-resolution (1320 × 2868) simulator recordings from the media simulator, in `build/marketing/trailer/sources/v2/`. `bun run prepare:sources` cuts them into the clips the composition reads (`tools/media/trailer/public/sources/`, ignored): it removes idle frames and never speeds a clip up.

| Raw take | Clip | Shot |
| --- | --- | --- |
| `ring-take5.mov` 10.3–11.6 s, last frame held 1.5 s | `hook.mp4` | Hook |
| `ring-take4.mov` 3.2–4.1, 4.6–7.6, 8.2–9.2, 9.7–10.97 s | `search.mp4` | Search it. |
| `macros-demo.d72c87d2.mp4` (`web/public/media/`, 720 × 1280) 6.3–10.6 s | `scan.mp4` | Scan it. |
| `ring-take4.mov` 10.3–11.9 s, last frame held 3 s | `rings.mp4` | Rings fill as you go. |
| `insights.mov` 1.5–6.8 s | `insights.mp4` | Track it. |
| `home-widgets.png` (frame of `home-widgets.mov`) held 5 s | `home.mp4` | Glance at it. |

The other files are not tracked either. Copy them once:

```sh
cp cal-macro-tracker/Assets.xcassets/AppIcon.appiconset/icon-ios.png tools/media/trailer/public/app-icon.png
ffmpeg -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=48000 -t 30 -c:a pcm_s16le tools/media/trailer/public/silence.wav
curl -L -o tools/media/trailer/public/app-store-badge.svg https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg
```

Bezel: download `https://devimages-cdn.apple.com/design/resources/download/Bezel-iPhone-18.dmg`, accept Apple's license, mount it, and copy `PNG/iPhone 18 Pro Max/iPhone 18 Pro Max - Black - Portrait.png` to `tools/media/trailer/public/bezel.png`. The PNG is 1470 × 3000 with a 1320 × 2868 screen opening at (75, 66). Use it unmodified.

### Recording the takes

Follow `docs/app-store/creative-assets/README.md`: lock the media simulator, build Debug for it, install, Settings > Developer > Load Demo Data, override the status bar to 9:41 with full signal, Wi-Fi and battery, then `xcrun simctl io <udid> recordVideo --codec h264 --force <file>.mov` (stop with SIGINT). Ring take: Today, Add Food, search "banana", Banana, Log Food, then hold on Today for 7 s. Reload demo data before each take so the totals start at 1310 kcal.

## Beat sheet

The grid is 120 BPM, so one beat is 0.5 s. Cuts land on it.

| Time | Beat |
| --- | --- |
| 0.0 | "Log your food." Today rings animate up, close-up |
| 1.0 | "Get on with your day." |
| 2.0 | "Search it." Device, banana search |
| 8.0 | "Scan it." Scan close-up through Logged |
| 13.0 | "Rings fill as you go." Close-up, rings animate to 1415 kcal |
| 17.0 | "Track it." Device, Insights |
| 21.0 | "Glance at it." Widget close-up |
| 25.0 | "Search." |
| 25.5 | "Scan." |
| 26.0 | "Track." |
| 26.5 | "Done." |
| 27.0 | End card, app icon |
| 27.5 | "MACROS" |
| 28.0 | "Coming soon to iPhone" or the App Store badge |
| 29.0 | `macrosios.com` |
| 30.0 | End |
