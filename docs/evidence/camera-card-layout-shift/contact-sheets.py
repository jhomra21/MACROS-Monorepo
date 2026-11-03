"""Run with Pillow installed, after capturing red/green fixtures."""
import pathlib
from PIL import Image, ImageDraw

root = pathlib.Path(__file__).parent
for phase in ["red", "green"]:
    for kind in ["barcode", "label"]:
        paths = [root / phase / f"{kind}-{amount}.png" for amount in ["1", "1.25", "1.5", "1.75", "2", "0.25", "10", "20"]]
        if not all(p.exists() for p in paths):
            continue
        sheet = Image.new("RGB", (390 * 4, 874 * 2), "#eeeeee")
        draw = ImageDraw.Draw(sheet)
        for index, path in enumerate(paths):
            x, y = index % 4 * 390, index // 4 * 874
            draw.text((x + 12, y + 8), f"{phase} {path.stem}", fill="black")
            sheet.paste(Image.open(path).convert("RGB").resize((390, 844)), (x, y + 30))
        sheet.save(root / f"{phase}-{kind}-contact-sheet.jpg", quality=85)
