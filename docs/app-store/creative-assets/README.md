# MACROS App Store creative assets

Ready for the owner to upload to the 1.0 page. No App Store Connect access or changes.

## Upload only these two files

| File | Dimensions | Encoding |
| --- | --- | --- |
| `header-3840x1646.jpg` | 3840 × 1646 (Apple's specified 21:9 canvas) | Opaque JPEG, embedded sRGB |
| `search-results-3840x2560.jpg` | 3840 × 2560 (3:2) | Opaque JPEG, embedded sRGB |

Both are below 15 MB. Exact byte counts and checksums are in `validation.json`.

Header: **Scan it. Log it. Hit your macros.** with the real Home rings screen. Search: unbranded Add Food on the left, Home in the center, real label scan review on the right. No added search headline. All screenshot pixels are unchanged except proportional scaling and rounded screen clipping. The dark perimeter is a simple device-like frame, not a hardware rendering.

The design follows the existing site's light surface band `#f5f5f7`, white, ink `#1d1d1f`, system display typography with tight tracking, and protein `#007aff`, carbs `#ff9f0a`, fat `#ef4f87`. The header uses the macro colors as oversized peripheral arcs, not invented app UI.

## Apple template safe areas

Downloaded November 4, 2026, using `curl -fL`. The `go` pages return JavaScript redirects, not HTTP redirects; followed their literal CDN targets and inspected all PSD layers using `psd-tools` 1.26.0 in `/tmp/macros-creative-venv`.

Coordinates are `(left, top, right, bottom)`, origin at the canvas top-left, right/bottom exclusive. These are the bounds of Apple's **Art Safe Area** pixel layers, not guessed guides.

| Template | Canvas | Art Safe Area | Width × height |
| --- | --- | --- | --- |
| Header | 3840 × 1646 | `(1097, 493, 2743, 1154)` | 1646 × 661 |
| Search | 3840 × 2560 | `(836, 765, 3004, 1795)` | 2168 × 1030 |
| Universal, reference only | 5244 × 2950 | `(1921, 660, 3323, 1622)` | 1402 × 962 |

Sources:
- https://developer.apple.com/go/?id=photoshop-product-page-header-template
- https://developer.apple.com/go/?id=photoshop-search-results-template
- https://developer.apple.com/go/?id=photoshop-universal-asset-template
- https://devimages-cdn.apple.com/design/resources/download/app-store/creative_assets-product_page_header_template-static.psd
- https://devimages-cdn.apple.com/design/resources/download/app-store/creative_assets-search_results_template-static.psd
- https://devimages-cdn.apple.com/design/resources/download/app-store/creative_assets-universal_asset_template-static.psd

Template hashes and extracted layer bounds are in `validation.json`. PSD files remain in `/tmp/macros-creative-templates`, not the repository. Important headline/UI content is centered in the safe rectangles; complete phone silhouettes, status bars, lower content, and peripheral background decoration intentionally extend beyond them. The template safe region is not a promise that every placement will show full phones. In the search safe crop, rings, macro totals, generic food rows, and scan review/nutrition facts remain visible.

## Inputs and capture

Source main: `eb77c15`, app build **33**.

- `web/src/assets/app-images/app-home.png`, 1320 × 2868, demo data, 9:41. Visually checked: generic foods, no third-party marks.
- `web/src/assets/app-images/app-scan-review.png`, 1320 × 2868, demo Oat Crunch Cereal label, 9:41. Visually checked: generic label, no third-party marks.
- `app-add-food-unbranded.png`, fresh 1320 × 2868 capture. Empty query displays the real On Device saved-food list: Almonds, Apple, Banana, Black beans, Brown rice, Chicken and rice bowl, Cottage cheese, Mixed salad; generic recent-food chips. No remote branded results or keyboard. Original branded `app-add-food.png` is **not used**.

Capture method follows `docs/evidence/web-refresh-build-32/README.md`:

1. Exclusively acquired `/tmp/macros-sim-locks/D16C3D35-889F-404F-BDD4-C640A6DBC4EF` using atomic `mkdir`. Existing locks are never taken; retry interval 120 seconds, bounded at two hours. Lock was immediately available.
2. Built current main Debug for this media simulator, derived data `/tmp/macros-creative-build`, with only `PACKAGED_FOOD_SEARCH_BASE_URL=https://cal-macro-tracker-usda-proxy.jhonra121.workers.dev`. No conditional URL override.
3. `plutil -extract USDA_PROXY_BASE_URL raw` confirmed that exact URL in the built app; `CFBundleVersion` was `33`, bundle ID `juan-test.cal-macro-tracker`.
4. Used the existing loaded demo dataset (Home matched 1310 kcal / P95 C162 F34). Did not reset or reload the already-correct fixture. Installed Debug build, set `xcrun simctl status_bar <UDID> override --time 9:41`, drove Add Food with the pinned CLI returned by T3 `device_open`, captured with `screenshot <absolute-path> --pixel-density 3`.
5. Cleared the status-bar override, closed/shut down the media simulator, released the lock with `rmdir`. No other simulator was changed. No XcodeBuildMCP defaults were used.

## Regenerate on the Mac

Run commands from `/Users/juan/.t3/worktrees/cal-macro-tracker/asc-creative-assets`. Bun, Playwright 1.64.1 with Chromium, macOS `sips`, and Python with Pillow are required. The renderer launches a headless browser directly, no web server.

```sh
cd /Users/juan/.t3/worktrees/cal-macro-tracker/asc-creative-assets && bun docs/app-store/creative-assets/render.mjs
cd /Users/juan/.t3/worktrees/cal-macro-tracker/asc-creative-assets && /tmp/macros-creative-venv/bin/python docs/app-store/creative-assets/previews.py
cd /Users/juan/.t3/worktrees/cal-macro-tracker/asc-creative-assets && sips -g pixelWidth -g pixelHeight -g hasAlpha -g space -g profile docs/app-store/creative-assets/header-3840x1646.jpg docs/app-store/creative-assets/search-results-3840x2560.jpg
```

`render.mjs` writes each **self-contained** HTML source (images embedded as data URLs), renders at 1× and exact canvas size, forces sRGB, and embeds the system sRGB profile. Each HTML can also be opened directly offline. `previews.py` creates separate RGB inspection files; it never adds guides to the upload assets.

Preview files:
- `*-safe-area.jpg`: full composition with green template bounds.
- `*-safe-crop.jpg`: exact safe rectangle enlarged to 780 px wide.
- `*-small.jpg`: complete composition at 600 px wide.
- `header-iphone-crop.jpg`: centered 4:3 stress crop at 390 px wide. This is an inspection choice, not a claimed Apple placement.

## Validation and guideline checklist

- Exact dimensions, no alpha, RGB and embedded sRGB confirmed using `sips`; checksums/file sizes recorded.
- Chromium decoded every original 1320 × 2868 image, with no page errors or horizontal layout overflow. Header text bounds `(1130,650)–(2100.1,977.4)` are inside Apple's safe area.
- Inspected complete, safe-area, small search, and iPhone-width header previews. Home leads search; food rows and the nutrition label distinguish the supporting screens. Fine UI copy naturally becomes small at thumbnail size; no claim that every nutrient line remains readable.
- Impeccable detector returned two overflow-clipping warnings on the header. Intentional: this is a fixed raster canvas clipping peripheral arcs, not interactive UI with escaping popovers. No interactive controls or animations are present.
- No prices, discounts, URLs, copyright symbols, awards, Apple recognition claims, other platforms/marketplaces, or unverifiable performance/health claims in either creative.
- 4+ appropriate, ordinary demo nutrition data, no personal information or third-party brands.
- Upload/review acceptance and final device-specific App Store crops remain Apple's decision; owner should inspect the upload preview before publishing.
- Debug build passed. No app code changed; no native test suite run for this asset-only task.
