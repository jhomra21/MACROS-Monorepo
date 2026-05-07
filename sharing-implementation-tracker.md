# Sharing Implementation Tracker

Working tracker for the no-account sharing feature. Update this file as implementation progresses with task status, bugs, quirks, findings, validation notes, and new decisions.

## Shared Understanding

- Goal: Let a user explicitly invite trusted people/devices to view daily aggregate calorie and macro totals without login, without exposing food/log details, and with revocation/removal controls.
- MVP scope: Current owner-local day sharing only in the UI, with server-side retention of daily snapshots from allowed sharing intervals for future history.
- Architecture:
  - `convex-backend/` contains Convex schema, functions, auth config, and TypeScript tests.
  - `worker/auth/` contains the `macros-auth` Cloudflare Worker auth broker.
  - Swift sharing paths are to be confirmed during code exploration.
- Local-first rule: SwiftData foods/logs remain authoritative and local. Sharing flows must never delete local food/log data.
- Privacy rule: Upload only aggregate daily snapshots for MVP: `day`, `timeZoneId`, `calories`, `protein`, `fat`, `carbs`, `entryCount`, and server `updatedAt`.

## Core Decisions

### Identity and Auth

- No login for MVP.
- On first sharing setup, generate opaque high-entropy `profileKey` and `profileSecret` on-device and store them in Keychain.
- Identity is device-local and non-recoverable. If Keychain identity is lost, sharing must be set up again.
- Add a concise Keychain-code comment documenting the non-recoverable identity decision.
- Use `macros-auth` Worker as the auth broker.
- Worker receives the Keychain profile credentials during registration/token refresh, verifies/creates the profile through protected Convex bootstrap endpoints, and issues a 24-hour JWT.
- JWT `sub` is `profileKey`, not Convex document ID.
- Convex is the source of truth for profiles; the Worker does not keep a separate identity database.
- Worker authenticates bootstrap calls to Convex with a Worker-held server secret mirrored as a Convex env var.
- Convex public functions derive caller identity from `ctx.auth`; caller-owned operations should not accept `profileId` as authority.
- Use dev-only setup for now:
  - Invite/auth base uses the deployed `macros-auth` `workers.dev` URL: `https://macros-auth.jhonra121.workers.dev`.
  - Audience should be explicit, e.g. `macros-convex-dev`.
- Keep JWT in memory only; refresh from Keychain profile credentials as needed.
- Worker token exchange returns JWT, expiry, profile status, and normalized display name if needed; relationship/snapshot state comes from Convex queries.
- Display name can be created during first registration/bootstrap. Later display name changes happen through authenticated Convex mutations.

### Profiles and Names

- Display names are private relationship-scoped data.
- Names are visible only during valid invite acceptance or within established sharing relationships.
- Invalid/expired/revoked invite lookups reveal no inviter metadata.
- Display names are not globally unique/searchable.
- Validate display names: trim whitespace, require 1–40 visible characters, reject control characters, allow normal Unicode.
- Existing relationships show latest display name immediately.

### Invites

- Invites use opaque random tokens; store only `tokenHash` in Convex.
- Invite links use `https://macros-auth.jhonra121.workers.dev` URL shape.
- If opened outside the app, redirect generically to the Astro site without forwarding the token:
  - `https://macros-web.jhonra121.workers.dev/`
- Browser-opened invite routes should redirect without token validation.
- Invite validation happens only in the app acceptance flow.
- Invites are single-use, expire after 7 days, and can be manually revoked.
- One active pending outgoing invite per inviter. Creating a new invite revokes the previous pending invite with clear copy.
- Accepting someone else’s invite does not revoke the accepter’s own pending outgoing invite.
- Invite acceptance requires the accepter to be online and authenticated via Worker-issued Convex JWT.
- Pending invite status may show creation/expiry, but not recipient/open metadata.
- No push notifications for invite acceptance in MVP; refresh state when opening sharing UI, manual sync, and after sharing actions.

### Relationships and Grants

- Sharing starts one-way: inviter A shares to accepter B.
- Reciprocal B → A sharing is available without another invite, but is off until B explicitly enables it.
- Model one canonical relationship per pair, keyed by sorted profile keys/IDs, with independent directional grants.
- Prevent duplicate relationships.
- Directional grant scope starts as `{ macros: true }`.
- Future scopes such as foods, micronutrients, and goals default off and require explicit per-direction opt-in.
- Use append-only directional grant intervals:
  - `relationshipId`
  - `fromProfileId`
  - `toProfileId`
  - `scope`
  - `startDay`
  - `endDay?`
  - `startedAt`
  - `endedAt?`
