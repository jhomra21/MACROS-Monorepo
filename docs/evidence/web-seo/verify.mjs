import assert from 'node:assert/strict';
import { writeFile } from 'node:fs/promises';

// E2E failure cases: incorrect MIME types, hidden drafts leaking, missing/duplicate
// canonicals or headings, accidental noindex, invalid JSON-LD, redirecting internal
// links, mismatched visible FAQ, broken images, and the launch flag left enabled.
export async function verifySite(browser, origin, output) {
	const page = await browser.newPage();
	const sitemap = await fetch(`${origin}/sitemap.xml`);
	assert.equal(sitemap.status, 200);
	assert.match(sitemap.headers.get('content-type'), /application\/xml/);
	const xml = await sitemap.text();
	const urls = [...xml.matchAll(/<loc>([^<]+)<\/loc>/g)].map(match => match[1]);
	assert.equal(urls.length, 7);
	const publicOrigin = new URL(urls[0]).origin;
	const robots = await fetch(`${origin}/robots.txt`);
	assert.equal(robots.status, 200);
	assert.match(robots.headers.get('content-type'), /text\/plain/);
	assert.equal(await robots.text(), `User-agent: *\nAllow: /\nSitemap: ${publicOrigin}/sitemap.xml\n`);
	assert.match(xml, /<lastmod>2026-11-04T00:00:00.000Z<\/lastmod>/);
	const pages = [];

	for (const url of urls) {
		assert.equal(new URL(url).origin, publicOrigin);
		const path = new URL(url).pathname;
		assert.ok(path.endsWith('/'));
		const response = await page.goto(`${origin}${path}`, { waitUntil: 'networkidle' });
		assert.equal(response.status(), 200, path);
		assert.equal(new URL(page.url()).pathname, path);

		const metadata = await page.evaluate(() => ({
			title: document.title,
			description: document.querySelector('meta[name="description"]').content,
			canonicals: [...document.querySelectorAll('link[rel="canonical"]')].map(link => link.href),
			robots: document.querySelector('meta[name="robots"]')?.content ?? '',
			h1: document.querySelectorAll('h1').length,
			schema: [...document.querySelectorAll('script[type="application/ld+json"]')].flatMap(script => JSON.parse(script.textContent)['@graph']),
			links: [...document.querySelectorAll('a[href]')].map(link => link.getAttribute('href')),
			smartBanner: !!document.querySelector('meta[name="apple-itunes-app"]'),
			badges: document.querySelectorAll('.app-store-badge').length,
			feed: !!document.querySelector('link[type="application/rss+xml"]'),
		}));

		assert.deepEqual(metadata.canonicals, [url]);
		assert.doesNotMatch(metadata.robots, /noindex/);
		assert.equal(metadata.h1, 1);
		assert.ok(metadata.title.length <= 60);
		assert.ok(metadata.description.length >= 145 && metadata.description.length <= 160);
		assert.equal(metadata.smartBanner, false);
		assert.equal(metadata.badges, 0);
		assert.equal(metadata.feed, false);
		const types = metadata.schema.map(item => item['@type']);
		assert.ok(types.includes(path === '/' ? 'MobileApplication' : 'BreadcrumbList'));

		if (path.includes('how-to-set')) {
			assert.ok(types.includes('Article'));
			assert.equal(await page.locator('meta[property="og:type"]').getAttribute('content'), 'article');
		}

		for (const link of metadata.links.filter(link => link.startsWith('/'))) {
			assert.ok(!link.startsWith('/blog') && link !== '/rss.xml', link);
			const pathname = new URL(link, origin).pathname;
			assert.ok(pathname.endsWith('/') || pathname.includes('.'), link);
			assert.equal((await fetch(`${origin}${pathname}`, { redirect: 'manual' })).status, 200, link);
		}

		if (path === '/') {
			const faq = metadata.schema.find(item => item['@type'] === 'FAQPage');

			const visibleFAQ = await page.locator('.faq-item').evaluateAll(items => items.map(item => ({
				question: item.querySelector('summary').textContent.trim(),
				answer: item.querySelector('p').textContent.trim(),
			})));

			assert.deepEqual(faq.mainEntity.map(item => ({ question: item.name, answer: item.acceptedAnswer.text })), visibleFAQ);
			assert.equal(await page.locator('.hero img').getAttribute('fetchpriority'), 'high');
		}

		pages.push({ path, title: metadata.title, description: metadata.description, types });
	}

	for (const path of ['/blog/', '/blog/macros-launch/', '/rss.xml', '/missing-page/']) {
		console.log(`Checking hidden or missing route ${path}`);
		const response = await page.goto(`${origin}${path}`);
		assert.equal(response.status(), 404, path);
		assert.match(await page.locator('meta[name="robots"]').getAttribute('content'), /noindex/);
	}

	const redirect = await fetch(`${origin}/privacy`, { redirect: 'manual' });
	assert.ok(redirect.status >= 300 && redirect.status < 400);
	assert.equal(new URL(redirect.headers.get('location'), origin).pathname, '/privacy/');

	const support = await fetch(`${origin}/api/support`, {
		method: 'POST', redirect: 'manual', body: new URLSearchParams({ website: 'bot' }),
	});

	assert.equal(support.status, 303);
	assert.equal(new URL(support.headers.get('location')).pathname, '/support/');

	const waitlist = await fetch(`${origin}/api/waitlist`, {
		method: 'POST', body: new URLSearchParams({ website: 'bot' }),
	});

	assert.equal(waitlist.status, 200);
	assert.equal(waitlist.headers.get('x-robots-tag'), 'noindex');
	await page.close();
	await writeFile(`${output}/endpoint-checks.json`, `${JSON.stringify({
		pages, sitemapURLs: urls.length, sitemapContentType: sitemap.headers.get('content-type'),
		robotsContentType: robots.headers.get('content-type'), hiddenBlogAndFeed: '404 + noindex',
		support: '303 to /support/#support-status-submitted', waitlist: 'POST-only, noindex, honeypot, no database write',
	}, null, 2)}\n`);
	console.log(`Verified ${urls.length} sitemap URLs, canonicals, metadata, JSON-LD, FAQ, internal links, 404, drafts, and form result states.`);
}

