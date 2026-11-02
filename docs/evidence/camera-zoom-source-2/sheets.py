"""Extract every frame on a consistent 30 fps timeline and paginate contact sheets."""
from pathlib import Path
import json
import math
import subprocess
import sys
from PIL import Image, ImageDraw, ImageFont

ROOT = Path("/Users/juan/.t3/worktrees/cal-macro-tracker/camera-zoom-source")
OUT = ROOT / "build/camera-zoom-source-2"
FONT = ImageFont.truetype("/System/Library/Fonts/Menlo.ttc", 15)

def render(name, native=False):
    tag = "-native" if native else ""
    frames = OUT / (name + tag + "-frames")
    frames.mkdir(exist_ok=True)
    filters = "" if native else "-vf fps=30"
    subprocess.run(f"cd {ROOT} && ffmpeg -v error -i {OUT/name}.mp4 {filters} -fps_mode passthrough {frames}/%03d.png",
                   shell=True, check=True)
    files = sorted(frames.glob("*.png"))
    times = [i / 30 for i in range(len(files))]
    if native:
        probe = subprocess.run(f"cd {ROOT} && ffprobe -v error -select_streams v:0 -show_entries frame=pts_time -of json {OUT/name}.mp4",
                               shell=True, check=True, capture_output=True, text=True)
        times = [float(frame["pts_time"]) for frame in json.loads(probe.stdout)["frames"]]
        (OUT / (name + "-native-times.json")).write_text(json.dumps(times) + "\n")
    for offset in range(0, len(files), 30):
        group = files[offset:offset+30]
        sheet = Image.new("RGB", (200 * 6, 459 * math.ceil(len(group)/6)), "#202020")
        draw = ImageDraw.Draw(sheet)
        for i, path in enumerate(group):
            frame = Image.open(path).convert("RGB")
            frame.thumbnail((194, 422))
            x, y = i % 6 * 200, i // 6 * 459
            sheet.paste(frame, (x+3, y+32))
            draw.text((x+3,y+6), f"{offset+i:03d} {times[offset+i]:.3f}s", fill="white", font=FONT)
        sheet.save(OUT / f"{name}{tag}-contact-{offset//30+1:02d}.jpg", quality=85)

if __name__ == "__main__":
    native = "--native" in sys.argv
    for name in [arg for arg in sys.argv[1:] if arg != "--native"]:
        render(name, native=native)
