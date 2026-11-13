# Instagram 4:5 carousel

Five sets of five 1080 x 1350 stills (4:5) with the short headlines, rendered from `tools/media/trailer/` with `bun run render:slides:instagram --out=<dir>`. The PNGs and `captions.md` are not tracked. Each JPG here is one sheet for one set: the five slides at 300 px wide.

Tracked sheets (two images, about 180 KB together):

| Sheet | Shows |
| --- | --- |
| `set-1-protein-math.jpg` | Protein math, 1500 x 375 |
| `set-5-before-dinner.jpg` | Before dinner, 1500 x 375 |

Regenerate a sheet from a render with `ffmpeg`, using five slides in order:

```sh
ffmpeg -i <dir>/set-5-before-dinner/1.png -i <dir>/set-5-before-dinner/2.png -i <dir>/set-5-before-dinner/3.png -i <dir>/set-5-before-dinner/4.png -i <dir>/set-5-before-dinner/5.png \
  -filter_complex "[0:v]scale=300:-1[s0];[1:v]scale=300:-1[s1];[2:v]scale=300:-1[s2];[3:v]scale=300:-1[s3];[4:v]scale=300:-1[s4];[s0][s1][s2][s3][s4]hstack=5[out]" \
  -map "[out]" -q:v 4 -frames:v 1 -y set-5-before-dinner.jpg
```

## Layout

- Marker row, y 60 to 130, x 90 to 990: the rings icon at top left (scale 0.27, 70 px) on set slide 1 only, as in TikTok, and `n/5` at top right.
- Headline: one size for every slide, 110 px, weight 700, line height 1.08, `short` copy, at most two lines in a box x 90 to 990. The box starts at y 180, 50 px under the marker row.
- Phone: Apple's unmodified bezel at scale 0.2881 (423.6 x 864.4 px), centred, top y 461.6, box y 461.6 to 1326.0. That is 24 px above the bottom edge. Every phone slide uses the same size and place. Set 3 slide 1 and the five CTA slides have no phone.
- Type-only slide and CTA slides are centred in y 130 to 1290.
- No "Demo data" label exists in the slide code.

## Size

The headline size is the largest whole-pixel size where every short headline stays within two lines. Measured on the renders: 108 and 110 px pass. 111 px puts "Serving size" isn't your portion. on three lines (set 2 slide 1), so 110 px is the limit. At 110 px the phone top is 461.6, which is the headline box bottom plus 44 px. The ink of a two-line headline ends about 2 px under its box, so the clear space above the bezel is at least 40 px.

## Checks

- All 25 stills are 1080 x 1350.
- Ink is any pixel with R, G and B all at or below 60. Measured on the renders with ffmpeg and a short Python script:
  - Headline lines per slide: at most two. Ink spans x 98 to 981, inside the 90 to 990 box and at least 60 px from the edges.
  - Lowest headline ink to bezel top: at least 40.6 px on every phone slide.
  - The bezel box lies inside the canvas, with a 24 px bottom margin.
- TikTok is unchanged: all 25 short TikTok stills are byte-identical to the renders from before this change.
- Every still was viewed.
