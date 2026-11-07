# Home demo video

Branch `web/demo-video`, based on `ad43c5f` (source files only). Validated locally on November 7, 2026. Nothing was deployed.

Two kinds of numbers appear below. Sections called "Final cut" were measured on the published 1,164,984-byte cut (`macros-demo.d72c87d2.mp4`, poster 36,926 bytes) after the review fixes. Sections called "Historical" were measured on the first cut (1,174,191 bytes, poster 38,800 bytes, with the opening hook card) and are kept only to show how the decision was reached.

## Decision

The video gets its own short section between "Quick enough to keep doing." (`#why`) and "Take a look inside." (`#showcase`). It does not replace the hero screenshot or sit beside it, for two reasons:

- **The hero stays fast.** The hero screenshot is a 29.5 KB WebP with high fetch priority. A video or its 37 KB poster in that spot would become the LCP element and compete with it.
- **It plays the bento back as one flow.** The feature cards show search, scan, rings, and widgets as stills. Right after them, the video shows the same features in order, and then the screenshot row lets you browse them.

The first cut opened with a hook card carrying the hero headline, so its poster would have repeated the H1. The published cut drops that card (see [Web cut](#web-cut)), and its poster is the Today screen, so the poster no longer repeats the headline. The hero placement is still rejected for the LCP reason.

The section is a plain band. The existing rule removes the top padding of a plain section that follows another, so it continues straight from the bento into the soft showcase band without extra space. On desktop the video sits left and the copy right, which mirrors the hero. On mobile the copy comes first.

The clip carries its own light #f2f2f7 canvas, so it keeps that surface in both schemes, like the light feature images in the bento. It gets the same 1px hairline and a 16px radius. No filter or tint changes the app's colors, and there is no device frame (`web/SEO.md`).

Copy: "One banana, one protein bar." and "Search for a banana and log it, then scan a protein bar. The rings fill as you go, and the day shows up in your charts and Home Screen widgets." The lead names what the video shows and is the video's `aria-describedby`. The accessible name is "MACROS app demo, 18 seconds, no sound".

## Behaviour

- `<video muted playsinline loop controls preload="none">` with explicit `width`/`height` and an `aspect-ratio` box, so nothing shifts when the video starts.
- A small inline module (656 bytes minified) plays it while at least half is on screen (`isIntersecting` and `intersectionRatio >= 0.5`; any overlap is not enough) and pauses it as soon as less than half is visible, when the page is hidden, and on `pagehide`. If autoplay is refused, for example in Low Power Mode, the controls remain.
- Only a pause made while the page is visible and the video is in view counts as the visitor's choice, and it stays paused after scrolling away and back. The module's own pauses and the browser's pauses when the page is hidden or leaving do not count, so they resume when the page shows again. A bfcache restore (`pageshow`) re-syncs the state. The home page has one demo, so the module is single-instance.
- With `prefers-reduced-motion: reduce` it never starts on its own and downloads nothing. The visitor sees the poster and the native play control. Turning reduced motion on mid-play pauses it.
- Native controls stay for everyone. A looping clip longer than 5 seconds that starts on its own needs a pause control (WCAG 2.2.2), and native controls are keyboard accessible. `controlslist="nodownload noremoteplayback"` and `disablepictureinpicture` keep the menu short.
- Without JavaScript, the visitor sees the poster with native controls.
- The observer and listeners live as long as the document, and a page restored from the back/forward cache keeps them. No timers.

## Bytes and caching

| Asset | Bytes | Loaded |
| --- | --- | --- |
| `/media/macros-demo.d72c87d2.mp4` | 1,164,984 | Only when it starts playing |
| Poster, Astro WebP 720 × 1280 | 36,926 | With the page; posters have no lazy loading |
| Inline script | 656 | With the HTML |

The poster is WebP instead of AVIF because `poster` takes one URL with no format fallback.

The filename carries the first 8 hex digits of the file's SHA-256 (`d72c87d2…`), and `public/_headers` sends `Cache-Control: public, max-age=31536000, immutable` for `/media/*`. Hashing was chosen over a modest max-age so that repeat visits never revalidate the 1.16 MB file. A re-encoded video must get a new name; the comment in `DemoVideo.astro` gives the command.

**Range requests.** Workers static assets ignore `Range`. Production returned `200` and the whole file for `Range: bytes=0-99` on existing assets (checked read-only on macrosios.com). Safari plays MP4 only after a `206` to its first-bytes probe. The Worker already runs first for every request (`run_worker_first` in `wrangler.jsonc`, which carries a comment that `/media/*` must keep reaching the Worker), so `src/lib/byte-range.ts` slices `/media/` responses (RFC 9110 single ranges). The asset's Content-Type, ETag, and Cache-Control pass through. The failure list sits above the tests in `src/worker.test.ts`. See [cloudflare-docs#34856](https://github.com/cloudflare/cloudflare-docs/pull/34856) and [workers-sdk#13534](https://github.com/cloudflare/workers-sdk/issues/13534).

How a range is served:

- **Size.** The static-assets binding sends no `Content-Length` to the Worker. Checked in `wrangler dev`: the ASSETS response headers were only `cache-control`, `cf-cache-status`, `content-type`, and `etag` (no `Content-Length`, no `Last-Modified`), for both GET and HEAD. With no usable `Content-Length` the Worker measures the file by reading a clone of the body, bounded at 8 MiB, then slices the bytes. A larger file is sent whole as 200. The edge may differ from local `wrangler dev`; unverified without a deploy.
- **Streaming.** When a response does carry `Content-Length`, the window is cut out of the stream: leading bytes are skipped, only the requested bytes are emitted, and the upstream is cancelled after the range end or when the client cancels. This path is covered by tests with chunked upstream streams, not by `wrangler dev`, because the local binding never takes it.
- **If-Range** (RFC 9110 §13.1.5). A strong entity-tag must equal the asset's strong ETag; `W/` tags on either side never match. An HTTP-date matches only when it equals `Last-Modified` exactly and `Last-Modified` is at least a second older than now; the binding sends no `Last-Modified`, so a date `If-Range` always gets 200. Anything else gets 200.

Final cut, `wrangler dev` on this branch (`audit.mjs browser`, routed through `run_worker_first` and the real ASSETS binding):

| Request | Result |
| --- | --- |
| HEAD | 200, `video/mp4`, `Accept-Ranges: bytes`, `Cache-Control: public, max-age=31536000, immutable` |
| `bytes=0-1` (Safari probe) | 206, `bytes 0-1/1164984`, 2 bytes |
| `bytes=0-1023` | 206, `bytes 0-1023/1164984`, 1,024 bytes, same headers |
| `bytes=-512` | 206, `bytes 1164472-1164983/1164984` |
| `bytes=1164974-` (last 10 bytes) | 206, 10 bytes; the last 164,984 bytes also match the file byte for byte |
| `bytes=1164984-`, `bytes=9999999-` | 416, `bytes */1164984` |
| `bytes=5-2` | 200, whole file |
| Strong matching `If-Range` | 206, 2 bytes |
| `If-Range` with `W/` ETag, stale ETag, or an HTTP-date | 200, whole file |
| `If-None-Match` with the current ETag | 304 |
| Missing `/media/nope.mp4` with Range | 404 |
| `/favicon.ico` with Range | 200, unchanged |

In `wrangler dev` the 404 page for a missing `/media/` file also carries the `immutable` `Cache-Control` from the `/media/*` rule in `public/_headers`. That predates this fix and is left as is.

## Lighthouse, mobile, home

Lighthouse 13 with Playwright Chromium and default simulated throttling, against `wrangler dev` on 127.0.0.1:8793. Three runs per batch; scores are Performance / Accessibility / Best practices / SEO. Lighthouse loads no video bytes: preload is `none` and nothing scrolls into view.

| Batch | Cut | LCP per run | TBT per run | CLS | Transfer | Scores |
| --- | --- | --- | --- | --- | --- | --- |
| Before (no video section) | n/a | 1.60, 1.60, 1.59 s | 0, 0, 0 ms | 0 | 151,063 B | 100 / 100 / 100 / 100 ×3 |
| After, batch 1 (historical) | first | 1.82, 1.59, 1.45 s | 185, 0, 0 ms | 0 | 165,015–165,030 B | 97, then 100 ×2 / 100 / 100 / 100 |
| After, final build (historical) | first | 1.78, 1.52, 1.45 s | 37, 0, 0 ms | 0 | 165,015–165,023 B | 100 / 100 / 100 / 100 ×3 |
| **Final cut, with review fixes** | published | 1.75, 1.44, 1.59 s | 0, 0, 0 ms | 0 | 163,255 B ×3 | 100 / 100 / 100 / 100 ×3 |

On the final cut the median LCP is 1.59 s against 1.60 s before, with 0 ms TBT in all three runs. Transfer is 12.2 KB above "before": the poster adds 37.1 KB, and the longer page pushes one lazy screenshot below the fold. The poster is the only video-related request on load. The LCP element was not re-read from the final run, so the earlier statement that it is still the hero comes from the first cut. This is lab data from one machine, not field INP.

## Browser checks

Final cut, Playwright Chromium against `wrangler dev`. `browser-checks.json` and `visibility-checks.json` are ignored raw output.

**Visibility thresholds** (`audit.mjs visibility`, 390 × 844, the video scrolled so an exact fraction is visible):

| Step | Fraction visible | Result |
| --- | --- | --- |
| Enter | 1% | paused, 0 MP4 requests |
| Grow | 49% | paused, 0 MP4 requests |
| Cross half | 51% | playing, 1 MP4 request |
| Shrink | 60% | still playing |
| Leave | 49% | paused |
| Shrink further | 1% | stays paused |
| Re-enter | 80% | playing again |

Pause provenance, in the same run: a pause made by the browser while `visibilityState` is hidden is not counted, so playback resumes when the page shows again. `pagehide` pauses, and a persisted `pageshow` resumes because the visitor never paused. A visitor's own pause at 60% survives leaving through 49%, re-entering at 90%, and a `pageshow`. The hidden, `pagehide`, and `pageshow` steps dispatch those events on the page; Chromium here does not background a tab or restore from bfcache, so those transitions are simulated.

**Other checks** (`audit.mjs browser`, 390 × 844 and 1440 × 900):

- Motion allowed: no MP4 request and paused before scrolling. Playing in view, paused out of view. A visitor's pause stays after scrolling away and back.
- Reduced motion: paused at 0 s with controls, no MP4 request after 1.5 s in view.
- CLS 0 at both widths across load, scroll, and playback. The media box stays 280 × 498 (390) and 320 × 569 (1440). No horizontal overflow.

Not verified: a real iPhone or Safari. Chromium does not exercise Safari's range probe, and the production asset binding was not tested (no deploy). After deploy, play the section on an iPhone and run `curl -sI -H 'Range: bytes=0-1' https://macrosios.com/media/macros-demo.d72c87d2.mp4`. A HEAD does not take the range path, so also run `curl -s -D - -o /dev/null -H 'Range: bytes=0-1' https://macrosios.com/media/macros-demo.d72c87d2.mp4` and expect 206.

`contact-sheet.jpg` is the final cut. Top row: 1440 light, 1440 dark, and 1440 dark while playing. Bottom row: 390 light and dark. The 1440 and 390 shots use the poster, which is the Today screen without the hook card.

## Repeat

From `web/`: `bun install --frozen-lockfile && bun run check && bun test src/worker.test.ts && bun run build`. From the root: `make lint-js` (needs `tools/oxlint` installed) and `git diff --check`.

Install the audit tooling in ignored `build/seo-tools` (`bun add playwright@1 lighthouse@13 chrome-launcher`). Run `bunx wrangler dev --port 8793 --ip 127.0.0.1` in `web/`, then from the root:

```sh
bun docs/evidence/web-demo-video/audit.mjs visibility
bun docs/evidence/web-demo-video/audit.mjs browser
bun docs/evidence/web-demo-video/audit.mjs lighthouse after
```

`browser` also sends the routed Range requests through `wrangler dev` and fails unless the Safari probe is 206, the last bytes are 206, an out-of-range start is 416, and the weak, date, and stale `If-Range` cases are 200.

Raw JSON and PNGs go to ignored `build/evidence/web-demo-video/`.

## Checks

- `bun run check`: 0 errors, 0 warnings, 0 hints. `bun run build`: passed.
- `bun test src/worker.test.ts`: 23 passed (five repeated runs, no flakes). These are the 9 existing tests plus 14 media Range tests. The Range tests were written before the review fixes; run against the previous `byte-range.ts`, 6 of the 23 fail (upstream cancel, no buffering ahead, the 8 MiB bound, strong-ETag `If-Range`, date `If-Range`, the one-second strong `Last-Modified` boundary) and 17 pass.
- `make lint-js`: 0 warnings, 0 errors. `git diff --check`: clean.
- The visibility and routed-Range checks run in `audit.mjs`, not in the Bun suite, because they need a browser and `wrangler dev`.
- Impeccable's design detector found nothing in `DemoVideo.astro` or `global.css`.

## Web cut

The published file is a separate cut without the opening hook card ("Log your food. Get on with your day."), because that line is already the hero headline on the same page. The poster is the first frame of that cut (Today at 1,620 kcal, dark mode). The social-media version keeps the hook.
