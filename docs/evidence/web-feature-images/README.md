# Feature card screenshots

Verified locally on November 6, 2026. Nothing deployed; no simulators used.

`sheet.png` is the sole tracked evidence image (under 300 KB). It shows the complete `#why` section at 390 × 844, 768 × 1024, and 1440 × 900, light beside dark. Raw PNGs and JSON measurements live in ignored `build/evidence/2026-11-06-feature-images/`. The sticky navigation and off-section skip link are hidden only during section capture.

## Design and crops

Images sit above unchanged copy in rounded, hairline-bordered frames. Single-column phone, two-column tablet, original 7/5, 5/7, 6/6 desktop grid. The actual crops are fully visible, without further CSS cropping, tint, or image shadows. Existing accents and reveal behavior remain.

`tools/media/feature-crops.mjs` records deterministic Sharp crops from the original 1320 × 2868 screenshots. Coordinates are **left, top, width, height**:

| Card | Source | Rectangle |
| --- | --- | --- |
| Logging | app-home.png | 130, 350, 1060, 1140 |
| Scanning | app-scan-review.png | 48, 184, 1224, 810 |
| Privacy | app-history.png | 48, 750, 1224, 1330 |
| Your portion | app-scan-details.png | 48, 490, 1224, 1410 |
| Sharing | app-sharing.png | 58, 448, 1204, 696 |
| Widgets, small | app-widgets.png | 698, 284, 528, 528 |
| Widgets, medium | app-widgets.png | 94, 936, 1132, 528 |

The two personal widget crops are stacked on a transparent 1132 × 1088 canvas, with a 32px gap. Alex's shared widget is excluded.

## Weight and validation

At 1440px, six selected AVIF images total **58,155 bytes at 1×**, **102,252 at 2×**, and **109,319 at 3×**. Equivalent WebP candidates total 84,096 / 160,692 / 175,746 bytes. All are below 350 KB. Phone and tablet select 31,427 bytes at 1×. Measurements sum the selected files, excluding HTTP headers.

Passed frozen dependency installation, `bun run check` (48 files, zero diagnostics), `bun test src/worker.test.ts` (9 tests), `bun run build`, root Oxlint (135 files, zero findings), and `git diff --check`. The build emits a nonfatal Fontconfig default-config warning. Mechanical design scan found no issues.

Opened and reviewed all six section captures and the final contact sheet. Browser checks confirm six decoded images, no horizontal overflow, lazy/async image attributes, and accurate card-width `sizes`. Reduced-motion checks pass at 1×/2×/3×; cards remain visible with JavaScript disabled. No added client JavaScript. Final diff reviewed for unnecessary code.

## Repeat

From the repository root, install website dependencies with `cd web && bun install --frozen-lockfile`. Then:

```sh
bun tools/media/feature-crops.mjs
mkdir -p build/feature-tools
cd build/feature-tools && bun add playwright@1.65.0 && bunx playwright install chromium
```

Return to the root. Start `cd web && bun run dev:worker --port 8798` in a separate terminal, then run `bun tools/media/capture-feature-images.mjs` from the root. Stop the local Worker afterward.
