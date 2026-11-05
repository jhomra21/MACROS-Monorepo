## 2026-10-25 Weight, Apple Health, and Reminders (WS5)

- Added an on-device weight log linked to `BodyProfile`, a free latest-weight Insights summary with Pro-gated trends and Apple Health import, free nutrition write support, and one free daily reminder with Pro named/smart reminder scheduling.
- Added additive SwiftData registration, HealthKit and notification setup, notification-to-Add-Food routing, and focused failure-mode coverage for weight analytics and reminder day selection.
- Validation: `make quality-format-check`, `make quality-build`, and focused XCTest selections passed (56 tests, zero failures). Simulator QA verified nutrition writes/edits, deletion of the latest Health sample, Health body-mass import, free Insights state, and weight formatting. Reminder delivery/background/cold-launch routing remain unverified. Evidence and exact limits: `build/ws5-qa-2026-10-25/QA.md`.
- Review fixes serialize Health nutrition writes, deletes, and backfill through one FIFO owner with enqueue-time snapshots (a delete supersedes queued writes for the same entry), report backfill outcomes in the single Settings status line, guard backfill cancellation by generation, restart weight observation after authorization, and require an exact-day baseline for the 7-day weight comparison; focused Health, weight, reminder, and migration tests pass.

## 2026-10-25 Retention and Polish (WS7)

- Centralized the display brand, added a calendar-aware dashboard logging streak and eligible post-save App Store review request, made barcode 429 responses non-retryable with bounded `Retry-After` feedback, and aligned current Insights and ring-color Pro entry copy. Deferred WS4/WS5/WS6 follow-ups are listed in the tracker.
## 2026-10-25 MACROS Pro (WS2)

- Replaced the single unlock offer with yearly (7-day trial), monthly, and family-shareable $49.99 lifetime Pro plans while preserving legacy lifetime access; added observable source/expiration, native contextual paywall, subscription management, redemption, and all six future feature gates. Rebased owner decisions use `healthWeightImport` for Pro; nutrition writing stays free.
- Locked Insights now deliberately shows real 7-day summary tiles and blurred real charts instead of the earlier fake/no-user-data preview; longer ranges remain locked. Preserved native translucent sheet glass without fake strokes.
- Build, formatting, and catalog guardrails pass; simulator UI verifies real totals and Debug Pro gates. StoreKit integration and purchase-path QA remain blocked by local `storekitd` development-entitlement rejection, not waived. Evidence: `build/ws2-qa-2026-10-25/QA.md`; WS9/device sandbox verification is still required.
- Repair follow-up reproduced the pre-existing rejection on a fresh iOS 26.4 simulator, after shutdown/erase, and through a visible XCUITest launch; documented Apple FB22237318 / FB22500243 and retained no signing workaround. Payment validation remains blocked.
- Payments review fixes add status/foreground access refresh, independent subscription management visibility, verified renewal/grace copy, listener-driven integration coverage, and a directly tested deterministic entitlement reducer. Pure tests pass; local purchase QA remains blocked at catalog activation.
- Re-review fix coalesces entitlement refreshes and awaits a final committed result before purchase/restore feedback; deterministic listener-free concurrency regressions pass without StoreKit catalog activation.
## 2026-10-25 Goal Calculator and Onboarding (WS3)

- Added a deterministic Mifflin-St Jeor goal calculator, persisted body profile, guided first-run onboarding, and Settings recalculation flow while preserving manual goal entry and the existing first-run completion flag.
- Added calculator failure-mode coverage and verified the existing meal migration fixture opens with the additive body-profile model.
- Review fixes keep macro calories at or above the safe minimum after rounding, parse localized decimal input, keep metric measurements at full precision across unit toggles, push target review from Settings recalculation so Back preserves the draft, show the proposed macro grams, give imperial height fields distinct focus, and add independent Mifflin-St Jeor reference tests.
## 2026-10-25 Launch Decisions Update

- Applied three owner decisions: `macros.pro.lifetime` is $49.99; writing nutrition to Apple Health is free and importing weight from Apple Health is Pro (`PaidFeature.healthWeightImport`); Terms of Use are governed by the State of Texas, USA. Trackers, website, and App Store drafts now match.

## 2026-10-25 Website Form Retention

- Added a daily Worker purge for support and waitlist submissions older than 365 days.

## 2026-10-25 App Store Connect Product Checklist

- Chose manual App Store Connect setup for WS9 and dropped the API script path; added the [product creation checklist](../../../docs/app-store/asc-products-checklist.md) with Apple Help references.

## 2026-10-25 Monetization Market Validation

- Added a sourced market-validation report for the locked monetization offer; no product prices, identifiers, or feature gates changed.

## 2026-10-25 Website, Legal, and App Store Metadata

- Expanded the website with privacy and terms pages, launch pricing and feature details, FAQ, and App Store placeholder; drafted App Store listing, privacy labels, and screenshot plans.

## 2026-10-25 Services Hardening

