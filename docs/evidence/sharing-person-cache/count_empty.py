#!/usr/bin/env python3
"""Count frames showing the person screen's empty-state card in a recording.

usage: count_empty.py <ref_video> <ref_time> <video> <enter_time> [<enter_time> ...]
The reference frame (taken from a known empty-state moment) is compared with every frame of each
window [enter, enter+1.6s] at 30 fps, over the Today card region. A frame counts as empty-state
when the mean absolute difference is below THRESH (settled page, not mid-push).
"""
import subprocess, sys

W, H = 60, 130
THRESH = 6.0


def gray_frames(video, start, dur, fps):
    cmd = ["/opt/homebrew/bin/ffmpeg", "-v", "error", "-ss", str(start), "-t", str(dur), "-i", video,
           "-vf", f"fps={fps},scale={W}:{H},format=gray", "-f", "rawvideo", "-"]
    raw = subprocess.run(cmd, capture_output=True, check=True).stdout
    n = W * H
    return [raw[i * n:(i + 1) * n] for i in range(len(raw) // n)]


def region(frame):
    # Today card: x 5-95%, y 6-26% of the screen
    rows = range(int(H * 0.06), int(H * 0.26))
    cols = range(int(W * 0.05), int(W * 0.95))
    return [frame[r * W + c] for r in rows for c in cols]


def diff(a, b):
    return sum(abs(x - y) for x, y in zip(a, b)) / len(a)


ref_video, ref_time, video, *enters = sys.argv[1:]
ref = region(gray_frames(ref_video, float(ref_time), 0.05, 20)[0])
for i, t in enumerate(enters, 1):
    frames = gray_frames(video, float(t), 1.6, 30)
    empty = [k for k, f in enumerate(frames) if diff(region(f), ref) < THRESH]
    print(f"entry{i}: empty-state frames at 30fps = {len(empty)} ({len(empty) / 30:.2f}s) of {len(frames)}")
