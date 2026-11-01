# Camera viewport corner verification

## Evidence

- Baseline camera screenshot from `origin/main`: [baseline-camera.png](baseline-camera.png)
- Updated camera screenshot: [after-scanning.png](after-scanning.png)
- Bottom-corner comparison (300 px crop, before left / after right): [scanning-corners-comparison.png](scanning-corners-comparison.png)

The comparison overlays the target inset display arc in red and the display edge radius in blue. Red is the curve the viewport should follow after the 16 pt inset. The updated viewport follows that red arc; the baseline corner is visibly tighter.

## Radii

The iPhone 17 screenshot is 1206 × 2622 px, or 402 × 874 pt at 3×.

The display corner radius is **62 pt** (**186 px**). This value is listed for iPhone 17 by [ScreenCorners](https://github.com/kylebshr/ScreenCorners#values-reported), which reads the device's `_displayCornerRadius`. The source table lists iPhone 17, 17 Pro, 17 Pro Max, and Air at 62 pt.

| Surface | Before | After |
| --- | ---: | ---: |
| Viewport top corners | 28 pt / 84 px | 28 pt / 84 px |
| Viewport bottom corners | 28 pt / 84 px | 62 − 16 = **46 pt / 138 px** |

The bottom target is concentric with the display after preserving the 16 pt inset. The screenshot alignment confirms it resolves against the full-screen presentation's display shape, not a smaller navigation-stack shape that would fall back to a minimum.

## Other camera surfaces

- Result card: left unchanged. It sits at the top of the camera layout; its bottom corners are far from the display's bottom corners.
- Camera controls: left unchanged. They are circular controls positioned above the bottom safe area, not surfaces with bottom corners aligned to the display corners.

## Verification and limits

- `make quality-format-check`: passed.
- `make quality-build`: passed.
- `FoodCameraFlowTests` and `BarcodeImageScannerTests` on iPad Air simulator: 28 tests passed, 0 failures.
- Captured the scanning/error presentation on iPhone 17 without erasing the simulator. The simulator camera is unavailable, so live scanning was not verified.
- The simulator camera is unavailable. I added the repository nutrition-label fixture to the iPhone 17 photo library, but could not open the photo picker with the available simulator interaction tools; XcodeBuildMCP tap/snapshot failed because `SimulatorKit.framework` was missing from the selected Xcode. The barcode/label result card was not captured.
- The display radius was taken from the cited device-value table, not printed at runtime.