- Store both day keys and server event timestamps.
- Enable/disable/remove/delete controls require successful server confirmation. Do not pretend privacy changes took effect offline.
- While a privacy action is pending, show pending UI; only finalize after server confirmation.
- Keep relationships with zero active grants so they can be re-enabled without a new invite.
- “Remove person” tombstones/deletes the relationship and grant history for both participants; reconnecting requires a new invite.
- Removed users should not receive a specific reason or notification.
- If a counterpart deleted their sharing profile, re-enable is unavailable; require a new invite if they set up a new identity.

### Visibility Semantics

- MVP UI shows current owner-local day only.
- Store snapshots from sharing start onward for future history, but do not expose history in MVP UI.
- Never expose data from before sharing started.
- Disabled gaps are not shared.
- Revocation/disable hides data immediately from viewers.
- If sharing is later re-enabled, viewers can see previously allowed days plus new allowed days going forward, excluding disabled gaps.
- Current day is visible immediately when a directional grant is active.
- If sharing is disabled mid-day, today becomes hidden until re-enabled.
- For future history, retain/share a day only if the grant was active at the end of that owner-local day.
- Add a concise code comment near visibility logic documenting the same-day disable and day-end retention rule.
- Dashboard/shared queries include relationship entries even if today’s snapshot is unavailable, returning `snapshot: null`.
- Neutral viewer state: “No shared data available for today.”
- Do not reveal whether no data is caused by disable, no entries, sync failure, or network issues.

### Sharing Controls

- Separate controls:
  - Per-person outgoing sharing toggle.
  - Global “Stop sharing my data” closes all outgoing grants but preserves relationships/history.
  - “Turn off sharing on this device” closes outgoing grants, stops uploads, stops viewing shared data, and stops token refresh until re-enabled.
- Re-enabling device sharing resumes incoming viewing automatically after auth.
- Outgoing sharing remains off after full device turn-off until the user explicitly selects/reenables people.
- Deleting the sharing profile deletes only Convex/cloud sharing data: profile, relationships/grants, invites, uploaded snapshots.
- Deleting the sharing profile must never delete local SwiftData food/log data.
- After deleting the sharing profile, clear sharing Keychain identity and local sharing metadata.
- UI must warn that deleting the sharing profile permanently removes cloud sharing identity/data/relationships and future sharing setup starts fresh.
- Delete sharing profile immediately after explicit destructive confirmation; no grace period.

### Snapshots and Sync

- SwiftData local logs/foods are the source of truth.
- Convex accepts client-computed daily aggregate totals.
- Upsert snapshots idempotently by `(ownerProfileId, day)`.
- Store only the latest snapshot per day; no event/version history for MVP.
- Upload explicit zero snapshot when sharing is enabled and there are no entries today.
- Automatic upload runs when today’s derived totals change, only while app is active or shortly after user changes logs.
- Do not block local logging on network/Convex failures.
- Retry quietly and show sync status/staleness only in the sharing screen.
- Provide “Sync now” in the sharing/settings screen; it reuses the same upload/refresh path as automatic sync.
- Store minimal local sharing metadata only:
  - last sync/upload time
  - last uploaded snapshot hash
  - last upload status
- Do not persist remote shared snapshots offline for MVP; keep remote shared data session/in-memory only.
- Do not upload past-day edits in MVP. Later, support past-day updates only for days inside allowed intervals.

### Timezones and Timestamps

- Snapshot `day` is owner device local calendar day at sync time: `yyyy-MM-dd`.
- Store `timeZoneId` with each snapshot.
- Viewers can see the owner timezone.
- Timezone conversion is display-only in MVP; server queries remain owner-day based.
- Store exact server `updatedAt`; UI displays coarse relative time, e.g. “Updated 20 min ago.”
- `updatedAt`, `createdAt`, `acceptedAt`, grant event timestamps, and deletion timestamps are server-generated.
- Client may send local `day` and `timeZoneId`; server validates format/bounds.

### Convex Query/API Shape

