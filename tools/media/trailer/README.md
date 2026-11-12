# MACROS launch trailer

This Remotion project renders the 29-second vertical MACROS trailer in one bold style: full-screen ring-colour fields, near-black 150 px headlines revealed word by word, small counters taken from the footage, and every app shot inside Apple's unmodified iPhone 18 Pro Max bezel at one fixed size and place. No push-ins, no bezel-free crops. Plan: `docs/plans/active/launch-trailer.md`. Evidence: `docs/evidence/trailer/`.

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

Each MP4 is 1080 × 1920, 30 fps, 870 frames, h264 yuv420p, stereo AAC (silent). The length comes from the last shot's end in `src/shots.ts` (`TOTAL_FRAMES`); any whole-frame duration works. `scripts/render.ts` renders, then remuxes to exactly that frame count and `frames / 30` seconds. Check with ffprobe.

## Shot table

All shots live in `src/shots.ts` as data: time, colour, headline phases, support line, counters and clip. Layout values (sizes, text and bezel positions) live in `src/styles.ts`. Change timings or copy there, not in components.

## Sources

None of these are tracked. Raw takes are native 1320 x 2868 simulator recordings from the media simulator, in `build/marketing/trailer/sources/v3/` (hook, search, home) and `v4/` (rings, insights). `bun run prepare:sources` cuts them into the clips the composition reads (`tools/media/trailer/public/sources/`, ignored): it normalises to 30 fps, removes idle frames and never speeds a clip up.

| Raw take | Clip | Shot |
| --- | --- | --- |
| `v3/flow-take1.mov` 0.5-4.0 s | `hook.mp4` | Hook: Today before logging, then the Add Food tap (3.5 s) |
| `v3/flow-take1.mov` 4.4-5.3, 6.3-7.6, 11.8-12.6, 13.0-13.9 s | `search.mp4` | Search it. |
| `web/public/media/macros-demo.d72c87d2.mp4` 6.3-10.2 s, cropped to x 112, y 222 (496 x 1028) under a status bar strip from 10.2 s, last frame held 0.1 s | `scan.mp4` | Scan it. (4.0 s) |
| `v4/rings-take1.mov` 2.4-3.0, 6.43-7.53, 12.23-13.33, 18.13-19.23, 24.13-25.23 s | `rings.mp4` | Rings fill as you go. (5.0 s) |
| `v4/insights-take1.mov` 4.2-8.2 s | `insights.mp4` | Track it. (4.0 s, 1.0x) |
| `v3/flow-take1.mov` 17.6-22.6 s | `home.mp4` | Glance at it. |

The other files are not tracked either. Copy them once:

```sh
ffmpeg -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=48000 -t 30 -c:a pcm_s16le tools/media/trailer/public/silence.wav
curl -L -o tools/media/trailer/public/app-store-badge.svg https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg
```

Bezel: download `https://devimages-cdn.apple.com/design/resources/download/Bezel-iPhone-18.dmg`, accept Apple's license, mount it, and copy `PNG/iPhone 18 Pro Max/iPhone 18 Pro Max - Black - Portrait.png` to `tools/media/trailer/public/bezel.png`. The PNG is 1470 × 3000 with a 1320 × 2868 screen opening at (75, 66). Use it unmodified.

### Recording the takes

Follow `docs/app-store/creative-assets/README.md`: lock the media simulator, build Debug for it, install, Settings > Developer > Load Demo Data, override the status bar to 9:41 with full signal, Wi-Fi and battery, then `xcrun simctl io <udid> recordVideo --codec h264 --force <file>.mov` (stop with SIGINT). Flow take: from Today, Add Food, search "banana", Banana, Log Food, then the Home Screen with only the MACROS icon and widgets. Scan take: Camera, photo picker, a barcode image, Log, Logged. Reload demo data before each take so the totals start at 1310 kcal. Rings take: after Load Demo Data swipe-delete Today's entries down to Oatmeal (350 kcal), start recording, then four times Add Food, a recent food chip (Turkey sandwich, Chicken and rice bowl, Pasta with tomato sauce, Salmon fillet), Log Food. Insights take: from Today (1310 kcal), tap the Insights button and rest on the top (Grant Debug Pro first). Recordings must be full screen with the 9:41 status bar.

## Beat sheet

The grid is 120 BPM, so one beat is 0.5 s. Cuts land on it; the type recap words use dotted-eighth beats (0.375 s).

| Time | Beat |
| --- | --- |
| 0.0 | "Log your food." Today before logging, counter 0 to 1310 |
| 1.5 | "Get on with your day." (2.0 s, fully readable 1.4 s) |
| 3.5 | "Search it." Banana search, counter 105 kcal |
| 7.5 | "Scan it." Camera, barcode, result, Logged, counter 200 kcal |
| 11.5 | "Rings fill as you go." Four logs, each back on Today: counter 350, 740, 1340, 1620, 2080 kcal |
| 16.5 | "Track it." Tap Insights, rest on its top, counter 125.7 g protein |
| 20.5 | "Glance at it." Clean Home Screen, widgets at 1415 (first 3.5 s of the clip) |
| 24.0 | "Search." |
| 24.375 | "Scan." |
| 24.75 | "Track." |
| 25.125 | "Done." |
| 26.0 | End card: rings mark on a white tile (rings sweep in over 0.6 s) |
| 26.5 | "MACROS" |
| 27.0 | "Coming soon to iPhone" or the App Store badge |
| 28.0 | `macrosios.com` |
| 29.0 | End |

## Transitions

All frame-driven (`src/transitions.tsx`, `src/media.tsx`, `src/text.tsx`); timings live in `src/styles.ts`. Each is centred on its cut.

- **Colour change (0.5 s, every cut):** the next ring colour grows as a disc from the centre of the phone, eased cubic-bezier(0.65, 0, 0.35, 1). Between two app shots the disc is behind the phone. Into a shot without a phone (type recap) it is drawn over the phone, which is covered and never animated.
- **Text:** headline, support line and counter fade out and drift up 24 px over the 0.25 s before the cut. Counters stay hidden until their count starts, after the headline has landed. Words reveal 0.06 s apart.
- **Screen:** between app shots (including hook to Search) only the recording inside the bezel cross-fades over 0.3 s; the bezel stays solid and identical. The outgoing clip rests on its last frame and the incoming one on its first, so footage is never moved or sped up.
