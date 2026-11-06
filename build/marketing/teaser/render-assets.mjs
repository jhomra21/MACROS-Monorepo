import { createRequire } from "node:module";
import { join } from "node:path";
import { mkdir } from "node:fs/promises";

const require = createRequire("/tmp/macros-teaser-renderer/package.json");
const { chromium } = require("playwright");
const sharp = require("sharp");
const dir = new URL(".", import.meta.url).pathname;
const browser = await chromium.launch({
  executablePath: `${process.env.HOME}/Library/Caches/ms-playwright/chromium-1248/chrome-mac-arm64/Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing`,
  headless: true,
});
try {
  const page = await browser.newPage({ deviceScaleFactor: 1 });
  for (const screen of ["home", "charts"]) {
    for (const height of [1350, 1920]) {
      for (const [letter, kind] of [["A", "clean"], ["B", "line"]]) {
        await page.setViewportSize({ width: 1080, height });
        await page.goto(`file://${join(dir, "render.html")}?screen=${screen}&kind=${kind}&height=${height}`);
        await page.evaluate(async () => {
          await document.fonts.ready;
          await Promise.all([...document.images].map(image => image.decode()));
        });
        const geometry = await page.locator(".phone img").boundingBox();
        if (Math.abs(geometry.width / geometry.height - 1320 / 2868) > .0001 || geometry.y + geometry.height > height - 63) {
          throw new Error("Full screen framing failed");
        }
        await page.screenshot({ path: join(dir, `${screen}-${letter}${height === 1920 ? "-tiktok" : ""}.png`) });
      }
    }
  }
  const files = ["home-A.png", "home-B.png", "charts-A.png", "charts-B.png"];
  const cells = await Promise.all(files.map(async (name, i) => ({
    input: await sharp(join(dir, name)).resize(540, 675).png().toBuffer(),
    left: i % 2 * 540, top: Math.floor(i / 2) * 675,
  })));
  await sharp({ create: { width: 1080, height: 1350, channels: 3, background: "#f2f2f7" } })
    .composite(cells).png().toFile(join(dir, "contact-sheet.png"));
  // Lossless alpha mask preserves every row of the native screen.
  await sharp(Buffer.from('<svg width="884" height="1920"><rect width="884" height="1920" rx="80" fill="white"/></svg>'))
    .png().toFile("/tmp/teaser-mask.png");
  await page.setViewportSize({ width: 1080, height: 1920 });
  await page.goto(`file://${join(dir, "endcard.html")}`);
  await page.evaluate(() => document.fonts.ready);
  await mkdir("/tmp/macros-endcard-v8", { recursive: true });
  for (let frame = 0; frame < 150; frame++) {
    await page.evaluate(time => window.renderFrame(time), frame / 60);
    await page.screenshot({ path: `/tmp/macros-endcard-v8/${String(frame).padStart(3, "0")}.png` });
  }
} finally {
  await browser.close();
}
