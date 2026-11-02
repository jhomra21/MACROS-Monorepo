# Camera side buttons: smoked glass candidates

Branch `fix/camera-concentric-corners`, `FoodCameraSheet.swift`. iPhone 17e, iOS 27.0, 3x, no camera in the simulator (placeholder branch). The test background is a throwaway, uncommitted crop of the Sonoma Horizon wallpaper drawn behind the viewport (bright crop, dark crop), same method as `docs/evidence/camera-glass/REPORT.md`. Reverted.

Measurement: mean luminance (Rec. 709 on sRGB bytes) of the circle body (0.55 to 0.85 of the radius) divided by the ring just outside (1.25 to 1.6 radius), Back button, same spot, same bright photo. Median of three y positions was stable within 0.01.

| Variant | Glass | Gradient | Body | Background | Ratio |
| --- | --- | --- | --- | --- | --- |
| ChatGPT (target, owner screenshot) | n/a | n/a | 55.4 | 142.0 | 0.39 |
| Before (this branch head) | clear | 35% | 194.0 | 168.7 | 1.15 |
| a | regular | none | 173.2 | 217.1 | 0.80 (different, brighter background) |
| b | clear | 55% | 167.9 | 141.0 | 1.19 |
| c (chosen) | regular | 35% | 154.3 | 168.6 | 0.92 |
| d (extra) | regular | 55% | 140.2 | 140.9 | 0.99 |

Over the dark photo (body/background): before 2.89, a 2.44, b 3.31, c 2.92.

## Result

No system-glass variant reaches 0.39. The test photo is very bright (background 169 to 217 vs 142 for ChatGPT's capture), and `.regular` renders as a light grey disc, not smoke. The old black-tint look (0.36) is only reachable with `.tint(.black...)`, which was ruled out.

- a has the lowest raw ratio, but with no scrim the background is 217, the disc is flat grey, and the rim highlight is barely visible. Icon contrast is the weakest.
- b (more dimming on clear glass) darkens the surroundings, not the disc: the disc stays lighter than its background (1.19), the milky look remains.
- c darkens the disc below its background (0.92), keeps the rim highlight and refraction, white icons stay legible (also over the dark photo and the placeholder). Chosen.
- d is no closer than c (0.99) because the gradient lowers the background as much as the body.

Applied c to all three side-button sites (Back, options toggle, expanded options). The `GlassEffectContainer`/`glassEffectID` morph is unchanged. The shutter stays `.clear.interactive()`: it is a thin ring around a white disc, and regular glass did not change its look.

## Not verified

Live camera feed, press feedback, Reduce Transparency / Increase Contrast, the options morph on screen.

## Validation

`make quality-format-check` clean, `make quality-build` succeeded, `FoodCameraFlowTests` on iPad `E91B597B`: 25 tests, 0 failures (`tests.log`).

Files: `side-by-side-candidates.png` (ChatGPT crop, before, a, b, c, c over dark photo, c placeholder, all 3x), per-variant full screenshots `<variant>-<bright|dark|none>.png` (`base` = before).
