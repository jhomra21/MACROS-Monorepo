# TikTok photo slideshows

Five sets of five 1080 x 1920 stills with the short headlines, and a 1080 x 1080 avatar, rendered from `tools/media/trailer/` with `bun run render:slides`. The PNGs are not tracked: they are in `build/marketing/tiktok/`. Each JPG here is one sheet for one set: the five slides at 300 px wide, with the same five below them, outlined in red with TikTok's photo-mode overlays. Regenerate with `bun run sheets:slides`, which renders the review copies itself.

Headlines are the shorter `short` set in `src/slides.ts`, one size (100 px) across all slides, at most two lines.

Tracked sheets (five images, about 1.04 MiB together, under the 2 MiB limit):

| Sheet | Shows |
| --- | --- |
| `set-1-protein-math.jpg` | Protein math |
| `set-2-serving-on-the-box.jpg` | The serving on the box |
| `set-3-why-my-email.jpg` | Why my email? (slide 1 has no phone) |
| `set-4-breakfast-at-your-desk.jpg` | Breakfast at your desk |
| `set-5-before-dinner.jpg` | Before dinner |

## Photo-mode overlays

TikTok draws its own UI over a photo post. The review sheets outline these four overlays, in image pixels of a 1080 x 1920 slide, measured on the owner's iPhone:

| Overlay | x | y | What it covers |
| --- | --- | --- | --- |
| Top bar | 0-1080 | 0-110 | TikTok's search bar and its own counter |
| Pill | 960-1060 | 150-190 | TikTok's "1/5" pill |
| Caption panel | 0-1080 | 1515-1920 | Caption, description and comment bar |
| Right column | 950-1080 | 1000-1920 | Like, comment and share buttons |

Text and the phone stay in the visible safe area: x 120-940, y 200-1480.

## Layout

- TikTok slides have no rings icon and no `n/5` marker. TikTok shows its own counter. Instagram keeps both.
- Headline: 100 px, weight 700, line height 1.08, in a box x 120-940 that starts at y 210. Each headline is one or two lines. The tallest headline's last ink row is y 428 (set 1 slide 4, set 3 slide 2, set 4 slide 1).
- Phone: Apple's unmodified bezel at scale 0.337 (495.4 x 1011.0 px), centred horizontally. Its box is x 292.3-787.7, y 469-1480, so it ends on the safe area's bottom edge. Its top is 40 px under the tallest headline's ink (ink edge at y 429, bezel at 469). Every phone slide uses the same size and place.
- Scale: the 40 px gap and the bottom edge at 1480 fix the size, so the scale is (1480 - 469) / 3000 = 0.337. Height is the limit, not width: the bezel is 495 px wide in an 820 px column.
- Set 3 slide 1 (type-only) and the five CTA slides are centred vertically in y 200-1480 (layout centre y 840). Their measured ink centres are y 836 (CTA) and y 848 (set 3 slide 1). The CTA rings mark stays: it is the end card, not the corner icon.
- Before this change, the headline started at y 290 and the bezel at y 560, scaled to 0.4453. The bezel ran to y 1887, under the caption panel on every phone slide.

## Checks

Pixel measurements on the 25 renders, with Pillow (the script is `build/evidence/tiktok-safe-area/measure.py`, not tracked). Content is any pixel that differs from the slide colour by more than 40 in any channel. Ink is a pixel with R, G and B all at or below 60, the headline colour.

| Check | Result |
| --- | --- |
| Content inside x 120-940, y 200-1480 | 25 of 25 slides. Content spans x 128-933 and y 222-1473. |
| Content pixels inside any overlay | 0 on all 25 slides (before this change, 189,000 to 228,000 px per phone slide under the caption panel) |
| Headline ink inside any overlay | 0 px on all 19 phone slides |
| Bezel box intersecting any overlay | None on all 19 phone slides |
| Black bezel frame inside the bezel box | Yes. Frame pixels span x 299-781, y 476-1473 inside x 292.3-787.7, y 469-1480. |
| Headline lines | 1 or 2 on every slide. None needs a third line. |
| Headline ink to bezel | 40 px at minimum (ink ends at y 428, bezel at 469). Other slides have more. |
| Headline ink x range | 128-932, inside x 120-940 |
| Headline ink top | y 223 (the box starts at y 210) |

Other checks:

- All 25 stills are 1080 x 1920.
- Instagram: the 25 stills and `captions.md` are byte-identical to the render from before this change (26 files compared, none differ).
- Copy is unchanged: headlines, screenshots and the CTA. `captions.md` is the current text from `origin/main` (commit `dfe4ec9`).

## Copy and claims

- "Eight servings. In this one box." `app-scan-review.png` shows "8 servings per container" on the label (zoomed to confirm; it is small in the 1320 px capture).
- "Scanning is free." `web/src/data/site.ts` FAQ: logging, search, barcode and label scans are free; Pro is optional.
- "Half the bag? Make it half." `app-scan-details.png` shows the Servings/Grams review; the servings stepper there steps 0.25.
- "Mine doesn't. Open it and log." and "Your diary stays on your phone." match the FAQ ("You can log food without an account") and the on-device storage rule.
- "Same yogurt as yesterday." and "There it is." sit on `app-add-food.png`, which shows a "greek yogurt" search with Plain Greek yogurt cup under On Device.
- Home Screen slides (set 5, slides 3-4) use `tools/media/trailer/public/sources/home-clean.png` (ignored), a still of the trailer's Home Screen after logging. It is frame 20.0 s of `build/marketing/trailer/sources/v3/flow-take1.mov` (the same take `home.mp4` is cut from, 17.6-22.6 s), 1320 x 2868. Checked by eye: only the MACROS icon and the MACROS widgets are visible. No third-party app icon, label, widget or shared-person widget. `app-widgets.png` was dropped because it shows third-party apps (Fitness, Watch, Files) and a shared-person widget, which Apple's marketing rules do not allow on a Home Screen shot.
- CTA: the site has a waitlist form (`WaitlistForm.astro` on the home and about pages), so slide 5 reads "Coming soon for iPhone. Join the waitlist."
