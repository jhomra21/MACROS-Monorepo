import { mkdir, readFile, rename, rm, writeFile } from 'node:fs/promises';
import { execFileSync } from 'node:child_process';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { chromium } from 'playwright';

const repository = resolve(fileURLToPath(new URL('../../../', import.meta.url)));

const evidence = resolve(repository, 'build/evidence/2026-11-27-appstore-frames2');

const captures = resolve(evidence, 'captures');

const output = resolve(evidence, 'out');

const bezelPath = resolve(evidence, 'official-bezel/iphone-17-black-portrait.png');

const profile = '/System/Library/ColorSync/Profiles/sRGB Profile.icc';

const dimensions = [
  { width: 1260, height: 2736, suffix: 'large' },
  { width: 1179, height: 2556, suffix: 'medium' },
];

const screenshots = [
  { file: 'scan-review.png', caption: 'Scan any label', slug: '01-scan-any-label' },
  { file: 'meal-photo.png', caption: 'Snap a photo of your meal', slug: '02-snap-a-photo-of-your-meal' },
  { file: 'home.png', caption: 'Your day at a glance', slug: '03-your-day-at-a-glance' },
  { file: 'add-food.png', caption: 'No account needed', slug: '04-no-account-needed' },
  { file: 'grams-editor.png', caption: 'Log the amount you ate', slug: '05-log-the-amount-you-ate' },
  { file: 'history.png', caption: 'See your food history', slug: '06-see-your-food-history' },
  { file: 'goal-settings.png', caption: 'Goals built around you', slug: '07-goals-built-around-you' },
];

await mkdir(output, { recursive: true });

const captureDataUrl = async filename =>
  `data:image/png;base64,${(await readFile(resolve(captures, filename))).toString('base64')}`;

const common = `
* { box-sizing: border-box; }
html, body { margin: 0; overflow: hidden; background: #f5f5f7; }
body { position: relative; color: #1d1d1f; font-family: -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif; }
.headline { position: absolute; left: 4%; width: 92%; margin: 0; text-align: center; font-weight: 750; letter-spacing: -.045em; line-height: 1.02; }

.device { position: absolute; aspect-ratio: 1350 / 2760; margin: 0; filter: drop-shadow(0 24px 36px #0003); }
.screen { position: absolute; overflow: hidden; background: #f5f5f7; }
.screen img, .bezel { position: absolute; display: block; width: 100%; height: 100%; }
.screen img { inset: 0; object-fit: fill; }
.bezel { inset: 0; }
`;

const browser = await chromium.launch({ headless: true, args: ['--force-color-profile=srgb'] });

const dataUrl = async filename =>
  `data:image/png;base64,${(await readFile(filename)).toString('base64')}`;

