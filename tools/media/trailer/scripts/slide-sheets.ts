// Contact sheets for the TikTok slideshows: bun run sheets:slides
// A sheet shows one set in one variant: the five slides at 300 px wide, with the same five below under the TikTok zone outlines.
// Renders the safe-zone copies itself. Every sheet goes to build/marketing/tiktok-compare/ (not tracked). The tracked evidence in
// docs/evidence/tiktok-slides/ is five images: the short sheets for sets 2, 3 and 5, and compare-set<n>.jpg for sets 1 and 4
// (short rows above full rows, each variant with and without the zones).
import { mkdirSync } from "node:fs";
import { TIKTOK_DIRS, fromRoot, run } from "./paths.ts";
import { SETS, type Copy } from "../src/slides.ts";

const COMPARE = fromRoot("build/marketing/tiktok-compare");
const EVIDENCE = fromRoot("docs/evidence/tiktok-slides");
const WIDTH = 300;
const COPIES: Copy[] = ["short", "full"];
const SHORT_ONLY = [2, 3, 5];

run(["bun", "scripts/render-slides.ts", "--safe-zones"]);

/** Slide paths of one set in one variant, from the normal render or the zone review copies. */
const slidePaths = (copy: Copy, n: number, review: boolean) => {
  const root = review ? `${TIKTOK_DIRS[copy]}/review` : TIKTOK_DIRS[copy];
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

mkdirSync(COMPARE, { recursive: true });
mkdirSync(EVIDENCE, { recursive: true });
SETS.forEach((set, s) => {
  const n = s + 1;
  const folder = `set-${n}-${set.slug}`;
  COPIES.forEach((copy) => sheet([slidePaths(copy, n, false), slidePaths(copy, n, true)], `${COMPARE}/${folder}-${copy}.jpg`));
  if (SHORT_ONLY.includes(n)) {
    sheet([slidePaths("short", n, false), slidePaths("short", n, true)], `${EVIDENCE}/${folder}.jpg`);
  } else {
    const rows = COPIES.flatMap((copy) => [slidePaths(copy, n, false), slidePaths(copy, n, true)]);
    sheet(rows, `${EVIDENCE}/compare-set${n}.jpg`);
  }
});
