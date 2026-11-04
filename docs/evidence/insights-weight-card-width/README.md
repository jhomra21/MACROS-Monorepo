# Insights weight-card width

Captured on the iPhone 17e simulator (`F976E800-DA1F-4F20-B755-DFD964E33975`, iOS 27.0), at 390 × 844 pixels and 1× scale, with demo data including weight entries.

## Pixel comparison

Pixel x-coordinates are inclusive:

| Range | Baseline weight card | Baseline tile grid | Fixed weight card | Fixed tile grid |
| --- | --- | --- | --- | --- |
| 7 days | 0–389 | 20–369 | 20–369 | 20–369 |
| All time | 0–389 | 20–369 | 20–369 | 20–369 |

The grid's two tile columns span x=20–190 and x=199–369. The baseline card touches both screen edges, while both fixed cards align with the grid's 20-pixel side inset.

## Screenshots

- `red-7-days.png`, origin/main (`21921b1`), Pro enabled.
- `red-all-time.png`, origin/main (`21921b1`), Pro enabled.
- `green-7-days.png`, fixed build, Pro enabled.
- `green-all-time.png`, fixed build, Pro enabled.
- `green-accessibility-maximum.png`, fixed build at `accessibility-extra-extra-extra-large`.
- `green-locked.png`, fixed build with Debug Pro disabled.

All original PNGs together are under 400 KB.


## Follow-up validation on the fixed branch

Captured on the iPhone 17e simulator (390 × 844 px, 1×). In Pro with an in-range seven-day entry, the card edges measured x=20–369 px, matching the tile grid edges x=20–369 px; the two grid columns measured x=20–190 and x=199–369 px. The All time range still displays the weight card.

For the out-of-range case, demo weight entries dated within seven days were deleted while retaining older entries. The weight card was absent, and the tile-grid top edge was y=98 px. With all weight entries deleted, the tile-grid top edge was also y=98 px, a 0 px difference (no extra 16 pt gap). Demo data was reseeded and Debug Pro re-enabled after the comparison.

The comparison captures use landscape orientation (844 × 390 px) to show the summary tiles clearly; the seven-day width and All time captures use portrait (390 × 844 px). Each added PNG is under 100 KB.

| Case | Evidence | Measurement / result |
| --- | --- | --- |
| Pro, 7 days, recent weight | `e2e-7-days-pro.png` | Card x=20–369 px; grid x=20–369 px |
| Pro, All time | `e2e-all-time-pro.png` | Weight card remains visible |
| Entries exist, none in 7 days | `e2e-no-recent-weight-7-days.png` | No weight card; tiles start at y=98 px |
| No weight entries | `e2e-no-weight-7-days.png` | Tiles start at y=98 px; 0 px delta |
| Restored demo data | `e2e-all-time-restored.png` | Weight card visible after restoration |

Serial iPad Air 11-inch simulator suite, excluding `PurchaseStoreStoreKitTests`: **247 passed, 0 failed, 0 skipped**. Result bundle: `/tmp/macros-insights-width2.xcresult`. `make quality-format-check` and `make quality-build` both passed.

## Follow-up validation on the fixed branch

Captured on the iPhone 17e simulator (390 × 844 px, 1×). In Pro with an in-range seven-day entry, the weight card content has 20 px side insets, matching the tile grid x=20–369 px and its two columns x=20–190 and x=199–369. The All time range continues to show the weight card.

To test the out-of-range state, all entries dated within the seven-day range were deleted while older entries remained. The card disappeared, and the summary tile grid started at y=98 px. With no weight entries at all, the grid also started at y=98 px, a 0 px difference (no extra 16 pt gap). Demo data was reseeded and Debug Pro re-enabled afterward.

The comparison captures use landscape orientation (844 × 390 px) to expose tile bounds; the recent-weight and All time captures use portrait (390 × 844 px). All new PNGs are under 100 KB each.

| Case | Evidence | Result |
| --- | --- | --- |
| Pro, 7 days, recent weight | `e2e-7-days-pro.png` | Weight card inset 20 px, aligned with tile grid x=20–369 px |
| Pro, All time | `e2e-all-time-pro.png` | Weight card visible |
| Older entries only | `e2e-no-recent-weight-7-days.png` | No card; tile top y=98 px |
| No weight entries | `e2e-no-weight-7-days.png` | Tile top y=98 px; 0 px difference |
| Demo data restored | `e2e-all-time-restored.png` | Card visible again after restore |

Serial iPad Air 11-inch suite, excluding `PurchaseStoreStoreKitTests`: **247 passed, 0 failed, 0 skipped**. Result bundle: `/tmp/macros-insights-width2.xcresult`. `make quality-format-check` and `make quality-build` passed.
