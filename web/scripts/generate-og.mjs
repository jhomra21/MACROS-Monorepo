// Rasterizes public/og.png (1200x630) from app-home.png. Run from web/: `bun scripts/generate-og.mjs`.
// Uses the `sharp` copy that Astro already installs for image optimization.
import sharp from 'sharp';

const width = 1200;

const height = 630;

const phoneWidth = 330;

const bezel = 10;

const radius = 54;

const screenshot = await sharp('src/assets/app-images/app-home.png')
	.resize({ width: phoneWidth - bezel * 2 })
	.png()
	.toBuffer();

const shotMeta = await sharp(screenshot).metadata();

const phoneHeight = (shotMeta.height ?? 0) + bezel * 2;

const roundedScreen = await sharp(screenshot)
	.composite([
		{
			input: Buffer.from(
				`<svg width="${shotMeta.width}" height="${shotMeta.height}"><rect width="100%" height="100%" rx="${radius - bezel}" fill="#fff"/></svg>`,
			),
			blend: 'dest-in',
		},
	])
	.png()
	.toBuffer();

const phone = await sharp({
	create: { width: phoneWidth, height: phoneHeight, channels: 4, background: '#1a1a1c' },
})
	.composite([
		{
			input: Buffer.from(`<svg width="${phoneWidth}" height="${phoneHeight}"><rect width="100%" height="100%" rx="${radius}" fill="#fff"/></svg>`),
			blend: 'dest-in',
		},
		{ input: roundedScreen, left: bezel, top: bezel },
	])
	.png()
	.toBuffer();

const background = `
<svg width="${width}" height="${height}" xmlns="http://www.w3.org/2000/svg" font-family="Helvetica, Arial, sans-serif">
	<rect width="100%" height="100%" fill="#f5f5f7"/>
	<text x="80" y="250" font-size="132" font-weight="800" letter-spacing="-5" fill="#1d1d1f">MACROS</text>
	<text x="84" y="324" font-size="40" font-weight="600" fill="#1d1d1f">Calories and macros,</text>
	<text x="84" y="374" font-size="40" font-weight="600" fill="#1d1d1f">without the account.</text>
	<text x="84" y="440" font-size="26" fill="#66666b">Nutrition Tracker for iPhone</text>
	<rect x="84" y="486" width="22" height="8" fill="#007aff"/>
	<rect x="106" y="486" width="21" height="8" fill="#ff9f0a"/>
	<rect x="127" y="486" width="21" height="8" fill="#ef4f87"/>
</svg>`;

await sharp(Buffer.from(background))
	.composite([{ input: await sharp(phone).extract({ left: 0, top: 0, width: phoneWidth, height: height - 70 }).toBuffer(), left: 760, top: 70 }])
	.png({ compressionLevel: 9 })
	.toFile('public/og.png');

console.log('wrote public/og.png');
