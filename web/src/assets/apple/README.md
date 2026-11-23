# Optional Apple iPhone bezel

`AppScreen.astro` will layer `/apple/iphone-17-light.png` over real MACROS screenshots when that file exists; otherwise it renders the existing plain rounded screenshot. The component adds no client JavaScript and does not draw Apple hardware.

The bezel must be an unmodified light-finish iPhone 17 product image obtained from Apple's [Design Resources, Product Bezels](https://developer.apple.com/design/resources/#product-bezels) (source page checked November 23, 2026). Apple's [App Store Marketing Guidelines](https://developer.apple.com/app-store/marketing/guidelines/) require using product imagery as-is and say it may only be used while the app is available for download. The account owner must accept Apple's App Store Marketing Artwork License Agreement before downloading or using the bezel. Do not put an edited, recolored, cropped, or simulated device image here.

The supplied Apple resource is a DMG, not a directly linkable transparent PNG. After the listing is downloadable and the owner has accepted Apple's agreement, export the light-finish iPhone 17 product bezel as a transparent PNG without modifying it, and save it at `web/public/apple/iphone-17-light.png`. The CSS screen aperture is an approximate fit; verify alignment against the original asset before setting `site.appStore.live` to `true`. Keep the plain screenshot fallback until then.
