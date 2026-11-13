// Renders the TikTok slideshows, avatar and captions: bun run render:slides [--safe-zones]
// Output: build/marketing/tiktok/set-<n>-<slug>/<i>.png, avatar.png, captions.md (--safe-zones writes review/ instead, with the TikTok zones outlined).
import { copyFileSync, mkdirSync, writeFileSync } from "node:fs";
import { fromRoot, run } from "./paths.ts";
import { SETS, SITE } from "../src/slides.ts";

const OUT = fromRoot("build/marketing/tiktok");
const SCREENS_SRC = fromRoot("web/src/assets/app-images");
const SCREENS_DEST = fromRoot("tools/media/trailer/public/screens");
// The rings mark sweeps in over 0.6 s, so stills are taken once it has settled.
const FRAME = 30;
const safeZones = process.argv.includes("--safe-zones");

const still = (id: string, out: string, props: object) =>
  run(["bunx", "remotion", "still", "src/index.ts", id, out, `--frame=${FRAME}`, "--image-format=png", `--props=${JSON.stringify(props)}`, "--overwrite"]);

mkdirSync(SCREENS_DEST, { recursive: true });
for (const name of new Set(SETS.flatMap((s) => s.slides.map((slide) => slide.screenshot)))) {
  if (name) copyFileSync(`${SCREENS_SRC}/${name}.png`, `${SCREENS_DEST}/${name}.png`);
}

const dir = safeZones ? `${OUT}/review` : OUT;
SETS.forEach((set, s) => {
  const setDir = `${dir}/set-${s + 1}-${set.slug}`;
  mkdirSync(setDir, { recursive: true });
  set.slides.forEach((_, i) => still("Slide", `${setDir}/${i + 1}.png`, { set: s + 1, index: i + 1, safeZones }));
});

if (!safeZones) {
  still("Avatar", `${OUT}/avatar.png`, {});
  const captions = SETS.map((set, s) => `## Set ${s + 1}: ${set.title}\n\n${set.caption}\nhttps://${SITE}\n\n${set.hashtags.join(" ")}\n`);
  writeFileSync(`${OUT}/captions.md`, `# TikTok captions\n\n${captions.join("\n")}`);
}
