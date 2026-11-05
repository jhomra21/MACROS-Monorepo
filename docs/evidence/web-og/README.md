# Per-page link previews

Implemented on `web/og`, based on `b5ac3f0`. No deployment.

## Rendering and fonts

One static Astro endpoint renders every `publicPages()` entry with the already installed sharp 0.35.5. SVG draws the three header rings with the same 64 × 64 geometry (center 32, radii 26/18/10, 7px rounded strokes); Pango draws text using the explicit macOS `/System/Library/Fonts/Helvetica.ttc` file. No font stack or silent fallback is requested. Missing font files fail the build.

Sharp's existing Pango text input fixes the measured wrapping problem without adding Satori, a canvas library, or an embedded font. At 58px, the privacy title measures roughly 1400px on one line, far beyond the 710px text column. Pango wraps by glyph width with word/character fallback, then the renderer reduces font size only if the full block exceeds its allotted height. No text is truncated. All seven images were opened and inspected, including the long home/privacy titles. The subtitle stays on one line for every current page.

Added dependency bytes: **0**. Added bundled font bytes: **0**. Added client JavaScript/runtime rendering: **0**. Seven final PNGs total **687,842 bytes** (roughly 0.69 MB); each is 1200 × 630. The existing browser header logo script, native document transitions, and other metadata/schema are unchanged. The noindex 404 reuses home's preview rather than creating another public image.

This build environment emits `Fontconfig error: Cannot load default config file: File not found` once during Sharp startup. The explicit Helvetica file renders successfully; check/build pass. This is not cross-platform font portability: builds intentionally target the owner's Mac. Astro 7's local image assets expose a non-enumerable `fsPath`, verified against the installed `createImageAsset` implementation, to read the exact frontmatter screenshot bytes. Recheck that integration when upgrading Astro.

## Cache identity

`socialImage()` is the pure identity helper used by the endpoint, SiteLayout, and Article schema. A 12-hex SHA-256 prefix hashes a fixed-order encoding of:

- Template version (`macros-rings-1`), bumped for any layout, color, typography, or compositing change.
- Locked Sharp/native renderer versions.
- Canonical page path, which also seeds each ring's stable 25–95% fill.
- Exact page title and description from `pages` or published frontmatter.
- Subtitle from the small page/screen map or article section.
- SHA-256 of the source screenshot bytes and explicit font file bytes.

No clock, randomness, build path, origin, or file modification timestamp enters the identity. Equal input produces equal filenames and PNG bytes. Changing the page title changes both the rendered text and URL. Main-page screenshots come from one small map; article screenshots come from frontmatter `image`.

## Final public page → image

Prefix image paths with `https://macros-web.jhonra121.workers.dev`. These are built files, **not deployed URLs**.

| Page | Image |
| --- | --- |
| `/` | `/social/home.506c688dfe25.png` |
| `/about/` | `/social/about.a8dbce5a5685.png` |
| `/support/` | `/social/support.9f12ddbdaa8f.png` |
| `/privacy/` | `/social/privacy.9aff7e0ad9d0.png` |
| `/terms/` | `/social/terms.20358f1b4d51.png` |
| `/guides/` | `/social/guides.a9fe010191db.png` |
| `/guides/how-to-set-macro-goals/` | `/social/guides/how-to-set-macro-goals.7f104f846a0a.png` |

Evidence PNG filenames flatten nested paths using `--`. `results.json` records the full URLs, lengths, and SHA-256 byte digests. Blog index/post images are absent from the final build because the announcement remains a draft.

## Repeat verification

From this worktree:

```sh
cd /Users/juan/.t3/worktrees/cal-macro-tracker/web-og && cd web && bun run check && bun run build
cd /Users/juan/.t3/worktrees/cal-macro-tracker/web-og && bun docs/evidence/web-og/verify-og.mjs
cd /Users/juan/.t3/worktrees/cal-macro-tracker/web-og && make lint-js && git diff --check
```

The E2E verifier reads the actual built sitemap, HTML, JSON-LD, and PNGs without a server. It verifies matching OG/Twitter URLs and alt, declared and actual dimensions, hashed filenames, Article image equality, exact image coverage, and missing draft pages/images/blog index/RSS. It builds an isolated temporary source copy twice and compares every filename and PNG digest with the original build. It edits only the home title, builds again, verifies only home's hash/bytes change, then restores the temporary source. It also temporarily publishes the draft and checks that blog index/post both acquire previews while existing pages stay byte-identical. Only the temporary copy is changed/deleted; the original draft stays untouched.

Recorded full `bun run build` cost (including Wrangler types, Astro check, TypeScript, and static build): clean source copy **6.78s**, repeat **5.13s**, title edit **5.18s**, publication fixture **5.40s**. The seven social routes account for about **1.33s** clean and **0.76s** repeat, including first-use font initialization; subsequent images take roughly 40–70ms each. These are local wall-clock samples, not deployment or user-facing performance claims. See `builds.log` and `results.json`; all evidence stays below 5 MB.
