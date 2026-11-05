import type { APIRoute } from 'astro';
import { readFile } from 'node:fs/promises';
import sharp from 'sharp';
import { publishedEntries, xmlEscape } from '../../../lib/seo';

export async function getStaticPaths() {
	const sections = await Promise.all((['guides', 'blog'] as const).map(async section =>
		(await publishedEntries(section)).map(entry => ({
			params: { section, slug: entry.id },
			props: { title: entry.data.title, section },
		}))),
	);

	return sections.flat();
}

export const GET: APIRoute = async ({ props }) => {
	// SAFETY: getStaticPaths above supplies these props for every prerendered route.
	const { title, section } = props as { title: string; section: 'guides' | 'blog' };
	const words = title.split(' ');
	const lines: string[] = [];

	for (const word of words) {
		const last = lines.length - 1;

		if (last < 0 || `${lines[last]} ${word}`.length > 23) {
			lines.push(word);
		} else {
			lines[last] += ` ${word}`;
		}
	}

	// Use Astro's existing sharp dependency, as the site's home OG script does.
	const filename = section === 'guides' ? 'app-calculator-review.png' : 'app-home.png';
	const source = await readFile(new URL(`src/assets/app-images/${filename}`, `file://${process.cwd()}/`));
	const screenshot = await sharp(source).resize({ height: 550 }).png().toBuffer();

	const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="630" font-family="Helvetica, Arial, sans-serif">
		<rect width="1200" height="630" fill="#f5f5f7"/>
		<text x="70" y="100" fill="#1d1d1f" font-size="34" font-weight="700">MACROS</text>
		${lines.map((line, index) => `<text x="70" y="${215 + index * 66}" fill="#1d1d1f" font-size="54" font-weight="700">${xmlEscape(line)}</text>`).join('')}
		<text x="70" y="525" fill="#66666b" font-size="25">${section === 'guides' ? 'Macro tracking guides' : 'News from the developer'} · iPhone</text>
		<rect x="70" y="555" width="70" height="7" fill="#007aff"/>
		<rect x="140" y="555" width="70" height="7" fill="#ff9f0a"/>
		<rect x="210" y="555" width="70" height="7" fill="#ef4f87"/>
	</svg>`;

	const image = await sharp(Buffer.from(svg))
		.composite([{ input: screenshot, left: 860, top: 40 }])
		.png({ compressionLevel: 9 }).toBuffer();

	return new Response(new Uint8Array(image), { headers: { 'Content-Type': 'image/png' } });
};
