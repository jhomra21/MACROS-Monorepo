// Run from the repository root: bun tools/media/feature-crops.mjs
import sharp from '../../web/node_modules/sharp';
import { mkdir } from 'node:fs/promises';

const source = new URL('../../web/src/assets/app-images/', import.meta.url);

const output = new URL('../../web/src/assets/feature-crops/', import.meta.url);

// Original 1320 × 2868 screenshots. Rectangles are left, top, width, height.
const crops = [
	['scanning', 'scan-review', 48, 160, 1224, 834],
	['privacy', 'history', 20, 1110, 1280, 956],
	['portion', 'scan-review', 96, 470, 1128, 574],
	['sharing', 'sharing', 58, 432, 1204, 730],
	['widgets', 'widgets', 0, 880, 1320, 690],
];

await mkdir(output, { recursive: true });

for (const [name, image, left, top, width, height] of crops) {
	await sharp(new URL(`app-${image}.png`, source).pathname)
		.extract({ left, top, width, height })
		.png()
		.toFile(new URL(`${name}.png`, output).pathname);
}

// Keep the complete rings and macro labels. Extend only the plain app background,
// sampled at the screenshot's edge, to match the wide desktop frame.
await sharp(new URL('app-home.png', source).pathname)
	.extract({ left: 0, top: 350, width: 1320, height: 1140 })
	.extend({ left: 460, right: 460, top: 0, bottom: 0, background: '#f2f2f7' })
	.png()
	.toFile(new URL('logging.png', output).pathname);
