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

So the device never moves inside a shot. Motion comes from the app recording itself, the type, the background, and hard cuts between shots. Close-ups of the app UI without the bezel are allowed and carry the "zoom" moments.

Platform safe zones on a 1080 × 1920 canvas (Instagram: top 250, bottom 320, sides 120; TikTok: top 160, bottom 480, sides 120; Shorts: top 380, bottom 380, left 60, right 120). Keep all text and the key part of every shot inside the shared safe area **x 120–960, y 380–1440**. The device may extend beyond it, but nothing that must be read may sit there.

## Visual system

- Background: near-black `#0A0A0C`. Each section gets a soft, slow full-frame color wash from one ring color (protein `#007AFF`, carbs `#FF9F0A`, fat `#EF4F87`), kept dark enough that white text stays at least 7:1 contrast.
- Type: Inter (OFL), weight 700 for headlines, letter-spacing −0.03em, white; supporting lines weight 500, `#A1A1A6`. Headlines 128–150 px, supporting 48–56 px. SF Pro is not used: its license covers interface mock-ups, not marketing films.
- Text motion: enter with a 16 px rise and fade over 0.35 s, ease-out `cubic-bezier(0.2, 0.8, 0.2, 1)`. Leave on a hard cut. One idea on screen at a time.
- Device: Apple's iPhone bezel matching the recording resolution, about 1000–1080 px tall, centered horizontally, below the headline. Static within each shot.
- Close-ups: the recording cropped and scaled up to 1.6–2×, with 56 px rounded corners. No bezel.
- Cuts land on a 0.5 s grid (120 BPM), so any 120 BPM track lines up; a beat sheet is in the tool README.

## Shot list (seconds)

| Time | Shot | On screen |
| --- | --- | --- |
| 0.0–2.0 | Hook, close-up | Today rings rolling up after a log (1310 to 1415 kcal). "Log your food." then, on the 1.0 s beat, "Get on with your day." |
| 2.0–8.0 | Device | "Search it." Supporting: "Type it, tap it, done." The search-and-log flow for a banana, idle time cut. |
| 8.0–13.0 | Close-up, no bezel | "Scan it." Supporting: "Barcodes and nutrition labels." The earlier edit's scan: camera on a protein bar, result card, Logged. Cropped below its status bar and pill. |
| 13.0–17.0 | Close-up | Rings and totals animating to 1415 kcal after the log. "Rings fill as you go." |
| 17.0–21.0 | Device | "Track it." Supporting: "Weight and calories, over time." Insights scroll. |
| 21.0–25.0 | Close-up | "Glance at it." Supporting: "Home Screen widgets." Large MACROS widget crop of the Home Screen. |

Styles (prop `style`): `restrained` uses near-black with a visible colour wash and 150 px type; `bold` uses solid ring-colour fields, 180–200 px type revealed word by word, counters taken from the recordings, and a 1.0 to 1.08 push-in on close-ups only. Bold text is near-black `#0A0A0C` (white on `#007AFF` is 4.02:1).
| 25.0–27.0 | Type | "Search." "Scan." "Track." on successive beats, then "Done." |
| 27.0–30.0 | End card | App icon, "MACROS", then "Coming soon to iPhone" or the App Store badge; `macrosios.com` small. |

Every claim must match current app behaviour. Recordings may be trimmed (prefer cutting idle frames) and played at most 1.5×; no faked UI. The v2 edit plays no clip faster than 1.2×.

## Sources

Full-resolution simulator recordings on the Mac (1320 × 2868, 30 fps): App Store clips under the `dashboard-tutorial-evidence` worktree `docs/app-store/media/clips/`, teaser raw takes under `camera-zoom/build/marketing/teaser/`. Copy into ignored build folders; never track recordings or Apple bezel files.

## Validation

- Render both variants; check duration 30.0 s, 900 frames, 1080 × 1920, H.264, AAC silent track.
- Contact sheet at 2 fps, a safe-zone overlay sheet, and the end cards, tracked under `docs/evidence/trailer/` within the 5-image, 2 MiB policy.
- Check every shot against the Apple rules above.

## Open

- Owner adds music; picks the variant to post depending on App Review timing.
