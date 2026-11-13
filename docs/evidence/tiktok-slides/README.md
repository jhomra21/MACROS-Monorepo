# TikTok photo slideshows

Five sets of five 1080 x 1920 stills and a 1080 x 1080 avatar, rendered from `tools/media/trailer/` with `bun run render:slides`. The PNGs are not tracked (`build/marketing/tiktok/`). Each JPG here is one set: the five slides at 300 px wide on top, the same five below with the TikTok zones outlined in red (top 150 px, bottom 380 px, right 140 px). Regenerate with `bun run sheets:slides`.

| Sheet | Set |
| --- | --- |
| `set-1-protein-math.jpg` | Protein math |
| `set-2-serving-on-the-box.jpg` | The serving on the box |
| `set-3-why-my-email.jpg` | Why my email? |
| `set-4-breakfast-at-your-desk.jpg` | Breakfast at your desk |
| `set-5-before-dinner.jpg` | Before dinner |

## Checks

- All 25 slides are 1080 x 1920 and `avatar.png` is 1080 x 1080 (`file`).
- Every slide viewed. No headline wraps past two lines; one headline size (74 px) throughout, with the CTA slide's text scaled by the same factor (MACROS 144 px, intro 45 px, CTA 53 px, site 41 px). 74 px is the largest size that keeps every headline in two lines: at 75 px "Breakfast again. First meeting in five minutes." wraps to three lines, so 96-110 px does not fit this copy. Measured from the rendered PNGs, all headline ink sits inside x 120-940 (widest: set 4 slide 1, x 127-933). Text is clear of the top 150 px and bottom 380 px. The phone is the trailer's bezel at the same size and place on every slide that has one; it extends into the bottom zone, which is allowed because no text is there.
- Claims against the screenshots and site:
  - "Eight servings. In this one box." `app-scan-review.png` shows "8 servings per container" on the label (zoomed to confirm; it is small in the 1320 px capture).
  - "Scanning is free." `web/src/data/site.ts` FAQ: logging, search, barcode and label scans are free; Pro is optional.
  - "Half the bag? Make it half." `app-scan-details.png` shows the Servings/Grams review; the servings stepper there steps 0.25.
  - "Mine doesn't. Open it and log." and "Your diary stays on your phone." match the FAQ ("You can log food without an account") and the on-device storage rule.
  - "Same yogurt as yesterday." and "There it is." sit on `app-add-food.png`, which shows a "greek yogurt" search with Plain Greek yogurt cup under On Device.
- Slides showing calculator targets or Insights-like totals (Today ring, widgets) carry a "Demo data" label beside the phone.
- Home Screen slides (set 5, slides 3-4) use `tools/media/trailer/public/sources/home-clean.png` (ignored), a still of the trailer's Home Screen after logging. It is frame 20.0 s of `build/marketing/trailer/sources/v3/flow-take1.mov` (the same take `home.mp4` is cut from, 17.6-22.6 s), 1320 x 2868. Checked by eye: only the MACROS icon and the MACROS widgets are visible. No third-party app icon, label, widget or shared-person widget. `app-widgets.png` was dropped because it shows third-party apps (Fitness, Watch, Files) and a shared-person widget, which Apple's marketing rules do not allow on a Home Screen shot.
- CTA: the site has a waitlist form (`WaitlistForm.astro` on the home and about pages), so slide 5 reads "Coming soon for iPhone. Join the waitlist."
