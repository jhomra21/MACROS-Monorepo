"""Rebuild bounded, reviewable evidence summaries from committed captures and local logs."""
import hashlib
import json
import pathlib
import re
import subprocess

ROOT = pathlib.Path(__file__).resolve().parent


def save(name, value):
    (ROOT / name).write_text(json.dumps(value, indent=2) + "\n")


def nodes(name):
    return json.loads((ROOT / "green" / f"{name}.json").read_text())["nodes"]


heights = {}
for phase in ["baseline", "extraction", "green"]:
    data = (ROOT / phase / "heights.csv").read_bytes()
    heights[phase] = {"measurements": len(data.splitlines()) - 1,
                      "sha256": hashlib.sha256(data).hexdigest()}
assert len({h["sha256"] for h in heights.values()}) == 1
save("height-comparison.json", heights)

# The AX identifier propagates to descendants, not an enclosing glass frame.
# Card/strip rects below are screenshot edge measurements, not invented AX frames.
geometry = {
    "portrait": {"capture": "green/final-zoom-expanded.png", "screen": [390, 844],
                 "glass_card": [16, 47, 358, 572.33], "drawn_strip": [16, 635.33, 358, 192.67],
                 "available_height": 763, "card_fraction_of_available": 0.75,
                 "drawn_strip_fraction_of_screen": 192.67 / 844},
    "keyboard": {"capture": "green/final-flow-keyboard.png",
                 "drawn_strip_height": 0, "viewport_padding": 0,
                 "note": "No strip pixels; hidden descendants may still be returned by XCTest."},
    "landscape": {"capture": "green/landscape.png", "screen": [844, 390],
                  "layout": "side-by-side", "card_width_fraction_of_available": 0.65},
    "accessibility": {"captures": ["green/ax3-scrolled.png", "green/ax5-final-scrolled.png"],
                      "pinned": ["Log"], "scrolls": ["summary", "quantity", "fields"]},
}
for name in ["final-zoom-expanded", "final-flow-keyboard", "ax5-final-expanded", "landscape"]:
    geometry[name + "_control_frames"] = [
        {"label": n["label"], "rect": n["rect"], "enabled": n.get("enabled")}
        for n in nodes(name) if n.get("kind") == "button"
        and n.get("label") in ["Log", "Scan again", "Retake", "Close camera"]]
save("heights.json", geometry)

checks = {}
checks["required_initial_disabled"] = any(
    n.get("label") == "Log" and not n.get("enabled") for n in nodes("required-review-initial"))
checks["one_confirmation_still_disabled"] = any(
    n.get("label") == "Log" and not n.get("enabled") for n in nodes("required-review-one-confirmed"))
checks["both_confirmations_enable_log"] = any(
    n.get("label") == "Log" and n.get("enabled") for n in nodes("required-review-enabled"))
for name in ["required-review-logged", "recovery-logged", "second-item-logged", "final-flow-logged"]:
    checks[name] = any(n.get("label") == "Logged" for n in nodes(name))
checks["recovery_name_required"] = any(
    n.get("label") == "Log" and not n.get("enabled") for n in nodes("recovery-inline-disabled"))
checks["dirty_zoom_preserved"] = any(
    n.get("value") == "Protected Draft" for n in nodes("zoom-dirty-blocked"))
checks["background_preserved"] = any(
    n.get("value") == "Protected Draft" for n in nodes("background-return"))
checks["renamed_clean_retake"] = not any(
    n.get("label") == "Discard changes?" for n in nodes("renamed-clean-retake"))
checks["clean_zoom_dismissed"] = not any(
    n.get("label") == "Food details" for n in nodes("final-clean-swipe"))
for capture_name, field in [("next-protein", "Protein"), ("previous-calories", "Calories")]:
    data = json.loads((ROOT / "rerun" / f"{capture_name}.json").read_text())["nodes"]
    checks[capture_name + "_focused"] = any(n.get("label") == field and n.get("focused") for n in data)
assert all(checks.values()), checks
save("capture-assertions.json", checks)

# Pixel probes supplement the contact sheet; they are not AX bounding boxes.
video = ROOT / "green" / "final-flow.mp4"
if video.exists():
    raw = subprocess.check_output([
        "/opt/homebrew/bin/ffmpeg", "-v", "error", "-i", str(video), "-t", "4",
        "-vf", "fps=10,scale=390:844", "-f", "rawvideo", "-pix_fmt", "rgb24", "-"])
    stride = 390 * 844 * 3
    frames = []
    for index in range(len(raw) // stride):
        frame = raw[index * stride:(index + 1) * stride]
        probes = {}
        for y in [650, 700, 750]:
            runs, start = [], None
            for x in range(391):
                pixel = frame[(y * 390 + x) * 3:(y * 390 + x) * 3 + 3] if x < 390 else b""
                matches = len(pixel) == 3 and 50 <= min(pixel) <= max(pixel) <= 80 and max(pixel) - min(pixel) <= 4
                if matches and start is None:
                    start = x
                if not matches and start is not None:
                    runs.append([start, x])
                    start = None
            probes[str(y)] = max(runs, key=lambda r: r[1] - r[0], default=None)
        frames.append({"seconds": index / 10, "contact_cell": [index // 8, index % 8],
                       "longest_neutral_viewport_pixel_runs": probes})
    save("zoom-frames.json", {"source": "green/final-flow.mp4", "sample_hz": 10,
                             "note": "Manual inspection: no wide/left sweep. Pixel runs sample the gray viewport, not the glass-card frame.",
                             "frames": frames})

log_names = {
    "isolated-red-compile": "/tmp/macros-inline-isolated-red.log",
    "isolated-red-assertions": "/tmp/macros-inline-isolated-red-stubs.log",
    "isolated-green": "/tmp/macros-inline-isolated-green.log",
    "final-suite": "/tmp/macros-inline-focus-appear-suite.log",
    "format": "/tmp/macros-inline-focus-appear-format.log",
    "build": "/tmp/macros-inline-focus-appear-quality-build.log",
    "lint-js": "/tmp/macros-inline-focus-appear-lint-js.log",
}
for name, path in log_names.items():
    source = pathlib.Path(path)
    if not source.exists():
        continue  # Rebuilding capture summaries does not require historical /tmp logs.
    lines = source.read_text().splitlines()
    selected = [line for line in lines if re.search(
        r"Test Suite |Executed \d+ tests|XCTAssert.*failed|error:.*(isDirty|recoveryDraftOpened)|\*\* .* (SUCCEEDED|FAILED) \*\*|Found \d+ warnings|Finished in|run_swift_format", line)]
    folder = ROOT / "validation"
    folder.mkdir(exist_ok=True)
    (folder / f"{name}.txt").write_text("\n".join(selected) + "\n")

manifest = [{"path": str(p.relative_to(ROOT)), "bytes": p.stat().st_size,
             "sha256": hashlib.sha256(p.read_bytes()).hexdigest()}
            for p in sorted(ROOT.rglob("*"))
            if p.is_file() and p.suffix in [".png", ".jpg", ".mp4", ".csv"]]
save("artifact-manifest.json", manifest)
print(json.dumps({"assertions": checks, "height_comparison": heights,
                  "media_bytes": sum(p["bytes"] for p in manifest)}, indent=2))
