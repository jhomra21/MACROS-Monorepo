import { createRequire } from "node:module";
import { join } from "node:path";
import { unlink } from "node:fs/promises";

const require = createRequire("/tmp/macros-teaser-renderer/package.json");
const { chromium } = require("playwright");
const sharp = require("sharp");
const dir = new URL(".", import.meta.url).pathname;
const browser = await chromium.launch({
  executablePath: `${process.env.HOME}/Library/Caches/ms-playwright/chromium-1248/chrome-mac-arm64/Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing`,
  headless: true,
});
const page = await browser.newPage({ deviceScaleFactor: 1 });
const html = `file://${join(dir, "render.html")}`;
const croppedHome = join(dir, ".home-crop.png");
const croppedCharts = join(dir, ".charts-crop.png");
await sharp(join(dir, "home.png")).extract({ left: 120, top: 330, width: 1080, height: 1180 }).png().toFile(croppedHome);
await sharp(join(dir, "charts.png")).extract({ left: 0, top: 350, width: 1320, height: 1470 }).resize(1080, 1203).png().toFile(croppedCharts);

for (const screen of ["home", "charts"]) {
  for (const kind of ["clean", "line", "crop"]) {
    await page.setViewportSize({ width: 1080, height: 1350 });
    await page.goto(`${html}?screen=${screen}&kind=${kind}`);
    if (kind === "crop") {
      await page.evaluate((src) => { document.querySelector("#screen").src = src; }, `file://${screen === "home" ? croppedHome : croppedCharts}`);
    }
    await page.waitForTimeout(150);
    await page.screenshot({ path: join(dir, `${screen}-${kind === "clean" ? "A" : kind === "line" ? "B" : "C"}.png`) });
  }
  await page.setViewportSize({ width: 1080, height: 1920 });
  await page.goto(`${html}?screen=${screen}&kind=tiktok`);
  await page.waitForTimeout(150);
  await page.screenshot({ path: join(dir, `${screen}-B-tiktok.png`) });
}

const files = ["home-A.png", "home-B.png", "home-C.png", "charts-A.png", "charts-B.png", "charts-C.png"];
const cellWidth = 360;
const cellHeight = 450;
const cells = await Promise.all(files.map(async (name) => {
  const image = await sharp(join(dir, name)).resize(cellWidth, cellHeight).png().toBuffer();
  return { input: image, left: (files.indexOf(name) % 3) * cellWidth, top: Math.floor(files.indexOf(name) / 3) * cellHeight };
}));
await sharp({ create: { width: cellWidth * 3, height: cellHeight * 2, channels: 3, background: "#f1f1f6" } })
  .composite(cells).png().toFile(join(dir, "contact-sheet.png"));
await browser.close();
await unlink(croppedHome);
await unlink(croppedCharts);
