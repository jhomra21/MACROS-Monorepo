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
// Each moment appears once: the hook is Today before logging, Search stops at the Log tap, Rings starts at the dismissal.
// The hook rests on Today for 1.6 s, then the Add Food tap and the sheet rising (2.0-4.0 s); 0.5-2.0 s is the same idle Today.
cut(flow, "hook.mp4", [[0.5, 4.0]]);
cut(flow, "search.mp4", [[4.4, 5.3], [6.3, 7.6], [11.8, 12.6], [13.0, 13.9]], 0.1);
cut(flow, "home.mp4", [[17.6, 22.6]]);
// Scan: camera, barcode, product card, Logged, from the original demo. It ends at 10.2 s, before the insights crossfade; the last frame rests 0.1 s to land the shot on the 0.5 s grid (4.0 s).
scan(DEMO_VIDEO, "scan.mp4", 6.3, 10.2, 10.2, 0.1);

// v4 takes (demo data, Today trimmed to one entry first). rings-take1: Today at 350 kcal, then four foods from the Add Food recents
// (Turkey sandwich, Chicken and rice bowl, Pasta with tomato sauce, Salmon fillet). Each segment starts as the Log Food sheet leaves and
// runs 1.1 s, so the ring finishes climbing and the new row shows (740, 1340, 1620, 2080 kcal). Sheets and idle time are cut.
const rings = `${RAW_DIR_V4}/rings-take1.mov`;
cut(rings, "rings.mp4", [[2.4, 3.0], [6.43, 7.53], [12.23, 13.33], [18.13, 19.23], [24.13, 25.23]]);
// insights-take1: Today, tap the Insights button, the push, then rest on the top of Insights (4.0 s from the tap's lead-in).
cut(`${RAW_DIR_V4}/insights-take1.mov`, "insights.mp4", [[4.2, 8.2]]);
