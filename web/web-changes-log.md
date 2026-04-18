# Web Changes Log

`web-changes-log.md` is the web-project history file for implemented work, bugs found, deployment/config decisions, and validation results.

## Website Foundation

### Delivered

- Added a Bun-managed Astro website under `web/`.
- Added the shared `SiteLayout.astro` shell with header, footer, navigation, and global styling.
- Added a centralized `site.ts` content model for site copy, navigation, screenshots, feature cards, and support checklist content.
- Added the public marketing pages:
  - `src/pages/index.astro`
  - `src/pages/about.astro`
  - `src/pages/privacy.astro`
  - `src/pages/support.astro`
- Added favicon assets under `public/`.
- Added shared app screenshots for the site and README, now stored under `src/assets/app-images/`.

### Main implementation steps

- Kept shared site content in `src/data/site.ts` instead of repeating copy across pages.
- Reused one layout and one CSS file instead of page-local structure/styling duplication.
- Kept static informational pages prerendered and left the support flow dynamic.
- Configured Astro to deploy through the Cloudflare adapter in `astro.config.mjs`.
- Moved site screenshots onto importable local assets so Astro can optimize them at build time.

## Screenshot Asset Pipeline and README Alignment

### Delivered

- Moved website screenshots from `public/app-images/` to `src/assets/app-images/`.
- Added light-mode screenshots:
  - `src/assets/app-images/home1-light.jpeg`
  - `src/assets/app-images/calendar-closed-light.jpeg`
- Updated `src/data/site.ts` to import screenshots as local Astro assets instead of string paths.
- Updated `src/pages/index.astro` to render screenshots through `astro:assets` `<Image />`.
- Updated the root `README.md` to reuse the shared web screenshot assets, including the new light-mode images.

### What went wrong

- The first web setup kept screenshots in `public/app-images/`.
- That worked for plain `<img>` tags, but Astro did not optimize those files for the marketing page.
- The root README had also drifted into its own screenshot set, which recreated duplicate asset maintenance.

### Root cause

- In this codebase, the Cloudflare adapter is configured with `imageService: 'compile'`.
- With that setup, Astro image optimization happens at build time for importable local assets, not for files referenced directly from `public/`.
- Keeping screenshots in `public/` preserved direct serving but skipped the build-time optimization path the app was already configured to use.

### What actually fixed it

- Moved the reusable screenshots into `src/assets/app-images/` so they can be imported.
- Switched the home page screenshot grid to `<Image />` with generated responsive widths and WebP output.
- Kept the README pointed at the same shared asset files so the repo no longer carries a second screenshot set.
- Added the new light-mode screenshots to the README instead of creating another image directory.

## Support Flow and Persistence

### Delivered

- Added `POST /api/support` in `src/pages/api/support.ts`.
- Added shared support validation and status helpers in `src/lib/support.ts`.
- Added client-side support form enhancement in `src/pages/support.astro` for JSON submission, inline field validation, and success/error messaging.
- Added D1 migration `migrations/0000_create_support_requests.sql` to persist support requests.
- Added Wrangler scripts for local and remote D1 migration application.

### Main implementation steps

- Kept request parsing, validation, and persistence as separate responsibilities.
- Used Zod validation as the single request-contract layer for support input.
- Preserved both response modes:
  - JSON clients receive structured `400` field errors or `200` success messages.
  - non-JS form posts keep redirect-based `submitted`, `invalid`, and `error` states.
- Stored support submissions with a minimal schema: `name`, `email`, `message`, and `created_at`.

## Support Flow Fixes

### Bug fixed: malformed JSON request handling

#### What went wrong

- The support API returned `request.json()` without awaiting it inside `parseRequest()`.
- That allowed malformed JSON to reject after the `try/catch` had already returned.
- The endpoint then bypassed the intended invalid-input path and surfaced a server error instead of a structured invalid request response.

#### Root cause

- The transport parsing boundary was incomplete.
- JSON parsing was started inside the parser but not fully resolved there, so async parse failures escaped the parser contract.

#### What actually fixed it

- `parseRequest()` now awaits `request.json()` before returning.
- Malformed JSON now falls back into the existing invalid-input path instead of becoming an unhandled route error.

### Bug fixed: incomplete remote D1 binding contract