- Public Convex functions return shaped DTOs, not raw database documents.
- Use one live sharing dashboard query for the Sharing screen:
  - relationships
  - display names
  - incoming/outgoing active booleans
  - scope
  - pending invite status
  - today’s allowed remote snapshots
- Convex queries return only other people’s snapshots; Swift merges the local user’s own current totals from SwiftData.
- Mutations return small statuses/IDs and rely on the live dashboard query/subscription to refresh.
- Live subscriptions are Sharing-screen scoped only; start on screen appearance and cancel when leaving.
- No global/app-wide remote snapshot subscription in MVP.

### Swift Service Shape

- Split services:
  - `SharingAuthService`: Keychain identity, Worker token exchange, Convex auth setup.
  - `SharingSyncService`: snapshot upload, sharing dashboard subscription, invites, sharing mutations.
- Wrap Keychain in a small `SharingIdentityStore` adapter/protocol.
- Use app-wide environment dependencies for auth/sync services.
- Sharing screen explicitly starts/stops live subscriptions.
- Automatic uploads trigger from a higher-level “daily totals changed” path after local save succeeds, not directly from SwiftData persistence internals.

### User-Facing Copy

- Include concise sharing disclaimer: “Shared totals are best-effort and may be delayed. They are not medical advice.”
- Expired/revoked/invalid invites show neutral “This invite is unavailable.”
- Deleting sharing profile copy must explain:
  - local food/log data remains
  - cloud sharing profile/data/relationships are permanently removed
  - enabling sharing later starts with a new identity and previous shared cloud data will not return

## Threat / Privacy Checklist

- [x] Public Convex functions never trust caller-supplied `profileId`.
- [x] All caller identity derives from `ctx.auth`.
- [x] Worker signing private key is only in Worker secrets.
- [x] Convex verifies JWTs through the `macros-auth` JWKS endpoint.
- [x] JWT includes `iss`, `aud`, `sub = profileKey`, `iat`, `exp`, and `kid`.
- [x] Dev audience is explicit, e.g. `macros-convex-dev`.
- [x] Invite tokens are opaque, high entropy, single-use, expiring, and server-side stored only as hashes.
- [x] Invalid invite paths reveal no inviter/name/status metadata.
- [x] Display names are relationship-scoped private data.
- [x] Snapshot queries enforce relationship and grant interval visibility server-side.
- [x] Disabled gaps and pre-share days are never returned.
- [x] Same-day disable hides current day until re-enabled.
- [x] Future history retains days only if sharing was active through owner-local day end.
- [x] Deleting sharing profile never deletes local SwiftData user data.
- [x] No remote shared snapshots are durably cached locally in MVP.
- [x] Snapshot payloads are bounded and validated.
- [x] Auth endpoints do not enable broad browser CORS.
- [x] Logs never include profile secrets, raw invite tokens, JWTs, or sensitive args.

## Milestones and Tasks

### Milestone 1 — Backend/Auth Contract

- [x] Create `convex-backend/` package.
- [x] Install current Convex AI guidance for the backend package.
- [x] Define Convex schema for profiles, invites, relationships, grant intervals, and daily snapshots.
- [x] Configure Convex auth for Worker-issued JWTs in dev.
- [x] Add protected Convex bootstrap endpoint/action for Worker profile registration/verification.
- [x] Implement profile lookup helper from `ctx.auth.subject`.
- [x] Implement invite creation/revocation/acceptance.
- [x] Implement relationship canonicalization and duplicate prevention.
- [x] Implement directional grant enable/disable and interval visibility helpers.
- [x] Implement `upsertMyDailySnapshot`.
- [x] Implement live sharing dashboard query returning shaped DTOs.
- [x] Implement delete sharing profile cloud-data deletion.
- [x] Add TypeScript tests for interval visibility, invites, profile/auth mapping, snapshot bounds, and deletion semantics.
- [x] Add Worker `worker/auth/` package named `macros-auth`.
- [x] Implement Worker token exchange/register endpoint.
- [x] Implement Worker invite redirect route to Astro site without forwarding token.
- [x] Add Worker JWT signing and tests for claims/public-key verification.
- [x] Add Worker JWKS endpoint for Convex custom JWT verification.
- [x] Add basic abuse protections: one pending invite, expiry, single-use, snapshot bounds, simple cooldowns if practical.
- [x] Validate dev deployment/config if credentials/tooling are available.
- [x] Add automated TypeScript smoke script if feasible.

