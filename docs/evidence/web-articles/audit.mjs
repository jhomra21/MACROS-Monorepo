import { spawn } from 'node:child_process';
import { mkdir, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { chromium } from '../../../build/seo-tools/node_modules/playwright/index.mjs';
import lighthouse from '../../../build/seo-tools/node_modules/lighthouse/core/index.js';
import * as chromeLauncher from '../../../build/seo-tools/node_modules/chrome-launcher/dist/index.js';
import { verifySite, verifyPublishedSite } from '../web-seo/verify.mjs';
import { verifyArticles } from './verify-articles.mjs';

const root = fileURLToPath(new URL('../../../', import.meta.url));

const output = fileURLToPath(new URL('./', import.meta.url));

const phase = process.argv[2] ?? 'after';

const origin = 'http://127.0.0.1:8797';

const server = spawn('bun', ['run', 'dev:worker', '--port', '8797'], {
	cwd: `${root}/web`, stdio: ['ignore', 'pipe', 'pipe'], detached: true,
});

let chrome;

let browser;

try {
	await new Promise((resolve, reject) => {
		let log = '';
		server.stdout.on('data', chunk => {
			log += chunk;

			if (log.includes('Ready on http://localhost:8797')) resolve();
		});
		server.stderr.on('data', chunk => { log += chunk; });
		server.once('error', reject);
		server.once('exit', code => reject(new Error(`Worker exited ${code}: ${log}`)));
	});
	await mkdir(output, { recursive: true });
	browser = await chromium.launch();

	if (phase === 'launch') {
		const page = await browser.newPage({ viewport: { width: 1440, height: 1000 }, reducedMotion: 'reduce' });
		await page.goto(origin, { waitUntil: 'networkidle' });

		if (await page.locator('meta[name="apple-itunes-app"]').getAttribute('content') !== 'app-id=6767565938') throw new Error('Smart App Banner missing');
		const badge = page.locator('.app-store-badge');

		if (await badge.count() !== 1 || await badge.getAttribute('href') !== 'https://apps.apple.com/app/id6767565938') throw new Error('Launch badge missing or duplicated');
		await badge.locator('img').evaluate(image => image.decode());
		await page.screenshot({ path: `${output}/app-store-flag-on.jpg`, quality: 80 });
		console.log('Flag-on Smart App Banner and official badge preview captured.');
	} else if (phase === 'published') {
		await verifyPublishedSite(browser, origin, output);
		const response = await fetch(`${origin}/social/blog/macros-launch.png`);

		if (!response.ok || !response.headers.get('content-type')?.includes('image/png')) throw new Error('Published blog social image missing');
		await writeFile(`${output}/blog-og.png`, new Uint8Array(await response.arrayBuffer()));
	} else if (phase === 'verify') {
		await verifySite(browser, origin, output);
		await verifyArticles(browser, origin, output);
	} else {
	await verifySite(browser, origin, output);

	if (phase !== 'before') await verifyArticles(browser, origin, output);

	if (phase !== 'screens') {
	chrome = await chromeLauncher.launch({
		chromePath: chromium.executablePath(), chromeFlags: ['--headless', '--no-sandbox'],
	});
	const results = [];

	const pageBytes = [];

	for (const [name, path] of [['home', '/'], ['guide', '/guides/how-to-set-macro-goals/']]) {
		const page = await browser.newPage();

		await page.goto(`${origin}${path}`, { waitUntil: 'networkidle' });

		const inlineJavaScript = await page.evaluate(() => [...document.scripts]
			.filter(script => !script.src && script.type !== 'application/ld+json')
			.reduce((sum, script) => sum + new TextEncoder().encode(script.textContent).length, 0));

		await page.close();

		for (const width of [390, 1440]) {
			const context = await browser.newContext({ viewport: { width, height: 900 }, deviceScaleFactor: 1 });
			const readingPage = await context.newPage();

			await readingPage.goto(`${origin}${path}`, { waitUntil: 'networkidle' });
			await readingPage.evaluate(async () => {
				for (const image of document.images) image.loading = 'eager';
				await Promise.all([...document.images].map(image => image.decode()));
			});

			const bytes = await readingPage.evaluate(() => {
				const entries = performance.getEntriesByType('resource');
				const navigation = performance.getEntriesByType('navigation')[0];

				return {
					transfer: navigation.transferSize + entries.reduce((sum, entry) => sum + entry.transferSize, 0),
					imageTransfer: entries.filter(entry => entry.initiatorType === 'img').reduce((sum, entry) => sum + entry.transferSize, 0),
					fontRequests: entries.filter(entry => /\.(woff2?|ttf)(\?|$)/.test(entry.name)).length,
				};
			});

			pageBytes.push({ name, width, ...bytes });
			await context.close();
		}

		for (const mode of ['mobile', 'desktop']) {
			const { lhr } = await lighthouse(`${origin}${path}`, {
				port: chrome.port, output: 'json', logLevel: 'error',
				onlyCategories: ['performance', 'accessibility', 'best-practices', 'seo'],
			}, mode === 'desktop' ? {
				extends: 'lighthouse:default', settings: {
					formFactor: 'desktop',
					screenEmulation: { mobile: false, width: 1440, height: 900, deviceScaleFactor: 1, disabled: false },
					throttling: { rttMs: 40, throughputKbps: 10240, cpuSlowdownMultiplier: 1 },
				},
			} : undefined);

			if (lhr.runtimeError) throw new Error(JSON.stringify(lhr.runtimeError));

			const result = {
				name, mode, scores: Object.fromEntries(Object.entries(lhr.categories).map(([key, value]) => [key, value.score * 100])),
				metrics: Object.fromEntries(['first-contentful-paint', 'largest-contentful-paint', 'total-blocking-time', 'cumulative-layout-shift', 'speed-index'].map(key => [key, { value: lhr.audits[key].numericValue, display: lhr.audits[key].displayValue }])),
				bytes: {
					inlineJavaScript,
					transfer: lhr.audits['total-byte-weight'].numericValue,
					javascript: lhr.audits['network-requests'].details.items.filter(item => item.resourceType === 'Script').reduce((sum, item) => sum + item.resourceSize, 0),
					javascriptTransfer: lhr.audits['network-requests'].details.items.filter(item => item.resourceType === 'Script').reduce((sum, item) => sum + item.transferSize, 0),
				},
				failures: Object.entries(lhr.audits).filter(([, audit]) => audit.score !== null && audit.score < 1).map(([id, audit]) => ({ id, title: audit.title, details: audit.details })),
			};

			results.push(result);
			console.log(JSON.stringify({ phase, name, mode, scores: result.scores, metrics: result.metrics, bytes: result.bytes }));
		}
	}

	await writeFile(`${output}/${phase}-lighthouse.json`, `${JSON.stringify(results, null, 2)}\n`);
	await writeFile(`${output}/${phase}-page-bytes.json`, `${JSON.stringify(pageBytes, null, 2)}\n`);
	}

	if (phase !== 'before') {
	const checks = [];

	for (const width of [390, 1440]) {
		for (const colorScheme of ['light', 'dark']) {
			const context = await browser.newContext({
				viewport: { width, height: width === 390 ? 844 : 1000 },
				colorScheme, reducedMotion: 'reduce', deviceScaleFactor: 1,
			});

			const page = await context.newPage();

			for (const [name, path] of [['guide', '/guides/how-to-set-macro-goals/']]) {
				await page.goto(`${origin}${path}`, { waitUntil: 'networkidle' });
				await page.evaluate(async () => {
					for (const image of document.images) image.loading = 'eager';
					await Promise.all([...document.images].map(image => image.decode()));
				});

				const check = await page.evaluate(() => ({
					path: location.pathname, width: innerWidth, scrollWidth: document.documentElement.scrollWidth,
					h1: document.querySelectorAll('h1').length,
					jsonLD: [...document.querySelectorAll('script[type="application/ld+json"]')].map(script => JSON.parse(script.textContent)),
					inlineJavaScript: [...document.scripts].filter(script => !script.src && script.type !== 'application/ld+json').reduce((sum, script) => sum + new TextEncoder().encode(script.textContent).length, 0),
					tablesScrollable: [...document.querySelectorAll('.table-scroll')].every(table => table.scrollWidth >= table.clientWidth),
				}));

				if (check.width !== check.scrollWidth || check.h1 !== 1) throw new Error(JSON.stringify(check));
				checks.push({ colorScheme, ...check });
				await page.locator('.article-toc a').first().click();

				if (!new URL(page.url()).hash) throw new Error('TOC anchor failed');

				for (const [index, diagram] of (await page.locator('[data-diagram]').all()).entries()) {
					// Clip from document coordinates without scrolling a sticky header over the diagram.
					await page.evaluate(() => scrollTo(0, 0));
					const clip = await diagram.boundingBox();

					if (!clip) throw new Error('Diagram has no layout box');
					await page.screenshot({ path: `${output}/diagram-${index + 1}-${width}-${colorScheme}.jpg`, clip, fullPage: true, type: 'jpeg', quality: 75 });
				}

				await page.evaluate(() => scrollTo(0, 0));
				await page.screenshot({ path: `${output}/${name}-${width}-${colorScheme}.jpg`, type: 'jpeg', quality: 72, fullPage: true, animations: 'disabled' });
			}

			await context.close();
		}
	}

	await writeFile(`${output}/browser-checks.json`, `${JSON.stringify(checks, null, 2)}\n`);
	}
	}
} finally {
	await browser?.close();
	await chrome?.kill();

	// A failed build exits before cleanup; preserve that error instead of masking it.
	if (server.exitCode === null) process.kill(-server.pid, 'SIGTERM');
}