#### What went wrong

- The original `wrangler.jsonc` only declared the `SUPPORT_DB` binding plus `migrations_dir`.
- That was enough for generated types and local workflows, but not for remote D1 operations.
- Remote migration commands failed because the binding was missing the actual database identity.

#### Root cause

- The worker code, migration scripts, and Wrangler config did not fully agree on the remote database contract.
- The real fix belonged in config, not in script branching or local-only workarounds.

#### What actually fixed it

- Consolidated `SUPPORT_DB` into one complete D1 binding in `wrangler.jsonc`.
- Added the production support database name and Cloudflare `database_id`.
- Kept `migrations_dir` on the same binding instead of splitting configuration across duplicate entries.
- Created the remote D1 database `cal-macro-tracker-support`.
- Applied the support schema migration locally and remotely.

### Bug fixed: deploy path could skip required schema setup

#### What went wrong

- The support endpoint depends on the `support_requests` table.
- The original `deploy` script built and deployed the worker but did not apply remote D1 migrations first.
- A fresh environment could therefore deploy code that immediately returned `500` on support submission.

#### Root cause

- Schema rollout was treated as a manual side step instead of part of the deployment contract for this web app.

#### What actually fixed it

- Updated `package.json` so `bun run deploy` now runs:
  1. `bun run build`
  2. `bun run db:migrations:apply:remote`
  3. `wrangler deploy`

## Current Web Architecture Notes

- Astro + `@astrojs/cloudflare` is the current web stack.
- Sessions are intentionally disabled through `src/lib/disabled-session-driver.ts`.
- Static marketing pages stay prerendered.
- The support page is prerendered static again, while only the support API remains dynamic for request handling and D1 persistence.
- Wrangler config is the source of truth for the support database binding and migration directory.
- Screenshot optimization currently relies on Astro's build-time pipeline via imported `src/assets` images and the Cloudflare adapter's `imageService: 'compile'` setting.

## Validation Recorded

### Completed validation

- `bun run check`
- `bun run db:migrations:apply:local`
- `bun run db:migrations:apply:remote`
- `bun run deploy:dry-run`
- `bun run build`

### Runtime verification completed

- Local malformed JSON POST to `/api/support` returns `400`.
- Local valid JSON POST to `/api/support` returns `200`.
- Remote D1 migration flow now resolves the configured support database successfully.
- Astro build output generates optimized `/_astro/*.webp` screenshot assets from the imported app images.

## Current Operational State

- The remote support database exists and is bound as `SUPPORT_DB`.
- The `support_requests` schema has been applied locally and remotely.
- The deploy path now includes the required remote migration step before deployment.

## Aesthetics Overhaul: Apple Native Design

### Delivered

- Refactored `src/styles/global.css` to adopt standard iOS dynamic colors (`#ffffff` and `#f2f2f7` for light mode; `#000000` and `#1c1c1e` for dark mode).
- Implemented true translucency in the sticky header (`backdrop-filter`) to replicate the signature Apple web header.
- Scrapped complex circular background gradients from the `page-shell`.
- Re-architected typography to reference the Apple `SF Pro Display` design by incorporating tighter letter spacing (`-0.04em`).
- Flattened the DOM hierarchy inside of `src/pages/index.astro`, removing complex 3D skew rendering logic to follow the "reduce layers" philosophy.
- Transitioned feature cards and screenshot galleries into a standard Apple "Bento-Box" styling layout (with 24px/32px radii, precise borders, and soft drop-shadows).

### Main implementation steps

- Streamlined CSS footprint avoiding multi-layered abstractions per `code-simplifier.md`.
- Rewrote `index.astro` to render simple flex/grid combinations directly mapping to the new bento styles, instead of nested device shells.
- Left Astro layout components, asset optimization pipelines, and backend routing untouched.

## Home Page Visual Redesign

### Delivered

- Rebuilt the `index.astro` homepage to feature 3 main sections matching updated design sketches.
- Built a massive "MACROS" typographical Hero Section with bouncing arrow and "Simplest Calorie - Macro tracker" subtitle.
- Implemented an "APP Photos" horizontal native-feeling carousel with `scroll-snap`.
- Designed a sleek "Join Waitlist" inline form for a dedicated waitlist flow instead of reusing the support endpoint.

