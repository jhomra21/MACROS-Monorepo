#!/usr/bin/env python3
"""Render trimmed simulator recordings as an App Store preview."""

from __future__ import annotations

import argparse
import json
import math
import subprocess
import tempfile
from pathlib import Path
from typing import Any

WIDTH = 886
HEIGHT = 1920
FPS = 30


def run(*args: str) -> None:
    subprocess.run(args, check=True)


def resolve_path(value: str, config_dir: Path) -> Path:
    path = Path(value).expanduser()
    return path.resolve() if path.is_absolute() else (config_dir / path).resolve()


def render(config_path: Path) -> None:
    config_path = config_path.resolve()
    config_dir = config_path.parent
    config: dict[str, Any] = json.loads(config_path.read_text())
    clips = config["clips"]
    if not clips:
        raise ValueError("At least one clip is required")

    output = resolve_path(config["output"], config_dir)
    output.parent.mkdir(parents=True, exist_ok=True)
    crossfade = float(config.get("crossfade", 0.2))
    if crossfade < 0 or crossfade > 0.25:
        raise ValueError("Crossfade must be between 0 and 0.25 seconds")

    root = Path(__file__).resolve().parent
    with tempfile.TemporaryDirectory(prefix="macros-app-preview-") as temporary:
        temp_dir = Path(temporary)
        pill_binary = temp_dir / "render-pill"
        run("swiftc", "-O", str(root / "render-pill.swift"), "-o", str(pill_binary))

        durations: list[float] = []
        inputs: list[str] = []
        filters: list[str] = []
        input_count = 0
        for index, clip in enumerate(clips):
            source = resolve_path(clip["input"], config_dir)
            start = float(clip["start"])
            end = float(clip["end"])
            duration = end - start
            if start < 0 or duration <= 0:
                raise ValueError(f"Clip {index} must have a positive start/end range")
            if index and crossfade >= duration:
                raise ValueError(f"Crossfade must be shorter than clip {index}")
            durations.append(duration)
            video_input = input_count
            inputs.extend(["-i", str(source)])
            input_count += 1
            base = f"base{index}"
            filters.append(
                f"[{video_input}:v]trim=start={start}:end={end},"
                f"setpts=PTS-STARTPTS,scale={WIDTH}:{HEIGHT}:flags=lanczos,"
                f"fps={FPS},setsar=1,settb=AVTB,format=yuv420p[{base}]"
            )
            if clip.get("label"):
                label_path = temp_dir / f"label-{index}.png"
                run(str(pill_binary), str(clip["label"]), str(label_path))
                label_input = input_count
                inputs.extend(["-loop", "1", "-framerate", str(FPS), "-t", str(duration), "-i", str(label_path)])
                input_count += 1
                label = f"label{index}"
                filters.append(
                    f"[{label_input}:v]format=rgba,fade=t=in:st=0:d=0.12:alpha=1[{label}]"
                )
                filters.append(f"[{base}][{label}]overlay=0:0:shortest=1:format=auto[{base}l]")
                base = f"{base}l"
            filters.append(f"[{base}]trim=duration={duration},settb=AVTB[{index}v]")

        current = "0v"
        timeline = durations[0]
        for index in range(1, len(clips)):
            next_input = f"{index}v"
            output_label = f"mix{index}"
            offset = timeline - crossfade
            filters.append(
                f"[{current}][{next_input}]xfade=transition=fade:duration={crossfade}:"
                f"offset={offset:.6f}[{output_label}]"
            )
            current = output_label
            timeline += durations[index] - crossfade

        audio_input = input_count
        inputs.extend(
            [
                "-f",
                "lavfi",
                "-t",
                f"{timeline:.6f}",
                "-i",
                "anullsrc=channel_layout=stereo:sample_rate=44100",
            ]
        )
        filter_graph = ";".join(filters)
        command = [
            "ffmpeg",
            "-hide_banner",
            "-y",
            *inputs,
            "-filter_complex",
            filter_graph,
            "-map",
            f"[{current}]",
            "-map",
            f"{audio_input}:a:0",
            "-r",
            str(FPS),
            "-fps_mode",
            "cfr",
            "-c:v",
            "libx264",
            "-profile:v",
            "high",
            "-level:v",
            "4.0",
            "-preset",
            "slow",
            "-pix_fmt",
            "yuv420p",
            "-b:v",
            "11M",
            "-minrate",
            "11M",
            "-maxrate",
            "11M",
            "-bufsize",
            "22M",
            "-x264-params",
            "nal-hrd=cbr:filler=1:keyint=60:min-keyint=60:scenecut=0",
            "-color_primaries",
            "bt709",
            "-color_trc",
            "bt709",
            "-colorspace",
            "bt709",
            "-c:a",
            "aac",
            "-b:a",
            "256k",
            "-ar",
            "44100",
            "-ac",
            "2",
            "-movflags",
            "+faststart",
            "-t",
            f"{timeline:.6f}",
            str(output),
        ]
        run(*command)

    poster = resolve_path(config["poster"], config_dir) if config.get("poster") else output.with_name("poster.png")
    poster_second = float(config.get("poster_second", 5.0))
    run(
        "ffmpeg",
        "-hide_banner",
        "-loglevel",
        "error",
        "-y",
        "-ss",
        str(poster_second),
        "-i",
        str(output),
        "-frames:v",
        "1",
        str(poster),
    )

    contact = (
        resolve_path(config["contact_sheet"], config_dir)
        if config.get("contact_sheet")
        else output.with_name("contact-sheet.jpg")
    )
    columns = int(config.get("contact_sheet_columns", 6))
    rows = math.ceil(timeline * 2 / columns)
    run(
        "ffmpeg",
        "-hide_banner",
        "-loglevel",
        "error",
        "-y",
        "-i",
        str(output),
        "-vf",
        f"fps=2,scale=177:384:flags=lanczos,tile={columns}x{rows}:padding=2:margin=2",
        "-frames:v",
        "1",
        str(contact),
    )
    print(f"Rendered {output} ({timeline:.2f}s), poster at {poster_second:.2f}s, contact sheet {contact}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("config", type=Path, help="JSON render configuration")
    args = parser.parse_args()
    render(args.config)


if __name__ == "__main__":
    main()
