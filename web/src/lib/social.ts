import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import sharp from 'sharp';
import { site } from '../data/site';
import { xmlEscape } from './seo';

// Bump when geometry, colors, type sizing, or compositing changes.
export const templateVersion = 'macros-rings-3';

export const fontFile = '/System/Library/Fonts/Helvetica.ttc';

const screens = {
	'/': ['app-home.png', 'Calorie counter & food diary'],
	'/about/': ['app-home.png', 'About MACROS'],
	'/support/': ['app-scan-review.png', 'Help with MACROS'],
	'/privacy/': ['app-sharing.png', 'Privacy & your data'],
	'/terms/': ['app-settings.png', 'Terms of use'],
	'/guides/': ['app-calculator-review.png', 'Macro tracking guides'],
	'/blog/': ['app-home.png', 'The MACROS blog'],
	'/learn/': ['app-calculator-review.png', 'Guides and the MACROS blog'],
} as const;

export interface SocialInput {
	path: string;
	title: string;
	heading: string;
	description: string;
	subtitle: string;
	screenshot: Buffer;
	font: Buffer;
}

const hash = (value: string | Buffer) => createHash('sha256').update(value).digest('hex');

// Pure: endpoint paths, layout metadata, and Article schema all use this identity.
export function socialImage(input: SocialInput) {
	const digest = hash(JSON.stringify([
		templateVersion, sharp.versions, input.path, input.title, input.description,
		input.subtitle, hash(input.screenshot), hash(input.font),
	])).slice(0, 12);

	const slug = input.path === '/' ? 'home' : input.path.replace(/^\/|\/$/g, '');

	return {
		src: `/social/${slug}.${digest}.png`, width: 1200, height: 630,
		alt: `${input.heading}. MACROS for iPhone with a real app screenshot.`,
	};
}

export async function socialInput(path: string, title: string, description: string, image?: ImageMetadata): Promise<SocialInput> {
	// SAFETY: static page paths are keys of screens; article paths use the fallback.
	const screen = screens[path as keyof typeof screens];
	const subtitle = screen?.[1] ?? (path.startsWith('/guides/') ? 'Macro tracking guides' : 'The MACROS blog');

	// SAFETY: Astro 7 createImageAsset adds non-enumerable fsPath to local collection images
	// (dist/assets/utils/image-asset.js); the public ImageMetadata type omits it.
	const screenshotFile = image ? (image as ImageMetadata & { fsPath: string }).fsPath
		: resolve('src/assets/app-images', screen?.[0] ?? 'app-home.png');

	const [screenshot, font] = await Promise.all([readFile(screenshotFile), readFile(fontFile)]);

	return { path, title, heading: title.split(' | ')[0]!, description, subtitle, screenshot, font };
}

async function textLayer(value: string, size: number, width: number, height: number, bold = false, color = '#1d1d1f', letterSpacing = 0) {
	const render = (fontSize: number) => sharp({
		text: {
			text: `<span foreground="${color}" letter_spacing="${letterSpacing * 1024}">${xmlEscape(value)}</span>`,
			font: `Helvetica ${bold ? 'Bold ' : ''}${fontSize}`, fontfile: fontFile,
			width, wrap: 'word-char', rgba: true,
		},
	}).png().toBuffer({ resolveWithObject: true });

	let layer = await render(size);

	// Pango measures and wraps glyphs; reduce type only when the full block cannot fit.
	while (layer.info.height > height) {
		size = Math.max(1, Math.floor(size * height / layer.info.height));
		layer = await render(size);
	}

	return layer.data;
}

// Crops a transparent text layer to its visible glyphs. Pango places text by advance width, and side bearings differ per glyph.
async function inkCrop(layer: Buffer) {
	const { data, info } = await sharp(layer).raw().toBuffer({ resolveWithObject: true });
	let left = info.width, top = info.height, right = -1, bottom = -1;

	for (let y = 0; y < info.height; y++) {
		for (let x = 0; x < info.width; x++) {
			if (data[(y * info.width + x) * info.channels + 3]! === 0) continue;
			left = Math.min(left, x); right = Math.max(right, x);
			top = Math.min(top, y); bottom = Math.max(bottom, y);
		}
	}

	return sharp(layer).extract({ left, top, width: right + 1 - left, height: bottom + 1 - top }).png().toBuffer({ resolveWithObject: true });
}

// The subtitle renders large, then scales down as a whole, so its ink is exactly as wide as the wordmark's.
async function brandLockup() {
	const [wordmark, subtitle] = await Promise.all([
		textLayer(site.name, 34, 240, 42, true).then(inkCrop),
		textLayer(site.lockupSubtitle, 68, 1200, 120, true, '#66666b', 2).then(inkCrop),
	]);

	const scaled = await sharp(subtitle.data).resize({ width: wordmark.info.width }).png().toBuffer({ resolveWithObject: true });

	return { wordmark, subtitle: scaled };
}

export async function renderSocialImage(input: SocialInput) {
	const seed = Buffer.from(hash(input.path), 'hex');

	const rings = ['#007aff', '#ff9f0a', '#ef4f87'].map((color, index) => {
		const radius = 26 - index * 8;
		const circumference = 2 * Math.PI * radius;
		const fill = (25 + seed[index]! % 71) / 100;

		return `<circle cx="32" cy="32" r="${radius}" stroke="#dedee3"/>
			<circle cx="32" cy="32" r="${radius}" stroke="${color}" stroke-dasharray="${circumference * fill} ${circumference}"/>`;
	}).join('');

	const background = `<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="630">
		<rect width="1200" height="630" fill="#f5f5f7"/>
		<rect x="838" y="0" width="362" height="630" fill="#e9e9ee"/>
		<g transform="translate(60 48)" fill="none" stroke-width="7" stroke-linecap="round">
			<g transform="rotate(-90 32 32)">${rings}</g>
		</g>
	</svg>`;

	const [lockup, subtitle, title, description, screenshot] = await Promise.all([
		brandLockup(),
		textLayer(input.subtitle, 23, 710, 30, false, '#66666b'),
		textLayer(input.heading, 58, 710, 225, true),
		textLayer(input.description, 24, 710, 115, false, '#66666b'),
		sharp(input.screenshot).resize({ height: 550 }).png().toBuffer({ resolveWithObject: true }),
	]);

	// The two-line lockup is centered on the rings (y 48 to 112).
	const lockupGap = 7;
	const lockupTop = Math.round(80 - (lockup.wordmark.info.height + lockupGap + lockup.subtitle.info.height) / 2);

	const image = await sharp(Buffer.from(background)).composite([
		{ input: lockup.wordmark.data, left: 142, top: lockupTop },
		{ input: lockup.subtitle.data, left: 142, top: lockupTop + lockup.wordmark.info.height + lockupGap },
		{ input: subtitle, left: 64, top: 153 },
		{ input: title, left: 60, top: 210 },
		{ input: description, left: 64, top: 465 },
		{ input: screenshot.data, left: 838 + Math.floor((362 - screenshot.info.width) / 2), top: 40 },
	]).png({ compressionLevel: 9 }).toBuffer();

	return image;
}
