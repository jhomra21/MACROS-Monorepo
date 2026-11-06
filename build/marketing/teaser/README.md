# MACROS teaser v8

Shorter owner-requested teaser, with no Edit Entry step. Only this directory
changes. Raw captures and the end-card frame sequence remain outside Git.
The eight v7 marketing image variants, native screenshots, contact sheet,
screen framing, colors, and end-card design are unchanged.

## Deliverables

- `teaser.mp4`: **16.900000 s; 2,955,308 bytes (2.96 MB)**.
- 1080 × 1920, H.264 / yuv420p, **60 fps constant**, 1,014 decoded frames.
- Silent, faststart (`moov` before `mdat`), below 15 MB.
- `frames.png`: `fps=2,scale=160:-1,tile=10x5`.
- `frame-widget.jpg`, `teaser-poster.jpg`: both widgets at **1,415**.
- `frame-endcard.jpg`: filled logo; `frame-rings-after.jpg`: Today at **1,415**.

Entire native 1320 × 2868 screen, scaled to 884 × 1920, centered on #f2f2f7
with the same 80 px rounded corners. No screen cropping. Status bar, keyboard,
bottom screen area, and Home Screen dock are retained.

## Timeline

Times describe the final encoded video, not tool latency.

| Time | Screen / action |
| --- | --- |
| 0.00–0.69 | Today, **1,310** |
| 0.69–2.35 | Add Food presentation and search list |
| 2.35–5.5 | Type **banana**, keyboard and search results |
| 5.5–6.48 | Pick Banana; Log Food form |
| 6.48–7.88 | Log Food dismissal and rings fill to **1,415** |
| 7.88–8.87 | Today hold, **1,415**, approximately 1 s |
| 8.87–11.40 | Open unlocked 30-day Insights; short chart scroll |
| 11.40–12.30 | Native Home zoom and widget refresh to **1,415** |
| 12.30–13.80 | Both widgets at **1,415**, 1.5 s hold |
| 13.80–14.40 | Fade to black, 0.6 s |
| 14.40–16.90 | Same animated end card, rendered at 60 fps; 0.8 s ring fill |

The widget refresh briefly shows the previous value before settling. This
native behavior is preserved, not cut out. Both widgets show 1,415 throughout
the deliberate final hold and in the poster.

## Recording and still-only edit

Final source: `/tmp/teaser-raw-v8-final.mp4`, one uninterrupted whole-device
recording through the T3-pinned agent-device CLI, requested at 60 fps with no
touch overlay. The first rehearsal was rejected because a snapshot after
Home reactivated the app. The final take has no snapshot or app reopening
between recording start and stop.

DEBUG Pro was granted before capture. The take logs one 105 kcal Banana:
**1,310 → 1,415**. No entry editing, serving changes, or second logging step.

`render-video.py` uses `freezedetect=n=0.00001:d=0.4`. Only detected still
interiors are removed, leaving approximately 0.5 s, or 1 s for the Today hold.
All sheet, keyboard, navigation, rings, scrolling, and Home animations remain
at their original speed, in full. Removed source intervals:

| Start | End |
| --- | --- |
| 0.438333 | 0.608333 |
| 2.251667 | 2.448333 |
| 6.588333 | 6.935000 |
| 9.081667 | 9.205000 |
| 11.690000 | 11.831667 |

The VFR source is sampled by presentation timestamps using `fps=60`; retained
frames use `setpts=N/(60*TB)`. Output uses `-r 60 -fps_mode cfr`. No optical
flow, interpolation, animation speed-up, or crossfade between app screens.
Only the final still is extended for the widget hold and fade.

## Measured frame cadence

**This is not a claim of uniformly 60 unique native frames per second.**
The simulator delivers irregular VFR motion. Its nominal `r_frame_rate=600/1`
is a timebase-derived value, not evidence of 600 fps.