### Main implementation steps

- Added new grids to `global.css` while maintaining the Apple Native variables schema (`--shadow-bento`, etc).
- Replaced the old "features" cards layout with the App Photos carousel, directly iterating on `site.screenshots`.
- Removed the "Sandwich Breakdown" section HTML and CSS to maintain visual simplicity.
- Standardized execution tools on native `bun` rather than fallback Node runtimes for subsequent modifications.
- Verified build pipeline comprehensively using `bun run build`.

## Home Page Visual Polishes

### Delivered

- Perfected the Apple-native presentation across the new homepage sections based on visual review.
- Refined typography with proper center alignment and a subtle silver/gradient clip-mask for the "MACROS" text.
- Removed padding from carousel image containers so screenshot assets bleed to the top edges of the bento cards organically.
- Converted the Waitlist section's raw device screenshot into a pure-CSS hardware render (simulating an inner screen-glass reflection, an outer titanium bezel ring, and an elevated drop shadow).

### Main implementation steps

- Updated SVG icons in `index.astro` to slightly thicker `stroke-width` matching proper structural balance.
- Re-architected `.waitlist-device-img` CSS with nested box gaps to mock explicit device hardware framing dynamically for light/dark mode preference curves.
- Restructured flex/grid parameters in `global.css` hero and waitlist segments to shrink unneeded vertical space and ensure true vertical-alignment with structural offsets.

## Waitlist Flow and Homepage Interaction Follow-up

### Delivered

- Added a dedicated `POST /api/waitlist` endpoint backed by the existing Worker/D1 setup.
- Added an email-only waitlist contract and local D1 migration `0001_create_waitlist_entries.sql`.
- Made repeat email submissions idempotent with a friendly “already on the waitlist” response instead of duplicate rows.
- Fixed the homepage waitlist CTA so it actually submits through the Worker contract instead of the unrelated support flow.
- Made the gallery arrow controls work.
- Adjusted the hero screenshot so the full image is visible instead of being cropped.
- Refined the waitlist section presentation: centered the screenshot above the form, collapsed the status area to one banner, and tuned the status reveal/hide motion with faster easing.

### Main implementation steps

- Extracted shared request parsing helpers into `src/lib/request.ts` and reused them from both support and waitlist APIs.
- Added `src/lib/waitlist.ts` to validate and normalize email input and keep waitlist-specific messages separate from support.
- Implemented `src/pages/api/waitlist.ts` with `INSERT OR IGNORE` semantics on a unique waitlist email index.
- Updated `src/pages/index.astro` so the waitlist form posts to `/api/waitlist`, handles JSON responses inline, and drives one reusable status banner instead of separate hidden success/error nodes.
- Added client-side carousel previous/next handlers that scroll by one card at a time.
- Tuned the waitlist status transition to use separate enter/exit easing with a `200ms` reveal and `150ms` hide, while keeping the auto-dismiss behavior.
- Raised the visible waitlist status height cap so wrapped mobile error/success copy can expand without clipping.

### Bugs and implementation findings

- The first homepage waitlist version was a real contract bug: it posted to `/support` and only supplied `email`, while the support flow required `name`, `email`, and `message`.
- The duplicate hidden status paragraphs kept reserving layout space because shared `.status` rules still applied; collapsing the waitlist to one status node and overriding the shared spacing rules fixed the phantom gap.
- The first banner-height cap was too small for wrapped mobile feedback, so multi-line waitlist messages could clip inside the animated container until the visible max-height was increased.
- Build-only validation was not enough for the spacing issue; the final verification required browser screenshots of the live local page.
- The waitlist migration has only been applied locally so far; remote D1 rollout remains a separate operational step.

### Validation recorded during this follow-up

- `bun run db:migrations:apply:local`
- Local D1 uniqueness check confirmed duplicate waitlist inserts stay at one row.
- `bun run build`
- `git diff --check -- web/src/pages/index.astro web/src/styles/global.css web/src/lib/request.ts web/src/lib/waitlist.ts web/src/pages/api/support.ts web/src/pages/api/waitlist.ts web/migrations/0001_create_waitlist_entries.sql`
- Local browser verification with `agent-browser` screenshots confirmed:
  - no hidden waitlist-status gap when idle
  - the success banner appears in the right place above the input
  - the carousel arrows work from the homepage UI
  - wrapped mobile waitlist status text is fully visible instead of clipping

