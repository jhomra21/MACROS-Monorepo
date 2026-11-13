// Contact sheets for the TikTok slideshows: bun run sheets:slides
// One sheet per set in the short variant: the five slides at 300 px wide, with the same five below under the TikTok zone outlines.
// Renders the safe-zone copies itself. The five sheets go to docs/evidence/tiktok-slides/ (tracked, five JPGs).
import { mkdirSync } from "node:fs";
import { TIKTOK_DIR, fromRoot, run } from "./paths.ts";
import { SETS } from "../src/slides.ts";

const EVIDENCE = fromRoot("docs/evidence/tiktok-slides");
const WIDTH = 300;

run(["bun", "scripts/render-slides.ts", "--safe-zones"]);

/** Slide paths of one set in the short variant, from the normal render or the zone review copies. */
const slidePaths = (n: number, review: boolean) => {
  const root = review ? `${TIKTOK_DIR}/review` : TIKTOK_DIR;
  return SETS[n - 1].slides.map((_, i) => `${root}/set-${n}-${SETS[n - 1].slug}/${i + 1}.png`);
};

/** One JPG from rows of slide paths; every row has the same number of slides. */
const sheet = (rows: string[][], out: string) => {
  const cols = rows[0].length;
  const paths = rows.flat();
  const inputs = paths.flatMap((path) => ["-i", path]);
  const scaled = paths.map((_, i) => `[${i}:v]scale=${WIDTH}:-1[s${i}]`);
  const stacked = rows.map((row, r) => `${row.map((_, c) => `[s${r * cols + c}]`).join("")}hstack=${cols}[r${r}]`);
  const filter = [...scaled, ...stacked, `${rows.map((_, r) => `[r${r}]`).join("")}vstack=${rows.length}[out]`].join(";");
  run(["ffmpeg", "-hide_banner", "-loglevel", "error", ...inputs, "-filter_complex", filter, "-map", "[out]", "-q:v", "4", "-frames:v", "1", "-y", out]);
};

mkdirSync(EVIDENCE, { recursive: true });
SETS.forEach((set, s) => {
  const n = s + 1;
  sheet([slidePaths(n, false), slidePaths(n, true)], `${EVIDENCE}/set-${n}-${set.slug}.jpg`);
});
