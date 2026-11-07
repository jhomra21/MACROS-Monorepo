// With `cd web && bunx wrangler dev --port 8790` running, run from the root.
// Install Playwright in ignored build/feature-tools first.
import { chromium } from '../../build/feature-tools/node_modules/playwright/index.mjs';
import sharp from '../../web/node_modules/sharp';
import { mkdir, writeFile, stat } from 'node:fs/promises';

const evidence = 'build/review';

const tracked = 'docs/evidence/web-feature-images';

const browser = await chromium.launch({ headless: true });

const results = [];

const tiles = [];

const labels = [];

let left = 12;

let sheetHeight = 0;

await mkdir(evidence, { recursive: true });

try {
	for (const [width, height, colorScheme] of [
		[1440, 900, 'light'],
		[1440, 900, 'dark'],
		[390, 844, 'light'],
		[768, 1024, 'light'],
	]) {
		const page = await browser.newPage({
			viewport: { width, height }, colorScheme, deviceScaleFactor: 2, reducedMotion: 'reduce',
		});

		await page.goto('http://localhost:8790/#why');

		for (const card of await page.locator('#why article').all()) await card.scrollIntoViewIfNeeded();
		await page.locator('#why img').evaluateAll(images => Promise.all(images.map(image => image.decode())));
		await page.waitForFunction(() => [...document.querySelectorAll('#why [data-reveal]')].every(element => element.classList.contains('is-revealed')));

		const images = await page.locator('#why img').evaluateAll(images => images.map(image => {
			const frame = image.parentElement.parentElement.getBoundingClientRect();
			const rect = image.getBoundingClientRect();

			return {
				alt: image.alt, src: image.currentSrc, width: rect.width, height: rect.height,
				frameWidth: frame.width, frameHeight: frame.height, fit: getComputedStyle(image).objectFit,
				loading: image.loading, decoding: image.decoding, sizes: image.sizes,
			};
		}));

		const overflow = await page.evaluate(() => document.documentElement.scrollWidth > innerWidth);

		if (overflow || images.length !== 6) throw new Error(`Invalid layout: ${width} ${colorScheme}`);

		for (const image of images) {
			if (image.fit !== 'cover' || Math.abs(image.width - image.frameWidth + 2) > 1 ||
				Math.abs(image.height - image.frameHeight + 2) > 1) throw new Error(`Unfilled frame: ${image.alt}`);
			image.bytes = (await stat(`web/dist${new URL(image.src).pathname}`)).size;
		}

		const name = `${width}-${colorScheme}`;

		const png = await page.locator('#why').screenshot({
			animations: 'disabled', style: '.site-header, .skip-link { visibility: hidden; }',
		});

		await sharp(png).resize({ width: 1440, withoutEnlargement: true }).jpeg({ quality: 82 }).toFile(`${evidence}/${name}.jpg`);
		const tile = await sharp(png).resize({ width: 340 }).png().toBuffer();
		const tileHeight = (await sharp(tile).metadata()).height;
		tiles.push({ input: tile, left, top: 40 });
		labels.push(`<text x="${left}" y="26">${width} × ${height} · ${colorScheme} · 2×</text>`);
		left += 352;
		sheetHeight = Math.max(sheetHeight, tileHeight + 52);
		results.push({ width, height, colorScheme, scale: 2, overflow, images, totalBytes: images.reduce((sum, image) => sum + image.bytes, 0) });
		await page.close();
	}
} finally {
	await browser.close();
}

const labelImage = `<svg width="${left}" height="${sheetHeight}" xmlns="http://www.w3.org/2000/svg"><style>text{font:14px Helvetica;fill:#fff}</style>${labels.join('')}</svg>`;

await sharp({ create: { width: left, height: sheetHeight, channels: 3, background: '#343438' } })
	.composite([...tiles, { input: Buffer.from(labelImage), left: 0, top: 0 }])
	.png({ palette: true, quality: 85, effort: 10 })
	.toFile(`${tracked}/sheet.png`);

if ((await stat(`${tracked}/sheet.png`)).size > 1_500_000) throw new Error('Contact sheet exceeds 1.5 MB');

await writeFile(`${evidence}/browser-checks.json`, JSON.stringify(results, null, 2));

console.log(JSON.stringify(results.map(({ width, colorScheme, totalBytes, images }) => ({
	width, colorScheme, totalBytes, images: images.map(({ alt, bytes }) => ({ alt, bytes })),
})), null, 2));
