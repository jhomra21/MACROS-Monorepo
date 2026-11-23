import type { APIRoute } from 'astro';
import { site } from '../data/site';
import { absoluteURL, publishedEntries } from '../lib/seo';

export const prerender = true;

export const GET: APIRoute = async () => {
	const [guides, posts] = await Promise.all([publishedEntries('guides'), publishedEntries('blog')]);

	const prices = site.proPrices.map(({ name, price, cadence, note }) => `- ${name}: ${price} ${cadence}; ${note.replace(/\.$/, '')}.`).join('\n');

	const links = [
		['Home', '/'],
		['Product facts', '/what-is-macros/'],
		['Privacy policy', '/privacy/'],
		['Support', '/support/'],
		['Learn', '/learn/'],
		...guides.map(entry => [entry.data.title, `/guides/${entry.id}/`] as const),
		...posts.map(entry => [entry.data.title, `/blog/${entry.id}/`] as const),
	];

	const content = [
		`# ${site.fullName}`,
		'',
		`${site.fullName} is a calorie and macro tracker for iPhone that needs no account. Food logs stay on the device; online searches and barcode lookups go through the MACROS Cloudflare Worker to public food databases. The app is available on the App Store: ${site.appStore.url}`,
		'',
		'## Key facts',
		`- Platform: ${site.facts.platform}; requires ${site.facts.minimumOS}.`,
		`- Account: ${site.facts.account}`,
		`- Food log: ${site.facts.dataLocation}`,
		`- Lookups: ${site.facts.lookups}`,
		`- Label scan: ${site.facts.labelScanning}`,
		`- Optional sharing: ${site.facts.optionalSharing}`,
		`- Export: ${site.facts.export}`,
		`- Food data sources: ${site.facts.foodSources}`,
		`- Free: ${site.facts.free}`,
		`- Ads: ${site.facts.ads}`,
		`- Availability: ${site.facts.status}`,
		'- Pro prices:',
		prices,
		'',
		'## Pages',
		...links.map(([label, path]) => `- [${label}](${absoluteURL(path)})`),
		'',
	].join('\n');

	return new Response(content, { headers: { 'Content-Type': 'text/plain; charset=utf-8' } });
};
