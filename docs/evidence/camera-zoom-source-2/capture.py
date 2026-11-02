"""Repeatable, device-specific evidence capture. No simulator discovery/configuration."""
import json
import os
from pathlib import Path
import shlex
import signal
import subprocess
import sys
import time

ROOT = Path("/Users/juan/.t3/worktrees/cal-macro-tracker/camera-zoom-source")
OUT = ROOT / "build/camera-zoom-source-2"
UDID = "918D29B9-97D3-42C0-9C47-00605E01E8DB"
AXE = "/opt/homebrew/Cellar/xcodebuildmcp/2.3.2/libexec/bundled/axe"
ENV = dict(os.environ, DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer")

def command(args, **kwargs):
    return subprocess.run("cd " + shlex.quote(str(ROOT)) + " && " + shlex.join(args),
                          shell=True, env=ENV, check=True, **kwargs)

def tap(label):
    command([AXE, "tap", "--label", label, "--udid", UDID, "--post-delay", "0.8"])

def capture(name, label):
    path = OUT / (name + ".mp4")
    launched = time.time()
    record = subprocess.Popen("cd " + shlex.quote(str(ROOT)) + " && exec " + shlex.join(
        ["xcrun", "simctl", "io", UDID, "recordVideo", "--codec=h264", str(path)]),
        shell=True, env=ENV, stderr=subprocess.PIPE, text=True)
    try:
        for line in record.stderr:
            if "Recording started" in line:
                ready = time.time()
                break
        # Fixed lead-in and tail are capture windows, not polling or application timing.
        time.sleep(0.5)
        start = time.time()
        targets = {"compact": ["-x", "352", "-y", "808"],
                   "photo": ["-x", "65", "-y", "365"]}
        target = targets.get(label, ["--label", label])
        command([AXE, "tap", *target, "--udid", UDID])
        end = time.time()
        time.sleep(3.0)
    finally:
        record.send_signal(signal.SIGINT)
        record.wait(timeout=20)
    (OUT / (name + "-timing.json")).write_text(json.dumps(
        {"input_command_start_epoch": start, "input_command_end_epoch": end,
         "record_launch_epoch": launched, "record_ready_epoch": ready,
         "source_label": label}, indent=2) + "\n")
    command(["ffprobe", "-v", "error", "-show_entries", "stream=avg_frame_rate,r_frame_rate,nb_frames,duration",
             "-of", "json", str(path)], stdout=open(OUT / (name + "-video-info.json"), "w"))

if __name__ == "__main__":
    if sys.argv[1] == "capture":
        capture(sys.argv[2], sys.argv[3])
    elif sys.argv[1] == "tap":
        tap(sys.argv[2])
