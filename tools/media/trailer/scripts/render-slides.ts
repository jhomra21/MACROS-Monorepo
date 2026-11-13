// Renders the slideshows with short headlines. TikTok (default): bun run render:slides [--safe-zones], which writes build/marketing/tiktok/
// with set-<n>-<slug>/<i>.png, avatar.png and captions.md; --safe-zones writes review/ instead, with the TikTok zones outlined.
// Instagram 4:5 (1080 x 1350): bun run render:slides:instagram [--out=<absolute dir>], which writes set-<n>-<slug>/<i>.png and captions.md
// to --out, default build/marketing/instagram/.
import { copyFileSync, mkdirSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";
import { INSTAGRAM_DIR, PUBLIC_SOURCES, TIKTOK_DIR, fromRoot, run } from "./paths.ts";
import { SETS, SITE } from "../src/slides.ts";
import type { Format, SlideProps } from "../src/slide.tsx";

const SCREENS_SRC = fromRoot("web/src/assets/app-images");
const SCREENS_DEST = fromRoot("tools/media/trailer/public/screens");
// home-clean is the trailer's Home Screen still (MACROS only), not an app screenshot; see docs/evidence/tiktok-slides/README.md.
const screenFile = (name: string) => (name === "home-clean" ? `${PUBLIC_SOURCES}/home-clean.png` : `${SCREENS_SRC}/${name}.png`);
// The rings mark sweeps in over 0.6 s, so stills are taken once it has settled.
const FRAME = 30;

const option = (name: string) => process.argv.find((arg) => arg.startsWith(`--${name}=`))?.slice(name.length + 3);
const format = (option("format") ?? "tiktok") as Format;
if (format !== "tiktok" && format !== "instagram") throw new Error(`Unknown --format=${format}`);
const safeZones = process.argv.includes("--safe-zones");
if (safeZones && format === "instagram") throw new Error("--safe-zones outlines the TikTok zones only");
const outOption = option("out");
const root = outOption ? resolve(outOption) : format === "instagram" ? INSTAGRAM_DIR : TIKTOK_DIR;
const dir = safeZones ? `${root}/review` : root;

const still = (id: string, out: string, props: object) =>
  run(["bunx", "remotion", "still", "src/index.ts", id, out, `--frame=${FRAME}`, "--image-format=png", `--props=${JSON.stringify(props)}`, "--overwrite"]);

mkdirSync(SCREENS_DEST, { recursive: true });
for (const name of new Set(SETS.flatMap((s) => s.slides.map((slide) => slide.screenshot)))) {
  if (name) copyFileSync(screenFile(name), `${SCREENS_DEST}/${name}.png`);
}

SETS.forEach((set, s) => {
  const setDir = `${dir}/set-${s + 1}-${set.slug}`;
  mkdirSync(setDir, { recursive: true });
  set.slides.forEach((_, i) => still("Slide", `${setDir}/${i + 1}.png`, { format, set: s + 1, index: i + 1, safeZones, copy: "short" } satisfies SlideProps));
});

if (!safeZones) {
  if (format === "tiktok") still("Avatar", `${root}/avatar.png`, {});
  const captions = SETS.map((set, s) => `## Set ${s + 1}: ${set.title}\n\n${set.caption}\nhttps://${SITE}\n\n${set.hashtags.join(" ")}\n`);
  const label = format === "instagram" ? "Instagram" : "TikTok";
  writeFileSync(`${root}/captions.md`, `# ${label} captions\n\n${captions.join("\n")}`);
}
