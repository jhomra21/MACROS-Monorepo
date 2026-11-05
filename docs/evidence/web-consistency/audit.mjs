// Failure cases: overflow, missing headings/images, theme contrast, draft leaks,
// metadata changes, motion differences, and increased executable JS.
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { cp, mkdir, mkdtemp, readFile, symlink, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { chromium } from '../../../build/seo-tools/node_modules/playwright/index.mjs';
import lighthouse from '../../../build/seo-tools/node_modules/lighthouse/core/index.js';
import * as chromeLauncher from '../../../build/seo-tools/node_modules/chrome-launcher/dist/index.js';
import { verifySite, verifyPublishedSite } from '../web-seo/verify.mjs';
import { verifyArticles } from '../web-articles/verify-articles.mjs';
import sharp from '../../../web/node_modules/sharp/dist/index.mjs';

const root = fileURLToPath(new URL('../../../', import.meta.url)).replace(/\/$/, '');

const output = fileURLToPath(new URL('./', import.meta.url));

const phase = process.argv[2] ?? 'before';

const web = process.argv[3] ?? `${root}/web`;

const screensOnly = process.argv.includes('--screens');

const origin = 'http://127.0.0.1:8798';

const routes = [['home', '/'], ['about', '/about/'], ['support', '/support/'], ['privacy', '/privacy/'], ['terms', '/terms/'], ['guides', '/guides/'], ['guide', '/guides/how-to-set-macro-goals/'], ['404', '/missing-page/']];

async function command(args, cwd) {
	const child = spawn('bun', args, { cwd, stdio: 'inherit' });
	await new Promise((resolve, reject) => {
		child.once('error', reject);
		child.once('exit', code => code === 0 ? resolve() : reject(new Error(`Exit ${code}`)));
	});
}

async function serve(directory, action) {
	const server = spawn('bun', ['x', '--no-install', 'wrangler', 'dev', '--port', '8798'], { cwd: directory, stdio: ['ignore', 'pipe', 'pipe'], detached: true });

	try {
		await new Promise((resolve, reject) => {
			let log = '';

			const receive = chunk => {
				log += chunk;

				if (log.includes('Ready on http://localhost:8798')) resolve();
			};

			server.stdout.on('data', receive);
			server.stderr.on('data', receive);
			server.once('error', reject);
			server.once('exit', code => reject(new Error(`Worker ${code}: ${log}`)));
		});
		await action();
	} finally {
		if (server.exitCode === null) process.kill(-server.pid, 'SIGTERM');
		await new Promise(resolve => server.exitCode !== null ? resolve() : server.once('exit', resolve));
	}
}

await mkdir(output, { recursive: true });

const browser = await chromium.launch();

const checks = [];

const bytes = [];

async function capture(pages) {
	for (const [name, path] of pages) {
		for (const width of [390, 1440]) {
			for (const colorScheme of ['light', 'dark']) {
				const page = await browser.newPage({ viewport: { width, height: width === 390 ? 844 : 1000 }, colorScheme, reducedMotion: 'reduce', deviceScaleFactor: 1 });
				await page.goto(origin + path, { waitUntil: 'networkidle' });
				await page.evaluate(async () => {
					for (const image of document.images) image.loading = 'eager';
					await Promise.all([...document.images].map(image => image.decode()));
				});
				const result = await page.evaluate(() => ({ width: innerWidth, scrollWidth: document.documentElement.scrollWidth, h1: document.querySelectorAll('h1').length }));
				assert.equal(result.width, result.scrollWidth, name);
				assert.equal(result.h1, 1, name);
				checks.push({ name, width, colorScheme, ...result });

				if (phase === 'after' && width === 390 && colorScheme === 'dark') {
					await page.addScriptTag({ path: `${root}/build/seo-tools/node_modules/axe-core/axe.min.js` });
					const contrast = await page.evaluate(async () => (await axe.run(document, { runOnly: ['color-contrast'] })).violations);
					assert.deepEqual(contrast, [], `Dark contrast: ${name}`);
				}

				const screenshot = await page.screenshot({ fullPage: true, animations: 'disabled' });
				await sharp(screenshot).resize({ width: Math.min(width, 720) }).jpeg({ quality: 28, mozjpeg: true }).toFile(`${output}/${phase}-${name}-${width}-${colorScheme}.jpg`);

				if (width === 390 && colorScheme === 'light') {
					const resources = await page.evaluate(async () => {
						const cssURLs = [...document.querySelectorAll('link[rel="stylesheet"]')].map(link => link.href);

						const jsURLs = [
							...[...document.scripts].flatMap(script => script.src ? [script.src] : []),
							...performance.getEntriesByType('resource').flatMap(resource => new URL(resource.name).pathname.endsWith('.js') ? [resource.name] : []),
						];

						const size = async urls => (await Promise.all([...new Set(urls)].map(async url => (await (await fetch(url)).arrayBuffer()).byteLength))).reduce((a, b) => a + b, 0);

						return { css: await size(cssURLs) + [...document.querySelectorAll('style')].reduce((n, style) => n + new TextEncoder().encode(style.textContent).length, 0), js: await size(jsURLs) + [...document.scripts].filter(script => !script.src && script.type !== 'application/ld+json').reduce((n, script) => n + new TextEncoder().encode(script.textContent).length, 0) };
					});

					bytes.push({ name, ...resources });
				}

				await page.close();
			}
		}
	}
}

let chrome;

try {
	await serve(web, async () => {
		await capture(routes);

		if (phase === 'after') {
			await verifySite(browser, origin, output);
			await verifyArticles(browser, origin, output);
			const page = await browser.newPage({ reducedMotion: 'no-preference' });
			await page.goto(`${origin}/guides/how-to-set-macro-goals/`);
			const figure = page.locator('.editorial__screenshot').last();
			await figure.evaluate(element => element.setAttribute('data-audit-target', ''));
			await figure.scrollIntoViewIfNeeded();
			await page.locator('[data-audit-target][data-reveal]').waitFor({ state: 'detached' });
			assert.equal(await figure.evaluate(element => getComputedStyle(element).opacity), '1');
			await page.close();
		}

		if (screensOnly) return;

		chrome = await chromeLauncher.launch({ chromePath: chromium.executablePath(), chromeFlags: ['--headless', '--no-sandbox'] });
		const results = [];

		for (const [name, path] of routes.filter(([name]) => ['home', 'about', 'support', 'privacy', 'guide'].includes(name))) {
			for (const mode of ['mobile', 'desktop']) {
				const { lhr } = await lighthouse(origin + path, { port: chrome.port, output: 'json', logLevel: 'error', onlyCategories: ['performance', 'accessibility', 'best-practices', 'seo'] }, mode === 'desktop' ? { extends: 'lighthouse:default', settings: { formFactor: 'desktop', screenEmulation: { mobile: false, width: 1440, height: 900, deviceScaleFactor: 1, disabled: false }, throttling: { rttMs: 40, throughputKbps: 10240, cpuSlowdownMultiplier: 1 } } } : undefined);
				assert.ok(!lhr.runtimeError, JSON.stringify(lhr.runtimeError));
				const result = { name, mode, scores: Object.fromEntries(Object.entries(lhr.categories).map(([key, value]) => [key, value.score * 100])), failures: Object.entries(lhr.audits).filter(([, audit]) => audit.score !== null && audit.score < 1).map(([id, audit]) => ({ id, title: audit.title, details: audit.details })) };
				results.push(result);
				console.log(JSON.stringify({ phase, name, mode, scores: result.scores }));
			}
		}

		await writeFile(`${output}/${phase}-lighthouse.json`, JSON.stringify(results, null, 2) + '\n');
		await chrome.kill();
		chrome = undefined;
	});
	// The draft is published only in an ignored scratch copy, never in source.
	const scratch = await mkdtemp(`${root}/build/consistency-${phase}-`);
	await cp(web, scratch, { recursive: true, filter: source => !['node_modules', 'dist', '.astro', '.wrangler'].includes(source.slice(`${web}/`.length).split('/')[0]) });
	await symlink(`${root}/web/node_modules`, `${scratch}/node_modules`);
	const post = `${scratch}/src/content/blog/macros-launch.md`;
	await writeFile(post, (await readFile(post, 'utf8')).replace('draft: true', 'draft: false'));
	await command(['run', 'build'], scratch);
	await serve(scratch, async () => {
		await capture([['blog', '/blog/'], ['post', '/blog/macros-launch/']]);

		if (phase === 'after') await verifyPublishedSite(browser, origin, output);
	});
	await writeFile(`${output}/${phase}-browser.json`, JSON.stringify(checks, null, 2) + '\n');
	await writeFile(`${output}/${phase}-bytes.json`, JSON.stringify(bytes, null, 2) + '\n');
} finally {
	await browser.close();
	await chrome?.kill();
}
