# Website, Legal, and App Store Metadata Tracker (WS8)

Branch `launch/ws8-website-legal`. Astro/TypeScript and copy only; no Xcode. Read `AGENTS.md`, `README.md`, `web/src/pages/*.astro`, `web/src/data/site.ts`, `web/src/worker.ts`, `web/src/lib/*.ts`, `convex-backend/convex/schema.ts` (to describe sharing data accurately), `worker/usda-proxy/src/index.ts` (search data flow), and `implementation-trackers/launch-program-tracker.md`.

## Shared Understanding

- The site is hero + waitlist + screenshot carousel, an About page, a Privacy page that only covers the website and support form, and a Support form. There is no Terms page, no pricing, no feature explanation, and the History and Calendar carousel cards use the same image.
- Apple requires, for auto-renewable subscriptions, a privacy policy link and terms of use link in the app binary and in App Store metadata, and accurate privacy labels. The paywall (WS2) links to `/privacy` and to Apple's standard EULA; this workstream adds `/terms` so the app can switch to it later.

## Core Decisions

### Privacy page rewrite (`/privacy`)

Cover, in plain language, each data flow with fields, purpose, provider, retention, and user choice:

- On-device data: food logs, saved foods and meals, goals, body profile, weight entries; stored in the app's protected container; deleted by deleting the app or using in-app controls; never uploaded except as described below.
- Packaged-food search and barcode lookup: query text or barcode plus standard request metadata (IP address) go to the developer's Cloudflare Worker, which queries Open Food Facts and USDA FoodData Central; responses are cached up to 24 hours; no account identifier is sent.
- Sharing circle (optional, off by default): a random device-generated profile key, a display name you choose, and per-day totals (calories, protein, carbs, fat, entry count, day, time zone) are stored in the developer's Convex backend to show them to people you invited; individual foods never leave the device; you can remove people, stop sharing, or delete the sharing profile in Settings, which deletes the stored totals and tombstones the profile key.
- Apple Health (optional): writing nutrition to Health is free; importing weight from Apple Health requires Pro. Health data stays within Apple Health on your device; the app never transmits Health data.
- Purchases: handled by Apple; the app only receives entitlement status.
- Reminders: local notifications only.
- Website: support form (name, email, message) and waitlist (email) stored in Cloudflare D1 for 12 months; Cloudflare request logs; no analytics SDKs or advertising.
- Children: not directed to children under 13. Contact and data-deletion route via the support page. Effective date.

### Terms page (`/terms`)

Short Terms of Use: not medical advice; subscription terms (auto-renewal, cancel in App Store settings, trial converts unless cancelled 24 hours before the end); lifetime purchase scope; acceptable use of sharing; reference to Apple's standard EULA where it governs; governing law: State of Texas, USA, and applicable United States federal law (decided 2026-10-25).

### Home page

- Replace the duplicate calendar screenshot with the sharing dashboard screenshot or drop the card until a new screenshot exists.
- Add sections in this order under the hero: "Why MACROS" (No account, Free barcode and label scanning, Your data stays on your phone, Share totals with people you choose), "Free vs Pro" table (Free column and Pro column matching the locked decisions; prices "$2.99/month, $19.99/year with a 7-day free trial, or $49.99 once"), and a short FAQ (Do I need an account? What is Pro? Does it work offline? What leaves my phone?). Keep the waitlist until launch; add an App Store badge placeholder component wired to a `site.appStoreURL` that is empty until release.
- Keep `site.ts` as the single data source; keep styling consistent with `global.css`; no new dependencies.

### App Store metadata draft

- `docs/app-store/listing.md`: name placeholder with three candidate names for the owner to check in App Store Connect, subtitle (30 chars), promotional text (170), description, keywords (100 chars, no duplicates of the name), what's new, support URL, marketing URL, privacy policy URL, review notes (how to test sharing with two sandbox devices, that Pro gates are visible in Settings), and age rating answers.
- `docs/app-store/privacy-labels.md`: mapping of each data flow above to Apple's privacy label categories (Health & Fitness data for app functionality, collected only when sharing is enabled, not linked to identity; Contact Info only on the website, not the app; no tracking), with the reasoning so the owner can enter it confidently.
- `docs/app-store/screenshots.md`: shot list for 6.9-inch and 6.5-inch sizes covering onboarding calculator, dashboard, add food, scan, insights, sharing, Pro paywall; to be captured after Phase 2.

## Proposed File Shape

- `web/src/pages/privacy.astro`, `terms.astro` (new), `index.astro`, `web/src/data/site.ts` (sections data, URLs), `web/src/components/*` if the site already uses components (check first), `web/src/styles/global.css` (minimal additions).
- `docs/app-store/listing.md`, `privacy-labels.md`, `screenshots.md` (new folder).

## Milestones and Tasks

1. Privacy and Terms pages.
2. Home sections and carousel fix.
3. Metadata drafts.
4. Validation: `cd web && bun run check && bun run build`, `make lint-js`, `git diff --check`; visual check of each page at mobile and desktop widths (screenshots in `build/ws8-qa-<date>/QA.md`). Changes-log entry. Do not deploy.

## Edge Cases

- Do not promise iCloud sync, AI, or Watch anywhere; they are deferred.
- Keep the honeypot input WS1 adds to the forms if that branch merges first (coordinate through the parent; otherwise leave forms untouched).
