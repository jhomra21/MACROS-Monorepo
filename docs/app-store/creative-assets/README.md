# App Store creative assets

This task refreshes the 1.0 product-page header and search-results creative without changing the approved listing or submitting anything to App Store Connect.

## Upload assets

Full-size output is kept in ignored `build/evidence/2026-11-23-appstore-creative/assets/`:

| Placement | File | Dimensions | Format |
| --- | --- | --- | --- |
| Product page header | `header-3840x1646.png` | 3840 × 1646 | Opaque PNG, sRGB |
| Search results | `search-results-3840x2560.jpg` | 3840 × 2560 | Opaque JPEG, sRGB |

Apple's current [creative asset specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications) require PNG for the 21:9 product-page header; search results accept JPEG, JPG, or PNG. Both designs keep key artwork inside the template Art Safe Area. The green bounds in the previews are inspection guides only and are not part of either upload asset.

Header copy: **Scan it. Log it. Hit your macros.** It uses the real build-39 Home screen with a realistic synthetic day. Search results show the real label-scan review, Home, and unbranded on-device Add Food screens, without extra headlines. The scan name was corrected in Edit details to **Oat Crunch Cereal**; the captured result shows 190 kcal, 5 g protein, 36 g carbs, and 3 g fat with the OCR warning gone. The search screen is staged as a wide composition, not a claim about Apple's precise device crop.

Palette and type match the site: `#f5f5f7`, `#1d1d1f`, `#007aff`, `#ff9f0a`, `#ef4f87`, with the system display font and tight tracking.

## Template safe areas

Coordinates are `(left, top, right, bottom)`, from the canvas top-left with right/bottom exclusive. The Art Safe Area bounds and template checksums are retained from the existing Apple-template record; the PSD templates themselves are not included in this worktree:

| Placement | Canvas | Art Safe Area |
| --- | --- | --- |
| Product page header | 3840 × 1646 | `(1097, 493, 2743, 1154)` |
| Search results | 3840 × 2560 | `(836, 765, 3004, 1795)` |

Apple template sources:

- https://developer.apple.com/go/?id=photoshop-product-page-header-template
- https://developer.apple.com/go/?id=photoshop-search-results-template
- https://devimages-cdn.apple.com/design/resources/download/app-store/creative_assets-product_page_header_template-static.psd
- https://devimages-cdn.apple.com/design/resources/download/app-store/creative_assets-search_results_template-static.psd

## Captures and regeneration

Captures were made from Debug build **1.0 (39)** of commit `dc6b2bf0b374b0e273ba18acf3675fb2026ce104` on the locked iPhone 18 Pro Max simulator, iOS 27.0, at 9:41. Synthetic demo data was loaded on the media simulator only. The scan review uses the generic Oat Crunch fixture; OCR did not confidently identify the name, so “Oat Crunch” was entered manually for the editable review state.

Ignored evidence contains the captures, upload assets, screenshots, and generated HTML:

- `build/evidence/2026-11-23-appstore-creative/captures/`
- `build/evidence/2026-11-23-appstore-creative/assets/`

From `docs/app-store/`:

```sh
bun install --frozen-lockfile
bunx playwright install chromium
bun creative-assets/render.mjs
bun creative-assets/previews.mjs
bun screenshots-v2/render.mjs
```

`render.mjs` embeds the captures in offline HTML and exports exact-size artwork. `previews.mjs` generates `-small`, `-safe-area`, and `-safe-crop` inspection images. Final output metadata and checksums are recorded in `validation.json`; the full deliverables stay ignored to keep tracked evidence under the repository's five-image / 2 MiB limit.

The separate 1.1 screenshot set uses **History** and **Daily Goals in Settings** rather than a sharing-choice screen. Its current-main build-40 captures are documented in [the screenshot plan](../screenshots.md). The media device had no connected synthetic sharing participant; creating one would require remote sharing writes, so no remote state was created. Existing Home Screen widgets from build 39 remain in the 1.0 capture evidence.

No prices or pricing terms, third-party marks, other-platform imagery, or App Store claims are included. Inspect Apple's actual upload preview before any future release or product-page change; final crops are Apple's decision.
