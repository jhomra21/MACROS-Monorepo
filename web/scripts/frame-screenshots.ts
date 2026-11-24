import { readdir, mkdir } from 'node:fs/promises';
import { join, resolve } from 'node:path';
import sharp from 'sharp';

const defaultBezelPath =
	'C:\\Users\\jhonr\\MACROS-Monorepo\\build\\apple-bezels\\x\\Bezel-iPhone-17\\PNG\\iPhone 17 Pro Max\\iPhone 17 Pro Max - Silver - Portrait.png';
const bezelPath = resolve(Bun.argv[2] ?? process.env.APPLE_BEZEL_PATH ?? defaultBezelPath);
const imageDirectory = resolve(import.meta.dir, '../src/assets/app-images');
const outputDirectory = join(imageDirectory, 'framed');
const screenshotNames = [
	'app-home.png',
	'app-add-food.png',
	'app-scan-review.png',
	'app-scan-details.png',
	'app-history.png',
	'app-insights.png',
	'app-sharing.png',
	'app-sharing-person.png',
	'app-widgets.png',
	'app-settings.png',
	'app-calculator-review.png',
];

const bezel = sharp(bezelPath).ensureAlpha();
const { data: bezelPixels, info: bezelInfo } = await bezel.raw().toBuffer({ resolveWithObject: true });
const alphaAt = (x: number, y: number) => bezelPixels[(y * bezelInfo.width + x) * 4 + 3]!;
const centerY = Math.floor(bezelInfo.height / 2);

function longestTransparentRun(valueAt: (position: number) => number, end: number) {
	let best = { first: 0, last: -1 };
	let first = -1;
	for (let position = 0; position <= end; position++) {
		if (valueAt(position) === 0) {
			if (first === -1) first = position;
		} else if (first !== -1) {
			if (position - first > best.last - best.first + 1) best = { first, last: position - 1 };
			first = -1;
		}
	}
	if (first !== -1 && end + 1 - first > best.last - best.first + 1) {
		best = { first, last: end };
	}
	return best;
}

const horizontal = longestTransparentRun((x) => alphaAt(x, centerY), bezelInfo.width - 1);
let vertical = { first: 0, last: -1 };
for (let x = horizontal.first; x <= horizontal.last; x++) {
	const run = longestTransparentRun((y) => alphaAt(x, y), bezelInfo.height - 1);
	if (run.last - run.first > vertical.last - vertical.first) vertical = run;
}
const screen = {
	left: horizontal.first,
	top: vertical.first,
	width: horizontal.last - horizontal.first + 1,
	height: vertical.last - vertical.first + 1,
};

if (screen.width !== 1320 || screen.height !== 2868) {
	throw new Error(`Detected unexpected screen aperture: ${screen.width}x${screen.height}.`);
}

const maskPixels = Buffer.alloc(screen.width * screen.height);
const minInteriorRun = Math.floor(screen.width * 0.15);
for (let y = 0; y < screen.height; y++) {
	let runStart = -1;
	for (let x = 0; x <= screen.width; x++) {
		const alpha = x < screen.width ? alphaAt(screen.left + x, screen.top + y) : 255;
		if (alpha < 255 && runStart === -1) runStart = x;
		if ((alpha === 255 || x === screen.width) && runStart !== -1) {
			if (x - runStart >= minInteriorRun) {
				for (let maskX = runStart; maskX < x; maskX++) {
					maskPixels[y * screen.width + maskX] = 255 - alphaAt(screen.left + maskX, screen.top + y);
				}
			}
			runStart = -1;
		}
	}
}
const screenMask = await sharp(maskPixels, {
	raw: { width: screen.width, height: screen.height, channels: 1 },
})
	.png()
	.toBuffer();

await mkdir(outputDirectory, { recursive: true });
for (const name of screenshotNames) {
	const sourcePath = join(imageDirectory, name);
	const outputPath = join(outputDirectory, name);
	const screenImage = await sharp(sourcePath)
		.removeAlpha()
		.resize(screen.width, screen.height, { fit: 'fill' })
		.png()
		.toBuffer();
	const maskedScreen = await sharp(screenImage)
		.joinChannel(screenMask)
		.png()
		.toBuffer();

	await sharp({
		create: {
			width: bezelInfo.width,
			height: bezelInfo.height,
			channels: 4,
			background: { r: 0, g: 0, b: 0, alpha: 0 },
		},
	})
		.composite([
			{ input: maskedScreen, left: screen.left, top: screen.top },
			{ input: await sharp(bezelPath).png().toBuffer(), left: 0, top: 0 },
		])
		.png({ compressionLevel: 9 })
		.toFile(outputPath);
}

const files = await readdir(outputDirectory);
console.log(
	`Detected screen opening at (${screen.left}, ${screen.top}), ${screen.width}x${screen.height}; generated ${files.length} framed screenshots.`,
);
