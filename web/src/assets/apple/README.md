# Apple product bezel

The unmodified iPhone 17 Pro Max Silver portrait bezel came from Apple's [Design Resources, Product Bezels](https://developer.apple.com/design/resources/#product-bezels), in `Bezel-iPhone-17.dmg`. It was downloaded on November 23, 2026, after the account owner accepted Apple's Design Resources license. The license permits displaying the bezel in images depicting mock-ups of our iOS app UI, but forbids redistributing the resource itself.

The raw bezel PNG is not committed or served separately. The committed `src/assets/app-images/framed/*.png` files are flattened depictions of MACROS app mock-ups, with screenshots composited beneath the unmodified bezel. Astro serves them through its image pipeline.

Regenerate the mock-up images with Bun and the web package's existing Sharp installation:

```sh
bun web/scripts/frame-screenshots.ts <bezel path>
```

With no argument, the script uses the owner's local extracted PNG path. The script scans the bezel's alpha channel to find the screen opening, clips the screenshot to the opening's inverse-alpha mask, and places the original bezel on top. Do not edit or publish the standalone bezel.