Milestone 1 smoke criteria:

- [x] Register/authenticate one profile through deployed Worker token exchange.
- [x] Register/authenticate two profiles.
- [x] A creates invite.
- [x] B accepts invite.
- [x] A → B visible.
- [x] B → A disabled until B enables reciprocal sharing.
- [x] Disabled intervals hide current-day data.
- [x] Re-enable restores allowed previous intervals and excludes disabled gaps.
- [x] Unauthorized calls cannot access snapshots.
- [x] Deleting sharing profile removes Convex sharing data only.

### Milestone 2 — Swift Service Integration

- [x] Confirm Swift feature paths during code exploration.
- [x] Add Convex Swift package dependency.
- [x] Add sharing deployment/auth config for dev.
- [x] Implement `SharingIdentityStore` Keychain adapter.
- [x] Add Keychain comment documenting device-local non-recoverable identity.
- [x] Implement `SharingAuthService`.
- [x] Implement `SharingSyncService`.
- [x] Wire app-wide environment dependencies.
- [x] Trigger automatic upload from higher-level daily totals changed path.
- [x] Implement manual “Sync now” reusing the automatic sync path.
- [x] Store minimal sync metadata only.
- [x] Keep remote shared data session/in-memory only.

### Milestone 3 — Sharing UI

- [x] First sharing setup flow: display name + auth bootstrap.
- [x] Create invite flow.
- [x] Revoke invite flow.
- [x] Accept invite flow.
- [ ] Accept invite flow with valid-invite name confirmation.
- [x] Sharing dashboard live subscription scoped to screen.
- [x] Show relationships sorted by display name.
- [x] Show remote today snapshots and neutral no-data states.
- [x] Show owner timezone and display-only local conversion affordance.
- [x] Show coarse last-updated time.
- [x] Add per-person outgoing toggle.
- [x] Add reciprocal sharing enable option.
- [x] Add global “Stop sharing my data.”
- [x] Add “Turn off sharing on this device.”
- [x] Add “Remove person.”
- [x] Add delete sharing profile destructive confirmation.
- [x] Add concise best-effort/not-medical-advice copy.

### Milestone 4 — Validation and Cleanup

- [x] Run backend tests.
- [x] Run Worker tests.
- [x] Add/run automated two-profile smoke script/checklist.
- [x] Run Swift format/quality checks.
- [x] Run Xcode build.
- [x] Review implementation against threat/privacy checklist.
- [x] Record quirks/findings in this tracker.
- [x] Fix invite acceptance so pasted full invite URLs work, not just raw tokens.
- [x] Persist the locally-created pending invite link while it remains pending so leaving the Sharing screen does not lose it.
- [x] Add smoke coverage for unauthorized snapshot access.
- [x] Improve invite UX beyond paste with deep link / universal link handoff into the app.

## Bugs / Quirks / Findings

- Convex custom JWT auth currently requires `jwks` to be a JWKS URL string plus `algorithm`; inline static JWKS config was rejected by local Convex validation. Implemented `/.well-known/jwks.json` on `macros-auth`.
- Real Convex dev deployment is `energized-pigeon-822`; `bunx convex dev --once --typecheck enable` validates functions against it.
- `macros-auth` is deployed at `https://macros-auth.jhonra121.workers.dev` and its JWKS endpoint is reachable.
- Worker token exchange succeeded with a dev smoke request using a MACROS-style user agent; Python's default urllib user agent hit Cloudflare 1010.
- Convex dashboard initially appeared empty after successful invite acceptance because Swift decoded backend `scope: { macros: true }` as a `String`, then replaced the subscription error with an empty dashboard. Removed the unused decoded `scope` field and now surface subscription errors.
- Added `convex-backend` `smoke:sharing` script for deployed dev smoke validation: two profiles register through Worker auth, invite/accept, one-way visibility, reciprocal enable, same-day disable/re-enable, and sharing-profile delete cleanup.
- Sharing invite acceptance now extracts the invite token from either a raw token or a full invite URL pasted into the field.
- Locally-created pending invite links are persisted in `UserDefaults` until expiry, revocation, replacement, or sharing-profile deletion so leaving the Sharing screen no longer loses the link.
- Sharing smoke now checks unauthenticated dashboard queries fail and unrelated authenticated profiles cannot see relationships or snapshots.
- Invite sharing now uses a `calmacrotracker://sharing/invite/{token}` app deep link. Opening that link routes directly to the Sharing screen with the invite field prefilled; the HTTPS Worker invite link remains shown as fallback copy.
- Invite app deep links now present a “Start Sharing?” confirmation dialog with Yes/No before accepting. Repeated invite links are routed by clearing and re-applying the pending open request so links still work while the app is already open.
- The invite confirmation uses a centered native SwiftUI alert instead of an anchored confirmation dialog.
- All Sharing flow confirmations now use centered native SwiftUI alerts. Revoke invite also now asks for confirmation before revoking. Visually checked Start Sharing, Revoke Invite, Turn Off Sharing, Remove Person, Stop Sharing My Data, and Delete Sharing Profile dialogs in the simulator.
- Threat/privacy review completed. Follow-up fixes added server-side invite hash format validation, constant-time bootstrap secret comparison, and Swift display-name truncation aligned to the backend 40-character limit.
- Post-implementation simplify cleanup accepted scoped findings: shared secure random-token generation, reused `HTTPJSONClient` for sharing auth responses, centralized post-log sharing sync callback wiring, and replaced untyped Convex helper contexts with generated types.
- Post-implementation defensive-code review removed the impossible post-insert relationship reload/error branch in invite acceptance; Swift and Worker review groups had no high-confidence redundant defensive branches.

