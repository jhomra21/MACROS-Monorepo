# Home demo video

Branch `web/demo-video`, based on `ad43c5f` (source files only). Validated locally on November 7, 2026. Nothing was deployed.

## Decision

The video gets its own short section between "Quick enough to keep doing." (`#why`) and "Take a look inside." (`#showcase`). It does not replace the hero screenshot or sit beside it, for three reasons:

- **The hero stays fast.** The hero screenshot is a 29.5 KB WebP with high fetch priority. A video or its 39 KB poster in that spot would become the LCP element and compete with it.
- **The poster repeats the H1.** The first frame carries "Log your food. Get on with your day.", the hero headline. Next to the H1 that line would appear twice.
- **It plays the bento back as one flow.** The feature cards show search, scan, rings, and widgets as stills. Right after them, the video shows the same features in order, and then the screenshot row lets you browse them.

The section is a plain band. The existing rule removes the top padding of a plain section that follows another, so it continues straight from the bento into the soft showcase band without extra space. On desktop the video sits left and the copy right, which mirrors the hero. On mobile the copy comes first.

The clip carries its own light #f2f2f7 canvas, so it keeps that surface in both schemes, like the light feature images in the bento. It gets the same 1px hairline and a 16px radius. No filter or tint changes the app's colors, and there is no device frame (`web/SEO.md`).

Copy: "One banana, one protein bar." and "Search for a banana and log it, then scan a protein bar. The rings fill as you go, and the day shows up in your charts and Home Screen widgets." The lead names what the video shows and is the video's `aria-describedby`. The accessible name is "MACROS app demo, 18 seconds, no sound".

## Behaviour

- `<video muted playsinline loop controls preload="none">` with explicit `width`/`height` and an `aspect-ratio` box, so nothing shifts when the video starts.
- A small inline module (387 bytes minified) plays it while at least half is on screen and pauses it off screen. A pause the visitor makes while it is visible stays paused after scrolling away and back. If autoplay is refused, for example in Low Power Mode, the controls remain.
- With `prefers-reduced-motion: reduce` it never starts on its own and downloads nothing. The visitor sees the poster and the native play control. Turning reduced motion on mid-play pauses it.
- Native controls stay for everyone. A looping clip longer than 5 seconds that starts on its own needs a pause control (WCAG 2.2.2), and native controls are keyboard accessible. `controlslist="nodownload noremoteplayback"` and `disablepictureinpicture` keep the menu short.
- Without JavaScript, the visitor sees the poster with native controls.
- The observer lives as long as the document. The site uses full page loads, so leaving the page releases it. No timers.

## Bytes and caching

| Asset | Bytes | Loaded |
| --- | --- | --- |
| `/media/macros-demo.246b3b23.mp4` | 1,174,191 | Only when it starts playing |
| Poster, Astro WebP 720 × 1280 | 38,800 | With the page; posters have no lazy loading |
| Inline script | 387 | With the HTML |

The poster is WebP instead of AVIF because `poster` takes one URL with no format fallback.

The filename carries the first 8 hex digits of the file's SHA-256 (`246b3b23…`), and `public/_headers` sends `Cache-Control: public, max-age=31536000, immutable` for `/media/*`. Hashing was chosen over a modest max-age so that repeat visits never revalidate the 1.17 MB file. A re-encoded video must get a new name; the comment in `DemoVideo.astro` gives the command.

**Range requests.** Workers static assets ignore `Range`. Production returned `200` and the whole file for `Range: bytes=0-99` on existing assets (checked read-only on macrosios.com). Safari plays MP4 only after a `206` to its first-bytes probe. The Worker already runs first for every request, so `src/lib/byte-range.ts` slices `/media/` responses (RFC 9110 single ranges). The asset's Content-Type, ETag, and Cache-Control pass through. Its failure list and tests come first in `src/worker.test.ts`. See [cloudflare-docs#34856](https://github.com/cloudflare/cloudflare-docs/pull/34856) and [workers-sdk#13534](https://github.com/cloudflare/workers-sdk/issues/13534).

