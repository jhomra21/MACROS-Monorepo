"""Non-upload inspection images. Requires Pillow; leaves upload pixels unchanged."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageCms

ROOT = Path(__file__).parent
SRGB = ImageCms.ImageCmsProfile(ImageCms.createProfile("sRGB")).tobytes()
SAFE = {"header": (1097, 493, 2743, 1154), "search-results": (836, 765, 3004, 1795)}
for name, box in SAFE.items():
    height = 1646 if name == "header" else 2560
    image = Image.open(ROOT / f"{name}-3840x{height}.jpg").convert("RGB")
    outlined = image.copy()
    draw = ImageDraw.Draw(outlined)
    draw.rectangle(box, outline="#00883b", width=10)
    outlined.thumbnail((960, 640), Image.Resampling.LANCZOS)
    outlined.save(ROOT / f"{name}-safe-area.jpg", quality=92, icc_profile=SRGB)
    image.resize((600, round(height * 600 / 3840)), Image.Resampling.LANCZOS).save(
        ROOT / f"{name}-small.jpg", quality=95, icc_profile=SRGB)
    if name == "header":
        # Centered 4:3 crop, shown at 390 px wide. A stress test, not an Apple placement promise.
        image.crop((822, 0, 3018, 1646)).resize((390, 292), Image.Resampling.LANCZOS).save(
            ROOT / "header-iphone-crop.jpg", quality=95, icc_profile=SRGB)
    image.crop(box).resize((780, round((box[3]-box[1])*780/(box[2]-box[0]))), Image.Resampling.LANCZOS).save(
        ROOT / f"{name}-safe-crop.jpg", quality=95, icc_profile=SRGB)
