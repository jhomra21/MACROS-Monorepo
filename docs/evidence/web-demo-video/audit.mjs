// Repeatable checks for the home demo video. Run from the repo root against a running
// `bunx wrangler dev --port 8793` serving a fresh `bun run build`:
//   bun docs/evidence/web-demo-video/audit.mjs lighthouse before|after
//   bun docs/evidence/web-demo-video/audit.mjs browser
// Tooling lives in ignored build/seo-tools (playwright, lighthouse, chrome-launcher).
import { mkdir, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { chromium } from '../../../build/seo-tools/node_modules/playwright/index.mjs';
import lighthouse from '../../../build/seo-tools/node_modules/lighthouse/core/index.js';
import * as chromeLauncher from '../../../build/seo-tools/node_modules/chrome-launcher/dist/index.js';

const origin = 'http://127.0.0.1:8793';

const [mode = 'browser', phase = 'after'] = process.argv.slice(2);

const raw = fileURLToPath(new URL('../../../build/evidence/web-demo-video/', import.meta.url));

await mkdir(raw, { recursive: true });

const median = values => [...values].sort((a, b) => a - b)[Math.floor(values.length / 2)];

if (mode === 'lighthouse') {
	const chrome = await chromeLauncher.launch({ chromePath: chromium.executablePath(), chromeFlags: ['--headless', '--no-sandbox'] });
	const runs = [];

	try {
		for (let run = 0; run < 3; run += 1) {
			const { lhr } = await lighthouse(`${origin}/`, { port: chrome.port, output: 'json', logLevel: 'error', onlyCategories: ['performance', 'accessibility', 'best-practices', 'seo'] });

			if (lhr.runtimeError) throw new Error(JSON.stringify(lhr.runtimeError));
			runs.push({
				scores: Object.fromEntries(Object.entries(lhr.categories).map(([key, value]) => [key, value.score * 100])),
				lcp: lhr.audits['largest-contentful-paint'].numericValue,
				cls: lhr.audits['cumulative-layout-shift'].numericValue,
				tbt: lhr.audits['total-blocking-time'].numericValue,
				bytes: lhr.audits['total-byte-weight'].numericValue,
				lcpElement: lhr.audits['largest-contentful-paint-element']?.details?.items?.[0]?.items?.[0]?.node?.snippet,
				mediaRequests: lhr.audits['network-requests'].details.items.filter(item => /\.(mp4|webp|avif)/.test(item.url)).map(item => `${item.url.replace(origin, '')} ${item.transferSize}`),
			});
		}
	} finally {
		await chrome.kill();
	}

	const summary = { phase, lcp: median(runs.map(r => r.lcp)), cls: Math.max(...runs.map(r => r.cls)), tbt: Math.max(...runs.map(r => r.tbt)), bytes: median(runs.map(r => r.bytes)), runs };
	await writeFile(`${raw}${phase}-lighthouse.json`, `${JSON.stringify(summary, null, 2)}\n`);
	console.log(JSON.stringify({ ...summary, runs: runs.map(({ mediaRequests: _mediaRequests, ...rest }) => rest), mediaRequests: runs[0].mediaRequests }, null, 1));
} else {
	const results = {};

	// Range and headers come from the Worker's asset path, not the browser.
	const video = await (await fetch(`${origin}/`)).text().then(html => html.match(/src="(\/media\/[^"]+\.mp4)"/)?.[1]);

	if (!video) throw new Error('No /media mp4 on the home page');
	const pick = r => Object.fromEntries(['content-type', 'content-length', 'content-range', 'accept-ranges', 'cache-control', 'etag'].map(h => [h, r.headers.get(h)]));
	const full = await fetch(`${origin}${video}`, { method: 'HEAD' });
	const range = await fetch(`${origin}${video}`, { headers: { Range: 'bytes=0-1023' } });
	const rangeBody = await range.arrayBuffer();
	const tail = await fetch(`${origin}${video}`, { headers: { Range: 'bytes=-512' } });
	await tail.arrayBuffer();
	results.http = { video, full: { status: full.status, ...pick(full) }, range: { status: range.status, bodyBytes: rangeBody.byteLength, ...pick(range) }, suffixRange: { status: tail.status, ...pick(tail) } };

	if (full.status !== 200 || range.status !== 206 || rangeBody.byteLength !== 1024 || full.headers.get('content-type') !== 'video/mp4') throw new Error(JSON.stringify(results.http));

	const browser = await chromium.launch();

	try {
		const state = page => page.locator('.demo video').evaluate(v => ({ paused: v.paused, controls: v.controls, autoplay: v.autoplay, currentTime: Number(v.currentTime.toFixed(2)), readyState: v.readyState, networkState: v.networkState, preload: v.preload }));

		const videoRequests = page => {
			const seen = [];

			page.on('request', r => { if (r.url().endsWith('.mp4')) seen.push(r.url().replace(origin, '')); });

			return seen;
		};

		// Motion allowed: nothing loads or plays until the section is in view, then it pauses out of view.
		const motion = await browser.newPage({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, reducedMotion: 'no-preference' });
		const motionRequests = videoRequests(motion);
		await motion.goto(`${origin}/`, { waitUntil: 'networkidle' });
		const beforeScroll = { ...(await state(motion)), requests: motionRequests.length };
		await motion.locator('.demo video').scrollIntoViewIfNeeded();
		await motion.waitForFunction(() => !document.querySelector('.demo video').paused && document.querySelector('.demo video').currentTime > 0.5, null, { timeout: 15000 });
		const inView = await state(motion);
		await motion.evaluate(() => window.scrollTo(0, 0));
		await motion.waitForFunction(() => document.querySelector('.demo video').paused, null, { timeout: 5000 });
		const outOfView = await state(motion);
		// A pause the visitor chose survives scrolling away and back.
		await motion.locator('.demo video').scrollIntoViewIfNeeded();
		await motion.waitForFunction(() => !document.querySelector('.demo video').paused, null, { timeout: 5000 });
		await motion.locator('.demo video').evaluate(v => v.pause());
		await motion.evaluate(() => window.scrollTo(0, 0));
		await motion.waitForTimeout(400);
		await motion.locator('.demo video').scrollIntoViewIfNeeded();
		await motion.waitForTimeout(800);
		const userPaused = await state(motion);
		results.motion = { beforeScroll, inView, outOfView, userPausedStaysPaused: userPaused.paused, requests: motionRequests };

		if (beforeScroll.requests !== 0 || !beforeScroll.paused || inView.paused || !outOfView.paused || !userPaused.paused) throw new Error(JSON.stringify(results.motion));

		// Reduced motion: poster plus native controls, no autoplay, no download until the visitor plays it.
		const reduced = await browser.newPage({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, reducedMotion: 'reduce' });
		const reducedRequests = videoRequests(reduced);
		await reduced.goto(`${origin}/`, { waitUntil: 'networkidle' });
		await reduced.locator('.demo video').scrollIntoViewIfNeeded();
		await reduced.waitForTimeout(1500);
		const reducedState = await state(reduced);
		results.reduced = { ...reducedState, requests: reducedRequests.length };

		if (!reducedState.paused || !reducedState.controls || reducedState.currentTime !== 0 || reducedRequests.length !== 0) throw new Error(JSON.stringify(results.reduced));

		// Layout shift across load and scroll, at both widths, with a buffered observer.
		results.cls = {};

		for (const width of [390, 1440]) {
			const page = await browser.newPage({ viewport: { width, height: width === 390 ? 844 : 900 } });
			await page.addInitScript(() => { window.__cls = 0; new PerformanceObserver(list => { for (const e of list.getEntries()) if (!e.hadRecentInput) window.__cls += e.value; }).observe({ type: 'layout-shift', buffered: true }); });
			await page.goto(`${origin}/`, { waitUntil: 'networkidle' });
			const box = await page.locator('.demo__media').boundingBox();
			await page.locator('.demo video').scrollIntoViewIfNeeded();
			await page.waitForFunction(() => !document.querySelector('.demo video').paused, null, { timeout: 15000 });
			await page.waitForTimeout(1000);
			const after = await page.locator('.demo__media').boundingBox();
			results.cls[width] = { cls: await page.evaluate(() => window.__cls), mediaBox: { width: box.width, height: box.height }, sameSizeWhilePlaying: Math.abs(after.height - box.height) < 0.5, scrollWidth: await page.evaluate(() => document.documentElement.scrollWidth) };
			await page.close();
		}

		// Section screenshots at 1440 and 390 in both schemes, with the poster showing (reduced motion).
		for (const width of [1440, 390]) {
			for (const colorScheme of ['light', 'dark']) {
				const page = await browser.newPage({ viewport: { width, height: width === 390 ? 844 : 900 }, deviceScaleFactor: 2, colorScheme, reducedMotion: 'reduce' });
				await page.goto(`${origin}/`, { waitUntil: 'networkidle' });
				const section = page.locator('.demo');
				await section.scrollIntoViewIfNeeded();
				await page.waitForTimeout(300);
				await section.screenshot({ path: `${raw}demo-${width}-${colorScheme}.png` });
				await page.close();
			}
		}
		// One playing frame, to show the video itself sits correctly once it replaces the poster.

		const playing = await browser.newPage({ viewport: { width: 1440, height: 900 }, deviceScaleFactor: 2, colorScheme: 'dark' });
		await playing.goto(`${origin}/`, { waitUntil: 'networkidle' });
		await playing.locator('.demo video').scrollIntoViewIfNeeded();
		await playing.waitForFunction(() => document.querySelector('.demo video').currentTime > 6, null, { timeout: 20000 });
		await playing.locator('.demo').screenshot({ path: `${raw}demo-1440-dark-playing.png` });
	} finally {
		await browser.close();
	}

	await writeFile(`${raw}browser-checks.json`, `${JSON.stringify(results, null, 2)}\n`);
	console.log(JSON.stringify(results, null, 1));
}
