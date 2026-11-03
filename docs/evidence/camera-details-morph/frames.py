"""Extract repeatable frame strips and observed blue Log bounds; no imaging dependencies."""
import json
import pathlib
import subprocess

ROOT = pathlib.Path(__file__).resolve().parent


def strip(source, target, start, fps=30, count=15):
    subprocess.run(["ffmpeg", "-y", "-ss", str(start), "-i", str(source), "-vf",
                    f"fps={fps},scale=260:-2,tile=5x{(count + 4) // 5}", "-frames:v", "1", str(target)],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)


def bounds(source):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", str(source), "-vf", "fps=30,scale=390:844",
                          "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], capture_output=True, check=True).stdout
    size = 390 * 844 * 3
    rows = []
    for i in range(len(raw) // size):
        frame = memoryview(raw)[i * size:(i + 1) * size]
        pixels = []
        for y in range(200, 620):
            xs = [x for x in range(25, 365) if frame[(y * 390 + x) * 3] < 70
                  and frame[(y * 390 + x) * 3 + 1] > 100 and frame[(y * 390 + x) * 3 + 2] > 160]
            if len(xs) > 170:
                pixels.append((y, min(xs), max(xs)))
        if pixels:
            rows.append({"t": round(i / 30, 3), "x": min(p[1] for p in pixels), "y": pixels[0][0],
                         "width": max(p[2] for p in pixels) - min(p[1] for p in pixels) + 1,
                         "height": pixels[-1][0] - pixels[0][0] + 1})
    changes = [r for i, r in enumerate(rows) if i == 0 or
               (r["y"], r["width"]) != (rows[i - 1]["y"], rows[i - 1]["width"])]
    return rows, changes


if __name__ == "__main__":
    source = ROOT / "green" / "morph.mp4"
    rows, changes = bounds(source)
    (ROOT / "green" / "log-bounds.json").write_text(json.dumps(changes, indent=2) + "\n")
    compact_y = rows[0]["y"]
    expanded_y = max(r["y"] for r in rows)
    expand = next(r["t"] for r in rows if r["y"] > compact_y + 4)
    collapse = next(r["t"] for r in rows if r["t"] > expand + 1 and r["y"] < expanded_y - 4)
    strip(source, ROOT / "green" / "expand-strip.jpg", max(0, expand - 0.1))
    strip(source, ROOT / "green" / "collapse-strip.jpg", max(0, collapse - 0.1))
    data = {"expandStripStart": round(max(0, expand - 0.1), 3),
            "collapseStripStart": round(max(0, collapse - 0.1), 3), "fps": 30,
            "method": "Observed blue raster, not reconstructed geometry; labels are relative to strip start.",
            "expansionFrames": [r for r in rows if expand - .1 <= r["t"] <= expand + .5],
            "collapseFrames": [r for r in rows if collapse - .1 <= r["t"] <= collapse + .5]}
    (ROOT / "green" / "frame-times.json").write_text(json.dumps(data, indent=2) + "\n")
    print(json.dumps(data, indent=2))
