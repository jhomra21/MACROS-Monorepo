// E2E for the website forms after moving client JSON schemas to zod/mini.
// Failure list written first: (1) client bundle fails to load or throws; (2) a 400 with fieldErrors
// no longer sets the field's custom validity; (3) a non-JSON body crashes the handler instead of
// falling back to the default message; (4) real success/duplicate responses lose their message;
// (5) support server-side field errors are not applied.
import { spawn } from 'node:child_process';
import { writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { chromium } from '../../../build/perf-tools/node_modules/playwright/index.mjs';

const web = fileURLToPath(new URL('../../../web/', import.meta.url));

const out = process.argv[2] ?? 'build/evidence/forms-e2e.json';

const origin = 'http://127.0.0.1:8798';

const results = [];

const check = (name, ok, detail = '') => { results.push({ name, ok, detail }); console.log(`${ok ? 'PASS' : 'FAIL'} ${name} ${detail}`); };

const server = spawn('bunx', ['wrangler', 'dev', '--port', '8798'], { cwd: web, stdio: ['ignore', 'pipe', 'pipe'], detached: true });

let browser;

try {
	await new Promise((resolve, reject) => {
		let log = '';
		server.stdout.on('data', c => { log += c;

 if (log.includes('Ready on')) resolve(); });
		server.stderr.on('data', c => { log += c; });
		server.once('exit', code => reject(new Error(`dev exited ${code}: ${log}`)));
	});
	browser = await chromium.launch();
	const page = await browser.newPage();
	const errors = [];
	page.on('pageerror', e => errors.push(String(e)));
	// The 400 responses are deliberate; Chromium logs every non-2xx fetch as a console error.
	page.on('console', m => { if (m.type() === 'error' && !m.text().includes('status of 400')) errors.push(m.text()); });

	await page.goto(`${origin}/`, { waitUntil: 'networkidle' });
	const form = page.locator('[data-waitlist-form]').first();
	const email = form.locator('input[name="email"]');
	const submit = form.locator('.waitlist-submit');
	const status = page.locator('[data-waitlist-status]').first();

	await email.fill('bad');
	check('invalid email disables submit', await submit.isDisabled());

	await page.route('**/api/waitlist', r => r.fulfill({ status: 400, contentType: 'application/json', body: JSON.stringify({ message: 'Server rejected', fieldErrors: { email: 'Server says no' } }) }));
	await email.fill('person@example.com');
	await submit.click();
	await page.waitForFunction(() => document.querySelector('[data-waitlist-status]')?.textContent === 'Server rejected');
	check('400 fieldErrors set custom validity', await email.evaluate(e => e.validationMessage) === 'Server says no');
	await page.unroute('**/api/waitlist');

	await page.route('**/api/waitlist', r => r.fulfill({ status: 200, contentType: 'text/plain', body: 'not json' }));
	await email.fill('person2@example.com');
	await submit.click();
	await page.waitForFunction(() => document.querySelector('[data-waitlist-status]')?.classList.contains('status--success'));
	check('non-JSON success falls back to default message', (await status.textContent()) === 'Thanks, you’re on the waitlist.', await status.textContent());
	await page.unroute('**/api/waitlist');

	const unique = `perf-e2e-${Date.now()}@example.com`;

	for (const expected of ['Thanks, you’re on the waitlist.', 'You’re already on the waitlist.']) {
		await email.fill(unique);
		await Promise.all([page.waitForResponse('**/api/waitlist'), submit.click()]);
		await page.waitForFunction(text => document.querySelector('[data-waitlist-status]')?.textContent === text, expected, { timeout: 5000 }).catch(() => {});
		check(`real local API: ${expected}`, (await status.textContent()) === expected, await status.textContent());
	}

	await page.goto(`${origin}/support/`, { waitUntil: 'networkidle' });
	const sform = page.locator('[data-support-form]');
	await sform.locator('[name="name"]').fill('Perf Tester');
	await sform.locator('[name="email"]').fill('a@b');
	await sform.locator('[name="message"]').fill('A detailed message for the support form check.');
	await Promise.all([page.waitForResponse('**/api/support'), sform.locator('button[type="submit"]').click()]);
	await page.waitForFunction(() => document.querySelector('[data-support-invalid]')?.classList.contains('status-banner--visible'), null, { timeout: 10000 }).catch(() => {});
	const emailMessage = await sform.locator('[name="email"]').evaluate(e => e.validationMessage);
	check('support server fieldErrors applied', emailMessage === 'Please enter a valid email address.', emailMessage);

	await sform.locator('[name="email"]').fill('perf-e2e@example.com');
	await Promise.all([page.waitForResponse('**/api/support'), sform.locator('button[type="submit"]').click()]);
	await page.waitForFunction(() => document.querySelector('[data-support-success]')?.classList.contains('status-banner--visible'), null, { timeout: 10000 }).catch(() => {});
	check('support success message', (await page.locator('[data-support-success]').textContent())?.includes('received') === true);

	check('no page or console errors', errors.length === 0, errors.join(' | '));
} finally {
	await browser?.close();

	try { process.kill(-server.pid, 'SIGTERM'); } catch {}

	writeFileSync(out, JSON.stringify({ when: new Date().toISOString(), results }, null, 2));

	if (results.some(r => !r.ok) || results.length === 0) process.exitCode = 1;
}
