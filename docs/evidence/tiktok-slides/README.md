# TikTok photo slideshows

Five sets of five 1080 x 1920 stills per headline variant, and a 1080 x 1080 avatar, rendered from `tools/media/trailer/` with `bun run render:slides`. The PNGs are not tracked: `build/marketing/tiktok/` holds the `short` variant (the default) and `build/marketing/tiktok-full/` holds `full`. Each JPG here is one sheet of five slides at 300 px wide. Regenerate with `bun run sheets:slides`.

Two headline variants:

- `short`: the shorter headlines in `src/slides.ts`, one size (100 px) across all slides, at most two lines.
- `full`: the original headlines, one size (105 px) across all slides, at most three lines.

Tracked sheets (five images, about 1.5 MB, under the 2 MiB limit):

| Sheet | Shows |
| --- | --- |
| `set-2-serving-on-the-box.jpg` | Serving on the box, short; top row normal, bottom row with TikTok zones outlined |
| `set-3-why-my-email.jpg` | Why my email?, short; same layout |
| `set-5-before-dinner.jpg` | Before dinner, short; same layout |
| `compare-set1.jpg` | Protein math, short (rows 1-2) above full (rows 3-4); each variant normal, then with zones |
| `compare-set4.jpg` | Breakfast at your desk, short (rows 1-2) above full (rows 3-4); same order |

The zone outlines are red: top 150 px, bottom 380 px, right 140 px.

## Checks

- Every slide of both variants viewed in the sheets, including the zone copies.
- All 50 normal-render stills are 1080 x 1920 and both avatars are 1080 x 1080 (`file`).
- Headline sizes are the largest found that keep each variant within its line limit, measured from the rendered PNGs (ink in y 280-880 for slides with a phone, so the phone is never counted):
  - `short` 100 px: every headline two lines or fewer; widest headline ink 804 px (set 2 slide 1). 102 px puts set 2 slide 1 on three lines. 101 px was not rendered.
  - `full` 105 px: every headline three lines or fewer; widest headline ink 799 px (set 3 slide 4). 110 px puts set 4 slide 1 on four lines, and 120 px puts set 1 slide 1 and set 3 slide 1 on four lines. 106 to 109 px were not rendered.
  - All headline ink sits inside x 120-940 and below y 150. The lowest headline ink on a slide with a phone ends by y 692; the phone starts at y 890, so the phone did not move.
- Copy changes are only the five approved short headlines. The CTA slide, the screenshots, the "Demo data" flags and the captions are unchanged.
- Claims against the screenshots and site (unchanged by the variants):
  - "Eight servings. In this one box." `app-scan-review.png` shows "8 servings per container" on the label (zoomed to confirm; it is small in the 1320 px capture).
  - "Scanning is free." `web/src/data/site.ts` FAQ: logging, search, barcode and label scans are free; Pro is optional.
  - "Half the bag? Make it half." `app-scan-details.png` shows the Servings/Grams review; the servings stepper there steps 0.25.
  - "Mine doesn't. Open it and log." and "Your diary stays on your phone." match the FAQ ("You can log food without an account") and the on-device storage rule.
  - "Same yogurt as yesterday." and "There it is." sit on `app-add-food.png`, which shows a "greek yogurt" search with Plain Greek yogurt cup under On Device.
- Slides showing calculator targets or Insights-like totals (Today ring, widgets) carry a "Demo data" label beside the phone.
- Home Screen slides (set 5, slides 3-4) use `tools/media/trailer/public/sources/home-clean.png` (ignored), a still of the trailer's Home Screen after logging. It is frame 20.0 s of `build/marketing/trailer/sources/v3/flow-take1.mov` (the same take `home.mp4` is cut from, 17.6-22.6 s), 1320 x 2868. Checked by eye: only the MACROS icon and the MACROS widgets are visible. No third-party app icon, label, widget or shared-person widget. `app-widgets.png` was dropped because it shows third-party apps (Fitness, Watch, Files) and a shared-person widget, which Apple's marketing rules do not allow on a Home Screen shot.
- CTA: the site has a waitlist form (`WaitlistForm.astro` on the home and about pages), so slide 5 reads "Coming soon for iPhone. Join the waitlist."
