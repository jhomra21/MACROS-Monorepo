// Turns the raw 1320 x 2868 simulator takes into the 30 fps clips the composition reads.
// Cuts only remove idle frames; no clip is sped up here.
import { mkdirSync } from "node:fs";
import { DEMO_VIDEO, PUBLIC_SOURCES, RAW_DIR, RAW_DIR_V4, run } from "./paths.ts";

type Segment = readonly [from: number, to: number];

const ENCODE = ["-an", "-c:v", "libx264", "-crf", "12", "-preset", "fast", "-r", "30", "-g", "30", "-pix_fmt", "yuv420p"];

/** Keeps the listed segments back to back (fps=30 first: simulator recordings are variable frame rate and drop idle frames); `holdEnd` repeats the last frame so a shot can rest on the result. */
function cut(input: string, output: string, segments: Segment[], holdEnd = 0) {
  const parts = segments.map(([from, to], i) => `[0:v]fps=30,trim=start_frame=${Math.round(from * 30)}:end_frame=${Math.round(to * 30)},setpts=PTS-STARTPTS[s${i}]`);
  const joined = segments.map((_, i) => `[s${i}]`).join("");
  const hold = holdEnd > 0 ? `,tpad=stop_mode=clone:stop_duration=${holdEnd}` : "";
  const graph = `${parts.join(";")};${joined}concat=n=${segments.length}:v=1:a=0${hold}`;
  run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-i", input, "-filter_complex", graph, ...ENCODE, "-y", `${PUBLIC_SOURCES}/${output}`]);
}

/**
 * The scan clip from the original demo recording (720 x 1280, 60 fps). The burnt-in "Scan it." pill sits over the real status bar
 * until about 10 s, so the body crop starts below it at y 222. The status bar strip (rows 148-221) comes from `stripAt`, a frame
 * after the pill has gone, so the phone shows the recording's own 9:41 status bar. The body plays at 1.0x; `holdEnd` rests the
 * last frame. Output is 496 x 1078, the screen's aspect.
 */
function scan(input: string, output: string, from: number, to: number, stripAt: number, holdEnd: number) {
  const body = `[0:v]fps=30,trim=start=${from}:duration=${to - from},setpts=PTS-STARTPTS,crop=496:1004:112:222,tpad=stop_mode=clone:stop_duration=${holdEnd}[body]`;
  const strip = `[0:v]fps=30,trim=start=${stripAt},setpts=PTS-STARTPTS,trim=end_frame=1,crop=496:74:112:148,loop=loop=-1:size=1,setpts=N/FRAME_RATE/TB[strip]`;
  const frames = Math.round((to - from + holdEnd) * 30);
  const stack = `[strip][body]vstack=inputs=2:shortest=1,trim=end_frame=${frames},setpts=PTS-STARTPTS,scale=out_range=tv,format=yuv420p`;
  run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-i", input, "-filter_complex", `${body};${strip};${stack}`, ...ENCODE, "-y", `${PUBLIC_SOURCES}/${output}`]);
}

mkdirSync(PUBLIC_SOURCES, { recursive: true });

const flow = `${RAW_DIR}/flow-take1.mov`;
// flow-take1: Today at 1310, Add Food, search "banana", Banana, Log, Today at 1415, then the Home Screen with the MACROS widgets.
// Each moment appears once: the hook is Today before logging, Search stops on the Log Food form before the Log tap, Rings starts at the dismissal.
// The hook is Today through 3.5 s of the take; the Add Food sheet rises after that. The clip stops at 3.5 s and holds its last
// Today frame, so the 3.5 s shot stays on Today (3.0 s of footage plus the 0.5 s hold).
cut(flow, "hook.mp4", [[0.5, 3.5]], 0.5);
cut(flow, "search.mp4", [[4.4, 5.3], [6.3, 7.6], [11.8, 12.6], [13.0, 13.9]], 0.1);
cut(flow, "home.mp4", [[17.6, 22.6]]);
// Scan: camera, barcode, product card, Logged, from the original demo. The demo still shows Today (1725 kcal) until about 6.5 s, so the
// clip starts on the camera at 6.6 s and the Search cross-fade lands on the camera only. It ends at 10.2 s, before the insights
// crossfade; the last frame rests 0.4 s so the shot still lasts 4.0 s on the 0.5 s grid.
scan(DEMO_VIDEO, "scan.mp4", 6.6, 10.2, 10.2, 0.4);

// v4 takes (demo data, Today trimmed to one entry first). rings-take1: Today at 350 kcal, then four foods from the Add Food recents
// (Turkey sandwich, Chicken and rice bowl, Pasta with tomato sauce, Salmon fillet). Each moment starts once the bottom Camera and Add Food
// buttons have settled after the Log Food sheet leaves; the ring and number have finished by then (740, 1340, 1620, 2080 kcal). Each is 1.1 s.
// The take ends at 25.44 s, so the last moment has 0.17 s of footage and holds its settled last frame for the rest. Sheets and idle time are cut.
const rings = `${RAW_DIR_V4}/rings-take1.mov`;
cut(rings, "rings.mp4", [[2.4, 3.0], [7.2, 8.3], [13.4, 14.5], [19.1, 20.2], [25.267, 25.44]], 0.933);
// insights-take1: Today, tap the Insights button, the push, then rest on the top of Insights (4.0 s from the tap's lead-in).
cut(`${RAW_DIR_V4}/insights-take1.mov`, "insights.mp4", [[4.2, 8.2]]);