const measureScreenOpening = async src => {
  const page = await browser.newPage();
  const opening = await page.evaluate(async source => {
    const image = new Image();
    image.src = source;
    await image.decode();
    const canvas = document.createElement('canvas');
    canvas.width = image.naturalWidth;
    canvas.height = image.naturalHeight;
    const context = canvas.getContext('2d', { willReadFrequently: true });
    context.drawImage(image, 0, 0);
    const pixels = context.getImageData(0, 0, canvas.width, canvas.height).data;
    const width = canvas.width;
    const height = canvas.height;
    const visited = new Uint8Array(width * height);
    const queue = new Int32Array(width * height);
    const seed = Math.floor(height / 2) * width + Math.floor(width / 2);
    let head = 0;
    let tail = 0;
    queue[tail++] = seed;
    visited[seed] = 1;
    let minX = width;
    let minY = height;
    let maxX = 0;
    let maxY = 0;
    let frameMinX = width;
    let frameMinY = height;
    let frameMaxX = 0;
    let frameMaxY = 0;

    while (head < tail) {
      const index = queue[head++];
      const x = index % width;
      const y = (index - x) / width;
      minX = Math.min(minX, x);
      maxX = Math.max(maxX, x);
      minY = Math.min(minY, y);
      maxY = Math.max(maxY, y);
      const neighbors = [
        x > 0 ? index - 1 : -1,
        x + 1 < width ? index + 1 : -1,
        y > 0 ? index - width : -1,
        y + 1 < height ? index + width : -1,
      ];
      for (const neighbor of neighbors) {
        if (neighbor >= 0 && !visited[neighbor] && pixels[neighbor * 4 + 3] === 0) {
          visited[neighbor] = 1;
          queue[tail++] = neighbor;
        }
      }
    }

    for (let index = 0; index < width * height; index++) {
      if (pixels[index * 4 + 3] > 0) {
        const x = index % width;
        const y = (index - x) / width;
        frameMinX = Math.min(frameMinX, x);
        frameMaxX = Math.max(frameMaxX, x);
        frameMinY = Math.min(frameMinY, y);
        frameMaxY = Math.max(frameMaxY, y);
      }
    }

    const contour = [];
    for (let y = minY; y < minY + 220; y++) {
      for (let x = minX; x < minX + 500; x++) {
        if (visited[y * width + x]) {
          contour.push([y - minY, x - minX]);
          break;
        }
      }
    }
    let radius = 0;
    let minimumError = Infinity;
    for (let candidate = 80; candidate <= 500; candidate += 0.1) {
      const error = contour.reduce((sum, [y, x]) => {
        const curveX = candidate - Math.sqrt(Math.max(0, candidate ** 2 - (candidate - y) ** 2));
        return sum + (x - curveX) ** 2;
      }, 0) / contour.length;
      if (error < minimumError) {
        minimumError = error;
        radius = candidate;
      }
    }
    const apertureSamples = [
      [0.18, 0.02],
      [0.82, 0.02],
      [0.002, 0.5],
      [0.998, 0.5],
      [0.18, 0.98],
      [0.82, 0.98],
    ].map(([relativeX, relativeY]) => {
      const x = Math.round(minX + (maxX - minX) * relativeX);
      const y = Math.round(minY + (maxY - minY) * relativeY);
      return { x, y, alpha: pixels[(y * width + x) * 4 + 3] };
    });
    return {
      width,
      height,
      x: minX,
      y: minY,
      right: maxX + 1,
      bottom: maxY + 1,
      radius,
      transparentPixels: tail,
      apertureSamples,
      frame: { left: frameMinX, top: frameMinY, right: frameMaxX + 1, bottom: frameMaxY + 1 },
    };
  }, src);
  await page.close();
  return opening;
};

