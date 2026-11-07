// Run from the repository root: bun tools/media/feature-crops.mjs
import sharp from '../../web/node_modules/sharp';
import { mkdir } from 'node:fs/promises';

const source = new URL('../../web/src/assets/app-images/', import.meta.url);

const output = new URL('../../web/src/assets/feature-crops/', import.meta.url);

// Original 1320 × 2868 screenshots. Rectangles are left, top, width, height.
const crops = [
	['logging', 'home', 130, 350, 1060, 1140],
	['scanning', 'scan-review', 48, 184, 1224, 810],
	['privacy', 'history', 48, 750, 1224, 1330],
	['portion', 'scan-details', 48, 490, 1224, 1410],
	['sharing', 'sharing', 58, 448, 1204, 696],
];

await mkdir(output, { recursive: true });

for (const [name, image, left, top, width, height] of crops) {
	await sharp(new URL(`app-${image}.png`, source).pathname)
		.extract({ left, top, width, height })
		.png()
		.toFile(new URL(`${name}.png`, output).pathname);
}

// Only the personal widgets: omit the shared Alex widget and Home Screen icons.
const widgets = new URL('app-widgets.png', source).pathname;

const small = await sharp(widgets).extract({ left: 698, top: 284, width: 528, height: 528 }).png().toBuffer();

const medium = await sharp(widgets).extract({ left: 94, top: 936, width: 1132, height: 528 }).png().toBuffer();

await sharp({ create: { width: 1132, height: 1088, channels: 4, background: '#00000000' } })
	.composite([{ input: small, left: 302, top: 0 }, { input: medium, left: 0, top: 560 }])
	.png()
	.toFile(new URL('widgets.png', output).pathname);
