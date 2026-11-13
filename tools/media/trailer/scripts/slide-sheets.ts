// One review sheet per set: the five slides at 300 px wide, with the same five below them under the TikTok zone outlines.
// Needs bun run render:slides first; this renders the outlined copies itself. Output: docs/evidence/tiktok-slides/set-<n>-<slug>.jpg
import { mkdirSync } from "node:fs";
import { fromRoot, run } from "./paths.ts";
import { SETS } from "../src/slides.ts";

const OUT = fromRoot("docs/evidence/tiktok-slides");
const TIKTOK = fromRoot("build/marketing/tiktok");
const WIDTH = 300;

run(["bun", "scripts/render-slides.ts", "--safe-zones"]);
mkdirSync(OUT, { recursive: true });

SETS.forEach((set, s) => {
  const folder = `set-${s + 1}-${set.slug}`;
  const inputs = [TIKTOK, `${TIKTOK}/review`].flatMap((root) => set.slides.flatMap((_, i) => ["-i", `${root}/${folder}/${i + 1}.png`]));
  const scaled = Array.from({ length: 10 }, (_, i) => `[${i}:v]scale=${WIDTH}:-1[s${i}]`).join(";");
  const filter = `${scaled};[s0][s1][s2][s3][s4]hstack=5[top];[s5][s6][s7][s8][s9]hstack=5[bottom];[top][bottom]vstack[out]`;
  run(["ffmpeg", "-hide_banner", "-loglevel", "error", ...inputs, "-filter_complex", filter, "-map", "[out]", "-q:v", "4", "-frames:v", "1", "-y", `${OUT}/${folder}.jpg`]);
});
