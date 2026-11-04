import { spawn } from 'node:child_process';
import { mkdir, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { chromium } from 'playwright';

const root = fileURLToPath(new URL('../../../', import.meta.url));

const output = fileURLToPath(new URL('./', import.meta.url));

const url = 'http://127.0.0.1:4318';

const server = spawn('bun', ['run', 'astro', 'preview', '--host', '127.0.0.1', '--port', '4318'], {
	cwd: `${root}/web`,
	stdio: ['ignore', 'pipe', 'pipe'],
});

let browser;

const report = [];

try {
	await new Promise((resolve, reject) => {
		let log = '';
		server.stdout.on('data', chunk => {
			log += chunk;

			if (log.includes('4318')) resolve();
		});
		server.stderr.on('data', chunk => { log += chunk; });
		server.once('error', reject);
		server.once('exit', code => reject(new Error(`Preview exited ${code}: ${log}`)));
	});
	await mkdir(output, { recursive: true });
	browser = await chromium.launch({ headless: true });

	for (const width of [390, 1440]) {
		for (const colorScheme of ['light', 'dark']) {
			const context = await browser.newContext({
				viewport: { width, height: width === 390 ? 844 : 1000 },
				deviceScaleFactor: 1,
				colorScheme,
				reducedMotion: 'reduce',
			});

			const page = await context.newPage();
			const errors = [];
			page.on('pageerror', error => errors.push(error.message));
			page.on('response', response => {
				if (response.status() >= 400) errors.push(`HTTP ${response.status()} ${response.url()}`);
			});
			await page.goto(url, { waitUntil: 'networkidle' });
			await page.evaluate(async () => {
				await document.fonts.ready;
				const images = [...document.images];

				for (const image of images) image.loading = 'eager';
				await Promise.all(images.map(image => image.decode()));
			});
			const cards = page.locator('.showcase__card');

			for (let index = 0; index < await cards.count(); index += 1) {
				await cards.nth(index).scrollIntoViewIfNeeded();
			}

			await page.evaluate(() => {
				document.querySelector('.showcase__track').scrollLeft = 0;
				window.scrollTo(0, 0);
			});
			await page.screenshot({
				path: `${output}/home-${width}-${colorScheme}.jpg`,
				type: 'jpeg', quality: 85, fullPage: true, animations: 'disabled',
			});

			for (const [index, name] of [[1, 'search'], [3, 'inline-details'], [5, 'insights'], [8, 'widgets']]) {
				await cards.nth(index).scrollIntoViewIfNeeded();
				await page.screenshot({
					path: `${output}/media-${name}-${width}-${colorScheme}.jpg`,
					type: 'jpeg', quality: 85, animations: 'disabled',
				});
			}

			const home = await page.evaluate(() => ({
				viewport: innerWidth,
				documentWidth: document.documentElement.scrollWidth,
				images: [...document.images].map(image => ({
					alt: image.alt, decoded: image.complete && image.naturalWidth > 0,
				})),
			}));

			if (home.documentWidth > width || home.images.some(image => !image.decoded))
				throw new Error(`Home overflow or undecoded image at ${width}/${colorScheme}`);
			await page.goto(`${url}/privacy`, { waitUntil: 'networkidle' });

			const privacy = await page.evaluate(() => ({
				viewport: innerWidth,
				documentWidth: document.documentElement.scrollWidth,
				hasSearchDisclosure: document.body.textContent.includes('normalized query, source, and page'),
			}));

			if (privacy.documentWidth > width || !privacy.hasSearchDisclosure || errors.length > 0)
				throw new Error(`Privacy or browser errors: ${JSON.stringify({ privacy, errors })}`);
			report.push({ width, colorScheme, home, privacy, errors });
			await context.close();
		}
	}

	await writeFile(`${output}/browser-checks.json`, `${JSON.stringify(report, null, 2)}\n`);
	console.log('Captured built-site screenshots at both widths and appearances. No overflow, image decode failures, HTTP errors, or page errors.');
} finally {
	await browser?.close();
	server.kill('SIGTERM');
	await new Promise(resolve => {
		if (server.exitCode !== null || server.signalCode !== null) resolve();
		else server.once('exit', resolve);
	});
}