Results from `wrangler dev` on the final build:

| Request | Result |
| --- | --- |
| HEAD | 200, `video/mp4`, `Accept-Ranges: bytes`, `Cache-Control: public, max-age=31536000, immutable` |
| `bytes=0-1` | 206, 2 bytes |
| `bytes=0-1023` | 206, `bytes 0-1023/1174191`, 1,024 bytes, same headers |
| `bytes=-512` | 206, `bytes 1173679-1174190/1174191` |
| `bytes=9999999-` | 416, `bytes */1174191` |
| `bytes=5-2`, or stale `If-Range` | 200, whole file |
| Matching `If-Range` | 206 |
| `If-None-Match` | 304 |
| Missing `/media/nope.mp4` | 404 |
| `/favicon.ico` with Range | 200, unchanged |

## Lighthouse, mobile, home

Lighthouse 13 with Playwright Chromium and default simulated throttling, against `wrangler dev` on 127.0.0.1:8793. Three runs per batch; scores are Performance / Accessibility / Best practices / SEO.

| Batch | LCP per run | TBT per run | CLS | Transfer | Scores |
| --- | --- | --- | --- | --- | --- |
| Before | 1.60, 1.60, 1.59 s | 0, 0, 0 ms | 0 | 151,063 B | 100 / 100 / 100 / 100 ×3 |
| After, batch 1 | 1.82, 1.59, 1.45 s | 185, 0, 0 ms | 0 | 165,015–165,030 B | 97, then 100 ×2 / 100 / 100 / 100 |
| After, final build | 1.78, 1.52, 1.45 s | 37, 0, 0 ms | 0 | 165,015–165,023 B | 100 / 100 / 100 / 100 ×3 |

The LCP element is still the hero, and LCP medians are unchanged (1.60 s before, 1.59 and 1.52 s after). Transfer grew by about 14 KB: the poster adds 39 KB, and the longer page pushes one lazy screenshot (25.6 KB) below the fold. The first run of each after batch had nonzero TBT, and one of them scored 97. The other four after runs had 0 ms. This is lab data from one machine, not field INP.

## Browser checks

`browser-checks.json` (ignored raw output) from Playwright Chromium at 390 × 844 and 1440 × 900:

- Motion allowed: no MP4 request and paused before scrolling. Playing in view, paused out of view. A visitor's pause stays after scrolling away and back.
- Reduced motion: paused at 0 s with controls, no MP4 request after 1.5 s in view.
- CLS 0 at both widths across load, scroll, and playback. The media box stays 280 × 498 (390) and 320 × 569 (1440). No horizontal overflow.

Not verified: a real iPhone or Safari. Chromium does not exercise Safari's range probe. After deploy, play the section on an iPhone and run `curl -sI -H 'Range: bytes=0-1' https://macrosios.com/media/macros-demo.246b3b23.mp4`.

`contact-sheet.jpg`, top row: 1440 light and dark with the poster. Bottom row: 1440 dark while playing, then 390 light and dark.

## Repeat

From `web/`: `bun install --frozen-lockfile && bun run check && bun test src/worker.test.ts && bun run build`. From the root: `make lint-js` (needs `tools/oxlint` installed) and `git diff --check`.

Install the audit tooling in ignored `build/seo-tools` (`bun add playwright@1 lighthouse@13 chrome-launcher`). Run `bunx wrangler dev --port 8793 --ip 127.0.0.1` in `web/`, then from the root:

```sh
bun docs/evidence/web-demo-video/audit.mjs browser
bun docs/evidence/web-demo-video/audit.mjs lighthouse after
```

Raw JSON and PNGs go to ignored `build/evidence/web-demo-video/`.

## Checks

- `bun run check`: 0 errors, 0 warnings, 0 hints. `bun run build`: passed.
- `bun test src/worker.test.ts`: 15 passed. These are the 9 existing tests plus 6 Range tests, written and run failing before the implementation.
- `make lint-js`: 0 warnings, 0 errors. `git diff --check`: clean.
- Impeccable's design detector found nothing in `DemoVideo.astro` or `global.css`.
