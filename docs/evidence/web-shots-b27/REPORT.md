# Build 27 Website Screenshot Refresh

- Source: `origin/main` at `67e85ad` (`chore: bump build 27`), captured on `D16C3D35-889F-404F-BDD4-C640A6DBC4EF` (iPhone 18 Pro Max, iOS 27.0), Debug build, 9:41 status bar.
- Loaded the app's Developer > Load Demo Data seed without erasing the simulator. Granted Debug Pro for the 30-day Insights capture.
- Captured home, Add Food, label review, history, 30-day Insights, settings, and Sharing list. Added Alex's person-detail screen, including rings, goals, Foods, and the sharing-scope control.
- Sharing screenshots use a temporary uncommitted Debug `-sharingUIHarness` fixture with Alex and Sam. No Convex production data or server-side disposable profiles were used. The harness source was removed after capture.
- Captured the widget Home Screen again and compared it with the October 30 image. The small and medium widgets look unchanged, so the website retains the existing `app-widgets.png`.
- Replaced screenshot comparisons are in `comparison-*.png`. Raw before/after captures are named `before-app-*.png` and `after-app-*.png`; `after-app-sharing-person.png` is the new feature capture.
- Regenerated `web/public/og.png` from the new home capture. Removed unreferenced `app-calendar.png`, `app-full-unlock.png`, `app-share.png`, and `app-sharing-settings.png`.

## Validation

- `bun run check`: passed (31 Astro files, no diagnostics).
- `bun run build`: passed, generated optimized WebP assets including the Alex detail screen.
- `make lint-js`: passed (93 files, 0 warnings, 0 errors).
- `git diff --check`: passed.
- The package has no separate web `lint` script; repository lint is `make lint-js`.

## Browser screenshots

- `local-hero-390-light.png` and `local-showcase-390-light.png` are local Astro preview captures. The showcase capture is incomplete: its lazy-loaded screenshot images are blank.
- `live-hero-390-light.png` and `live-hero-390-dark.png` capture the deployed hero at a 390 CSS-pixel viewport (780 × 1688 PNG at 2× device scale).
- `live-showcase-390-dark.png` contains decoded gallery images, but the page was scrolled too far to show the showcase heading. It is retained as a partial capture, not complete responsive evidence.
- The live page was confirmed to serve the new hashed `/_astro/*.webp` screenshot assets, including the Alex sharing-detail image. The live responsive screenshot set is incomplete; do not treat the blank showcase capture as visual evidence.
