# MACROS launch trailer

This Remotion project renders the 30-second vertical MACROS trailer. Plan: `docs/plans/active/launch-trailer.md`.

## Open Studio and render

Run these from `tools/media/trailer/`. Renders go to `build/marketing/trailer/` at the repo root.

```sh
bun install
bun run studio             # opens Remotion Studio in the browser
bun run render:coming-soon # coming-soon.mp4
bun run render:app-store   # app-store.mp4
bun run render:review      # review.mp4 with safe-zone outlines
bun run render:cover       # cover.png (frame 30)
```

Each MP4 is 1080 × 1920, 30 fps, 900 frames, h264 yuv420p, with a silent stereo AAC track. Check with ffprobe.

## Where the assets go

None of these are tracked. All paths are ignored by git. Run from the repo root.

Sources. Copy them to both folders:

```sh
mkdir -p build/marketing/trailer/sources tools/media/trailer/public/sources
cp <worktrees>/dashboard-tutorial-evidence/docs/app-store/media/clips/{a1-log,b2-insights}.mov build/marketing/trailer/sources/
cp <worktrees>/camera-zoom/build/marketing/teaser/raw.mp4 build/marketing/trailer/sources/
cp <worktrees>/dashboard-tutorial-evidence/docs/evidence/web-scan-retake/after-app-scan-review.png build/marketing/trailer/sources/scan-review.png
ffmpeg -ss 53 -i build/marketing/trailer/sources/raw.mp4 -t 4 -vf crop=1320:640:0:900 -an -c:v libx264 -crf 14 -r 30 -pix_fmt yuv420p build/marketing/trailer/sources/widgets-only.mp4
cp build/marketing/trailer/sources/* tools/media/trailer/public/sources/
```

Other files:

```sh
cp cal-macro-tracker/Assets.xcassets/AppIcon.appiconset/icon-ios.png tools/media/trailer/public/app-icon.png
ffmpeg -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=48000 -t 30 -c:a pcm_s16le tools/media/trailer/public/silence.wav
```

Bezel. Download `https://devimages-cdn.apple.com/design/resources/download/Bezel-iPhone-18.dmg`, then accept Apple's license and mount it:

```sh
yes | hdiutil attach -nobrowse -readonly -mountpoint /tmp/bezel18 Bezel-iPhone-18.dmg
cp "/tmp/bezel18/PNG/iPhone 18 Pro Max/iPhone 18 Pro Max - Black - Portrait.png" tools/media/trailer/public/bezel.png
hdiutil detach /tmp/bezel18
```

The PNG is 1470 × 3000 with a 1320 × 2868 screen opening at (75, 66). The constants are in `src/trailer.tsx`. Use the bezel unmodified.

Badge:

```sh
curl -L -o tools/media/trailer/public/app-store-badge.svg https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg
```

## Beat sheet

The grid is 120 BPM, so one beat is 0.5 s. Cuts land on it.

| Time | Beat |
| --- | --- |
| 0.0 | “Log your food.” Today ring close-up |
| 1.0 | “Get on with your day.” |
| 2.0 | “Search it.” Device, banana search |
| 8.0 | “Scan it.” Device, label scan review |
| 14.0 | “Rings fill as you go.” Close-up |
| 17.0 | “Track it.” Device, Insights |
| 21.0 | “Glance at it.” Widget crop |
| 25.0 | “Search.” |
| 25.5 | “Scan.” |
| 26.0 | “Track.” |
| 26.5 | “Done.” |
| 27.0 | End card, app icon |
| 27.5 | “MACROS” |
| 28.0 | “Coming soon to iPhone” or the App Store badge |
| 29.0 | `macrosios.com` |
| 30.0 | End |
