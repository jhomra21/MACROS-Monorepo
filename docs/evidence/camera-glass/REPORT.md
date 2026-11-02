# Camera controls: native Liquid Glass

Branch `fix/camera-concentric-corners`. Code in `FoodCameraSheet.swift`.

## Which screenshot is which (from pixels)

- `owner-ours-IMG_3307.jpg` is ours: the shutter ring is a 1 pt line (3 px at 3x, edges at x=555..559 and the disc starts at 578), and the side circles are flat and dark with no rim highlight.
- `owner-chatgpt-IMG_3295.jpg` is ChatGPT's: the shutter ring is a thick glass band (x=561..581, about 6.7 pt) with a specular rim, and the side circles have a visible edge highlight and refraction.

## Measured sizes (both screenshots are 1320 px wide, 3x, same scale)

| Element | Ours before | ChatGPT | After (this change) |
| --- | --- | --- | --- |
| Side button diameter | 124 px = 41 pt (40 pt glass) | 135 to 136 px = 45 pt | 44 pt glass, 44 pt hit target |
| Shutter outer diameter | 208 px = 69 pt (68 pt frame) | 195 px = 65 pt | 66 pt glass ring, 68 pt hit target |
| Shutter white disc | 162 px = 54 pt | 156 px = 52 pt | 52 pt |
| Shutter ring thickness | about 1 pt line | about 6.7 pt glass | 7 pt glass |

The brief estimated side circles at about 52 pt. The measured ChatGPT side circles are 45 pt (the 52 pt figure matches the white shutter disc), so the side buttons are 44 pt, the minimum hit target.

Measured finding that differs from the brief: ChatGPT's side circles are not lighter than ours. Mean luminance of the circle body against the background just outside it is 55 vs 142 for ChatGPT and 33 vs 92 for ours (ratio 0.39 vs 0.36), so both read as dark smoked glass. What ChatGPT has and ours lacked is the glass rim highlight and refraction, plus the thick glass shutter ring. After this change the side buttons are clear glass over a 35% dimming gradient, so they read lighter and more transparent than ChatGPT's over bright scenes (see the bright capture). If the owner wants ChatGPT's darker look, raise the gradient opacity; do not tint the glass.

## Glass variant: `.clear.interactive()`

Apple HIG, Materials (`https://developer.apple.com/design/human-interface-guidelines/materials`):

> The *clear* variant is highly translucent, which is ideal for prioritizing the visibility of the underlying content and ensuring visually rich background elements remain prominent. Use this variant for components that float above media backgrounds — such as photos and videos — to create a more immersive content experience.

> If the underlying content is bright, consider adding a dark dimming layer of 35% opacity.

The camera viewport is live media, so the side buttons and shutter use `.glassEffect(.clear.interactive(), in: Circle())` with no tint. `controlsDimmingLayer` is a bottom gradient (clear to 35% black, 220 pt tall) behind the controls, hidden while a result is frozen (the controls are hidden then too). `Glass` documents `regular`, `clear`, `identity`, `tint(_:)` and `interactive(_:)`; `glassEffect(_:in:)` anchors the material to the view bounds; `GlassEffectContainer` blends shapes as they approach each other by `spacing`.

## Container decision

The shutter is not in a `GlassEffectContainer`. Back (leading), shutter (centre) and the options stack (trailing) are far apart, and a shared container would only risk blending the shutter into a side button. The options stack keeps its existing `GlassEffectContainer(spacing: 12)` with `glassEffectID` and `.matchedGeometry`, unchanged apart from the removed tint.

## Evidence (iPhone 17e, iOS 27.0, 3x, simulator has no camera)

The simulator cannot run the live scanner, so the "no camera" branch (`canLiveScan == false`) is what renders. For the bright and dark cases a throwaway, uncommitted debug patch drew a photo behind the controls (a crop of the macOS Sonoma Horizon wallpaper, bright and dark regions). It was not committed.

- `before-bright.png`, `before-dark.png`, `before-placeholder.png`: ea38ea2.
- `after-bright.png`, `after-dark.png`, `after-placeholder.png`: first pass, glass only, no dimming layer. Over bright content the white icons are weak.
- `after-scrim-bright.png`, `after-scrim-dark.png`, `after-scrim-placeholder.png`: committed code (glass plus dimming layer).
- `side-by-side-after-vs-chatgpt.png`: before (owner screenshot), after, and ChatGPT, all at 3x.
- `tests.log`: `FoodCameraFlowTests` on the iPad.

Placeholder state: `foregroundStyle(canLiveScan ? .white : .primary)` still applies. The glyphs render white on the dark-gray placeholder because the sheet forces `.environment(\.colorScheme, .dark)`, so `.primary` resolves to white.

## Validation

- `make quality-format-check`: clean.
- `make quality-build`: succeeded.
- `FoodCameraFlowTests` on iPad `E91B597B`: 25 tests, 0 failures.

## Not verified

- A real camera feed (no camera in the simulator).
- The expanded options morph animation on screen; the code path is unchanged apart from removing the tint and the inner 40 to 44 pt frame.
- Reduce Transparency and Increase Contrast rendering.
- Press feedback from `.interactive()` (static captures only).