## Milestone 2 Context

- App startup and dependency injection entry point: `cal-macro-tracker/cal_macro_trackerApp.swift`.
  - Existing app-wide dependencies use `@State` plus `.environment(...)` (`AppDayContext`, `AppEntitlements`, `PurchaseStore`).
  - Sharing services should follow the same pattern: initialize once in the app and inject via environment.
- Root navigation entry point: `cal-macro-tracker/App/AppRootView.swift`.
  - Settings currently lives behind the Dashboard toolbar route; Sharing UI can start as a Settings section or route from Settings.
  - `onOpenURL` currently maps only existing `AppOpenRequest` cases; invite deep links will require extending `AppOpenRequest` and routing.
- Daily totals derivation:
  - `cal-macro-tracker/App/LogEntryDaySnapshotReader.swift` uses `@Query(LogEntryQuery.descriptor(for: day))`.
  - `cal-macro-tracker/Data/Services/LogEntryDaySummary.swift` produces `LogEntryDaySnapshot`.
  - `cal-macro-tracker/Shared/NutritionSnapshot.swift` sums `calories`, `protein`, `fat`, and `carbs`.
  - `cal-macro-tracker/Shared/DailyMacroSnapshotLoader.swift` can already load today's totals from a `ModelContainer`; this is the best reusable path for sharing snapshot upload.
- Local log mutation hooks:
  - `cal-macro-tracker/Data/Services/LogEntryRepositoryOperations.swift` centralizes `logFood`, `saveEdits`, `delete`, and `logAgain`.
  - Each successful mutation currently calls `WidgetTimelineReloader.reloadMacroWidgets()`.
  - A clean next hook is a small post-save notifier/service called after successful repository persistence, not inside SwiftData internals.
- Settings integration:
  - `cal-macro-tracker/Features/Settings/SettingsScreen.swift` is a Form with sections for goals, food suggestions, purchase state, macro colors, and saved foods.
  - Sharing controls can be introduced as a new Settings section before saved foods, then expanded into a dedicated screen.
- App storage and metadata:
  - `cal-macro-tracker/App/AppStorageKeys.swift` currently contains simple preferences only.
  - Sharing sync metadata keys can live here if stored in `UserDefaults`, but profile credentials must use Keychain.
- Model container:
  - `cal-macro-tracker/Data/Services/AppModelContainerFactory.swift` delegates to `SharedModelContainerFactory`.
  - `SharedModelContainerFactory` uses the app group store and applies iOS file protection.
  - Sharing cloud delete must remain separate from SwiftData model containers and never delete local `FoodItem`/`LogEntry`.
- Xcode package state:
  - Added `https://github.com/get-convex/convex-swift` at `0.8.1` with app target product dependency `ConvexMobile`.
  - Convex Swift `0.8.1` does not include an x86_64 simulator binary slice; app target excludes x86_64 for iOS Simulator builds.
