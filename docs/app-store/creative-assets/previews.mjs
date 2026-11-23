import { execFileSync } from 'node:child_process';
import { mkdir, readFile, rm } from 'node:fs/promises';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { chromium } from 'playwright';

const repository = resolve(fileURLToPath(new URL('../../../', import.meta.url)));

const assets = resolve(repository, 'build/evidence/2026-11-23-appstore-creative/assets');

const scratch = resolve(assets, 'preview-source');

const profile = '/System/Library/ColorSync/Profiles/sRGB Profile.icc';

await mkdir(scratch, { recursive: true });

const creatives = [
  {
    name: 'header',
    file: 'header-3840x1646.png',
    width: 3840,
    height: 1646,
    safe: { left: 1097, top: 493, width: 1646, height: 661 },
  },
  {
    name: 'search-results',
    file: 'search-results-3840x2560.jpg',
    width: 3840,
    height: 2560,
    safe: { left: 836, top: 765, width: 2168, height: 1030 },
  },
];

const browser = await chromium.launch({ headless: true, args: ['--force-color-profile=srgb'] });

try {
  for (const creative of creatives) {
    const sourcePath = resolve(assets, creative.file);
    const source = await readFile(sourcePath);
    const mime = creative.file.endsWith('.png') ? 'image/png' : 'image/jpeg';
    const data = `data:${mime};base64,${source.toString('base64')}`;

    const safeArea = await browser.newPage({
      viewport: {
        width: 960,
        height: Math.round(creative.height * 960 / creative.width),
      },
      deviceScaleFactor: 1,
      colorScheme: 'light',
    });

    const width = 960;
    const height = Math.round(creative.height * width / creative.width);
    const scale = width / creative.width;
    await safeArea.setContent(`<!doctype html><html><meta charset="utf-8"><style>
      *{box-sizing:border-box}html,body{margin:0;overflow:hidden;background:#f5f5f7}
      body{position:relative;width:${width}px;height:${height}px}
      img{display:block;width:100%;height:100%}
      .safe{position:absolute;left:${creative.safe.left * scale}px;top:${creative.safe.top * scale}px;
        width:${creative.safe.width * scale}px;height:${creative.safe.height * scale}px;
        border:3px solid #00a34a;box-shadow:0 0 0 9999px #0000}
      </style><body><img src="${data}" alt="${creative.name}"><div class="safe"></div></body></html>`);
    const safeAreaPath = resolve(scratch, `${creative.name}-safe-area.png`);
    await safeArea.screenshot({ path: safeAreaPath, type: 'png' });
    await safeArea.close();
    const safeAreaJpg = resolve(assets, `${creative.name}-safe-area.jpg`);
    execFileSync('sips', ['-m', profile, '-s', 'format', 'jpeg', '-s', 'formatOptions', '92', safeAreaPath, '--out', safeAreaJpg]);

    const small = resolve(assets, `${creative.name}-small.jpg`);
    execFileSync('sips', [
      '-Z',
      '600',
      '-m',
      profile,
      '-s',
      'format',
      'jpeg',
      '-s',
      'formatOptions',
      '92',
      sourcePath,
      '--out',
      small,
    ]);

    const safeCropRaw = resolve(scratch, `${creative.name}-safe-crop.png`);
    execFileSync('sips', [
      '-c',
      String(creative.safe.height),
      String(creative.safe.width),
      '-s',
      'format',
      'png',
      '--cropOffset',
      String(creative.safe.top),
      String(creative.safe.left),
      sourcePath,
      '--out',
      safeCropRaw,
    ]);
    const safeCrop = resolve(assets, `${creative.name}-safe-crop.jpg`);
    execFileSync('sips', [
      '-Z',
      '780',
      '-m',
      profile,
      '-s',
      'format',
      'jpeg',
      '-s',
      'formatOptions',
      '92',
      safeCropRaw,
      '--out',
      safeCrop,
    ]);
  }
} finally {
  await browser.close();

  await rm(scratch, { recursive: true, force: true });
}
