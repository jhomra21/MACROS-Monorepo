import { mkdir, readFile, rename, rm, writeFile } from 'node:fs/promises';
import { execFileSync } from 'node:child_process';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { chromium } from 'playwright';

const repository = resolve(fileURLToPath(new URL('../../../', import.meta.url)));

const evidence = resolve(repository, 'build/evidence/2026-11-23-appstore-creative');

const captures = resolve(evidence, 'captures');

const output = resolve(evidence, 'screenshots-v2');

const profile = '/System/Library/ColorSync/Profiles/sRGB Profile.icc';

const dimensions = [
  { width: 1320, height: 2868, suffix: '6.9-inch' },
  { width: 1179, height: 2556, suffix: 'medium' },
];

const screenshots = [
  { file: 'scan-review.png', caption: 'Scan any label', slug: '01-scan-any-label' },
  { file: 'home.png', caption: 'Your day at a glance', slug: '02-your-day-at-a-glance' },
  { file: 'add-food.png', caption: 'No account needed', slug: '03-no-account-needed' },
  { file: 'grams-editor.png', caption: 'Log the amount you ate', slug: '04-log-the-amount-you-ate' },
  { file: 'history.png', caption: 'See your food history', slug: '05-see-your-food-history' },
  { file: 'goal-review.png', caption: 'Goals built around you', slug: '06-goals-built-around-you' },
];

await mkdir(output, { recursive: true });

const dataUrl = async filename =>
  `data:image/png;base64,${(await readFile(resolve(captures, filename))).toString('base64')}`;

const common = `
* { box-sizing: border-box; }
html, body { margin: 0; overflow: hidden; background: #f5f5f7; }
body { position: relative; color: #1d1d1f; font-family: -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif; }
.headline { position: absolute; top: 2.6%; left: 4%; width: 92%; margin: 0; text-align: center; font-weight: 750; letter-spacing: -.045em; line-height: 1.02; }
.screen { position: absolute; left: 50%; top: 13.2%; width: 95.2%; transform: translateX(-50%); overflow: hidden; border-radius: 4.5%; box-shadow: 0 32px 84px -30px #0005; }
.screen img { display: block; width: 100%; height: auto; }
`;

const browser = await chromium.launch({ headless: true, args: ['--force-color-profile=srgb'] });

const renderPage = async (name, markup, width, height) => {
  const page = await browser.newPage({ viewport: { width, height }, deviceScaleFactor: 1, colorScheme: 'light' });
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.setContent(markup);

  const report = await page.evaluate(async () => {
    await document.fonts.ready;
    await Promise.all([...document.images].map(image => image.decode()));
    const screen = document.querySelector('.screen, .cell') ?? document.body;
    const headline = document.querySelector('.headline');

    return {
      image: { width: document.images[0].naturalWidth, height: document.images[0].naturalHeight },
      screen: screen.getBoundingClientRect().toJSON(),
      headline: headline?.getBoundingClientRect().toJSON() ?? null,
      headlineClipped: headline ? headline.scrollWidth > headline.clientWidth : false,
      headlineOverlapsScreen: headline ? headline.getBoundingClientRect().bottom >= screen.getBoundingClientRect().top : false,
      screenBleedsBottom: screen.getBoundingClientRect().bottom > innerHeight,
    };
  });

  const isScreenshot = /^\d{2}-/.test(name);
  if (
    errors.length ||
    (isScreenshot &&
      (report.headlineClipped || report.headlineOverlapsScreen || !report.screenBleedsBottom))
  ) {
    throw new Error(JSON.stringify({ name, errors, report }));
  }
  const path = resolve(output, `${name}.png`);
  await page.screenshot({ path, type: 'png' });
  await page.close();
  const profiledPath = `${path}.srgb.png`;
  await rm(profiledPath, { force: true });
  execFileSync('sips', ['-m', profile, path, '--out', profiledPath]);
  await rename(profiledPath, path);
  console.log(JSON.stringify({ name, errors, report }));
};

try {
  const data = new Map(await Promise.all(screenshots.map(async item => [item.file, await dataUrl(item.file)])));
  const rendered = [];

  for (const size of dimensions) {
    const titleSize = Math.round(size.width * 0.062);
    const screenSize = Math.round(size.width * 0.952);

    const markupFor = (item, src) => `<!doctype html><html lang="en"><meta charset="utf-8"><title>${item.caption}</title><style>${common}
      body { width:${size.width}px; height:${size.height}px; }
      .headline { font-size:${titleSize}px; }
      .screen { width:${screenSize}px; }
      </style><body><h1 class="headline">${item.caption}</h1><figure class="screen"><img src="${src}" alt="MACROS app screen"></figure></body></html>`;

    for (const item of screenshots) {
      const name = `${item.slug}-${size.suffix}`;
      await renderPage(name, markupFor(item, data.get(item.file)), size.width, size.height);
      rendered.push({ ...item, size, name });
    }
  }

  const cellWidth = 380;
  const cellHeight = 826;
  const gap = 34;

  const previewData = new Map(
    await Promise.all(
      rendered.map(async item => [
        item.name,
        `data:image/png;base64,${(await readFile(resolve(output, `${item.name}.png`))).toString('base64')}`,
      ]),
    ),
  );

  const previewMarkup = (items, columns, title) => {
    const cells = items.map(({ caption, slug, size }, index) => {
      const renderedName = `${slug}-${size.suffix}`;
      const column = index % columns;
      const row = Math.floor(index / columns);

      return `<section class="cell" style="left:${gap + column * (cellWidth + gap)}px;top:${gap + row * (cellHeight + gap)}px">
        <img src="${previewData.get(renderedName)}" alt="${caption}"></section>`;
    });

    const rows = Math.ceil(items.length / columns);
    const width = columns * cellWidth + (columns + 1) * gap;
    const height = rows * cellHeight + (rows + 1) * gap;

    return `<!doctype html><html lang="en"><meta charset="utf-8"><title>${title}</title><style>
      *{box-sizing:border-box}html,body{margin:0;overflow:hidden;background:#f5f5f7;color:#1d1d1f;font-family:-apple-system,BlinkMacSystemFont,sans-serif}
      body{position:relative;width:${width}px;height:${height}px}.cell{position:absolute;width:${cellWidth}px}
      img{display:block;width:${cellWidth}px;height:auto;border-radius:24px;box-shadow:0 12px 32px #0002}
      </style><body>${cells.join('')}</body></html>`;
  };

  const sheetItems = rendered.filter(item => item.size.suffix === '6.9-inch');
  const previewWidth = 3 * cellWidth + 4 * gap;
  await renderPage(
    'search-result-preview',
    previewMarkup(sheetItems.slice(0, 3), 3, 'Search result preview'),
    previewWidth,
    cellHeight + 2 * gap,
  );
  await renderPage(
    'contact-sheet',
    previewMarkup(sheetItems, 3, 'Screenshot contact sheet'),
    previewWidth,
    2 * cellHeight + 3 * gap,
  );
  await writeFile(
    resolve(output, 'screenshots.json'),
    `${JSON.stringify({ captures: screenshots, sizes: dimensions, rendered: rendered.map(({ caption, slug, size, name }) => ({ caption, slug, size, file: `${name}.png` })) }, null, 2)}\n`,
  );
} finally {
  await browser.close();
}
