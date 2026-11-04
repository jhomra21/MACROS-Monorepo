"""Dense strips from the actual cropped iPad videos, not layout reconstructions."""
import json
import pathlib
import subprocess

ROOT = pathlib.Path(__file__).resolve().parent


def strip(source, target, start, fps=30, count=25):
    subprocess.run(["ffmpeg", "-y", "-ss", str(start), "-i", str(source), "-vf",
                    f"fps={fps},crop=362:824:14:28,scale=300:-2,trim=end_frame={count},tile=6x{(count + 5) // 6}:nb_frames={count}:color=black",
                    "-frames:v", "1", str(target)],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)


def bounds(source):
    width, height = 390, 1122
    raw = subprocess.check_output(["ffmpeg", "-v", "error", "-i", str(source),
                                  "-vf", "fps=30", "-f", "rawvideo", "-pix_fmt", "rgb24", "-"])
    size = width * height * 3
    rows = []
    for i in range(len(raw) // size):
        frame = memoryview(raw)[i * size:(i + 1) * size]
        pixels = []
        for y in range(190, 950, 2):
            xs = [x for x in range(20, 370, 3) if frame[(y * width + x) * 3] < 70
                  and frame[(y * width + x) * 3 + 1] > 100 and frame[(y * width + x) * 3 + 2] > 160]
            if len(xs) > 56:
                pixels.append((y, min(xs), max(xs)))
        if pixels:
            rows.append({"t": round(i / 30, 3), "x": min(p[1] for p in pixels), "y": pixels[0][0],
                         "width": max(p[2] for p in pixels) - min(p[1] for p in pixels) + 1,
                         "height": pixels[-1][0] - pixels[0][0] + 2})
    return rows


def transitions(phase, name, prefix=""):
    source = ROOT / phase / (name + ".mp4")
    rows = bounds(source)
    compact_y = rows[0]["y"]
    expanded_y = max(r["y"] for r in rows)
    expand = next(r["t"] for r in rows if r["y"] > compact_y + 4)
    collapse = next(r["t"] for r in rows if r["t"] > expand + 1 and r["y"] < expanded_y - 4)
    data = {"fps": 30, "framesPerStrip": 25, "columns": 6, "frameWidth": 300,
            "crop": "362:824:14:28", "source": source.name,
            "method": "Observed blue raster (2 px y / 3 px x samples), not reconstructed geometry.",
            "expandStripStart": round(max(0, expand - .1), 3),
            "collapseStripStart": round(max(0, collapse - .1), 3)}
    for action, start in [("expand", data["expandStripStart"]), ("collapse", data["collapseStripStart"])]:
        strip(source, ROOT / phase / (prefix + action + "-strip.jpg"), start)
        data[action + "Frames"] = [r for r in rows if start <= r["t"] <= start + .8]
    (ROOT / phase / (prefix + "frame-times.json")).write_text(json.dumps(data, indent=2) + "\n")
    return data


def compact_comparison():
    folder = ROOT / "green"
    crop = "crop=346:52:32:235"
    pixels = []
    for name in ["compact", "collapsed"]:
        pixels.append(subprocess.check_output(
            ["ffmpeg", "-v", "error", "-i", str(folder / (name + ".png")),
             "-vf", crop, "-frames:v", "1", "-f", "rawvideo", "-pix_fmt", "rgb24", "-"]))
    differences = [abs(a - b) for a, b in zip(*pixels)]
    report = {"crop": crop, "beforeVsAfter": {
        "meanAbsoluteChannelDifference": sum(differences) / len(differences),
        "maximumChannelDifference": max(differences)}}
    assert max(differences) == 0, report
    (folder / "compact-row-pixels.json").write_text(json.dumps(report, indent=2) + "\n")
    subprocess.run(["ffmpeg", "-y", "-i", str(folder / "compact.png"),
                    "-i", str(folder / "collapsed.png"), "-filter_complex",
                    f"[0:v]{crop}[a];[1:v]{crop}[b];[a][b]hstack",
                    "-frames:v", "1", str(folder / "compact-before-after.png")],
                   capture_output=True, check=True)


if __name__ == "__main__":
    compact_comparison()
    print(json.dumps(transitions("green", "morph"), indent=2))
    if (ROOT / "green" / "reduce-motion.mp4").exists():
        print(json.dumps(transitions("green", "reduce-motion", "reduce-motion-"), indent=2))