- Added Cloudflare Worker per-IP request limits, a strict SQLite Durable Object-backed shared USDA budget, non-cacheable degraded empty results, configurable food lookup deadline, bounded restaurant legacy scanning, Convex daily profile quotas with profile-deletion cleanup, and support/waitlist honeypots. Reduced Worker log and trace sampling to 10%; public success response contracts remain unchanged.
- Validation and repeatable loopback QA are recorded in `build/ws1-qa-2026-10-25/QA.md`.

## 2026-10-25 Bundled Common Food Database

- Bundled 2,865 generic foods from the latest USDA FNDDS CSV release (2021–2023, October 2024; public domain, 17 U.S.C. § 105), with deterministic nutrient/portion mapping, content-versioned bootstrap updates, and an online-search prompt for sparse local results.
- Follow-up QA improved local search ranking for whole-word matches and selected preparation modifiers; regression coverage protects canonical matches and avoids substring collisions.

## 2026-10-13 JavaScript and TypeScript Lint Tooling

- Added isolated `tools/oxlint` Bun tooling with Oxlint 1.88.0, all generic vendored anti-slop rules, native `oxc/no-accumulating-spread`, and classic `eslint/complexity` max 20. Existing source findings are reported, not rewritten.
- Validation: plugin typecheck and controlled CLI smoke checks passed; Convex (8 unit + 18 integration), auth (2), runtime QA (93 requests/46 groups), and USDA/web type checks passed. Final lint reports 500 errors and 2 warnings across 44 files, including one complexity-26 function. Findings remain unsuppressed. Evidence and exact scope are under `build/nonphone-confidence-2026-10-13/`.
- Follow-up cleanup migrated owned JS/TS/Astro findings to schema-validated boundary parsing, precise owner types, and small focused helpers without changing lint configuration, severities, or coverage. Final `make lint-js`: zero errors and warnings; regression suites and package checks are recorded in `build/lint-cleanup-2026-10-13/`.

## 2026-10-13 Swift Sharing Reliability and Calendar Timezones

- Give sharing one upload owner that drains current local totals, joins manual/automatic requests, suppresses unchanged writes, and settles failures for explicit recovery. Ready-launch, foreground, day/clock/timezone events now request that same sync.
- Service-owned device disable cancels subscriptions/uploads and clears metadata. Committed profile deletion disables immediately; a persisted nonsecret cleanup marker supports local-only retries and blocks reuse of a tombstoned identity. Auth clears its session before secure deletion and prevents stale login completion.
- Move pending invite bearer tokens into the existing device-only Keychain policy, sharing only SecItem I/O with unchanged identity encoding/account. Preference migration removes the legacy token only after secure save; failed deletion remains explicitly recoverable.
- Preserve CalendarDay's supplied timezone and use its calendar for history/analytics grouping. CalendarDay remains a nonpersisted value, with no model/schema migration.
- Validation: pre-fix RED, then 34/34 capability-supported tests passed; full suite 34/40 passed with the same four StoreKit setup and two barcode runtime failures. Debug/Release app + widget, production/test format, StoreKit config and whitespace checks passed. Focused ownership/seam cleanup reviewed; evidence and remaining limits: `build/nonphone-confidence-2026-10-13/swift-reliability/QA.md`.
- Reviewed follow-up: joined pending credential cleanup, guarded stale device-disable responses, and formatted CalendarDay titles with its captured calendar/timezone. Regression tests failed before fixes; supported selection passed 39/39 including the migration fixture. Full suite had 39 passes, six failures, and zero skipped tests: four StoreKit setup cases and two Vision barcode cases. Debug/Release, formatter, StoreKit and whitespace checks passed.
- Defensive-review follow-up: removed redundant credential-cleanup task identity and fixed History's captured-timezone DST query boundary. New SwiftData query regressions passed in the 42/42 supported selection; details and known full-suite baseline limits: `build/nonphone-confidence-2026-10-13/DEFENSIVE-FOLLOWUP.md`.

## 2026-10-13 Local Auth, Invitation and Upstream Contract Fixes

- Validate bootstrap identity, normalized visible display name and active-profile state at the auth I/O boundary before issuing tokens; unusable responses remain generic failures.
- Make live same-owner invite retries write-free with unchanged expiry. Reject hash reuse before revoking other invitations; acceptance rejects any hash with accepted history, while revoked/expired same-owner history may coexist only with one live candidate. No history migration/deletion.
- Extract the existing food deadline adapter and reuse it for direct USDA and barcode routes, covering response bodies while preserving OFF fallback/retry/restaurant budgets. Bootstrap uses its own platform timeout signal.
- Promote original-entry native HTTP/Miniflare QA into dev-only `tools/runtime-qa`, discoverable with `make qa-network`; registered Convex QA remains excluded from function discovery by its multi-dot basename.
- Validation: RED reproductions followed by GREEN, 93 local HTTP requests/46 groups, 18 registered Convex scenarios and all 50 existing tests; affected package checks passed. Evidence: `build/nonphone-confidence-2026-10-13/network/`.
- Replay regression follow-up: a seeded accepted invite plus same-owner pending duplicate reproduced a cross-viewer grant on RED; acceptance now rejects before writes. GREEN evidence and all final counts are recorded in `build/nonphone-confidence-2026-10-13/network/replay-green/`.
