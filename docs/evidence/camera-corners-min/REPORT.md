# Camera bottom-corner minimum evidence

Simulator: iPhone 17 (`918D29B9-97D3-42C0-9C47-00605E01E8DB`), iOS 27.0, Xcode 26.4.1. The simulator was not erased.

## Artifacts

- `before-contact.png`: 10-second video of the pre-fix build, from Dashboard to the camera entry.
- `after-contact.png`: 26-second video of the fixed build while the camera view remained open.

## Findings and limits

The pre-fix recording shows the Dashboard followed by the camera view; it does not capture a clear mid-zoom frame, so it cannot independently establish the reported square-corner frame. The post-fix recording shows rounded bottom corners on the settled viewport in every sampled frame. This simulator reports “Camera unavailable” and displays the app's fallback camera surface, so these captures cannot establish a 28 pt measurement or the settled 46 pt concentric radius, nor do they prove all intermediate zoom frames. The source now specifies `.concentric(minimum: 28)`, which Apple documents as the floor applied when the computed concentric radius falls below the minimum.

The requested empirical all-frame comparison remains unverified in this simulator environment.

## Validation

- `make quality-format-check`: passed.
- `make quality-build`: passed.
- `FoodCameraFlowTests` on iPad Air 11-inch (`E91B597B-CE57-4C0B-A8A4-51CBDC3386AB`): 25 passed, 0 failures.
