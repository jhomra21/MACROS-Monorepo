# Sharing v2: per-person food sharing, Pro rule, Sharing redesign, cleanup

Status: draft for owner approval. Sources: `build/sharing-audit/REPORT.md` (Mac camera-zoom worktree), `build/convex-research/REPORT.md` (Windows), owner answers on 2026-11-01.

## Owner decisions
1. New connections default to **macros only**. Foods are turned on per person by the sender.
2. Each shared food shows its **name, amount (quantity + serving), calories, protein, carbs, and fat**. No log time, notes, photos, or brand IDs.
3. **Pro rule:** a connection is active only while **at least one of the two people has Pro**. Inside an active connection, both people may share macros or foods, whether or not they have Pro themselves. Creating an invite needs Pro (as today).
4. If neither person has Pro, the connection **pauses both ways**. The people stay connected, and sharing resumes when either one has Pro again.
5. The server enforces Pro from **Apple's signed purchase records**, not from what the app claims.
6. Viewers see **today only**, for macros and foods, as they do now.

## Current state (verified)
- Grants are directional rows in `shareGrantIntervals` (from to) with `scope: { macros: boolean }` (`schema.ts:58-70`). Acceptance creates owner to accepter only (`sharing.ts:140-179`).
- `dailySnapshots` holds one totals row per owner/day. No food data leaves the device today.
- The app already uses ConvexMobile 0.8.1 with a live `subscribe` for `sharing:sharingDashboard` (`SharingRemoteClient.swift:60-70`). Uploads are event-driven and deduplicated by hash (`SharingSyncService.swift:109-185`).
- Pro is checked only in the app. Convex has no entitlement data, and `createInvite` does not check Pro.
- The UI is split in two:
  - The swipe-left Sharing page lists people. The per-person toggle and Remove are hidden inside an expanding card.
  - Settings > Sharing is a stack of buttons with no people list: name, a manual "Sync Shared Totals Now", invite, accept, and three red actions.
- Convex gaps:
  - The dashboard does about 4 reads per person and collects the full grant history.
  - Profile deletion runs in one unbounded mutation.
  - There are no return validators.
  - HTTP bootstrap coerces its body.
  - Every quota counter for a profile and day is kept on one document.
- Ten copy locations say foods are not shared (audit section 9).

## Design

### Backend (Convex)
**Schema (additive, safe for build 23):**
- `shareGrantIntervals.scope` becomes `{ macros: boolean, foods: v.optional(v.boolean()) }`. If `foods` is missing, it means false.
- New table `sharedFoodEntries`:
  - Fields: `ownerProfileId`, `day`, `localEntryId`, `sortIndex`, `name` (max 80 characters), `quantityText` (max 40), `calories`, `protein`, `carbs`, `fat`, and `updatedAt`.
  - Indexes: `by_owner_day_sort ["ownerProfileId","day","sortIndex"]` and `by_owner_local ["ownerProfileId","localEntryId"]`.
  - One row per food, never an array.
  - Cap: 100 rows per owner per day.
- New table `entitlements`, holding `profileId`, `productId`, `originalTransactionId`, `expiresAt` (optional; lifetime has none), `revokedAt` (optional), `environment`, and `verifiedAt`. Index `by_profile`.
- `shareGrantIntervals`: add the index `by_from_to_ended ["fromProfileId","toProfileId","endedAt"]`, so the active grant is read with `eq("endedAt", undefined)` and no history scan.

**Pro verification:**
- A Convex Node action `entitlements:submitPurchase({ signedTransaction })` takes StoreKit 2 `jwsRepresentation` strings from the app.
- It verifies each one with Apple's official `@apple/app-store-server-library` `SignedDataVerifier`. The checks:
  - offline, against Apple's root certificates (stored in the repo);
  - bundle ID `juan-test.cal-macro-tracker`;
  - app Apple ID 6767565938;
  - environment Production or Sandbox, chosen by the transaction's `environment` claim, with Xcode and StoreKit-test transactions rejected.
