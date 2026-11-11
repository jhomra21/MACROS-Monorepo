// Renders trailer MP4s and covers: bun run render <all | style variant [--review] | cover style>
import { OUT_DIR, run } from "./paths.ts";
import type { Props } from "../src/trailer.tsx";

const STYLES = ["restrained", "bold"] as const;
const VARIANTS = ["coming-soon", "app-store"] as const;
const COVER_FRAME = 30;

const remotion = (args: string[]) => run(["bunx", "remotion", ...args]);

function renderVideo(props: Props, name: string) {
  const raw = `${OUT_DIR}/${name}-raw.mp4`;
  remotion(["render", "src/index.ts", "Trailer", raw, "--overwrite", `--props=${JSON.stringify(props)}`, "--codec=h264", "--crf=18", "--pixel-format=yuv420p", "--audio-codec=aac", "--enforce-audio-track"]);
  // Remotion's AAC track runs a few ms long; trimming to 29.99 s keeps exactly 900 video frames and 30.000 s.
  run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-i", raw, "-map", "0", "-c", "copy", "-t", "29.99", "-movflags", "+faststart", "-y", `${OUT_DIR}/${name}.mp4`]);
  run(["rm", raw]);
}

function renderCover(style: Props["style"]) {
  const props: Props = { style, variant: "coming-soon", safeZones: false };
  remotion(["still", "src/index.ts", "Trailer", `${OUT_DIR}/cover-${style}.png`, `--frame=${COVER_FRAME}`, "--image-format=png", `--props=${JSON.stringify(props)}`, "--overwrite"]);
}

const [command, second, third, fourth] = process.argv.slice(2);
if (command === "all") {
  for (const style of STYLES) {
    for (const variant of VARIANTS) renderVideo({ style, variant, safeZones: false }, `${style}-${variant}`);
    renderVideo({ style, variant: "coming-soon", safeZones: true }, `review-${style}`);
    renderCover(style);
  }
} else if (command === "cover" && STYLES.includes(second as never)) {
  renderCover(second as Props["style"]);
} else if (STYLES.includes(command as never) && VARIANTS.includes(second as never)) {
  const review = third === "--review" || fourth === "--review";
  renderVideo({ style: command as Props["style"], variant: second as Props["variant"], safeZones: review }, review ? `review-${command}` : `${command}-${second}`);
} else {
  console.error("usage: bun run render all | <restrained|bold> <coming-soon|app-store> [--review] | cover <restrained|bold>");
  process.exit(1);
}