## Waitlist Validation Client-side Finalization

### Delivered

- Moved waitlist email validation fully onto the client so live validation no longer calls the Worker.
- Added a bundled IANA TLD snapshot in `src/lib/waitlist-tlds.ts` for instant top-level-domain checks like `.com`, `.io`, and country-code TLDs.
- Refactored `src/lib/waitlist.ts` so syntax, domain-label, and TLD validation live in one shared local module the homepage can use directly.
- Simplified `src/pages/index.astro` so the waitlist button enable/disable state is computed locally on each keystroke with no network request.
- Reduced `src/pages/api/waitlist.ts` to insert-only behavior for submitted emails, keeping it out of the validation path.

### Main implementation steps

- Added a local regex-based syntax gate plus domain-label checks before the final TLD lookup.
- Switched the homepage form to use the shared validation helper directly inside the inline script rather than calling `/api/waitlist` while typing.
- Removed the experimental live Worker/domain validation path so there is no per-keystroke request traffic for email validation.
- Kept only lightweight request parsing and email normalization in the Worker submit handler before the D1 insert.

### Architecture outcome

- Waitlist validation is now client-side only.
- The Worker is no longer involved in live validation and no longer re-validates email/TLD rules on submit.
- The Worker only receives the final waitlist submission payload and persists it.

### Validation recorded

- `bun run astro check`
- Manual local browser verification on `http://localhost:4321/` confirmed:
  - invalid partial emails keep the submit button disabled
  - fake TLDs such as `.3` and non-IANA suffixes stay invalid
  - no live waitlist validation request is sent to the Worker while typing

## Waitlist Contract Enforcement Repair

### Delivered

- Restored the Worker submit boundary as the authoritative waitlist contract check instead of trusting client-only validation.
- Kept live waitlist validation local in the homepage script while removing the duplicate HTML `pattern` contract from the form input.
- Fixed the shared waitlist validator so valid punycode TLDs such as `xn--p1ai` pass, while malformed local parts such as `.foo@`, `foo.@`, and `a..b@` stay invalid.
- Preserved idempotent waitlist inserts through the existing `INSERT OR IGNORE` Worker path.

### Main implementation steps

- Reused `validateWaitlistRequest()` in `src/pages/api/waitlist.ts` so the same shared waitlist contract now runs on both the client and the Worker submit path.
- Refined `src/lib/waitlist.ts` so one shared validator owns normalization, email syntax, domain-label checks, and IANA-backed TLD validation without splitting those rules across multiple layers.
- Removed the homepage input `pattern` attribute from `src/pages/index.astro` so browser-native constraints no longer compete with the shared waitlist contract.
- Kept the homepage's per-keystroke enable/disable UX local, but left final persistence guarded by the Worker before D1 insertion.

### Bugs and implementation findings

- The client-only finalization was a contract regression: direct POSTs could persist any non-empty string because the Worker submit path no longer called the shared waitlist validator.
- The first local syntax gate also contradicted the bundled IANA snapshot by rejecting punycode TLDs before the shared TLD lookup ran.
- Replacing the server contract with a looser local parser was not a safe simplification for this codebase because the Worker is the persistence boundary for waitlist submissions.

### Architecture outcome

- Live waitlist validation is still local-first in the browser; the Worker is not called on each keystroke.
- The Worker is still involved on final submit: `src/pages/index.astro` posts to `/api/waitlist`, the Worker route parses the request, runs `validateWaitlistRequest()`, returns structured validation errors when needed, and only then inserts the normalized email into D1.
- The browser and Worker now share one waitlist contract instead of maintaining separate submit-time rules.

### Validation recorded

- `bun run check`
- `bun run build`
- Direct validator verification confirmed:
  - `hello` is rejected
  - `.foo@example.com`, `foo.@example.com`, and `a..b@example.com` are rejected
  - `user@example.com` is accepted
  - `user@example.xn--p1ai` is accepted
  - fake non-IANA TLDs are rejected
- Final review pass result: `LGTM — no issues found.`

## Observability Configuration Follow-up