const renderPage = async (name, markup, width, height) => {
  const page = await browser.newPage({ viewport: { width, height }, deviceScaleFactor: 1, colorScheme: 'light' });
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.setContent(markup);

  const report = await page.evaluate(async () => {
    await document.fonts.ready;
    await Promise.all([...document.images].map(image => image.decode()));
    const device = document.querySelector('.device');
    const screen = document.querySelector('.screen, .cell') ?? document.body;
    const headline = document.querySelector('.headline');
    const bezel = document.querySelector('.bezel');
    const deviceRect = device?.getBoundingClientRect();
    const frame = device ? device.dataset.frame.split(',').map(Number) : null;
    const phone = deviceRect && frame
      ? {
          left: deviceRect.left + deviceRect.width * frame[0] / bezel.naturalWidth,
          right: deviceRect.left + deviceRect.width * frame[2] / bezel.naturalWidth,
          top: deviceRect.top + deviceRect.width * frame[1] / bezel.naturalWidth,
          bottom: deviceRect.top + deviceRect.width * frame[3] / bezel.naturalWidth,
        }
      : null;

    return {
      image: { width: document.images[0].naturalWidth, height: document.images[0].naturalHeight },
      bezel: bezel ? { width: bezel.naturalWidth, height: bezel.naturalHeight } : null,
      device: device?.getBoundingClientRect().toJSON() ?? null,
      screen: screen.getBoundingClientRect().toJSON(),
      canvas: { width: document.body.clientWidth, height: document.body.clientHeight },
      phoneCenterOffset: phone ? (phone.left + phone.right) / 2 - innerWidth / 2 : null,
      headline: headline?.getBoundingClientRect().toJSON() ?? null,
      headlineClipped: headline ? headline.scrollWidth > headline.clientWidth : false,
      headlineOverlapsScreen: headline && phone ? headline.getBoundingClientRect().bottom >= phone.top : false,
      phone,
      deviceFitsCanvas: phone
        ? phone.left >= innerWidth * 0.05 - 1 &&
          innerWidth - phone.right >= innerWidth * 0.05 - 1 &&
          innerHeight - phone.bottom >= innerHeight * 0.02 &&
          phone.top >= 0
        : true,
    };
  });

  const isScreenshot = /^\d{2}-/.test(name);
  if (
    errors.length ||
    (isScreenshot &&
      (report.headlineClipped || report.headlineOverlapsScreen || !report.deviceFitsCanvas ||
        Math.abs(report.phoneCenterOffset) > 1))
  ) {
    throw new Error(JSON.stringify({ name, errors, report }));
  }
  const path = resolve(output, `${name}.png`);
  const screenshot = await page.screenshot({ type: 'png' });
  const raster = await page.evaluate(async ({ png, screen }) => {
    const image = new Image();
    image.src = `data:image/png;base64,${png}`;
    await image.decode();
    const source = document.querySelector('.screen img');
    const canvas = document.createElement('canvas');
    canvas.width = image.naturalWidth;
    canvas.height = image.naturalHeight;
    const context = canvas.getContext('2d', { willReadFrequently: true });
    context.drawImage(image, 0, 0);
    const pixels = context.getImageData(0, 0, canvas.width, canvas.height).data;
    const sourceCanvas = source ? document.createElement('canvas') : null;
    const sourcePixels = sourceCanvas
      ? (() => {
          sourceCanvas.width = source.naturalWidth;
          sourceCanvas.height = source.naturalHeight;
          const sourceContext = sourceCanvas.getContext('2d', { willReadFrequently: true });
          sourceContext.drawImage(source, 0, 0);
          return sourceContext.getImageData(0, 0, sourceCanvas.width, sourceCanvas.height).data;
        })()
      : null;
    let nonOpaquePixels = 0;
    for (let index = 3; index < pixels.length; index += 4) {
      if (pixels[index] !== 255) nonOpaquePixels++;
    }
    const samples = source
      ? [
          [0.18, 0.02],
          [0.82, 0.02],
          [0.002, 0.5],
          [0.998, 0.5],
          [0.18, 0.97],
          [0.82, 0.97],
        ].map(([x, y]) => {
          const px = Math.round(screen.x + screen.width * x);
          const py = Math.round(screen.y + screen.height * y);
          const offset = (py * canvas.width + px) * 4;
          const sx = Math.min(sourceCanvas.width - 1, Math.round(sourceCanvas.width * x));
          const sy = Math.min(sourceCanvas.height - 1, Math.round(sourceCanvas.height * y));
          const sourceOffset = (sy * sourceCanvas.width + sx) * 4;
          const rgba = [...pixels.slice(offset, offset + 4)];
          const sourceRGBA = [...sourcePixels.slice(sourceOffset, sourceOffset + 4)];
          const difference = Math.max(
            ...rgba.slice(0, 3).map((value, channel) => Math.abs(value - sourceRGBA[channel])),
          );
          return { x: px, y: py, rgba, sourceRGBA, difference };
        })
      : [];
    return { width: canvas.width, height: canvas.height, nonOpaquePixels, samples };
  }, { png: screenshot.toString('base64'), screen: report.screen });
  if (
    raster.nonOpaquePixels ||
    raster.samples.some(sample => sample.rgba[3] !== 255) ||
    raster.samples.some(sample => sample.difference > 12) ||
    raster.width !== width ||
    raster.height !== height
  ) {
    throw new Error(JSON.stringify({ name, raster }));
  }
  await writeFile(path, screenshot);
  await page.close();
  const profiledPath = `${path}.srgb.png`;
  await rm(profiledPath, { force: true });
  execFileSync('sips', ['-m', profile, path, '--out', profiledPath]);
  await rename(profiledPath, path);
  console.log(JSON.stringify({ name, errors, report, raster }));
};

