# Owner recording continuation (v2, owner goals)

`tail.mp4`: 7.766667 s, 466 frames, native 1320×2868, H.264 High /
yuv420p, 60 fps CFR, CRF 14, silent, faststart. No overlays, internal cuts,
retiming, or interpolation. Simulator goals match the owner's phone:
**1,700 kcal / P 160 g / C 210 g / F 50 g**. Today reads **1925 of 1700 kcal**
(over goal, as on the owner's phone) with 123.3 / 201 / 81.3 and goals 160 / 210 / 50;
both MACROS widgets show **1925** with the same goals.

## Timeline (seconds in tail.mp4)

| Event | Time |
| --- | ---: |
| Start, Today at top showing 1925 (still) | 0.000 |
| Insights button press feedback begins (end of pure still) | 0.783 |
| Insights push starts (Today-hold ends) | 1.000 |
| Push settled; Insights at top, 30 days, Weight and Calories populated | 1.483 |
| Small scroll starts | 2.667 |
| Scroll settled (momentum finished) | 4.567 |
| Swipe-home / Home transition starts | 5.067 |
| Close animation fully settled | 5.767 |
| End of captured frames, then final-frame hold | 5.850 |
| End | 7.767 |

Measured on frame differences of the 60 fps CFR resample of the raw recording, to 1/60 s.
The scroll is a short swipe (about one fifth of the screen); it stays on
Weight / Avg cards / Calories and never reaches Fiber or "No data".
Scroll-settle to Home start is 0.5 s. The Insights hold before the scroll is about 1.2 s.

The only post-processing is trimming leading still time (source frames 0–379) and
extending the last captured frame. `simctl recordVideo` writes no frames while the screen is
static, so the raw file ends about 0.1 s after the Home animation. The Home Screen
was verified static for the next 3 s during capture; the final real frame is
cloned for 114 frames (1.9 s, `tpad=stop_mode=clone`) so the widgets hold about 2 s.
Widgets are real, never composited.

`tail-today.jpg` is the frame at 0.5 s. `tail-end.jpg` is the frame at 7.5 s.

Source: `/tmp/teaser-tail2-raw.mov`; recorder PID 38941 stopped with SIGINT
and exited 0. Pipeline: `fps=60`, `select=gte(n,380)`, `tpad` clone 114,
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
C 39, F 47.3, not saved as reusable) was logged; Today was verified at 1925 / 123.3 / 201 / 81.3.
Afterward the entry was deleted and goals restored to 2200 / 150 / 240 / 70.
Verified Today **1310 / P 95 / C 162 / F 34, four foods, "of 2200 kcal"**,
both widgets **1310** with 150 / 240 / 70, Settings **MACROS Pro, Free**
(Grant Debug Pro offered again). Status-bar override cleared, light appearance
retained, recorder stopped, lock released, Device panel closed without shutting down
the simulator. A "Teaser total" saved food already present in the On Device search list
before this run was left untouched.

Home Screen icon: yellow flexed arm on an off-white rounded square, the
same artwork as `cal-macro-tracker/Assets.xcassets/AppIcon.appiconset/icon-ios.png`.
