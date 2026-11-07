// Manual post-deploy step: tell IndexNow search engines (Bing and partners) which URLs changed.
// Never part of check, build, test, or deploy. Run it only after an authorized deploy, so the
// key file and the pages are live. See "Notify IndexNow after a deploy" in web/SEO.md.
//
//   bun run indexnow                      submit every URL in dist/sitemap(-*).xml
//   bun run indexnow <url> [<url>...]     submit only these canonical URLs
//   bun run indexnow --dry-run [...]      print the payload, send nothing, skip the live key check
//
// Exit codes: 0 sent or dry run, 1 usage, 2 key file, 3 dist or sitemap, 4 non-canonical URL,
// 5 key file not live, 6 network failure, 7 IndexNow rejected the request.
import { existsSync, readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { siteOrigin } from '../src/data/origin';

const endpoint = 'https://api.indexnow.org/indexnow';

const maxUrlsPerRequest = 10_000;

const webRoot = join(import.meta.dir, '..');

const publicDir = join(webRoot, 'public');

const distDir = join(webRoot, 'dist');

const host = new URL(siteOrigin).host;

class Failure extends Error {
	constructor(readonly exitCode: number, message: string) {
		super(message);
	}
}

// The key is the file name, so there is one source of truth. The file must also contain the key.
function readKey(): string {
	const files = readdirSync(publicDir).filter(name => /^[0-9a-f]{32}\.txt$/.test(name));

	if (files.length !== 1) {
		throw new Failure(2, `Expected exactly one 32-character hex key file in web/public, found ${files.length}.`);
	}

	const key = files[0]!.slice(0, -'.txt'.length);

	if (readFileSync(join(publicDir, files[0]!), 'utf8').trim() !== key) {
		throw new Failure(2, `web/public/${files[0]} must contain exactly the key ${key}.`);
	}

	return key;
}

const xmlUnescape = (value: string) => value
	.replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&apos;/g, "'").replace(/&amp;/g, '&');

function sitemapURLs(): string[] {
	if (!existsSync(distDir)) {
		throw new Failure(3, 'web/dist does not exist. Run "bun run build" first, or pass explicit URLs.');
	}

	const files = readdirSync(distDir).filter(name => /^sitemap(-[^/\\]*)?\.xml$/.test(name));

	if (files.length === 0) {
		throw new Failure(3, 'No sitemap.xml or sitemap-*.xml in web/dist. Run "bun run build" first, or pass explicit URLs.');
	}

	const urls = files.flatMap(name => {
		const xml = readFileSync(join(distDir, name), 'utf8');

		// A sitemap index lists other sitemaps, not pages.
		return xml.includes('<sitemapindex') ? [] : [...xml.matchAll(/<loc>\s*([^<]+?)\s*<\/loc>/g)].map(match => xmlUnescape(match[1]!));
	});

	if (urls.length === 0) {
		throw new Failure(3, `No <loc> page URLs found in web/dist (${files.join(', ')}).`);
	}

	return urls;
}

// Canonical means what the sitemap publishes: https, the apex host, no query or fragment, and a
// trailing slash on HTML pages (file endpoints such as /sitemap.xml keep their extension).
function nonCanonicalReason(value: string): string | undefined {
	let url: URL;

	try {
		url = new URL(value);
	} catch {
		return 'not a valid URL';
	}

	if (url.protocol !== 'https:') return 'not https';

	if (url.host !== host) return `host is not ${host}`;

	if (url.search || url.hash) return 'has a query or fragment';

	if (url.username || url.password) return 'has credentials';

	if (!url.pathname.endsWith('/') && !/\.[a-z0-9]+$/i.test(url.pathname)) return 'HTML page without a trailing slash';

	return undefined;
}

function chunk<T>(items: T[], size: number): T[][] {
	return Array.from({ length: Math.ceil(items.length / size) }, (_, index) => items.slice(index * size, (index + 1) * size));
}

async function assertKeyIsLive(keyLocation: string, key: string) {
	let response: Response;

	try {
		response = await fetch(keyLocation, { signal: AbortSignal.timeout(15_000) });
	} catch (error) {
		throw new Failure(6, `Could not reach ${keyLocation}: ${String(error)}`);
	}

	if (response.status !== 200 || (await response.text()).trim() !== key) {
		throw new Failure(5, `${keyLocation} is not live with the key (HTTP ${response.status}). Deploy first, or the engines will answer 403.`);
	}
}

const rejection = new Map([
	[400, 'Invalid format.'],
	[403, 'Key not valid: the key file is missing or does not contain the key.'],
	[422, 'URLs do not belong to the host, or the key does not match the protocol schema.'],
	[429, 'Too many requests. Wait before submitting again.'],
]);

async function submit(payload: { host: string; key: string; keyLocation: string; urlList: string[] }) {
	let response: Response;

	try {
		response = await fetch(endpoint, {
			method: 'POST',
			headers: { 'Content-Type': 'application/json; charset=utf-8' },
			body: JSON.stringify(payload),
			signal: AbortSignal.timeout(30_000),
		});
	} catch (error) {
		throw new Failure(6, `Could not reach ${endpoint}: ${String(error)}`);
	}

	// 200 means received. 202 means received with key validation pending. Neither means indexed.
	if (response.status !== 200 && response.status !== 202) {
		throw new Failure(7, `IndexNow answered HTTP ${response.status}. ${rejection.get(response.status) ?? 'Unexpected response.'}`);
	}

	console.log(`Sent ${payload.urlList.length} URLs: HTTP ${response.status}${response.status === 202 ? ' (key validation pending)' : ''}.`);
}

async function main() {
	const args = process.argv.slice(2);
	const dryRun = args.includes('--dry-run');
	const explicit = args.filter(arg => !arg.startsWith('--'));
	const unknownFlag = args.find(arg => arg.startsWith('--') && arg !== '--dry-run');

	if (unknownFlag) throw new Failure(1, `Unknown flag ${unknownFlag}. Usage: bun run indexnow [--dry-run] [url...]`);

	const key = readKey();
	const urls = [...new Set(explicit.length > 0 ? explicit : sitemapURLs())];

	const problems = urls.flatMap(url => {
		const reason = nonCanonicalReason(url);

		return reason ? [`  ${url}: ${reason}`] : [];
	});

	if (problems.length > 0) throw new Failure(4, `Refusing to submit non-canonical URLs:\n${problems.join('\n')}`);

	const keyLocation = `${siteOrigin}/${key}.txt`;
	const batches = chunk(urls, maxUrlsPerRequest).map(urlList => ({ host, key, keyLocation, urlList }));

	if (dryRun) {
		console.log(`Dry run: would POST ${batches.length} request(s) to ${endpoint}. Nothing was sent.`);

		for (const batch of batches) console.log(JSON.stringify(batch, null, 2));

		return;
	}

	await assertKeyIsLive(keyLocation, key);

	for (const batch of batches) await submit(batch);
}

try {
	await main();
} catch (error) {
	if (!(error instanceof Failure)) throw error;
	console.error(error.message);
	process.exit(error.exitCode);
}