- Milestone 2 service foundation:
  - `Features/Sharing/SharingConfiguration.swift` stores dev Convex/Worker endpoints.
  - `Features/Sharing/SharingIdentityStore.swift` stores generated profile credentials in Keychain only.
  - `Features/Sharing/SharingAuthService.swift` implements a custom Convex `AuthProvider` backed by the Worker token endpoint.
  - `Features/Sharing/SharingSyncService.swift` uploads today's aggregate snapshot via `sharing:upsertMyDailySnapshot`.
  - Automatic upload is wired through `LogEntryRepository` post-save callback and only runs when device sharing is enabled.
  - Settings includes an MVP “Sharing on This Device” toggle and “Sync Shared Totals Now” action.
- Milestone 3 UI foundation:
  - Added `Features/Sharing/SharingScreen.swift` and linked it from Settings.
  - Sharing screen starts a Convex dashboard subscription only while visible and device sharing is enabled.
  - Screen supports device toggle, manual sync, create invite link, paste/accept invite token, remote today totals, neutral no-data state, owner timezone, coarse updated text, and per-person outgoing/reciprocal sharing toggle.
  - Invite acceptance currently uses a pasted raw token because app-link token extraction is not wired yet and the Worker browser redirect intentionally drops tokens.
- Milestone 3 destructive controls:
  - Convex now supports removing a person by closing both directional grants and tombstoning the relationship.
  - Swift service/UI now support revoking the current invite, stopping outgoing sharing, removing a person, and deleting the sharing profile after confirmation.
  - Deleting a sharing profile clears the local Keychain sharing identity, disables device sharing, and resets local sync state after the Convex delete mutation succeeds.
- Sharing setup cleanup:
  - Sharing screen now requires a display name before first auth bootstrap and can save display-name changes through `sharing:updateDisplayName`.
  - Turning off sharing on the device now closes outgoing grants before disabling local sharing.

## Open Questions / Blockers

- Remaining optional implementation order: native universal-link setup if a production domain is chosen, then valid-invite name confirmation polish.
- Optional polish: valid-invite name confirmation means the recipient would see a confirmation screen like “Accept invite from Juan?” after the app verifies the invite token but before creating the relationship. This is intentionally separate from the current MVP because invalid/expired invite responses must stay neutral, and adding preview metadata requires a new privacy-safe backend endpoint that reveals inviter name only for a valid pending invite.

## Validation Notes