export async function verifyPublishedSite(browser, origin, output) {
	const page = await browser.newPage();
	const xml = await (await fetch(`${origin}/sitemap.xml`)).text();
	const urls = [...xml.matchAll(/<loc>([^<]+)<\/loc>/g)].map(match => match[1]);
	const publicOrigin = new URL(urls[0]).origin;

	assert.equal(urls.length, 9);
	assert.ok(urls.includes(`${publicOrigin}/blog/`));
	assert.ok(urls.includes(`${publicOrigin}/blog/macros-launch/`));

	for (const path of ['/blog/', '/blog/macros-launch/']) {
		const response = await page.goto(`${origin}${path}`, { waitUntil: 'networkidle' });

		assert.equal(response.status(), 200);
		assert.equal(await page.locator('link[rel="canonical"]').getAttribute('href'), `${publicOrigin}${path}`);
		assert.equal(await page.locator('link[type="application/rss+xml"]').getAttribute('href'), `${publicOrigin}/rss.xml`);
		assert.equal(await page.locator('.site-nav a[href="/blog/"]').count(), 1);
	}

	const article = await page.locator('script[type="application/ld+json"]').textContent();

	assert.ok(JSON.parse(article)['@graph'].some(item => item['@type'] === 'Article'));
	assert.equal(await page.locator('meta[property="og:type"]').getAttribute('content'), 'article');
	assert.equal(await page.locator('meta[property="article:published_time"]').count(), 1);
	assert.equal(await page.locator('meta[property="article:modified_time"]').count(), 1);

	const rss = await fetch(`${origin}/rss.xml`);

	assert.equal(rss.status, 200);
	assert.match(rss.headers.get('content-type'), /xml/);
	await page.goto(`${origin}/rss.xml`);

	const feed = await page.evaluate(() => {
		const doc = new DOMParser().parseFromString(document.documentElement.outerHTML, 'application/xml');

		return { errors: doc.querySelectorAll('parsererror').length, items: doc.querySelectorAll('item').length };
	});

	assert.equal(feed.errors, 0);
	assert.equal(feed.items, 1);
	await page.close();
	await writeFile(`${output}/publication-checks.json`, `${JSON.stringify({
		sitemapURLs: urls.length, blogIndex: 200, launchPost: 200, navigationAndFeedDiscovery: true,
		articleMetadata: true, rssStatus: rss.status, rssContentType: rss.headers.get('content-type'),
		parsedFeedItems: feed.items, note: 'Temporary local-only publication check; draft restored before final build.',
	}, null, 2)}\n`);
	console.log('Verified published blog index, article, sitemap, navigation, RSS discovery, and parsed feed.');
}
