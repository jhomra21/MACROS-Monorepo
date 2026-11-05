## 2026-11-02 State-machine fixes F2 / F3

- Shared-store migration now backs up committed SQLite/WAL data into disposable staging, validates and synchronizes a self-contained base, then publishes it by same-directory rename. Legacy files and existing shared stores remain untouched; widgets cannot open staging.
- Removed sharing people no longer revive the detail screen's captured snapshot. Live roster membership controls availability and cancels its stream; removal hides macros, foods, and controls while preserving paused/notShared guards.
- Six migration tests and live two-person dev E2E pass after captured red runs; format/build/JS lint pass. Full serial non-StoreKit iPad suite passed (234 tests, 0 failures). Evidence and limits: `docs/evidence/state-machine-fixes/README.md`.

- 2026-11-02: Camera result-layout animations now wait for the presentation to finish, so provisional first measurements cannot animate the viewport in from the left during the Add Food zoom. Reverted the ineffective source modifier-order change; later result sizing, staged reveal, Reduce Motion, compact mode, and dismissal are preserved.
- 2026-11-02: Shared person and dashboard totals now animate live updates with the Dashboard’s smooth timing, numeric text transitions, and Reduce Motion support; food rows animate on stable IDs.

## 2026-11-03 Shared-person widget fix round 2 (branch only)

- NB1: preserve raw personal-widget/photo-import Pro access; scope expiry to shared widgets, carry billing-grace deadlines and unknown renewal state, and allow 24 hours for verified auto-renewals the app has not observed.
- NS1/NS2: prune unconfirmed person-day denials after computing new denials so same-day re-share/revoke invalidates again; publishing/sign-out can overwrite undecodable control files.
- Review nits 1–10: reload shared Home Screen appearance, retry in-flight invalidation in 30 minutes, treat nil selection as Default, restore inline Offline, cap response reads, log migration failure without blocking legacy auth, preserve generation on Default changes, clear future-entry layouts/access, inject the preview sharing service, and handle disabled person links.
- Owner decision pending: shared Home Screen widgets currently reuse the personal widget background; no product approval is inferred from that implementation.
- Validation: 232 serial non-StoreKit iPad and 20 backend tests, build/format/JS lint passed; A grace/background and final-source Test B checks plus ring-change provider reload were captured, slim verification passed, used simulators were shut down and locks released (`docs/evidence/shared-person-widget-e2e/fix-round-2/REPORT.md`). Test B has no macros today; no fresh live nutrition/ring-color or sandbox renewal pass is claimed.

## 2026-11-02 Shared-person widgets (branch only, not released)

- Fix round 1, B1/S1/S6 and nit 7: migration runs lazily for each token-exchange attempt, preserves widget control on failure, repairs duplicate group bytes from the legacy identity, verifies before persistent-reference legacy deletion, and cannot block identity cleanup on a widget-file failure. Identity constants now have one source.
- Fix round 1, S2/S3 and nits 3–6/13/14/17: invalidate only newly denied/removed people, separate personal reloads, centralize Default/control publishing, skip unchanged writes, retain publication errors, preserve picker tags before dashboard resolution, and route disabled person links directly to Sharing settings. Privacy-sensitive redaction remains; Settings describes iOS privacy controls because the simulator's unauthenticated Lock Screen does not redact.
- Fix round 1, S4/S5 and nits 1/2/8–12/15/16: prepare shared layout once outside rendering, omit accessory appearance/photo work, share photo storage, expire Pro projections/timelines, use midnight refreshes for app-owned states and neutral missing-control copy, tolerate duplicate intent IDs, simplify bounded HTTP reads/Retry-After, and reduce accessory text without empty personal accessibility values. Smoke deployment allowlisting is configurable and defaults to dev.
- Fix-round validation: 232 serial non-StoreKit iPad tests, 20 backend tests, 76 integrations, build/format/lint and dev smoke passed. Fresh A/B evidence proves legacy upgrade, same-process retry, divergent duplicate recovery, personal-log reload isolation, denial transition, all five installed families and distinct real cold/warm widget taps. Server Pro pause, live offline and authenticated-lock redaction remain blocked; A/B slim verification passed and all used simulators were shut down (`docs/evidence/shared-person-widget-e2e/fix-round-1/REPORT.md`).
- Added separate configurable Pro shared-person widgets for small, medium, inline, circular, and rectangular families, reusing the existing layouts and glass-free ring renderer. Default selections follow Sharing settings; explicit selections stay fixed. Own-day widgets remain URL-free.
- The extension independently fetches today's authorized macros and actual goals about every 30 minutes, without foods or push. Midnight entries blank yesterday; protected, backup-excluded last-good files are limited to the current day and app-written generation. Authoritative denial purges cached nutrition; offline rendered widgets cannot be remotely retracted instantly.
- Identity migration copies and verifies the existing private Keychain item into the existing App Group before deleting only the verified old group copy. Fresh installs add there too. Legacy unscoped reads, updates, and deletes are intended to remain compatible; TestFlight upgrades and downgrades have not been verified on a signed device. Invite tokens remain private; JWTs are extension-private and bound to identity, generation, and deployment.
- `sharing:personDay` accepts optional `includeFoods` (default true); false skips the food-day read and returns an empty foods array. The additive change was deployed only to dev energized-pigeon-822. Both targets share deployment/auth constants, still pointing to dev.
- Release gate: do not merge/upload before 1.0 approval and the production cutover. The eventual release must use the cutover deployment and matching Worker audience; no production, website, or App Store Connect changes were made here.

