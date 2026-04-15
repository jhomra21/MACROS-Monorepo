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
- The support page and support API remain dynamic because they depend on request handling and D1 persistence.
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
