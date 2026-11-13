# TikTok photo slideshows

Five sets of five 1080 x 1920 stills with the short headlines, and a 1080 x 1080 avatar, rendered from `tools/media/trailer/` with `bun run render:slides`. The PNGs are not tracked: they are in `build/marketing/tiktok/`. Each JPG here is one sheet for one set: the five slides at 300 px wide, with the same five below under the TikTok zone outlines. Regenerate with `bun run sheets:slides`.

Headlines are the shorter `short` set in `src/slides.ts`, one size (100 px) across all slides, at most two lines.

Tracked sheets (five images, under the 2 MiB limit):

| Sheet | Shows |
| --- | --- |
| `set-1-protein-math.jpg` | Protein math |
| `set-2-serving-on-the-box.jpg` | The serving on the box |
| `set-3-why-my-email.jpg` | Why my email? (slide 1 has no phone) |
| `set-4-breakfast-at-your-desk.jpg` | Breakfast at your desk |
| `set-5-before-dinner.jpg` | Before dinner |

The zone outlines are red: top 150 px, bottom 380 px, right 140 px.

## Phone layout

- The icon and the `n/5` marker are unchanged. The marker's baseline is at y 233.
- The headline block starts at y 290. The headline ink starts at y 303 to 307, 74 px below the marker baseline.
- Each phone slide has the bezel at y 560, 52 px below the lowest headline ink of the tallest two-line headline (y 507). Text never overlaps the bezel.
- The bezel is scaled to 0.4453 of Apple's PNG (654.6 x 1335.9 px), centred horizontally. Its box is x 212.7 to 867.3, y 560 to 1895.9, so it stays 24 px inside the bottom edge. The black frame ends at y 1886 because the PNG has a transparent strip under the frame.
- The phone extends into TikTok's bottom 380 px zone. No text is there.
- Set 3 slide 1 (no phone) and the five CTA slides keep their layout.

## Checks

- All 25 short stills are 1080 x 1920 (`ffprobe`).
- Pixel measurements on the rendered PNGs (ink is any channel at or below 60):
  - Icon and marker rows (y 150 to 265) are byte-identical to the previous render on all 25 slides.
  - Set 3 slide 1 and the five CTA slides are byte-identical to the previous render, and so is the avatar.
  - Each headline is one or two lines. On every phone slide, the headline ink ends above y 508, so none of it touches the bezel box (y 560 to 1896, x 213 to 867).
  - The bezel box lies inside the 1080 x 1920 canvas.
- Headline size is unchanged (100 px), and so are the line limits. The width checks from the earlier render still hold, since the words and size are the same.
- Copy: the five approved short headlines are used. The "Demo data" label is removed from every slide, and the flag and its field are gone from `src/slides.ts`. Screenshots, captions and the CTA are unchanged.
- Claims against the screenshots and site (unchanged):
  - "Eight servings. In this one box." `app-scan-review.png` shows "8 servings per container" on the label (zoomed to confirm; it is small in the 1320 px capture).
  - "Scanning is free." `web/src/data/site.ts` FAQ: logging, search, barcode and label scans are free; Pro is optional.
  - "Half the bag? Make it half." `app-scan-details.png` shows the Servings/Grams review; the servings stepper there steps 0.25.
  - "Mine doesn't. Open it and log." and "Your diary stays on your phone." match the FAQ ("You can log food without an account") and the on-device storage rule.
  - "Same yogurt as yesterday." and "There it is." sit on `app-add-food.png`, which shows a "greek yogurt" search with Plain Greek yogurt cup under On Device.
- Home Screen slides (set 5, slides 3-4) use `tools/media/trailer/public/sources/home-clean.png` (ignored), a still of the trailer's Home Screen after logging. It is frame 20.0 s of `build/marketing/trailer/sources/v3/flow-take1.mov` (the same take `home.mp4` is cut from, 17.6-22.6 s), 1320 x 2868. Checked by eye: only the MACROS icon and the MACROS widgets are visible. No third-party app icon, label, widget or shared-person widget. `app-widgets.png` was dropped because it shows third-party apps (Fitness, Watch, Files) and a shared-person widget, which Apple's marketing rules do not allow on a Home Screen shot.
- CTA: the site has a waitlist form (`WaitlistForm.astro` on the home and about pages), so slide 5 reads "Coming soon for iPhone. Join the waitlist."
