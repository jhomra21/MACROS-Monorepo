import { readFile, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { chromium } from 'playwright';

const directory = fileURLToPath(new URL('./', import.meta.url));

const profile = await readFile('/System/Library/ColorSync/Profiles/sRGB Profile.icc');

const image = async path => `data:image/png;base64,${(await readFile(new URL(path, import.meta.url))).toString('base64')}`;

const home = await image('../../../web/src/assets/app-images/app-home.png');

const food = await image('./app-add-food-unbranded.png');

const scan = await image('../../../web/src/assets/app-images/app-scan-review.png');

const phone = (name, src) => `<figure class="phone ${name}"><img src="${src}" alt="${name} app screen"></figure>`;

const common = `
* { box-sizing:border-box; }
html,body { margin:0; overflow:hidden; background:#f5f5f7; }
body { position:relative; font-family:-apple-system,BlinkMacSystemFont,'Helvetica Neue',sans-serif; color:#1d1d1f; }
.phone { position:absolute; margin:0; padding:12px; background:#1a1a1c; border-radius:92px; box-shadow:0 38px 80px -30px #0004; }
.phone img { display:block; width:100%; height:auto; border-radius:80px; }
.band { position:absolute; border-radius:50%; border:100px solid; }
`;

const document = (title, css, body) => `<!doctype html><html lang="en"><meta charset="utf-8"><title>${title}</title><style>${common}${css}</style><body>${body}</body></html>`;

const header = document('MACROS product page header', `
body { width:3840px; height:1646px; }
.band { width:2100px; height:2100px; left:-1330px; top:-230px; border-color:#007aff; }
.band.second { width:1820px; height:1820px; left:-1190px; top:-90px; border-color:#ff9f0a; }
.band.third { width:1540px; height:1540px; left:-1050px; top:50px; border-color:#ef4f87; }
.right-band { position:absolute; left:3030px; top:0; width:810px; height:1646px; background:#fff; border-radius:823px 0 0 823px; }
h1 { position:absolute; left:1130px; top:650px; margin:0; font-size:140px; line-height:1.08; letter-spacing:-.035em; font-weight:750; white-space:nowrap; }
h1 span { display:block; }
h1 .last { margin-top:25px; max-width:1000px; }
.home { width:490px; left:2220px; top:355px; border-radius:72px; padding:10px; }
.home img { border-radius:62px; }
`, `<div class="band"></div><div class="band second"></div><div class="band third"></div><div class="right-band"></div><h1><span>Scan it. Log it.</span><span class="last">Hit your macros.</span></h1>${phone('home', home)}`);

const search = document('MACROS search results', `
body { width:3840px; height:2560px; background:#f5f5f7; }
.backdrop { position:absolute; left:0; top:1020px; width:3840px; height:1000px; background:#fff; }
.stripe { position:absolute; left:0; top:2020px; width:3840px; height:16px; background:linear-gradient(90deg,#007aff 0 33.333%,#ff9f0a 33.333% 66.666%,#ef4f87 66.666%); }
.food { left:860px; top:700px; width:650px; }
.home { left:1560px; top:570px; width:720px; }
.scan { left:2330px; top:700px; width:650px; }
`, `<div class="backdrop"></div><div class="stripe"></div>${phone('food', food)}${phone('home', home)}${phone('scan', scan)}`);

const browser = await chromium.launch({ headless:true, args:['--force-color-profile=srgb'] });

try {
  for (const [name, html, height] of [['header',header,1646],['search-results',search,2560]]) {
    await writeFile(`${directory}${name}.html`, html);
    const page = await browser.newPage({ viewport:{width:3840,height}, deviceScaleFactor:1, colorScheme:'light' });
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    await page.setContent(html);
    await page.evaluate(async () => {
      await document.fonts.ready;
      await Promise.all([...document.images].map(image => image.decode()));
    });

    const geometry = await page.evaluate(() => ({
      images:[...document.images].map(img=>({width:img.naturalWidth,height:img.naturalHeight})),
      headline:document.querySelector('h1')?.getBoundingClientRect().toJSON(),
      overflow:document.body.scrollWidth > innerWidth,
    }));

    if (errors.length || geometry.overflow) throw new Error(JSON.stringify({errors,geometry}));
    await page.screenshot({path:`${directory}${name}-3840x${height}.jpg`,type:'jpeg',quality:97});
    // Add an explicit ICC APP2 segment without recompressing the screenshot.
    const jpegPath = `${directory}${name}-3840x${height}.jpg`;
    const jpeg = await readFile(jpegPath);
    const payload = Buffer.concat([Buffer.from('ICC_PROFILE\0\x01\x01', 'binary'), profile]);
    const marker = Buffer.alloc(4);
    marker.writeUInt16BE(0xffe2, 0);
    marker.writeUInt16BE(payload.length + 2, 2);
    const segments = [jpeg.subarray(0, 2), marker, payload];
    let offset = 2;

    while (offset < jpeg.length) {
      const type = jpeg.readUInt16BE(offset);

      if (type === 0xffda || type === 0xffd9) {
        segments.push(jpeg.subarray(offset));
        break;
      }

      const end = offset + 2 + jpeg.readUInt16BE(offset + 2);
      const existingProfile = type === 0xffe2 && jpeg.subarray(offset + 4, offset + 16).toString() === 'ICC_PROFILE\0';

      if (!existingProfile) segments.push(jpeg.subarray(offset, end));
      offset = end;
    }

    await writeFile(jpegPath, Buffer.concat(segments));
    console.log(JSON.stringify({name,errors,geometry}));
    await page.close();
  }
} finally {
  await browser.close();
}
