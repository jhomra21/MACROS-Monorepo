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
- Added public app screenshots and favicon assets under `public/`.

### Main implementation steps

- Kept shared site content in `src/data/site.ts` instead of repeating copy across pages.
- Reused one layout and one CSS file instead of page-local structure/styling duplication.
- Kept static informational pages prerendered and left the support flow dynamic.
- Configured Astro to deploy through the Cloudflare adapter in `astro.config.mjs`.

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

## Validation Recorded

### Completed validation

- `bun run check`
- `bun run db:migrations:apply:local`
- `bun run db:migrations:apply:remote`
- `bun run deploy:dry-run`

### Runtime verification completed

- Local malformed JSON POST to `/api/support` returns `400`.
- Local valid JSON POST to `/api/support` returns `200`.
- Remote D1 migration flow now resolves the configured support database successfully.

## Current Operational State

- The remote support database exists and is bound as `SUPPORT_DB`.
- The `support_requests` schema has been applied locally and remotely.
- The deploy path now includes the required remote migration step before deployment.