- On success, an internal mutation upserts the profile's entitlement. Only `macros.pro.monthly`, `macros.pro.yearly`, and `macros.pro.lifetime` count. `fullunlock001` does not.
- `hasPro(profileId, now)` is true when there is an unrevoked lifetime entitlement, or an unrevoked subscription whose `expiresAt` is later than now.
- Refund and expiry accuracy: add a `POST /appstore/notifications` HTTP action for App Store Server Notifications V2. It verifies the signed payload the same way, then updates `expiresAt` or `revokedAt`. The owner sets this URL in App Store Connect (one field). Until then, expiry still works from the signed `expiresDate`, and renewals arrive when the app re-submits on launch.
- `connectionActive(a, b, now) = hasPro(a) || hasPro(b)`. This is enforced in `createInvite` (the creator needs Pro), in the dashboard query, and in the person-day query. Writes are allowed while a connection is paused; reads return `paused: true` and no data.
- Rollout switch: Convex env `SHARING_REQUIRE_PRO`. While it is off (the default), every existing connection counts as active, so build 23 keeps working. Turn it on after the update has shipped and been out long enough for Pro users to submit their purchases.

**Write path.** One mutation, `syncMyDay({ snapshot, foods? })`, replaces `upsertMyDailySnapshot` (the old function stays as a thin wrapper for build 23):
- It upserts the totals row.
- If the owner has at least one active foods grant, it diffs `foods` by `localEntryId`: insert, patch, delete. Unchanged rows are not written.
- If no foods grant is active, it deletes the owner's food rows for that day and ignores `foods` (data minimization).
- Foods from previous days are deleted by a daily cron in bounded batches, since foods are today-only.
- It counts against the existing snapshot quota (200 per day).

**Read path.**
- `sharingDashboard` (list; must stay compatible with build 23):
  - It reads both relationship indexes, then for each person the active inbound and outbound grant through `by_from_to_ended`, plus the snapshot.
  - It adds `foodsShared`, `connectionPaused`, and `outgoingScope` fields.
  - It never returns food rows. Old clients ignore the new keys.
- New `personDay({ otherProfileId, day })` (live, subscribed only while a person screen is open):
  - It checks the relationship, that the connection is active, and an inbound grant with `macros` visible for that day.
  - It returns totals.
  - Only if the current inbound grant has `foods: true`, it also returns `sharedFoodEntries` for that owner and day (`take(100)`, ordered by `sortIndex`).
  - It returns a compact DTO with return validators.
- `setOutgoingScope({ otherProfileId, scope: "off" | "macros" | "macrosAndFoods" })` replaces the boolean toggle (the old function stays as a wrapper). Switching foods off takes effect immediately, by ending the current interval and opening a new one with the new scope; today's macro visibility follows the existing interval rules.

**Hardening (from the Convex research):**
- Return validators on every public function.
- Profile deletion becomes a scheduled, batched internal job covering invites, snapshots, food rows, grants, relationships, quotas, and entitlements. The public mutation tombstones the profile right away.
- The HTTP bootstrap rejects invalid bodies with a 400.
- Quota counters: keep them on one document, but measure with `bunx convex insights` before splitting.

**Tests:**
- Extend `convex/_qa/sharing.integration.ts` (convex-test) to cover:
  - foods off by default;
  - foods visible only with a foods grant;
  - foods hidden immediately after switching off;
  - pause when neither person has Pro;
  - an invite rejected without Pro;
  - the build 23 wrappers;
  - deletion batches;
  - the cap of 100 foods;
  - isolation between users and between days;
  - JWS verification with invalid, Xcode, wrong-bundle, and expired transactions.
- Use signed test fixtures. Mock the verifier in convex-test, and unit-test the verifier wrapper separately with Apple's sample-style fixtures.

