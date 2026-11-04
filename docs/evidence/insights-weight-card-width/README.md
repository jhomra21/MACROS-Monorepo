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

All PNGs together are under 400 KB.
