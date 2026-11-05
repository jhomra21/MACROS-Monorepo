// Failure cases: missing/extra images, wrong dimensions, metadata/schema mismatch,
// draft leaks, unstable bytes, and a title edit invalidating unrelated previews.
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { cp, mkdir, mkdtemp, readFile, readdir, rm, symlink, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../../..');

const web = join(root, 'web');

const evidence = join(root, 'build/evidence/2026-11-05-web-og');

const digest = bytes => createHash('sha256').update(bytes).digest('hex');

async function files(directory) {
	const entries = await readdir(directory, { withFileTypes: true });

	const nested = await Promise.all(entries.map(entry => entry.isDirectory()
		? files(join(directory, entry.name))
		: [join(directory, entry.name)]));

	return nested.flat();
}

async function inspect(directory) {
	const dist = join(directory, 'dist');
	const sitemap = await readFile(join(dist, 'sitemap.xml'), 'utf8');
	const paths = [...sitemap.matchAll(/<loc>(.*?)<\/loc>/g)].map(match => new URL(match[1]).pathname);
	const pages = [];

	for (const path of paths) {
		const html = await readFile(join(dist, path, 'index.html'), 'utf8');
		const meta = name => html.match(new RegExp(`<meta (?:property|name)="${name}" content="([^"]*)"`))?.[1];
		const url = meta('og:image');

		assert.ok(url, path);
		assert.equal(url, meta('twitter:image'), path);
		assert.ok(meta('og:image:alt'), path);
		assert.equal(meta('og:image:alt'), meta('twitter:image:alt'), path);
		assert.equal(meta('og:image:width'), '1200');
		assert.equal(meta('og:image:height'), '630');
		assert.match(new URL(url).pathname, /^\/social\/.+\.[a-f0-9]{12}\.png$/);
		const bytes = await readFile(join(dist, new URL(url).pathname));

		assert.equal(bytes.subarray(0, 8).toString('hex'), '89504e470d0a1a0a');
		assert.equal(bytes.readUInt32BE(16), 1200);
		assert.equal(bytes.readUInt32BE(20), 630);
		const graph = html.match(/<script type="application\/ld\+json">(.*?)<\/script>/)?.[1];
		const article = graph && JSON.parse(graph)['@graph'].find(item => item['@type'] === 'Article');

		if (/^\/(?:guides|blog)\/.+/.test(path)) assert.ok(article, `Article schema missing: ${path}`);

		if (article) assert.equal(article.image, url, path);
		pages.push({ path, url, sha256: digest(bytes), bytes: bytes.length });
	}

	const images = await files(join(dist, 'social'));

	assert.equal(images.length, pages.length, 'No extra or draft social images');
	const content = await files(join(directory, 'src/content'));

	for (const filename of content) {
		const source = await readFile(filename, 'utf8');

		if (!/^draft: true$/m.test(source)) continue;
		const relative = filename.split('/src/content/')[1].replace(/\.md$/, '');

		assert.ok(!paths.includes(`/${relative}/`));
		assert.ok(!images.some(image => image.includes(relative)));
		await assert.rejects(readFile(join(dist, relative, 'index.html')), { code: 'ENOENT' });
	}

	if (!paths.some(path => path.startsWith('/blog/') && path !== '/blog/')) {
		assert.ok(!paths.includes('/blog/'));
		await assert.rejects(readFile(join(dist, 'blog/index.html')), { code: 'ENOENT' });
		await assert.rejects(readFile(join(dist, 'rss.xml')), { code: 'ENOENT' });
	}

	return pages;
}

async function build(directory) {
	const start = performance.now();
	const process = Bun.spawn(['bun', 'run', 'build'], { cwd: directory, stdout: 'pipe', stderr: 'pipe' });

	const [stdout, stderr, code] = await Promise.all([
		new Response(process.stdout).text(), new Response(process.stderr).text(), process.exited,
	]);

	assert.equal(code, 0, stdout + stderr);

	return { seconds: Number(((performance.now() - start) / 1000).toFixed(2)), stdout, stderr };
}

const baseline = await inspect(web);

const temporary = await mkdtemp(join(tmpdir(), 'macros-og-'));

try {
	await cp(web, temporary, { recursive: true, filter: source =>
		!['node_modules', 'dist', '.astro', '.wrangler', '.git'].includes(source.slice(web.length + 1).split('/')[0]),
	});
	await symlink(join(web, 'node_modules'), join(temporary, 'node_modules'));
	const first = await build(temporary);
	const firstPages = await inspect(temporary);

	assert.deepEqual(firstPages, baseline, 'Clean copy reproduces original names and bytes');
	const second = await build(temporary);

	assert.deepEqual(await inspect(temporary), baseline, 'Two builds have identical names and bytes');
	const metadataFile = join(temporary, 'src/lib/seo.ts');
	const metadata = await readFile(metadataFile, 'utf8');

	assert.ok(metadata.includes('MACROS: Calorie Counter & Food Diary for iPhone'));
	await writeFile(metadataFile, metadata.replace(
		'MACROS: Calorie Counter & Food Diary for iPhone', 'MACROS: Food Diary for iPhone (hash check)',
	));
	const changed = await build(temporary);
	const changedPages = await inspect(temporary);

	for (const page of baseline) {
		const next = changedPages.find(candidate => candidate.path === page.path);

		if (page.path === '/') {
			assert.notEqual(next.url, page.url);
			assert.notEqual(next.sha256, page.sha256);
		} else {
			assert.deepEqual(next, page, page.path);
		}
	}

	await writeFile(metadataFile, metadata);
	const postFile = join(temporary, 'src/content/blog/macros-launch.md');
	const post = await readFile(postFile, 'utf8');

	assert.ok(post.includes('draft: true'));
	await writeFile(postFile, post.replace('draft: true', 'draft: false'));
	const publication = await build(temporary);
	const publishedPages = await inspect(temporary);

	assert.equal(publishedPages.length, baseline.length + 2);
	assert.ok(publishedPages.some(page => page.path === '/blog/'));
	assert.ok(publishedPages.some(page => page.path === '/blog/macros-launch/'));

	for (const page of baseline) {
		assert.deepEqual(publishedPages.find(candidate => candidate.path === page.path), page);
	}

	await writeFile(postFile, post);
	await mkdir(evidence, { recursive: true });

	for (const page of baseline) {
		await cp(join(web, 'dist', new URL(page.url).pathname), join(evidence, new URL(page.url).pathname.slice('/social/'.length).replaceAll('/', '--')));
	}

	assert.ok(baseline.reduce((total, page) => total + page.bytes, 0) < 2 * 1024 * 1024);
	await writeFile(join(evidence, 'results.json'), JSON.stringify({
		pages: baseline, identicalBuilds: true, isolatedTitleInvalidation: true, draftLeaks: false,
		isolatedPublication: 'Blog index and post both gain matching previews; existing pages unchanged',
		buildSeconds: { clean: first.seconds, repeat: second.seconds, titleEdit: changed.seconds, publication: publication.seconds },
	}, null, 2) + '\n');
	await writeFile(join(evidence, 'builds.log'), [first, second, changed, publication]
		.map(result => (result.stdout + result.stderr).replace(/[ \t]+$/gm, '')).join('\n'));
	console.log(JSON.stringify({ pages: baseline.length, clean: first.seconds, repeat: second.seconds, titleEdit: changed.seconds, status: 'passed' }));
} finally {
	// Only the temporary copy created by this run is removed; source files stay untouched.
	await rm(temporary, { recursive: true, force: true });
}
