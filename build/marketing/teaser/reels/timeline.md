# MACROS teaser reels v3

Source: `origin/tmp/teaser-assets-v8`, unchanged 16.900 s / 1,014 frames.

## Timeline

Times include entrance and exit, with end exclusive. Entrance: 0.28 s cubic ease-out, opacity 0→1, 24 px upward travel, scale 0.96→1. Exit: final 0.20 s cubic ease-in, opacity 1→0, 12 px upward travel. Every caption gap is at least 0.15 s. Times are quantized to 60 fps.

| Video | Caption / hook | In | Exit starts | Out | On screen |
| --- | --- | ---: | ---: | ---: | --- |
| reel-A.mp4 | Hook A | 0.000 | 2.050 | 2.250 | Today / Add Food list; lower food-list hook |
| reel-A.mp4 | Search it. | 2.400 | 5.100 | 5.300 | Typing banana and matching results; exits before Log Food presentation |
| reel-A.mp4 | Log it. | 5.500 | 7.683 | 7.883 | Log Food form, tap, dismissal, and rings filling to 1,415 |
| reel-A.mp4 | Track it. | 9.150 | 11.200 | 11.400 | Unlocked Insights charts and chart scroll; exits as Home zoom begins |
| reel-A.mp4 | Glance at it. | 11.850 | 13.450 | 13.650 | Home widgets, including native refresh, then both at 1,415; exits before fade |
| reel-B.mp4 | Hook B | 0.000 | 2.050 | 2.250 | Today / Add Food list; lower food-list hook |
| reel-B.mp4 | Search it. | 2.400 | 5.100 | 5.300 | Typing banana and matching results; exits before Log Food presentation |
| reel-B.mp4 | Log it. | 5.500 | 7.683 | 7.883 | Log Food form, tap, dismissal, and rings filling to 1,415 |
| reel-B.mp4 | Track it. | 9.150 | 11.200 | 11.400 | Unlocked Insights charts and chart scroll; exits as Home zoom begins |
| reel-B.mp4 | Glance at it. | 11.850 | 13.450 | 13.650 | Home widgets, including native refresh, then both at 1,415; exits before fade |
| reel-C.mp4 | Hook C | 0.000 | 3.250 | 3.450 | Home widgets 0–1.20; crossfade 1.20–1.40; then Today / Add Food |
| reel-C.mp4 | Search it. | 3.600 | 6.300 | 6.500 | Typing banana and matching results; exits before Log Food presentation |
| reel-C.mp4 | Log it. | 6.700 | 8.883 | 9.083 | Log Food form, tap, dismissal, and rings filling to 1,415 |
| reel-C.mp4 | Track it. | 10.350 | 12.400 | 12.600 | Unlocked Insights charts and chart scroll; exits as Home zoom begins |
| reel-C.mp4 | Glance at it. | 13.050 | 14.650 | 14.850 | Home widgets, including native refresh, then both at 1,415; exits before fade |
| teaser-captions.mp4 | Search it. | 2.400 | 5.100 | 5.300 | Typing banana and matching results; exits before Log Food presentation |
| teaser-captions.mp4 | Log it. | 5.500 | 7.683 | 7.883 | Log Food form, tap, dismissal, and rings filling to 1,415 |
| teaser-captions.mp4 | Track it. | 9.150 | 11.200 | 11.400 | Unlocked Insights charts and chart scroll; exits as Home zoom begins |
| teaser-captions.mp4 | Glance at it. | 11.850 | 13.450 | 13.650 | Home widgets, including native refresh, then both at 1,415; exits before fade |

## Placement and edit decisions

- Pills: SF system font loaded by headless Chrome from `/System/Library/Fonts/SFNS.ttf` using `@font-face`, bold 64 px, 18×40 px padding, rgba(0,0,0,0.78), 999 px radius. **Center y=64, not 190**: the source's search field / title row occupy y≈165–255. The pill's settled bounds y=10.8–117.2 preserve them, along with chart titles, rings, macro numbers and widgets.
- Hooks: same font, bold 76 px, line-height 1.1, 32×44 px padding, rgba(0,0,0,0.72), 32 px radius, top y=1160, bottom y=1391.2. Letter spacing −1.5 px fits A within x=20.6–1059.4 without changing its font size or explicit lines. Hook C is below the widgets. No orphan words.
- Hook lines: A: “Logging lunch shouldn't take” / “longer than eating it.”; B: “Your macros,” / “without the homework.”; C: “Your day, right on” / “your Home Screen.”
- Search is intentionally delayed to visible typing at 2.40 s to retain a 2.25 s hook and 0.15 s clear gap. C shifts all source actions by exactly 1.20 s; no Glance caption appears during its widget opening. Its 1.20 s widget hold crossfades for 0.20 s to the original start.
- No step captions on the opening Today shot or end card. Last caption ends 0.15 s before source fade starts (13.80 s, C 15.00 s). No audio, interpolation, simulator interaction, or app changes.
- Worktree began clean on `tmp/teaser-reel-hooks-v2`; it had no diff from `origin/tmp/teaser-reel-hooks`. Superseded ignored overlay PNGs remain untracked and are not part of this commit. No user changes were discarded.

## Encoding verification

All outputs: H.264, 1080×1920, yuv420p, CRF 16, `-fps_mode cfr -r 60`, silent, faststart. ffprobe decoded frame counts and every frame timestamp checked against frameIndex/60; each file below 15,000,000 bytes.

| File | Duration | Frames | FPS | Bytes | MB |
| --- | ---: | ---: | --- | ---: | ---: |
| reel-A.mp4 | 16.900 s | 1014 | 60/1 | 4181302 | 4.18 |
| reel-B.mp4 | 16.900 s | 1014 | 60/1 | 4147851 | 4.15 |
| reel-C.mp4 | 18.100 s | 1086 | 60/1 | 4488628 | 4.49 |
| teaser-captions.mp4 | 16.900 s | 1014 | 60/1 | 3997495 | 4.00 |

`sheet.png`: one row per video, 200 px-wide frames at every hook/caption midpoint, each labelled with its time. Covers show fully entered hooks (C on its opening widgets). Rendering scratch files remain outside this directory.
