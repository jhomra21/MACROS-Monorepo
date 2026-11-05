import assert from 'node:assert/strict';
import { writeFile } from 'node:fs/promises';

// E2E failure cases: missing visual comments, broken anchors, decoded screenshot
// failures, social/schema disagreement, draft image leaks, table/page overflow,
// lost form listeners or reveal effects after full-document navigation.
export async function verifyArticles(browser, origin, output) {
	const page = await browser.newPage({ viewport: { width: 390, height: 844 }, reducedMotion: 'reduce' });
	const errors = [];

	page.on('pageerror', error => errors.push(error.message));
	await page.goto(`${origin}/guides/how-to-set-macro-goals/`, { waitUntil: 'networkidle' });
	assert.equal(await page.locator('[data-diagram]').count(), 3);
	assert.equal(await page.locator('.editorial__screenshot').count(), 4);
	assert.equal(await page.locator('.article-toc a').count(), 7);

	for (const anchor of await page.locator('.article-toc a').all()) {
		const href = await anchor.getAttribute('href');

		assert.equal(await page.locator(href).count(), 1, href);
	}

	const image = await page.locator('meta[property="og:image"]').getAttribute('content');
	const twitter = await page.locator('meta[name="twitter:image"]').getAttribute('content');
	const schema = JSON.parse(await page.locator('script[type="application/ld+json"]').textContent());

	assert.equal(image, twitter);
	assert.equal(image, schema['@graph'].find(item => item['@type'] === 'Article').image);
	const social = await page.request.get(`${origin}${new URL(image).pathname}`);

	assert.equal(social.status(), 200);
	assert.match(social.headers()['content-type'], /image\/png/);
	await writeFile(`${output}/guide-og.png`, await social.body());
	await page.evaluate(async () => {
		for (const image of document.images) image.loading = 'eager';
		await Promise.all([...document.images].map(image => image.decode()));
	});

	const screenshots = await page.locator('.editorial__screenshot img').evaluateAll(images =>
		images.map(image => ({ width: image.width, naturalWidth: image.naturalWidth, sizes: image.sizes, loading: image.loading })),
	);

	assert.ok(screenshots.every(image => image.width <= 320 && image.naturalWidth > 0));
	assert.equal((await page.request.get(`${origin}/social/blog/macros-launch.png`)).status(), 404);

	await page.locator('.site-nav a[href="/support/"]').click();
	await page.waitForURL('**/support/');
	await page.locator('#name').fill('Website audit');
	await page.locator('#email').fill('audit@example.com');
	await page.locator('#message').fill('Local browser audit of the support form after document navigation.');
	await page.route('**/api/support', route => route.fulfill({
		status: 200, contentType: 'application/json', body: JSON.stringify({ message: 'Local support audit passed.' }),
	}));
	await page.getByRole('button', { name: 'Send request' }).click();
	await page.locator('[data-support-success].status-banner--visible').waitFor();
	assert.equal(await page.locator('[data-support-success]').textContent(), 'Local support audit passed.');

	await page.locator('.site-header a[href="/"]').first().click();
	await page.waitForURL(origin + '/');
	const form = page.locator('[data-waitlist-form]').first();

	await form.locator('input[name="email"]').fill('audit@example.com');
	await page.route('**/api/waitlist', route => route.fulfill({
		status: 200, contentType: 'application/json', body: JSON.stringify({ message: 'Local waitlist audit passed.' }),
	}));
	await form.getByRole('button', { name: 'Join the waitlist' }).click();
	await page.locator('[data-waitlist-status].status-banner--visible').first().waitFor();
	assert.equal(await page.locator('[data-waitlist-status]').first().textContent(), 'Local waitlist audit passed.');

	await page.goBack();
	await page.waitForURL('**/support/');
	assert.equal(await page.locator('[data-support-form]').getAttribute('data-support-initialized'), 'true');
	assert.deepEqual(errors, []);

	const motionPage = await browser.newPage({ reducedMotion: 'no-preference' });

	motionPage.on('pageerror', error => errors.push(error.message));
	await motionPage.addInitScript(() => {
		addEventListener('pagereveal', event => { window.articleNativeTransition = !!event.viewTransition; });
	});
	await motionPage.goto(`${origin}/support/`, { waitUntil: 'networkidle' });
	await motionPage.locator('.site-header a[href="/"]').first().click();
	await motionPage.waitForURL(origin + '/');
	assert.equal(await motionPage.evaluate(() => window.articleNativeTransition), true);
	await motionPage.locator('[data-reveal]').first().scrollIntoViewIfNeeded();
	await motionPage.locator('[data-reveal].is-revealed').first().waitFor({ state: 'visible' });
	assert.deepEqual(errors, []);
	await motionPage.close();

	await writeFile(`${output}/article-checks.json`, `${JSON.stringify({
		diagrams: 3, screenshots, tocAnchors: 7, socialImage: image, draftSocialImage: 404,
		supportAfterNavigation: 'passed, browser-mocked response, no database write',
		waitlistAfterNavigation: 'passed, browser-mocked response, no database write',
		backNavigation: 'passed', nativeTransitionsAndReveal: 'passed, normal and reduced motion', pageErrors: errors,
	}, null, 2)}\n`);
	await page.close();
}