| File | r_frame_rate | avg_frame_rate | Decoded frames | Duration |
| --- | --- | --- | --- | --- |
| Raw | 600/1 | 128000/2653 (48.247 fps) | 640 | 13.265 s |
| Final | 60/1 | 60/1 | 1,014 | 16.900 s |

Unique-frame measurement uses default `mpdecimate` over the whole frame,
with `-fps_mode passthrough`. These are moving spans, not whole-clip averages.
The rings span includes the food-sheet dismissal and visible ring update.

| Motion | Source interval | Source frames | Source unique frames / fps | Final interval | Final frames | Final unique frames / fps |
| --- | --- | --- | --- | --- | --- | --- |
| Rings fill | 7.200–7.800 | 60 | 40 / **66.67** | 6.500–7.100 | 36 | 27 / **45.00** |
| App-to-Home zoom | 12.350–12.850 | 36 | 29 / **58.00** | 11.383333–11.883333 | 30 | 24 / **48.00** |

Most encoded frames in both measured motion spans are unique (75% and 80%).
VFR sampling needs repeated frames where native updates arrive irregularly;
none are invented by interpolation. Native Home capture falls short of
60 unique fps, and the encoded motion does not sustain 60 unique fps either.
The end card is independently rendered as 150 frames at 60 fps, not upsampled
from v7's 30 fps sequence.

## Verification

Ran `ffprobe -count_frames` on raw and final files. Checked every final frame's
presentation timestamp against `frameIndex / 60`, stream codec, dimensions,
pixel format, absence of audio, duration, file size, and faststart atom order.
Inspected `frames.png`, full-size widget and end-card stills, and the native
Home animation around both scene flags.

Scene detection: `select='gt(scene,0.25)',showinfo`.

| Flag | Timestamp | Visible content | Finding |
| --- | --- | --- | --- |
| 0 | **11.450000 s** | Insights shrinks into a rounded app card over the Home Screen | Continuous native Home animation, not an edit cut |
| 1 | **11.483333 s** | Smaller Insights card over blurred wallpaper and widgets | Same native animation, not an edit cut |

Exactly two flags; no other scene flags. The preceding still removal ends at
raw 11.831667 s, before the raw 12.368 s Home motion. Both flags are within
retained motion. Did not alter animation to hide detector false positives.

Repeatable commands (run from the camera-zoom worktree):

```sh
bun build/marketing/teaser/render-assets.mjs
python3 build/marketing/teaser/render-video.py
ffprobe -v error -count_frames -show_streams -show_format \
  build/marketing/teaser/teaser.mp4
ffmpeg -i build/marketing/teaser/teaser.mp4 \
  -vf "select='gt(scene,0.25)',showinfo" -fps_mode passthrough -f null -
ffmpeg -y -i build/marketing/teaser/teaser.mp4 \
  -vf 'fps=2,scale=160:-1,tile=10x5' -frames:v 1 \
  build/marketing/teaser/frames.png
# Substitute the table's source or final interval for START and END.
ffmpeg -i /tmp/teaser-raw-v8-final.mp4 \
  -vf 'trim=start=7.2:end=7.8,mpdecimate,showinfo' \
  -fps_mode passthrough -f null -
```

Requires ffmpeg/ffprobe, the untracked raw take above, and existing Playwright /
Sharp dependencies at `/tmp/macros-teaser-renderer`.

## Restored simulator state

Used only media simulator `D16C3D35-889F-404F-BDD4-C640A6DBC4EF`, under its
exclusive `/tmp/macros-sim-locks/` directory lock. No app source or other
simulator was changed; no Xcode build or app test run was needed.

After capture, deleted only the added Banana and confirmed Today:
**1,310 kcal / four foods**. Explicitly revoked DEBUG Pro and verified
**MACROS Pro, Free** in Settings. Visually confirmed **both widgets at 1,310**.
Cleared the 9:41 status-bar override, stopped the recorder, released the lock,
and closed this thread's Device panel without shutting down the simulator.
