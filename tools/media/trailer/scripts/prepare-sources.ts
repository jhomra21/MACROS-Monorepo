// Turns the raw simulator takes into the 30 fps clips the composition reads.
// Cuts only remove idle frames; no clip is sped up.
import { mkdirSync } from "node:fs";
import { DEMO_VIDEO, PUBLIC_SOURCES, RAW_DIR, run } from "./paths.ts";

type Segment = readonly [from: number, to: number];

const ENCODE = ["-an", "-c:v", "libx264", "-crf", "12", "-preset", "fast", "-r", "30", "-g", "30", "-pix_fmt", "yuv420p"];

/** Keeps the listed segments back to back; `holdEnd` repeats the last frame so a shot can rest on the result. */
function cut(input: string, output: string, segments: Segment[], holdEnd = 0) {
  const parts = segments.map(([from, to], i) => `[0:v]trim=${from}:${to},setpts=PTS-STARTPTS[s${i}]`);
  const joined = segments.map((_, i) => `[s${i}]`).join("");
  const hold = holdEnd > 0 ? `,tpad=stop_mode=clone:stop_duration=${holdEnd}` : "";
  const graph = `${parts.join(";")};${joined}concat=n=${segments.length}:v=1:a=0${hold}`;
  run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-i", input, "-filter_complex", graph, ...ENCODE, "-y", `${PUBLIC_SOURCES}/${output}`]);
}

mkdirSync(PUBLIC_SOURCES, { recursive: true });

// Take 4: Add Food, search "banana", Banana, Log. Idle stretches (Today before the tap, sheet open, results, form) are trimmed.
cut(`${RAW_DIR}/ring-take4.mov`, "search.mp4", [[3.2, 4.1], [4.6, 7.6], [8.2, 9.2], [9.7, 10.97]]);
// Take 4 from the Log tap: Today animates up, then rests on the new totals.
cut(`${RAW_DIR}/ring-take4.mov`, "rings.mp4", [[10.3, 11.9]], 3);
// Take 5, a separate take of the same flow, so the hook does not repeat the Rings shot frame for frame.
cut(`${RAW_DIR}/ring-take5.mov`, "hook.mp4", [[10.3, 11.6]], 1.5);
cut(`${RAW_DIR}/insights.mov`, "insights.mp4", [[1.5, 6.8]]);
// Home Screen: one still frame of the widget page, held.
run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-loop", "1", "-framerate", "30", "-t", "5", "-i", `${RAW_DIR}/home-widgets.png`, "-an", "-c:v", "libx264", "-crf", "12", "-r", "30", "-g", "30", "-pix_fmt", "yuv420p", "-y", `${PUBLIC_SOURCES}/home.mp4`]);
// Scan: the previous edit, camera on a protein bar through to Logged. 60 fps source, 720 x 1280, no bezel.
cut(DEMO_VIDEO, "scan.mp4", [[6.3, 10.6]]);
