# MACROS teaser v7

Owner-requested marketing deliverables, including the video and eight image
variants, are an explicit exception to the normal tracked-evidence size limit.
Only files in this directory changed. Raw captures and end-card frame sequences
remain outside Git.

## Deliverables

- `teaser.mp4`: 1080 × 1920, H.264 / yuv420p, 30 fps, silent, faststart.
  Duration 23.066667 s; size 2,809,778 bytes (2.81 MB).
- `home.png`, `charts.png`: recaptured native 1320 × 2868 screenshots.
- `home-A`, `home-B`, `charts-A`, `charts-B`: 1080 × 1350.
  Corresponding `-tiktok` files: 1080 × 1920. A is clean; B has a headline.
- `contact-sheet.png`: the four 4:5 variants.
- `frames.png`: required 2 fps, 160 px wide, 10 × 6 verification sheet.
- `frame-widget.jpg`, `teaser-poster.jpg`: final unfaded Home Screen frame.
- `frame-endcard.jpg`: filled end-card logo.
- `frame-rings-after.jpg`: edited Today total.

All image layouts preserve the native screen aspect ratio with `object-fit:
contain`. No screen extraction/cropping remains. Video uses the entire native
screen scaled to 884 × 1920, centered on #f2f2f7 with 80 px rounded corners.
Status bar, keyboard bottom row, bottom screen area, and Home Screen dock were
visually checked. The app itself hides the home indicator; no bottom pixels
were removed. C variants were deleted.

## Recording and edit

Rehearsed the full flow before recording. The final take is one uninterrupted
simctl screen capture. DEBUG Pro was granted before the take, with no app
reopening until the take finished. The earlier take was rejected because
reopening the app refreshes entitlements and resets DEBUG Pro.

Nutrition: **1,310 → 1,415 → 1,520 kcal**. Banana is 105 kcal; editing to two
servings makes it 210 kcal. Both Home Screen widgets show 1,520 in the take.

`render-video.py` uses `freezedetect=n=0.00001:d=0.4`, stricter than the requested
0.001 threshold, and removes only the interior of long still spans. It leaves
0.25 s on each side (about 0.5 s total). All short spans and every real animation
remain at original speed, including stepper changes, sheet presentations,
navigation, ring easing, scrolling, and the app-to-Home zoom. There is no optical
flow, crossfade between app screens, or animation retiming. The Home Screen
holds for approximately 1.5 s before the 0.6 s fade. The final 2.5 s is HTML
rendered in headless Chrome at 30 fps; rings fill over 0.8 s.

Rebuild in this worktree:

```sh
bun build/marketing/teaser/render-assets.mjs
python3 build/marketing/teaser/render-video.py
```

Requires the raw take at `/tmp/teaser-raw-v7.mov`, existing local Playwright /
Sharp dependencies at `/tmp/macros-teaser-renderer`, and ffmpeg / ffprobe.
The raw take is intentionally not committed.

## Verification

Ran:

```sh
ffmpeg -i build/marketing/teaser/teaser.mp4 \
  -vf "select='gt(scene,0.25)',showinfo" -f null -
ffmpeg -i build/marketing/teaser/teaser.mp4 \
  -vf 'fps=2,scale=160:-1,tile=10x6' -frames:v 1 build/marketing/teaser/frames.png
```

Scene detection flags exactly:

| Timestamp | Visible content | Finding |
| --- | --- | --- |
| 18.100000 s | Insights begins shrinking over the Home Screen | Native app-to-Home animation, not a cut |
| 18.166667 s | App contracts toward its icon over blurred widgets | Same continuous native animation, not a cut |

Inspected all 18 frames from 17.9–18.5 s at 30 fps: uninterrupted shrink,
icon morph, and wallpaper/widget unblur. These are scene-detector false
positives on real motion. No hard edit cut is flagged. Neither event is an edit
boundary: the last removed still span ended at raw 65.015 s (edited ~16.75 s);
the flagged motion is raw ~66.357–66.423 s. Did not modify the real animation
to hide detector flags. Requested “none except possibly fade” is therefore
not literally achieved; preserving the authentic animation takes precedence.

Verified stream metadata, duration, size, no audio, full-screen aspect ratio,
all eight image geometries, contact sheet, end card, and edit-span boundaries.
No app source changed; no app build or app test run was needed.

After capture, deleted only the added Banana. Today: **1,310 kcal / four foods**.
Both widgets: **1,310 kcal**. Explicitly revoked DEBUG Pro and verified
**MACROS Pro, Free** in Settings. Left the unchanged Home Screen layout visible,
cleared the status-bar override, stopped the owned recorder, and released the
media simulator lock. No other simulators were used.

## Half-second timeline

Times below sample the final encoded video, not wall-clock tool latency.

| Time | Screen / action |
| --- | --- |
| 0.0 | Today, 1,310 |
| 0.5 | Today, before Add Food |
| 1.0 | Add Food presenting |
| 1.5 | Add Food search list |
| 2.0 | Add Food search list |
| 2.5 | Search focus and keyboard presentation |
| 3.0 | Banana search, complete keyboard |
| 3.5 | Banana results |
| 4.0 | Banana results |
| 4.5 | Banana results |
| 5.0 | Banana Log Food push |
| 5.5 | Log Food form |
| 6.0 | Log Food dismissal / ring update |
| 6.5 | Today, 1,415 |
| 7.0 | Today, 1,415 |
| 7.5 | Banana edit sheet begins |
| 8.0 | Edit Entry |
| 8.5 | Edit Entry quantity |
| 9.0 | Serving increment |
| 9.5 | Serving increment |
| 10.0 | Serving increment |
| 10.5 | Two servings |
| 11.0 | Edit form scrolling toward Save |
| 11.5 | Save Changes visible |
| 12.0 | Two servings, 210 kcal |
| 12.5 | Two servings, 210 kcal |
| 13.0 | Two servings, Save Changes |
| 13.5 | Save dismissal |
| 14.0 | Today, rings updating to 1,520 |
| 14.5 | Today, 1,520 |
| 15.0 | Today, 1,520 |
| 15.5 | Insights navigation push |
| 16.0 | Unlocked 30-day Insights |
| 16.5 | Unlocked Insights |
| 17.0 | Chart scroll |
| 17.5 | Calories and macro charts |
| 18.0 | Insights immediately before Home zoom |
| 18.5 | Home zoom finishing, widgets 1,520 |
| 19.0 | Home Screen hold, widgets 1,520 |
| 19.5 | Home Screen hold, dock visible |
| 20.0 | Fade to black |
| 20.5 | Fade finishing |
| 21.0 | End card, rings filling |
| 21.5 | End card, rings filled |
| 22.0 | MACROS / Coming soon to iPhone |
| 22.5 | End card hold |
| 23.0 | End card hold (ends at 23.067) |
