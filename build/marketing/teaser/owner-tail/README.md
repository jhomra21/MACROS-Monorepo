# Owner recording continuation

`tail.mp4`: 6.266667 s, 376 frames, native 1320×2868, H.264 High /
yuv420p, 60 fps CFR, CRF 14, silent, faststart. No overlays, internal cuts,
motion trimming, retiming, interpolation, or fabricated widgets.

## Timeline (seconds in tail.mp4)

| Event | Time |
| --- | ---: |
| Insights at top, 30 days; Weight and Calories populated | 0.000 |
| Small scroll begins | 1.767 |
| Scroll settled | 2.600 |
| Native Home transition begins | 3.500 |
| App-close / Home animation fully settled | 4.500 |
| End | 6.267 |

Timing is measured on exported frames, to 1/60 s. The post-scroll pause is
about 0.9 s, rather than the requested approximately 0.5 s, because the UI
driver adds latency. It is preserved: only leading/trailing still time was
trimmed. The 25-point scroll is under one third of the screen and retains
Weight, Avg Calories, and the Calories chart. No Fiber or “No data” card.
Both real widgets show **1925 / P 123.3 / C 201 / F 81.3** throughout the
final 1.5 s (4.766667–6.266667). `tail-end.jpg` is the frame at 6.000 s.

Source: `/tmp/teaser-tail-raw.mov`; recorder PID 95806 stopped with SIGINT
and exited 0. Sample VFR source with `fps=60`, retain frames [52,428),
then reset timestamps. No interior removal or added end still.
All 376 presentation timestamps checked against frameIndex/60.
Final widget-region mpdecimate check retains one frame over the last 1.5 s.

## Transparent overlays

All PNGs are 1080×1920 RGBA, rendered from HTML in headless Chrome, with
SF loaded by `@font-face` from `/System/Library/Fonts/SFNS.ttf`.
Bounds below include every nonzero-alpha pixel; right/bottom are exclusive.

| File | Visible bounds (left, top, right, bottom) |
| --- | --- |
| `pill-dark-track.png` | (386, 10, 694, 117) |
| `pill-dark-glance.png` | (329, 10, 751, 117) |
| `hook-light.png` | (137, 1184, 943, 1416) |

Pills use v3 placement: center (540,64), bold 64 px, line-height 1.1,
18×40 px padding, 999 px radius, white on rgba(0,0,0,0.78).
Hook: center (540,1300), bold 76 px, line-height 1.1, 32×44 px padding,
radius 32, #1d1d1f on rgba(255,255,255,0.94), with the two explicit lines.

## Simulator restored

Only media simulator D16C3D35-889F-404F-BDD4-C640A6DBC4EF was controlled.
The manual form accepted one “Teaser total”, 1 serving, exactly 615 kcal /
P 28.3 / C 39 / F 47.3; Today was verified at 1925 / 123.3 / 201 / 81.3.
Deleted that entry afterward. Verified Today **1310 / P 95 / C 162 / F 34,
four foods**, both widgets **1310**, explicit DEBUG Pro revocation and
Settings **MACROS Pro, Free**. Status-bar override cleared, light appearance
retained, recorder stopped, lock released, Device panel closed without
shutting down the simulator.

Home Screen icon: yellow flexed arm on an off-white rounded square, the
same artwork as `cal-macro-tracker/Assets.xcassets/AppIcon.appiconset/icon-ios.png`.
No icon, source, project, or other simulator changes.
