"""Render v8 from the uninterrupted native recording; never retime motion."""
import json
import re
import subprocess
from pathlib import Path

DIR = Path(__file__).resolve().parent
RAW = "/tmp/teaser-raw-v8-final.mp4"
FREEZES = "/tmp/teaser-v8-strict-freeze.log"


def run(args, log):
    with open(log, "w") as output:
        subprocess.run(args, stdout=output, stderr=subprocess.STDOUT, check=True)


run(["ffmpeg", "-hide_banner", "-i", RAW, "-vf",
     "freezedetect=n=0.00001:d=0.4", "-an", "-fps_mode", "vfr", "-f", "null", "-"],
    FREEZES)
# A stricter threshold than the requested 0.001 protects ring easing and tiny
# control changes. Only shorten detected still interiors, never motion.
spans = []
start = None
for kind, value in re.findall(r"freeze_(start|end): ([\d.]+)", Path(FREEZES).read_text()):
    if kind == "start":
        start = float(value)
    elif start is not None:
        end = float(value)
        # Today holds for one second after the 1,415 ring fill.
        keep = 1.0 if 8 < start < 9 else .5
        if end - start > keep + 1 / 60:
            spans.append((start + keep / 2, end - keep / 2))
        start = None
selection = "+".join(f"between(t,{a:.6f},{b:.6f})" for a, b in spans)
duration = float(json.loads(subprocess.check_output([
    "ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "json", RAW,
]))["format"]["duration"])
# Sample the VFR source by its presentation timestamps, with no interpolation.
count = sum(not any(a <= frame / 60 <= b for a, b in spans)
            for frame in range(round(duration * 60)))
# The final source frame has both widgets updated. Hold 1.5 s, then fade .6 s.
live_duration = count / 60 + 2.1
filters = (
    f"[0:v]scale=884:1920,fps=60,select='not({selection})',"
    "setpts=N/(60*TB),format=rgba[screen];"
    "[screen][1:v]alphamerge=shortest=1[phone];"
    "[2:v][phone]overlay=98:0:shortest=1,format=yuv420p,"
    f"tpad=stop_mode=clone:stop_duration=2.1,fade=t=out:st={live_duration-.6:.6f}:d=0.6[out]"
)
run(["ffmpeg", "-y", "-i", RAW, "-loop", "1", "-i", "/tmp/teaser-mask.png",
     "-f", "lavfi", "-i", "color=c=0xf2f2f7:s=1080x1920:r=60",
     "-filter_complex", filters, "-map", "[out]", "-an", "-c:v", "libx264",
     "-preset", "medium", "-crf", "20", "-pix_fmt", "yuv420p", "-r", "60",
     "-fps_mode", "cfr", "-t", str(live_duration),
     "/tmp/macros-live-v8.mp4"], "/tmp/teaser-live-encode.log")
run(["ffmpeg", "-y", "-framerate", "60", "-i", "/tmp/macros-endcard-v8/%03d.png",
     "-c:v", "libx264", "-preset", "medium", "-crf", "20", "-pix_fmt", "yuv420p",
     "-r", "60", "-fps_mode", "cfr", "-an", "/tmp/macros-endcard-v8.mp4"], "/tmp/teaser-endcard-encode.log")
Path("/tmp/macros-v8-concat.txt").write_text(
    "file '/tmp/macros-live-v8.mp4'\nfile '/tmp/macros-endcard-v8.mp4'\n")
run(["ffmpeg", "-y", "-f", "concat", "-safe", "0", "-i", "/tmp/macros-v8-concat.txt",
     "-c", "copy", "-movflags", "+faststart", str(DIR / "teaser.mp4")],
    "/tmp/teaser-concat.log")
Path("/tmp/teaser-v8-edit.json").write_text(json.dumps({
    "rawDuration": duration, "removedStillSpans": spans,
    "liveDuration": live_duration, "endcardDuration": 2.5,
}, indent=2))
print(Path("/tmp/teaser-v8-edit.json").read_text())