## 2026-11-01 Reusable sharing invite link

- One link can connect multiple people until its original 7-day expiry or revocation. Repeat acceptance keeps the existing relationship and open grant; removed pairs can reconnect. Legacy accepted invites remain blocked, and function signatures and the 20/day creation quota are unchanged.
- Create Invite reuses the device's saved, identity-bound link with more than one hour remaining, without a server call. Unbound legacy links, changed identities, and expired/near-expiry links get a new issuance. Settings already supports deliberate replacement: Revoke Invite, then Create Invite Link.
- Security trade-off: anyone holding the link can connect or reconnect until expiry/revocation; removing a person does not cancel the link. New acceptances do not write single-recipient metadata, so deleting an acceptor cannot delete the owner's reusable link. Existing accepted metadata stays in the schema for old documents. Expiry is checked on acceptance; the only cleanup cron sweeps foods, and owner deletion already deletes all owned invites.
- Recommend a future per-invite acceptance rate limit to bound link-leak abuse. The current quota model is per-profile creation/upload/name counters, not per-invite, so no acceptance quota was added.
- Copy: Sharing settings explains reuse, 7-day expiry, revocation and replacement; Remove Person warns about reconnection via a live link; the website Pro FAQ and privacy policy explain reusable bearer links. Website deployment is needed for that copy, but is not part of this change.
- Validation: 20 backend unit, 75 integration, and 228 serial non-StoreKit iPad tests passed with build/format/JS lint; dev-only deploy, healthy before/after insights, disposable HTTP smoke, and A/B live reuse/reacceptance evidence passed (`docs/evidence/reusable-invite/REPORT.md` on `docs/asc-review-screenshots`).

## 2026-11-01 Add Food Zoom and Paused Sharing Scope

- Dashboard "Add Food" now zooms the sheet out of the button and back on dismiss, like Camera. Only the button uses the new `.dashboardAddFood` destination; deep links, quick actions, and scan entry points keep the plain sheet. The shared transition namespace is now `dashboardTransition`. Sheet detent, drag indicator, and swipe-to-dismiss are unchanged.
- Person screen: a segmented Picker ignores per-segment `.disabled`, so "Macros + Foods" stayed selectable while paused. The option is now omitted while paused unless it is the current scope, and `updateScope` refuses it while paused (the server accepts it, so the guard is client-side). Backend untouched.
- Validation: format check, build, and 225 tests passed on the iPad runner (StoreKit tests skipped). Evidence: `docs/evidence/add-food-zoom/REPORT.md` on `docs/asc-review-screenshots`.

## 2026-11-01 Sharing UI and Ring Polish (build 25 owner bugs)

