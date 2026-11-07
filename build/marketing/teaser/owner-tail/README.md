# Owner recording continuation (v3, owner goals, fat 81.9)

`tail.mp4`: 4.783333 s, 287 frames, native 1320×2868, H.264 High /
yuv420p, 60 fps CFR, CRF 14, silent, faststart. No overlays, internal cuts,
retiming, or interpolation. Simulator goals match the owner's phone:
**1,700 kcal / P 160 g / C 210 g / F 50 g**. Today (verified before the take) reads
**1925 of 1700 kcal** with 123.3 / 201 / **81.9** and goals 160 / 210 / 50.
Both MACROS widgets show **1925** with 123.3 / 201 / 81.9: the medium widget shows
`81.9` over goal `50`; the small widget shows `81.9` with an up-arrow (not rounded).
Today is no longer in the clip: the take starts directly on Insights.

## Timeline (seconds in tail.mp4)

| Event | Time |
| --- | ---: |
| Start, Insights at top, 30 days, Weight and Calories populated (still) | 0.000 |
| Small scroll starts | 1.200 |
| Scroll settled (momentum finished) | 1.450 |
| Swipe-home / Home transition starts | 2.067 |
| Close animation fully settled | 2.667 |
| Last frame with any change | 2.733 |
| Final-frame hold ends / End | 4.783 |

Measured on frame differences of the 60 fps CFR resample of the raw recording, to 1/60 s.
The scroll is a short swipe (172 px of 954 pt viewport, about 0.18 of the screen,
400 ms gesture); it stays on Weight / Avg cards / Calories and never reaches Fiber
or "No data". Insights is held about 1.2 s before the scroll; scroll-settle to Home
start is about 0.6 s (0.617 s measured).

The only post-processing is trimming leading still time (source frames 0–286) and
extending the last captured frame. `simctl recordVideo` writes no frames while the screen
is static, so the raw file ends shortly after the Home animation. The Home Screen was
static afterward, so the final real frame is cloned for 116 frames (1.93 s,
`tpad=stop_mode=clone`) and the widgets hold about 2 s. Widgets are real, never composited.

`tail-end.jpg` is the frame at 4.5 s (Home Screen with both widgets at 1925).
`tail-today.jpg` is retained from v2 (Today frame, no longer used; it shows the old 81.3 fat).

Source: `/tmp/teaser-tail3-raw.mov`; recorder PID 64837 stopped with SIGINT. Pipeline:
`fps=60`, `select=gte(n,287)`, `tpad` clone 116,
`-c:v libx264 -profile:v high -crf 14 -pix_fmt yuv420p -an -movflags +faststart`.

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
These overlays are unchanged from v1.

## Simulator restored

Only media simulator D16C3D35-889F-404F-BDD4-C640A6DBC4EF was controlled.
Original goals were **2200 kcal / P 150 / C 240 / F 70**. For the take they were
set to 1700 / 160 / 210 / 50 and one manual "Teaser total" (615 kcal, P 28.3,
C 39, F 47.9, not saved as reusable) was logged; Today was verified at 1925 / 123.3 / 201 / 81.9.
Afterward the entry was deleted and goals restored to 2200 / 150 / 240 / 70.
Verified Today **1310 / P 95 / C 162 / F 34, four foods, "of 2200 kcal"**,
both widgets **1310** with 150 / 240 / 70, Settings **MACROS Pro, Free**
(temporary Debug Pro was granted for Insights and is gone; the app was relaunched).
Status-bar override cleared, light appearance retained, recorder stopped, lock
released, Device panel closed without shutting down the simulator.

The "Teaser total" saved food (615 kcal, P 28.3 • C 39 • F 47.3) from an earlier run is
still in the On Device list: the app has no delete UI for saved foods (long-press and swipe
on the row only open the Log Food form), so it was left in place.

Home Screen icon: yellow flexed arm on an off-white rounded square, the
same artwork as `cal-macro-tracker/Assets.xcassets/AppIcon.appiconset/icon-ios.png`.
