# Launch trailer (vertical)

Status: active. Owner request 2026-11-11: replace the bland screen-recording demo with an announcement-style trailer, inspired by Apple's product films, for Instagram Reels, YouTube Shorts and TikTok. The owner adds music later.

## Output

- 1080 × 1920, 30 fps, H.264 MP4, 30.0 s (900 frames), with a silent stereo AAC track so editors accept it.
- Two end-card variants from one project: `coming-soon` ("Coming soon to iPhone") and `app-store` (Apple's black "Download on the App Store" badge, static).
- A cover frame PNG (first strong frame) for Reels/TikTok covers.
- Renders go to ignored `build/marketing/trailer/`. Only code, README and evidence are tracked.

## Tooling

Remotion project in `tools/media/trailer/` (Bun). Reasons:

- Remotion Studio runs in the browser, so the owner can scrub, retime and re-render without a desktop editor.
- Remotion is free for individuals and companies of up to three people.
- Diffusion Studio Core (the owner's suggestion) renders in the browser too, but its free tier requires a "Made with Diffusion Studio" watermark unless a license key is bought (README, Nov 2025). Revisit if the owner buys a key.

## Rules that shape the design

Apple's App Store marketing guidelines (Apple Product Images):

- Use Apple's official product bezel, unmodified: no tilt, spin, flip, 3D, reflections, shadows, highlights, cropping, obstruction, or animating the device image. Nothing may appear to come out of the screen.
- Copy goes beside the device, never on top of it.
- Status bar: full signal, Wi-Fi and battery. Home Screen only to show our widget, with no third-party content.
- One App Store badge per video. Do not modify, angle or animate it; keep it subordinate to the main message.
- Use fictional data, never a real person's.

So the device never moves inside a shot, and there are no push-ins. Every app shot sits inside the bezel at one size and position. Motion comes from the app recording itself, the type, the counters and hard cuts between shots. There are no bezel-free close-ups.

Platform safe zones on a 1080 × 1920 canvas (Instagram: top 250, bottom 320, sides 120; TikTok: top 160, bottom 480, sides 120; Shorts: top 380, bottom 380, left 60, right 120). Keep all text and the key part of every shot inside the shared safe area **x 120–960, y 380–1440**. The device may extend beyond it, but nothing that must be read may sit there.

## Visual system

One bold style, tidied toward Apple's announcement look: centred, one idea at a time.

- Background: a full colour field per shot in the ring colours (protein `#007AFF`, carbs `#FF9F0A`, fat `#EF4F87`). Text is near-black `#0A0A0C` (4.92, 9.62 and 5.78:1; white on `#007AFF` is 4.02:1).
- Type: Inter (OFL). Headlines 150 px / 700, letter-spacing -0.03em, revealed word by word (0.2 s apart), at most two lines, bottom-aligned at y 380-680. Support line 48 px / 500 at y 700. Counter 72 px with a 36 px label at y 780, smaller than the headline and always in the same place. SF Pro is not used: its license covers interface mock-ups, not marketing films.
- Counters count from 0 (or the real start value) to the value the recording shows, start at the cut and land within 1 s. They stay hidden until counting starts, so none rests at 0.
- Device: Apple's iPhone 18 Pro Max bezel at 0.34 scale, centred, top at y 890, identical in every app shot, static. The recording fills the screen opening at native 1320 x 2868.
- Cuts are hard and land on a 0.5 s grid (120 BPM); a beat sheet is in the tool README.

## Shot list (seconds)

| Time | Shot | On screen |
| --- | --- | --- |
| 0-2 | Hook | Today before logging, 1310 kcal. "Log your food." then, on the 1.0 s beat, "Get on with your day." Counter 0 to 1310. |
| 2-6 | Search | "Search it." Type it, tap it, done. Search "banana", Banana, the Log Food form (stops before the Log tap). Counter 105 kcal per banana. |
| 6-12 | Scan | "Scan it." Barcodes and nutrition labels. Camera, barcode, Chocolate Dough Protein Bar result card (200 kcal), Logged. Counter 200 kcal logged. |
| 12-16 | Rings | "Rings fill as you go." Banana logged: the sheet dismisses and Today rolls 1310 to 1415 kcal. |
| 16-20 | Track | "Track it." Insights scroll. Counter 125.7 g protein, 30-day avg. |
| 20-25 | Glance | "Glance at it." The full Home Screen page with only the MACROS widgets and icon, showing 1415. |
| 25-27 | Type | "Search." "Scan." "Track." "Done." on successive beats. |
| 27-30 | End card | App icon, "MACROS", then "Coming soon to iPhone" or the App Store badge; `macrosios.com` small. |

Every claim must match current app behaviour. Recordings may be trimmed (prefer cutting idle frames) and played at most 1.5×; no faked UI. The v3 edit plays no clip faster than 1.2× (only Insights, at 1.2×).

## Sources

Full-resolution simulator recordings on the Mac (1320 × 2868, 30 fps): App Store clips under the `dashboard-tutorial-evidence` worktree `docs/app-store/media/clips/`, teaser raw takes under `camera-zoom/build/marketing/teaser/`. Copy into ignored build folders; never track recordings or Apple bezel files.

## Validation

- Render both variants; check duration 30.0 s, 900 frames, 1080 × 1920, H.264, AAC silent track.
- Contact sheet at 2 fps, a safe-zone overlay sheet, and the end cards, tracked under `docs/evidence/trailer/` within the 5-image, 2 MiB policy.
- Check every shot against the Apple rules above.

## Open

- Owner adds music; picks the variant to post depending on App Review timing.
