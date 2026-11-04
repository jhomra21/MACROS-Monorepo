import type { APIRoute } from 'astro';
import { absoluteURL, publicPages, xmlEscape } from '../lib/seo';

export const GET: APIRoute = async () => {
	const entries = await publicPages();
	const urls = entries.map(entry => `<url><loc>${xmlEscape(absoluteURL(entry.path))}</loc>${'lastmod' in entry ? `<lastmod>${entry.lastmod}</lastmod>` : ''}</url>`).join('');

	return new Response(`<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">${urls}</urlset>`, {
		headers: { 'Content-Type': 'application/xml; charset=utf-8' },
	});
};