- Dashboard rings: glass on a stroked-path shape drew an edge line down each track and at ring seams (visible when collapsed and mid-transition). Tracks now glass a filled disc and mask the band out; look and animatable diameter are unchanged.
- Person screen: rings and legend were two List rows, so the List drew a separator between them. They are now one row using the dashboard `of N g` legend style; the no-goals P/C/F fallback, paused, not-shared, and foods states are kept.
- Sharing list: people render in a `List` (primary name, secondary totals, orange paused status) instead of accent-tinted links in a `ScrollView`. The `+` button is now a Menu: Create Invite (Pro-gated, shares the link through the system sheet) and Accept Invite (opens the existing Sharing settings flow). Backup and invite share the new `URLShareSheet`.
- Validation: format check, build, and 217 tests passed on the iPad runner. Visual evidence on iPhone 17 used a temporary, uncommitted mock sharing backend, not the dev Convex backend. Evidence: `docs/evidence/sharing-ui/REPORT.md` on `docs/asc-review-screenshots`.
- Person screen reopen: the empty state flashed (about 0.2 s) on every visit because the day was cleared and the auth token re-fetched; `SharingSyncService` now caches the last-known day in memory (dropped on pause, revoke, removal, scope loss, day change, sign-out) and skips repeat auth, verified on two simulators against dev Convex with 225 tests passing (`docs/evidence/sharing-person-cache/REPORT.md`).

## 2026-11-01 Camera Viewport Corners

- Camera viewport keeps its 28 pt top corners and uses display-concentric bottom corners, with a 28 pt minimum during zoom transitions.
- Camera side buttons use untinted regular Liquid Glass (44 pt; the sheet is forced dark, so it reads as smoked glass) and the shutter is a 66 pt interactive clear glass ring around a 52 pt white disc, sized from the owner's ChatGPT camera screenshot; appearance is left to system Liquid Glass settings.

## 2026-11-01 Sharing v2 backend (unreleased)

- Added opt-in per-person food sharing, reactive Pro enforcement (off by default), Apple-signed purchase/grace verification, ordered server notifications, bounded cleanup/deletion, and validated APIs while preserving build 23 response shapes.
- Validation: backend typecheck, 19 unit tests, 41 integration tests, JS lint, and local isolate/Node bundling passed; all deployment, smoke, and deployment-based Sandbox verification skipped by owner instruction.

## Sharing v2 app (unreleased)

- Added per-person food payload sync, signed StoreKit entitlement submission, ConvexMobile 0.8.2, a people hub, a live person screen, and simplified sharing settings.
- Validation: bounded Debug simulator build, Swift format, diff check, 25 sharing-focused tests, and 203 non-StoreKit tests passed. People empty-state captures are in `build/sharing-v2/ui/`, but the reused simulator unexpectedly had Sharing enabled, so they do not satisfy the requested sharing-off/no-server-call condition; Settings captures and preview rendering remain unverified.

## 2026-11-01 TestFlight Build 24

- Per-person sharing (Nothing / Macros / Macros + Foods) with live food lists, shared daily goals, server-verified Pro (enforcement off), and redesigned People / Person / Sharing Settings.
- Dashboard ring: whole ring tappable, smooth expand/collapse, “Food” header, “of N g” legend, and consistent spacing.
- Serving amounts display to 2 decimals.
- Validation: bounded Debug build, format/JS lint/diff checks, backend 20 unit + 69 integration tests, and serial non-StoreKit iPad suite (217 tests, 0 failures) passed.

## 2026-10-31 TestFlight Build 23

- Onboarding targets show proposed macro grams as the primary values.
- Validation: bounded Debug build and serial non-StoreKit iPad suite passed (198 tests, 0 failures); TestFlight preflight and upload completed.

## 2026-10-31 TestFlight Build 22

- Tutorial Done recap uses directional hand symbols for left, right, and tap actions.
- Validation: bounded Debug build, format/diff checks, and iPhone 17 visual verification passed; serial non-StoreKit iPad suite passed in build 21 (198 tests, 0 failures).

## 2026-10-31 TestFlight Build 21

- Tutorial Done card recap centered like the Welcome screen.
- Validation: format and diff checks, iPhone 17 light/dark/accessibility screenshots, and serial non-StoreKit iPad suite passed (198 tests, 0 failures).