### iOS
**Sync (`Features/Sharing`):**
- `SharingDailySnapshotPayload` gains an optional `foods: [SharedFoodPayload]`, built from today's `LogEntry` rows with an explicit whitelist: name, quantity text, kcal, protein, carbs, fat, a stable local ID, and sort index.
- The hash covers foods too, so editing a food re-syncs once.
- Foods are sent only when the dashboard says I share foods with at least one person.
- Purchase submission: on launch, after any purchase or restore, and when `Transaction.updates` fires, send the `jwsRepresentation` of current Pro entitlements to `entitlements:submitPurchase` (deduplicated by transaction ID and expiry). This happens only when sharing is enabled.
- Update ConvexMobile from 0.8.1 to 0.8.2.
- Split `SharingSyncService` (437 lines) into:
  - `SharingUploadCoordinator`: drain, hash, and snapshot+foods;
  - `SharingDashboardFeed`: subscriptions;
  - `SharingAccountActions`: enable, name, invites, delete, purchase submission.
  Behavior and the existing `SharingReliabilityTests` stay the same.

**UI redesign:**
- **People (the swipe-left page, the hub):**
  - One row per person: ring, name, today's kcal and macros, and a status line ("Sees your macros", "Sees your macros and foods", "You don't share with Alex", or "Paused, needs MACROS Pro").
  - Toolbar: "+" opens Invite (Pro-gated), and the gear opens Sharing Settings.
  - Empty state: one clear call to invite or accept.
  - Expanding cards are removed.
- **Person screen (push from a row):**
  - Their day, with rings, macro columns, and their food list when they share foods with me (name, amount, kcal, P/C/F per row).
  - Section "What {name} sees from you", a segmented control: Nothing / Macros / Macros + Foods.
  - Remove {name} (with confirmation).
  - When paused, a short banner explains why, with an upgrade button for whoever lacks Pro.
- **Sharing Settings (gear, also from Settings):**
  - Sharing on/off toggle.
  - Display name.
  - Invite section: create, share link, expiry, revoke (Pro).
  - Accept invite (paste field; links open it directly).
  - Footer with what is shared.
  - "Stop Sharing With Everyone" and "Delete Sharing Profile" grouped at the bottom.
  - Removed: "Sync Shared Totals Now" (syncing is automatic) and the separate "Turn Off Sharing on This Device" button (now the toggle).
- Use existing components: `MacroRingSetView`, `MacroSummaryColumnView`, and the app's list rows. Native SwiftUI, no new glass. Support Dynamic Type sizes up to AX, VoiceOver labels, and Reduce Motion.

### Copy and metadata
- Update all ten locations listed in audit section 9, including the app disclosure, the website (`site.ts` and the privacy page), and the App Store docs.
- The App Store privacy label gets a new entry, done in App Store Connect by me after approval: food names and nutrition the user chooses to share are "User Content / Other" (or "Health & Fitness"), linked to the user, used for App Functionality, and not used for tracking.
- Review notes get a sentence on per-person food sharing.

### Convex tooling for agents
- Add a user-scoped Convex MCP server for Droid with read-only tools only (`status`, `tables`, `functionSpec`, `insights`), no production PII flags.
- Run `bunx convex ai-files status` and update the generated guidelines only if that path does not call `npx skills`.
- Record `bunx convex insights --details` for prod before and after the change.