- `convex-backend`: `bun run check` passed.
- `worker/auth`: `bun run check` passed.
- `convex-backend`: `bunx convex dev --once --typecheck enable` passed against dev deployment `energized-pigeon-822`.
- `worker/auth`: deployed to `https://macros-auth.jhonra121.workers.dev`; token exchange smoke passed with curl and MACROS-style user agent.
- Swift: `make quality-format-check` passed.
- Swift: `xcodebuild -project "cal-macro-tracker.xcodeproj" -scheme "cal-macro-tracker" -configuration Debug -destination 'generic/platform=iOS Simulator' build` passed after excluding x86_64 simulator for the app target.
- Swift Milestone 3 UI foundation: `make quality-format-check` passed.
- Swift Milestone 3 UI foundation: `xcodebuild -project "cal-macro-tracker.xcodeproj" -scheme "cal-macro-tracker" -configuration Debug -destination 'generic/platform=iOS Simulator' build` passed.
- Sharing destructive controls: `bun run --cwd "convex-backend" check` passed.
- Sharing destructive controls: `cd "convex-backend" && bunx convex dev --once --typecheck enable` passed.
- Sharing destructive controls: `make quality-format-check` passed.
- Sharing destructive controls: `xcodebuild -project "cal-macro-tracker.xcodeproj" -scheme "cal-macro-tracker" -configuration Debug -destination 'generic/platform=iOS Simulator' build` passed.
- Sharing setup cleanup: `bun run --cwd "convex-backend" check` passed.
- Sharing setup cleanup: `bun run --cwd "worker/auth" check` passed.
- Sharing setup cleanup: `cd "convex-backend" && bunx convex dev --once --typecheck enable` passed.
- Sharing setup cleanup: `make quality-format-check` passed.
- Sharing setup cleanup: `xcodebuild -project "cal-macro-tracker.xcodeproj" -scheme "cal-macro-tracker" -configuration Debug -destination 'generic/platform=iOS Simulator' build` passed.
- Sharing dashboard decode fix: `make quality-format-check` passed.
- Sharing dashboard decode fix: iOS Simulator build passed through XcodeBuildMCP, then live simulator UI showed Juan's shared totals and updated when food was added on the owner device.
- Sharing smoke/URL cleanup: `bun run --cwd "convex-backend" check` passed.
- Sharing smoke/URL cleanup: `bun run --cwd "convex-backend" smoke:sharing` passed against dev deployment.
- Sharing smoke/URL cleanup: `bun run --cwd "worker/auth" check` passed.
- Sharing smoke/URL cleanup: `cd "convex-backend" && bunx convex dev --once --typecheck enable` passed.
- Sharing smoke/URL cleanup: `make quality-format-check` passed.
- Sharing smoke/URL cleanup: XcodeBuildMCP iOS Simulator build passed.
- Sharing deep-link/unauthorized smoke: `bun run --cwd "convex-backend" check` passed.
- Sharing deep-link/unauthorized smoke: `bun run --cwd "convex-backend" smoke:sharing` passed against dev deployment.
- Sharing deep-link/unauthorized smoke: `bun run --cwd "worker/auth" check` passed.
- Sharing deep-link/unauthorized smoke: `cd "convex-backend" && bunx convex dev --once --typecheck enable` passed.
- Sharing deep-link/unauthorized smoke: `make quality-format-check` passed.
- Sharing deep-link/unauthorized smoke: XcodeBuildMCP iOS Simulator build passed.
- Sharing invite confirmation dialog: `make quality-format-check` passed.
- Sharing invite confirmation dialog: `bun run --cwd "convex-backend" check` passed.
- Sharing invite confirmation dialog: XcodeBuildMCP iOS Simulator build passed.
- Sharing invite confirmation dialog: `xcrun simctl openurl booted 'calmacrotracker://sharing/invite/testInviteTokenForDialog'` opened the app and showed the “Start Sharing?” confirmation dialog.
- Sharing centered invite alert: `make quality-format-check` passed.
- Sharing centered invite alert: `bun run --cwd "convex-backend" check` passed.
- Sharing centered invite alert: XcodeBuildMCP iOS Simulator build passed.
- Sharing dialog audit: visually verified centered native alerts for invite acceptance and all destructive sharing actions in the iOS simulator.
- Sharing dialog audit: `make quality-format-check` passed.
- Sharing dialog audit: XcodeBuildMCP iOS Simulator build passed.
- Threat/privacy checklist review: verified caller identity, JWT/JWKS/audience, invite privacy, relationship-scoped names, grant-interval visibility, local-data separation, no broad CORS, and sensitive logging behavior.
- Threat/privacy checklist review: `bun run --cwd "convex-backend" check` passed.
- Threat/privacy checklist review: `bun run --cwd "convex-backend" smoke:sharing` passed against dev deployment.
- Threat/privacy checklist review: `cd "convex-backend" && bunx convex dev --once --typecheck enable` passed.
- Threat/privacy checklist review: `bun run --cwd "worker/auth" check` passed.
- Threat/privacy checklist review: `make quality-format-check` passed.
- Threat/privacy checklist review: XcodeBuildMCP iOS Simulator build passed.
- Post-implementation cleanup: simplify review, defensive-code review, and `changes-log.md` update completed.

## 2026-05-06 Rebuild QA Pass

- Rebuilt and relaunched the iPhone 17 Pro simulator app with XcodeBuildMCP.
- Verified sharing setup from Settings: disabled state, Enable Sharing, enabled controls, Create Invite Link, fallback URL, expiry copy, and Revoke Invite confirmation.
- Verified app invite deep links on the target simulator open the system “Open in MACROS?” handoff and then show the centered “Start Sharing?” confirmation dialog.
- Accepted two temporary Convex-backed QA invites. The Sharing screen showed each person, incoming status, timezone/update copy, and aggregate-only daily snapshot values without food/log details.
- Verified destructive dialogs are centered native alerts for Revoke Invite, Remove Person, Stop Sharing My Data, and Delete Sharing Profile.
- Finding fixed during QA: repeated/open-app sharing routes now carry a request id so a new invite deep link rebuilds `SharingScreen` with the latest invite input instead of reusing stale navigation state.
- Simulator note: use the explicit simulator UUID with `xcrun simctl openurl`; `booted` targeted a different booted simulator in this session.