try {
  const data = new Map(await Promise.all(screenshots.map(async item => [item.file, await captureDataUrl(item.file)])));
  const bezelData = await dataUrl(bezelPath);
  const screenOpening = await measureScreenOpening(bezelData);
  const bezelWidth = screenOpening.width;
  const bezelHeight = screenOpening.height;
  if (
    !screenOpening.transparentPixels ||
    !screenOpening.radius ||
    screenOpening.apertureSamples.some(sample => sample.alpha !== 0)
  ) {
    throw new Error(`Could not measure bezel screen opening: ${JSON.stringify(screenOpening)}`);
  }
  console.log(JSON.stringify({ screenOpening }));
  const rendered = [];

  for (const size of dimensions) {
    const titleSize = Math.round(size.width * 0.062);
    const holeLeft = screenOpening.x / bezelWidth * 100;
    const holeTop = screenOpening.y / bezelHeight * 100;
    const holeWidth = (screenOpening.right - screenOpening.x) / bezelWidth * 100;
    const holeHeight = (screenOpening.bottom - screenOpening.y) / bezelHeight * 100;
    const radiusX = screenOpening.radius / bezelWidth * 100;
    const radiusY = screenOpening.radius / bezelHeight * 100;
    const frame = screenOpening.frame;
    const frameWidth = frame.right - frame.left;
    const frameHeight = frame.bottom - frame.top;
    const captionTop = size.height * 0.026;
    const captionBottom = captionTop + titleSize * 1.02;
    const phoneTop = captionBottom + size.height * 0.035;
    const phoneWidth = Math.min(
      size.width * 0.9,
      (size.height * 0.98 - phoneTop) * frameWidth / frameHeight,
    );
    const scale = phoneWidth / frameWidth;
    const deviceSize = bezelWidth * scale;
    const deviceLeft = size.width / 2 - (frame.left + frame.right) / 2 * scale;
    const deviceTop = phoneTop - frame.top * scale;

    const markupFor = (item, src) => `<!doctype html><html lang="en"><meta charset="utf-8"><title>${item.caption}</title><style>${common}
      body { width:${size.width}px; height:${size.height}px; }
      .headline { top:${captionTop}px; font-size:${titleSize}px; }
      .device { width:${deviceSize}px; left:${deviceLeft}px; top:${deviceTop}px; }
      .screen { left:${holeLeft}%; top:${holeTop}%; width:${holeWidth}%; height:${holeHeight}%; border-radius:${radiusX}% / ${radiusY}%; }
      </style><body><h1 class="headline">${item.caption}</h1><figure class="device" data-frame="${frame.left},${frame.top},${frame.right},${frame.bottom}">
        <div class="screen"><img src="${src}" alt="MACROS app screen"></div>
        <img class="bezel" src="${bezelData}" alt="Apple iPhone 17 Black portrait bezel">
      </figure></body></html>`;

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

  const sheetItems = rendered.filter(item => item.size.suffix === 'large');
  const previewWidth = 3 * cellWidth + 4 * gap;
  await renderPage(
    'search-result-preview',
    previewMarkup(sheetItems.slice(0, 3), 3, 'Search result preview'),
    previewWidth,
    cellHeight + 2 * gap,
  );
  await renderPage(
    'contact-sheet',
    previewMarkup(sheetItems, 4, 'Screenshot contact sheet'),
    4 * cellWidth + 5 * gap,
    2 * cellHeight + 3 * gap,
  );
  await writeFile(
    resolve(output, 'screenshots.json'),
    `${JSON.stringify({ captures: screenshots, sizes: dimensions, bezel: { source: 'https://developer.apple.com/design/resources/', model: 'iPhone 17', color: 'Black', screenOpening }, rendered: rendered.map(({ caption, slug, size, name }) => ({ caption, slug, size, file: `${name}.png` })) }, null, 2)}\n`,
  );
} finally {
  await browser.close();
}
