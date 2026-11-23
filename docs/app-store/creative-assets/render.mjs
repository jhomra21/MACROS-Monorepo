import { mkdir, readFile, rm, writeFile } from 'node:fs/promises';
import { execFileSync } from 'node:child_process';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { chromium } from 'playwright';

const repository = resolve(fileURLToPath(new URL('../../../', import.meta.url)));

const evidence = resolve(repository, 'build/evidence/2026-11-23-appstore-creative');

const captures = resolve(evidence, 'captures');

const output = resolve(evidence, 'assets');

const profilePath = '/System/Library/ColorSync/Profiles/sRGB Profile.icc';

const profile = await readFile(profilePath);

const imageData = async filename =>
  `data:image/png;base64,${(await readFile(resolve(captures, filename))).toString('base64')}`;

await mkdir(output, { recursive: true });

const [home, scan, food] = await Promise.all([
  imageData('home.png'),
  imageData('scan-review.png'),
  imageData('add-food.png'),
]);

const common = `
* { box-sizing: border-box; }
html, body { margin: 0; overflow: hidden; background: #f5f5f7; }
body { position: relative; font-family: -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif; color: #1d1d1f; }
.phone { position: absolute; margin: 0; padding: 12px; background: #1a1a1c; border-radius: 76px; box-shadow: 0 38px 80px -30px #0004; }
.phone img { display: block; width: 100%; height: auto; border-radius: 64px; }
`;

const html = (title, css, content) =>
  `<!doctype html><html lang="en"><meta charset="utf-8"><title>${title}</title><style>${common}${css}</style><body>${content}</body></html>`;

const phone = (name, src) => `<figure class="phone ${name}"><img src="${src}" alt="${name} app screen"></figure>`;

const header = html(
  'MACROS product page header',
  `
  body { width: 3840px; height: 1646px; }
  .band { position: absolute; border-radius: 50%; border: 100px solid; }
  .band.blue { width: 2100px; height: 2100px; left: -1330px; top: -230px; border-color: #007aff; }
  .band.orange { width: 1820px; height: 1820px; left: -1190px; top: -90px; border-color: #ff9f0a; }
  .band.pink { width: 1540px; height: 1540px; left: -1050px; top: 50px; border-color: #ef4f87; }
  .right-band { position: absolute; left: 3030px; top: 0; width: 810px; height: 1646px; background: #fff; border-radius: 823px 0 0 823px; }
  h1 { position: absolute; left: 1140px; top: 592px; width: 1030px; margin: 0; font-size: 132px; line-height: 1.06; letter-spacing: -.04em; font-weight: 750; }
  h1 span { display: block; }
  h1 .last { margin-top: 12px; }
  .home { width: 510px; left: 2180px; top: 300px; padding: 10px; border-radius: 72px; }
  .home img { border-radius: 62px; }
  `,
  `<div class="band blue"></div><div class="band orange"></div><div class="band pink"></div><div class="right-band"></div><h1><span>Scan it. Log it.</span><span class="last">Hit your macros.</span></h1>${phone('home', home)}`,
);

const searchResults = html(
  'MACROS search results asset',
  `
  body { width: 3840px; height: 2560px; background: #f5f5f7; }
  .backdrop { position: absolute; left: 0; top: 1050px; width: 3840px; height: 960px; background: #fff; }
  .stripe { position: absolute; left: 0; top: 2010px; width: 3840px; height: 16px; background: linear-gradient(90deg, #007aff 0 33.333%, #ff9f0a 33.333% 66.666%, #ef4f87 66.666%); }
  .scan { left: 850px; top: 650px; width: 580px; }
  .home { left: 1630px; top: 535px; width: 580px; }
  .food { left: 2390px; top: 650px; width: 580px; }
  `,
  `<div class="backdrop"></div><div class="stripe"></div>${phone('scan', scan)}${phone('home', home)}${phone('food', food)}`,
);

const writePng = async (browser, name, markup, width, height) => {
  const page = await browser.newPage({
    viewport: { width, height },
    deviceScaleFactor: 1,
    colorScheme: 'light',
  });

  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.setContent(markup);

  const geometry = await page.evaluate(async () => {
    await document.fonts.ready;
    await Promise.all([...document.images].map(image => image.decode()));
    const headline = document.querySelector('h1');

    return {
      images: [...document.images].map(image => ({ width: image.naturalWidth, height: image.naturalHeight })),
      headline: headline?.getBoundingClientRect().toJSON(),
      viewport: { width: innerWidth, height: innerHeight },
    };
  });

  if (errors.length) throw new Error(JSON.stringify({ name, errors, geometry }));

  const source = resolve(output, `${name}.render.png`);
  await page.screenshot({ path: source, type: 'png' });
  await writeFile(resolve(output, `${name}.html`), markup);
  await page.close();

  return { source, geometry, errors };
};

const embedSrgbProfile = async (source, target) => {
  const jpeg = await readFile(source);
  const marker = Buffer.alloc(4);
  const payload = Buffer.concat([Buffer.from('ICC_PROFILE\0\x01\x01', 'binary'), profile]);
  marker.writeUInt16BE(0xffe2, 0);
  marker.writeUInt16BE(payload.length + 2, 2);
  const parts = [jpeg.subarray(0, 2), marker, payload];
  let offset = 2;

  while (offset < jpeg.length) {
    const markerType = jpeg.readUInt16BE(offset);

    if (markerType === 0xffda || markerType === 0xffd9) {
      parts.push(jpeg.subarray(offset));
      break;
    }

    const end = offset + 2 + jpeg.readUInt16BE(offset + 2);

    const hasProfile =
      markerType === 0xffe2 && jpeg.subarray(offset + 4, offset + 16).toString() === 'ICC_PROFILE\0';

    if (!hasProfile) parts.push(jpeg.subarray(offset, end));
    offset = end;
  }

  await writeFile(target, Buffer.concat(parts));
};

const browser = await chromium.launch({ headless: true, args: ['--force-color-profile=srgb'] });

try {
  for (const [name, markup, width, height] of [
    ['header-3840x1646', header, 3840, 1646],
    ['search-results-3840x2560', searchResults, 3840, 2560],
  ]) {
    const { source, geometry, errors } = await writePng(browser, name, markup, width, height);

    if (name.startsWith('header')) {
      const png = resolve(output, 'header-3840x1646.png');
      execFileSync('sips', ['-m', profilePath, '-s', 'format', 'png', source, '--out', png]);
    } else {
      const jpeg = resolve(output, 'search-results-3840x2560.jpg');
      execFileSync('sips', [
        '-m',
        profilePath,
        '-s',
        'format',
        'jpeg',
        '-s',
        'formatOptions',
        '95',
        source,
        '--out',
        jpeg,
      ]);
      await embedSrgbProfile(jpeg, jpeg);
    }

    console.log(JSON.stringify({ name, errors, geometry }));

    await rm(source, { force: true });
  }
} finally {
  await browser.close();
}