## Phases, owners, and checks
1. **Backend.** Sol 6.1 medium, because it is high-risk (payments and auth). Schema, entitlements, Node verifier, notifications endpoint, `syncMyDay`, `personDay`, `setOutgoingScope`, wrappers, batched deletion, cron, validators. Checks: `bun run check`, `bun run test:integration`, and a deploy to the **dev** deployment followed by `bun run smoke:sharing` against dev.
2. **iOS sync.** Luna high. Payload with foods, purchase submission, ConvexMobile 0.8.2, the service split. Checks: `SharingReliabilityTests`, the full non-StoreKit suite (198 or more tests), and new tests for the payload whitelist and hash.
3. **iOS UI.** Sonnet 5.5 medium. The People hub, the Person screen, and Sharing Settings. Checks: screenshots in light, dark, and AX on two simulators, sharing between two existing simulators against the dev backend, and owner screenshots.
4. **Copy, web, and docs.** Luna high. The ten locations, a website deploy, and the changes log.
5. **Review.** Sol 6.1 medium on the full diff, then fixes. An Opus final review if the owner wants one.
6. **Release:**
   - Convex prod deploy (additive schema; build 23 unaffected while `SHARING_REQUIRE_PRO` is off).
   - TestFlight build 24.
   - The owner tests with two devices.
   - Update the App Store privacy label.
   - Submit as version 1.1 (or 1.0.1) after 1.0 is approved.
   - Turn on `SHARING_REQUIRE_PRO` later.

## Risks
- **Pro verification in a Convex Node action.** Confirm the library works in the Convex Node runtime. If it does not, verify in the Cloudflare Worker instead (same checks).
- **Timing.** If 1.0 is approved and released before this ships, build 23 users keep working because enforcement is off until the switch is turned on.
- **Food names may be personal.** The disclosure must say exactly what is shared and with whom, and the default stays macros-only.

## Adopted from plan review (2026-11-01). These changes override the sections above.
1. `personDay({ otherProfileId, day, ownerToday })` takes the same current-day check as `sharingDashboard`. It requires `day === ownerToday`, calls `assertCurrentDayKey`, and rejects a deleted other profile or a removed relationship. A test covers asking for a past day.
2. `entitlements` gets an index `by_original_transaction`.
   - A notification applies only when its `signedDate` is newer than the stored `verifiedAt`.
   - A transaction that verifies but matches no row returns 200.
   - Production and Sandbox each need a notification URL in App Store Connect.
3. There are two `SignedDataVerifier`s, Production (with app ID 6767565938) and Sandbox.
   - The `environment` field is read from the unverified payload only to choose the verifier. Every other environment is rejected before verification.
   - Online checks are off, which means no revocation checking; notifications cover that.
   - The Apple Root CA G3 DER file is downloaded from apple.com/certificateauthority and committed.
   - `"use node"` files export only actions, so mutations live in a separate file. If bundling fails, add `node.externalPackages`.
   - Verification is also tested on the dev deployment with a real Sandbox transaction from a device build.
4. A single `originalTransactionId` can grant Pro to at most 5 profiles. A test covers going over the cap.
5. Billing grace period counts as Pro, matching the app (`AppEntitlements.swift:82-85`).
   - On `DID_FAIL_TO_RENEW` with the `GRACE_PERIOD` subtype, `expiresAt` becomes `gracePeriodExpiresDate`.
   - The app also submits the renewal-info JWS.
6. A grant counts as active for foods only when it is open AND the connection is active (someone has Pro). Otherwise `syncMyDay` deletes that day's food rows. Paused connections store no foods.
7. Switching foods on or off edits `scope.foods` on the open grant in place. A grant is closed and reopened only when macros changes.
8. The build 23 wire contracts are frozen, and a test asserts each one:
   - `acceptInvite` returns `[String: String]`
   - `createInvite` returns `{inviteId, expiresAt}`
   - `upsertMyDailySnapshot` returns `{snapshotId}`
   - each dashboard person keeps `scope.macros`
   - new keys are only added, never changed
9. Turning on `SHARING_REQUIRE_PRO` pauses every connection whose only Pro user is still on build 23, and those users can't create invites, until they update. The flag lives in a one-row `settings` table, not an env var, so live queries react to it.
10. Old food rows are deleted on the owner's first `syncMyDay` of a new day. A weekly cron sweeps whatever is left.
11. After `setOutgoingScope` turns foods on, the app syncs right away, so the viewer's first load already has foods.
12. Phase 3 (UI) uses Luna high and moves to Sonnet only if needed.
13. The Convex MCP server and AI-files setup are a separate small task (step 0), done before Phase 1. They are not part of the release review.
