// Renders the trailer MP4s and cover: bun run render <all | coming-soon | app-store | review | cover>
import { OUT_DIR, run } from "./paths.ts";
import { FPS, TOTAL_FRAMES } from "../src/shots.ts";
import type { Props } from "../src/trailer.tsx";

const COVER_FRAME = 30;

const remotion = (args: string[]) => run(["bunx", "remotion", ...args]);

function renderVideo(props: Props, name: string) {
  const raw = `${OUT_DIR}/${name}-raw.mp4`;
  remotion(["render", "src/index.ts", "Trailer", raw, "--overwrite", `--props=${JSON.stringify(props)}`, "--codec=h264", "--crf=18", "--pixel-format=yuv420p", "--audio-codec=aac", "--enforce-audio-track"]);
  // Remotion's AAC track runs a few ms long; ending the copy 10 ms before the last frame's end keeps exactly TOTAL_FRAMES video frames and a container duration of TOTAL_FRAMES / FPS.
  const cutoff = (TOTAL_FRAMES / FPS - 0.01).toFixed(3);
  run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-i", raw, "-map", "0", "-c", "copy", "-t", cutoff, "-movflags", "+faststart", "-y", `${OUT_DIR}/${name}.mp4`]);
  run(["rm", raw]);
}

function renderCover() {
  const props: Props = { variant: "coming-soon", safeZones: false };
  remotion(["still", "src/index.ts", "Trailer", `${OUT_DIR}/cover.png`, `--frame=${COVER_FRAME}`, "--image-format=png", `--props=${JSON.stringify(props)}`, "--overwrite"]);
}

const target = process.argv[2];
const jobs: Record<string, () => void> = {
  "coming-soon": () => renderVideo({ variant: "coming-soon", safeZones: false }, "coming-soon"),
  "app-store": () => renderVideo({ variant: "app-store", safeZones: false }, "app-store"),
  review: () => renderVideo({ variant: "coming-soon", safeZones: true }, "review"),
  cover: renderCover,
};
if (target === "all") Object.values(jobs).forEach((job) => job());
else if (target in jobs) jobs[target]();
else {
  console.error("usage: bun run render all | coming-soon | app-store | review | cover");
  process.exit(1);
}
