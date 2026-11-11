// Turns the raw 1320 x 2868 simulator takes into the 30 fps clips the composition reads.
// Cuts only remove idle frames; no clip is sped up here.
import { mkdirSync } from "node:fs";
import { PUBLIC_SOURCES, RAW_DIR, run } from "./paths.ts";

type Segment = readonly [from: number, to: number];

const ENCODE = ["-an", "-c:v", "libx264", "-crf", "12", "-preset", "fast", "-r", "30", "-g", "30", "-pix_fmt", "yuv420p"];

/** Keeps the listed segments back to back (fps=30 first: simulator recordings are variable frame rate and drop idle frames); `holdEnd` repeats the last frame so a shot can rest on the result. */
function cut(input: string, output: string, segments: Segment[], holdEnd = 0) {
  const parts = segments.map(([from, to], i) => `[0:v]fps=30,trim=${from}:${to},setpts=PTS-STARTPTS[s${i}]`);
  const joined = segments.map((_, i) => `[s${i}]`).join("");
  const hold = holdEnd > 0 ? `,tpad=stop_mode=clone:stop_duration=${holdEnd}` : "";
  const graph = `${parts.join(";")};${joined}concat=n=${segments.length}:v=1:a=0${hold}`;
  run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-i", input, "-filter_complex", graph, ...ENCODE, "-y", `${PUBLIC_SOURCES}/${output}`]);
}

mkdirSync(PUBLIC_SOURCES, { recursive: true });

const flow = `${RAW_DIR}/flow-take1.mov`;
// flow-take1: Today at 1310, Add Food, search "banana", Banana, Log, Today at 1415, then the Home Screen with the MACROS widgets.
// Each moment appears once: the hook is Today before logging, Search stops at the Log tap, Rings starts at the dismissal.
cut(flow, "hook.mp4", [[2.0, 4.0]]);
cut(flow, "search.mp4", [[4.4, 5.3], [6.3, 7.6], [11.8, 12.6], [13.0, 13.9]], 0.1);
cut(flow, "rings.mp4", [[14.0, 17.5]], 0.5);
cut(flow, "home.mp4", [[17.6, 22.6]]);
// scan-take2: Camera, photo picker, barcode, result card, Logged. Idle stretches between taps are trimmed.
cut(`${RAW_DIR}/scan-take2.mov`, "scan.mp4", [[2.6, 3.9], [5.6, 6.3], [7.6, 8.6], [10.9, 11.4], [13.6, 14.8], [17.8, 19.0]], 0.1);
cut(`${RAW_DIR}/insights.mov`, "insights.mp4", [[1.5, 6.3]]);