### Delivered

- Enabled Workers logs explicitly in `web/wrangler.jsonc`.
- Enabled Workers traces explicitly in `web/wrangler.jsonc`.
- Kept observability managed in source control instead of relying on dashboard-only config drift.

### Main implementation steps

- Expanded the Wrangler `observability` block to keep `enabled: true` at the top level.
- Added `observability.logs.invocation_logs = true` so logs are grouped by invocation in Cloudflare's Workers Logs UI.
- Added `observability.logs.head_sampling_rate = 1` and `observability.traces.head_sampling_rate = 1` so both logs and traces are fully sampled for now.
- Added `observability.traces.enabled = true` because current Cloudflare tracing still requires the explicit traces switch; `observability.enabled` alone only guarantees logs.

### Validation recorded

- `bun run check`
- `bun run deploy:dry-run`

## Support Page Static Rendering Correction

### Delivered

- Switched `src/pages/support.astro` back to a prerendered static page.
- Kept `POST /api/support` as the only dynamic support route that invokes the Worker and writes to D1.
- Moved support status query-param handling fully into the client script so redirect-based fallback UX still works without server-rendering the page.

### What went wrong

- The support page had drifted back to `export const prerender = false`.
- That made every `GET /support` request invoke the Worker, even though viewing the support form itself does not need server work.
- In production, that meant ordinary support-page visits would show up in Worker traffic and observability alongside the actual submission API traffic.

### Root cause

- The redirect/status UX for support form fallbacks was being handled in Astro frontmatter.
- That implementation detail accidentally forced the page itself to stay on-demand rendered instead of keeping only the submit endpoint dynamic.

### What actually fixed it

- Restored `export const prerender = true` in `src/pages/support.astro`.
- Removed the server-side query-param status rendering from the page frontmatter.
- Recreated the same `submitted`, `invalid`, and `error` banner behavior in the client-side support script using `window.location.search`.
- Left `src/pages/api/support.ts` as `prerender = false`, so only support submissions hit the Worker.

### Architecture outcome

- `GET /support` is now served as a static asset again.
- `POST /api/support` remains the dynamic Worker path for validation and persistence.
- Support-page traffic no longer needs Worker execution just to render the form.

### Validation recorded

- `bun run check`
- `bun run build`
- `bun run deploy:dry-run`
- Build output confirmed `/support/index.html` is prerendered again.

## Support Static Fallback Status Repair

### Delivered

- Kept `src/pages/support.astro` fully prerendered/static.
- Restored visible fallback status feedback for non-JS `POST /api/support` submissions.
- Kept the JS-enhanced support form flow and the Worker-backed `POST /api/support` contract unchanged.

### What went wrong

- After moving support status handling out of Astro frontmatter, the page still relied on `/support?status=...` redirects for non-JSON form posts.
- The prerendered HTML hid all status banners by default, and only the client script read `window.location.search` to reveal one.
- That meant the redirect fallback no longer showed any status if JavaScript was unavailable or failed.

### Root cause

- The page architecture was correctly changed to keep `GET /support` static, but the old redirect contract still depended on JS to interpret query params.
- The real fix belonged in the redirect target and static page behavior, not in making `/support` dynamic again.

### What actually fixed it

- Replaced support redirect targets from `/support?status=...` to `/support#...` in `src/lib/support.ts`.
- Added shared support status element IDs in `src/lib/support.ts` so the API and page still use one redirect mapping layer.
- Updated `src/pages/support.astro` to render dedicated static `submitted`, `invalid`, and `error` banners with stable IDs.
- Added `.support-status-banner:target` handling in `src/styles/global.css` so redirected fallback requests show the right banner without Worker rendering or client JavaScript.
- Kept the enhanced JS submit flow reusing the same status elements through `.is-visible`, while also separating validation failures from generic server failures.

### Architecture outcome

- `GET /support` remains a static asset and does not invoke the Worker on ordinary page visits.
- `POST /api/support` remains the only dynamic support path for validation and D1 persistence.
- Redirect-based fallback status now works on the static page without requiring JavaScript.

### Validation recorded

- `bun run check`
- `bun run build`
- `bun run deploy:dry-run`
- Build output confirmed `/support/index.html` remains prerendered.
