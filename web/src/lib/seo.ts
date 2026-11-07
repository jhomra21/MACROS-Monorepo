import { getCollection } from 'astro:content';
import { site } from '../data/site';
import type { JsonObject } from './json';

export const absoluteURL = (path: string) => new URL(path, site.url).href;

export const appStoreURL = () => `https://apps.apple.com/app/id${site.appStore.id}`;

export const publishedEntries = (collection: 'guides' | 'blog') =>
	getCollection(collection, ({ data }) => !data.draft);

// Resolves frontmatter `related` references. A typo fails the build; a draft target is skipped, so a draft is never linked.
export async function relatedEntries(related: readonly string[] = []) {
	const all = (await Promise.all([getCollection('guides'), getCollection('blog')])).flat();

	const byReference = new Map(all.map(entry => [`${entry.collection}/${entry.id}`, entry]));

	return related.flatMap(reference => {
		const entry = byReference.get(reference);

		if (!entry) throw new Error(`Unknown related entry "${reference}". Use "guides/<id>" or "blog/<id>".`);

		return entry.data.draft ? [] : [entry];
	});
}

export const pages = {
	'/': {
		title: 'MACROS: Calorie Counter & Food Diary for iPhone',
		description: site.description,
	},
	'/about/': {
		title: 'About MACROS | No-account calorie and macro tracker',
		description: 'Meet MACROS, a calorie counter and macro tracker for iPhone. Keep a food diary on your device, scan barcodes and nutrition labels, and start with no account.',
	},
	'/support/': {
		title: 'MACROS support | Food diary and macro tracker help',
		description: 'Get help with the MACROS calorie counter and food diary for iPhone. Contact MACROS support about barcode scans, nutrition labels, daily goals, or purchases.',
	},
	'/privacy/': {
		title: 'MACROS privacy | Your iPhone food diary and data',
		description: 'Learn how MACROS stores your food diary on iPhone and handles food search, barcode scans, optional sharing, Apple Health, purchases, and website form data.',
	},
	'/terms/': {
		title: 'MACROS terms | Calorie counter and food diary',
		description: 'Read the terms for the MACROS calorie counter and food diary for iPhone, including optional Pro purchases, subscriptions, sharing, and nutrition information.',
	},
	'/guides/': {
		title: 'Macro tracking guides for iPhone | MACROS',
		description: 'Set protein, carb, and fat goals in MACROS for iPhone. Read the calculator math, check the cited nutrition ranges, and follow the steps to save your targets.',
	},
	'/blog/': {
		title: 'MACROS blog | Serving sizes, label calories, and protein',
		description: 'Posts from MACROS on logging a serving, why label calories skip 4-4-9 math, and how much protein to eat to build muscle. Each cites its sources.',
	},
} as const;

interface PublicPage {
	path: string;
	title: string;
	description: string;
	image?: ImageMetadata;
	lastmod?: string;
}

export async function publicPages(): Promise<PublicPage[]> {
	const [guides, posts] = await Promise.all([publishedEntries('guides'), publishedEntries('blog')]);

	return [
		...Object.keys(pages)
			.filter(path => (path !== '/blog/' || posts.length > 0) && (path !== '/guides/' || guides.length > 0))
			.map(path => ({
				path,
				// SAFETY: path comes directly from Object.keys(pages).
				...pages[path as keyof typeof pages],
			})),
		...[...guides, ...posts].map(entry => ({
			path: `/${entry.collection}/${entry.id}/`,
			lastmod: entry.data.updated.toISOString(),
			title: entry.data.title,
			description: entry.data.description,
			image: entry.data.image,
		})),
	];
}

export const xmlEscape = (value: string) => value.replace(/[<>&"']/g, character => ({
	'<': '&lt;', '>': '&gt;', '&': '&amp;', '"': '&quot;', "'": '&apos;',
}[character]!));

export function breadcrumbs(path: string, title: string) {
	const section = path.startsWith('/guides/') ? 'guides' : path.startsWith('/blog/') ? 'blog' : undefined;
	const items: { name: string; item: string }[] = [{ name: site.name, item: absoluteURL('/') }];

	if (section && path !== `/${section}/`) {
		items.push({ name: section === 'guides' ? 'Guides' : 'Blog', item: absoluteURL(`/${section}/`) });
	}

	items.push({ name: title, item: absoluteURL(path) });

	return {
		'@type': 'BreadcrumbList',
		itemListElement: items.map((item, index) => ({ '@type': 'ListItem', position: index + 1, ...item })),
	};
}

export const organizationId = absoluteURL('/#organization');

// Pages that reference the Organization carry the name and URL too, because crawlers do not resolve an @id defined on another page.
export const organizationReference: JsonObject = {
	'@type': 'Organization', '@id': organizationId, name: site.name, url: absoluteURL('/'),
};

// The Apple touch icon is the 180 x 180 app icon, above Google's 112 px logo minimum.
export const organizationStructuredData: JsonObject = {
	...organizationReference,
	logo: absoluteURL('/apple-touch-icon.png'),
	sameAs: [site.instagramURL],
};

export const homeStructuredData: JsonObject[] = [
	{
		'@type': 'MobileApplication', name: site.fullName, url: absoluteURL('/'),
		operatingSystem: 'iOS 26+', applicationCategory: 'HealthApplication',
		description: `${site.description} Optional MACROS Pro in-app purchases are available.`,
		offers: { '@type': 'Offer', price: '0', priceCurrency: 'USD' },
	},
	organizationStructuredData,
	{ '@type': 'WebSite', name: site.fullName, url: absoluteURL('/'), publisher: { '@id': organizationId } },
	{ '@type': 'FAQPage', mainEntity: site.faq.map(faq => ({
		'@type': 'Question', name: faq.question, acceptedAnswer: { '@type': 'Answer', text: faq.answer },
	})) },
];
