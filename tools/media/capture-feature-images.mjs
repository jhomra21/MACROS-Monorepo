// Optional local tooling: cd build/feature-tools && bun add playwright
// With `cd web && bun run dev:worker --port 8798` running, run this from the root.
import { chromium } from '../../build/feature-tools/node_modules/playwright/index.mjs';
import sharp from '../../web/node_modules/sharp';
import { mkdir, writeFile, stat, copyFile } from 'node:fs/promises';

const evidence = 'build/evidence/2026-11-06-feature-images';

const tracked = 'docs/evidence/web-feature-images';

const browser = await chromium.launch({ headless: true });

const results = [];

const tiles = [];

const labels = [];

let rowTop = 0;

await mkdir(evidence, { recursive: true });

await mkdir(tracked, { recursive: true });

try {
	for (const [width, height] of [[390, 844], [768, 1024], [1440, 900]]) {
		for (const colorScheme of ['light', 'dark']) {
			const page = await browser.newPage({ viewport: { width, height }, colorScheme, deviceScaleFactor: 1 });

			await page.goto('http://localhost:8798/#why');
			await page.locator('#why').scrollIntoViewIfNeeded();

			// Visit every card to trigger the site's real reveal observer and native lazy loading.
			for (const card of await page.locator('#why article').all()) {
				await card.scrollIntoViewIfNeeded();
			}

			await page.locator('#why img').evaluateAll(images => Promise.all(images.map(image => image.decode())));
			await page.waitForFunction(() => [...document.querySelectorAll('#why [data-reveal]')].every(element => element.classList.contains('is-revealed')));
			await page.locator('#why').evaluate(async section => {
				await Promise.all(section.getAnimations({ subtree: true }).map(animation => animation.finished));
			});

			const images = await page.locator('#why img').evaluateAll(images => images.map(image => ({
				alt: image.alt,
				src: image.currentSrc,
				width: image.getBoundingClientRect().width,
				height: image.getBoundingClientRect().height,
				sizes: image.sizes,
				loading: image.loading,
				decoding: image.decoding,
			})));

			const overflow = await page.evaluate(() => document.documentElement.scrollWidth > innerWidth);

			if (overflow || images.length !== 6) throw new Error(`Invalid feature layout: ${width} ${colorScheme}`);

			for (const image of images) {
				image.bytes = (await stat(`web/dist${new URL(image.src).pathname}`)).size;
			}

			const name = `${width}-${colorScheme}.png`;

			await page.locator('#why').screenshot({
				path: `${evidence}/${name}`,
				animations: 'disabled',
				style: '.site-header, .skip-link { visibility: hidden; }',
			});
			results.push({ width, height, colorScheme, overflow, images, totalBytes: images.reduce((sum, image) => sum + image.bytes, 0) });

			const tile = await sharp(`${evidence}/${name}`).resize({ width: 360 }).png().toBuffer();

			const column = (results.length - 1) % 2;

			tiles.push({ input: tile, left: column * 384 + 12, top: rowTop + 40 });
			labels.push(`<text x="${column * 384 + 12}" y="${rowTop + 26}">${width} × ${height} · ${colorScheme}</text>`);

			if (column === 1) rowTop += (await sharp(tile).metadata()).height + 64;

			await page.close();
		}
	}
} finally {
	await browser.close();
}

const labelImage = `<svg width="768" height="${rowTop}" xmlns="http://www.w3.org/2000/svg"><style>text{font:16px Helvetica;fill:#fff}</style>${labels.join('')}</svg>`;

await sharp({ create: { width: 768, height: rowTop, channels: 3, background: '#343438' } })
	.composite([...tiles, { input: Buffer.from(labelImage), left: 0, top: 0 }])
	.png({ palette: true, quality: 85, effort: 10 })
	.toFile(`${evidence}/sheet.png`);

await writeFile(`${evidence}/browser-checks.json`, JSON.stringify(results, null, 2));

await copyFile(`${evidence}/sheet.png`, `${tracked}/sheet.png`);

console.log(JSON.stringify(results.map(({ width, colorScheme, totalBytes }) => ({ width, colorScheme, totalBytes })), null, 2));
