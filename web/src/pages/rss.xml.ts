import type { APIRoute } from 'astro';
import { absoluteURL, publishedEntries, xmlEscape } from '../lib/seo';
import { site } from '../data/site';

export const GET: APIRoute = async () => {
	const posts = await publishedEntries('blog');

	if (posts.length === 0) return new Response(null, { status: 404 });

	const items = posts.sort((a, b) => b.data.published.getTime() - a.data.published.getTime()).map(post => {
		const url = xmlEscape(absoluteURL(`/blog/${post.id}/`));

		return `<item><title>${xmlEscape(post.data.title)}</title><description>${xmlEscape(post.data.description)}</description><link>${url}</link><guid isPermaLink="true">${url}</guid><pubDate>${post.data.published.toUTCString()}</pubDate></item>`;
	}).join('');

	return new Response(`<?xml version="1.0" encoding="UTF-8"?><rss version="2.0"><channel><title>${site.name} blog</title><link>${xmlEscape(absoluteURL('/blog/'))}</link><description>News from MACROS.</description><language>en</language>${items}</channel></rss>`, {
		headers: { 'Content-Type': 'application/rss+xml; charset=utf-8' },
	});
};
