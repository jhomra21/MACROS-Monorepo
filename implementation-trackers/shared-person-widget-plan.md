# Shared-person Home Screen and Lock Screen widgets

Status: implementation plan only, 2026-11-01. No app, backend, entitlement, or project changes are included.

## 1. Scope and evidence baseline

Implement after `fix/sharing-ui-ring-polish` merges. This plan was researched on Mac from `origin/main` **9761515** in the isolated `shared-widget-plan` worktree. All source references below are relative to this repository at that commit; recheck line numbers and merged interfaces before implementation.

Fixed owner decisions:

- The extension fetches server data itself on its WidgetKit timeline, requesting an update about every 15–30 minutes. No push updates.
- Add separate shared-person widgets, leaving the existing own-day widgets available. Home Screen: `.systemSmall`, `.systemMedium`. Lock Screen: `.accessoryInline`, `.accessoryCircular`, `.accessoryRectangular`. No additional families.
- Reuse existing widget layouts and `MacroRingSetView`; add the person's name. Use the native Home Screen Smart Stack to switch between own-day and shared-person widgets, not an in-widget toggle. Lock Screen families remain separate placements, not a custom stack.
- Edit Widget has one Person picker: **Default** plus all current connected people. A device-local in-app default controls only widgets configured as Default. Explicit selections never silently change people.
- The viewer needs Pro, using the existing App Group access record, independently of the sharing connection rule.
- Today only, macros and actual shared goals only. No foods. Missing goals mean empty rings, never the viewer's goals or fabricated defaults. Preserve paused, not-shared, and removed semantics. Preserve the server's ≥1 Pro-per-connection rollout switch, currently off per the owner.

### Verified source map

| Area | Real code and relevant lines |
| --- | --- |
| Original sharing requirements | `implementation-trackers/sharing-v2-plan.md:5-11,43-53,62-72,157-183`. It is a historical plan, not a substitute for the implementation. For example, the implemented food storage is `sharedFoodDays`, not the originally proposed row-per-food table. |
| Device identity and authentication | `cal-macro-tracker/Features/Sharing/SharingAuthService.swift:4-20,47-98,111-156`; `SharingSecureStorage.swift:11-53`; `SharingIdentityStore.swift:3-37` in the same directory. |
| App's remote reads | `cal-macro-tracker/Features/Sharing/SharingRemoteClient.swift:75-96`; `SharingDashboardFeed.swift:11-16`; `SharingConfiguration.swift:3-8`. |
| Feed ownership and lifecycle | `cal-macro-tracker/Features/Sharing/SharingSyncService.swift:221-295,310-320,410-480`; device enabled preference is currently standard defaults, not App Group storage (`SharingLocalStateStore.swift:7-18`). |
| Person and goals models | `cal-macro-tracker/Features/Sharing/SharingSyncModels.swift:16-28,99-183`; person display/visibility behavior in `SharingPersonScreen.swift:19-25,28-87,158-196,221-227`. |
| Server authorization/read | `convex-backend/convex/sharing.ts:305-418`; profile check in `authHelpers.ts:3-19`; today tolerance in `sharingModel.ts:70-79`; grant visibility in `sharingModel.ts:95-120`. |
| Server Pro rule | `convex-backend/convex/proModel.ts:6-21`; reactive `settings.sharingRequirePro` and derived `proStatus` in `schema.ts:6,23-25`; expiry recomputation in `proStatus.ts:34-65`. This is not an environment flag in the current code. |
| Server DTO/goals | `convex-backend/convex/sharingValidators.ts:21-30,41-53`; `sharing.ts:422-449`; `schema.ts:54-68,83-109`. |
| Widget declarations/layouts | `cal-macro-tracker/CalMacroWidget/DailyMacroWidget.swift:11-19,59-89,111-148,167-241,271-318`; `DailyMacroAccessoryWidget.swift:5-24,27-88`; bundle in `CalMacroWidgetBundle.swift:4-10`. |
| Shared visual primitives | `cal-macro-tracker/Shared/MacroRingSetView.swift:9-39,132-175,192-195`; `MacroGoalsSnapshot.swift:9-15`. Existing accessory circular uses a calorie Gauge, not the three-ring view (`DailyMacroAccessoryWidget.swift:47-55`). Preserve that layout too. |
| Shared storage/Pro | `cal-macro-tracker/Shared/WidgetAppearanceStorage.swift:33-63,84-115`; `Features/Purchases/AppEntitlements.swift:98-109`; `Shared/SharedAppConfiguration.swift:3-8`; `Data/Services/WidgetTimelineReloader.swift:3-7`. |
| Settings placement | `cal-macro-tracker/Features/Sharing/SharingScreen.swift:25-48,103-119,181-195`; the other candidate is appearance-only `Features/Settings/WidgetBackgroundSettingsSection.swift:15-73`. |
| Current deep links | `cal-macro-tracker/Shared/AppOpenRequest.swift:12-55`; `App/AppRootView.swift:33-39,72-96,202-217`; `cal_macro_trackerApp.swift:165-169`; scheme registration `Info-iOS.plist:23-35`. |
| Signing and source membership | App entitlements `cal-macro-tracker/cal-macro-tracker.entitlements:5-10`; extension entitlements `cal-macro-tracker/CalMacroWidget/CalMacroWidget.entitlements:5-8`; `cal-macro-tracker.xcodeproj/project.pbxproj:53-99,113-125,178-209,475-505,518-546,567-601,609-641`. |
| Existing authorization tests | `convex-backend/convex/_qa/sharing.integration.ts:181-230`: pause, inbound grant absent/ended, strangers, removal, deletion, and wrong day. Live smoke foundation: `convex-backend/scripts/sharingSmoke.ts:27-129`. |
| Privacy declarations | `docs/app-store/privacy-labels.md:7-25`; `cal-macro-tracker/CalMacroWidget/PrivacyInfo.xcprivacy:5-28`; previous widget behavior/design decisions in `changes-log.md:143-148,209,243-258`. |

Read `AGENTS.md`, `docs/development/swift.md`, the sharing-v2 plan, the `apple-widget-design-review` skill, and the generated Convex guidance. The skill's local-data fallback remains important, but the owner's explicit extension-fetch decision governs this feature.

Live-tool limitation: the Convex status tool returned **`No CONVEX_DEPLOYMENT set, run npx convex dev to configure a Convex project`** for this new worktree. No configuration, deploy, or live database write was attempted. The endpoint is verified from `SharingConfiguration.swift`; the flag's current off state is owner-provided, not independently queried here.

## 2. Authentication: reuse Keychain, not a second credential system

### How it works today

1. `SharingIdentityStore.loadOrCreate()` creates random `profileKey` and `profileSecret` values only if the device has no identity. They are Codable data in a generic-password Keychain item, service `juan-test.cal-macro-tracker.sharing`, account `profile-identity`.
2. `SharingKeychainItem` currently has **no `kSecAttrAccessGroup`**; it uses the app's private default group. New items use `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. Pending invite secrets use a separate private account, `pending-invite`.
3. `SharingAuthProvider` POSTs `{profileKey, profileSecret, displayName}` to `https://macros-auth.jhonra121.workers.dev/v1/token`; both `login` and `loginFromCache` perform that exchange. `SharingAuthService` owns `ConvexClientWithAuth`, coalesces authentication, and invalidates stale responses during identity cleanup. This is device-local pseudonymous identity, not an Apple/account login.
4. The Worker hashes `profileKey.profileSecret`, calls protected Convex bootstrap, and signs an RS256 JWT with issuer, audience, subject, issued-at, and expiry (`worker/auth/src/index.ts:35-86,106-143`; `crypto.ts:3,22-32,59-60`). The JWT lasts **24 hours**; `expiresAt` is **epoch milliseconds**, while JWT `exp` is seconds. There is no refresh-token grant.
5. `convex-backend/convex/auth.config.ts:1-9` validates issuer/JWKS and audience `macros-convex-dev`. `requireCurrentProfile` uses the JWT subject to find an existing, nondeleted profile. The extension must never contain Worker bootstrap/admin/signing secrets.

### Chosen approach: the existing App Group as a Keychain access group

Apple explicitly allows iOS App Group identifiers to be used as Keychain access groups [A5]. Both targets already have the same group. Use **`kSecAttrAccessGroup = "group.juan-test.cal-macro-tracker"`** for a narrowly selected shared identity item and a separate short-lived JWT cache item. These are Keychain records, **not App Group files or UserDefaults**.

- Required entitlement, already present in **both** entitlement files: **`com.apple.security.application-groups`**, array containing **`group.juan-test.cal-macro-tracker`**.
- **No new `keychain-access-groups` entitlement is necessary for this choice.** Do not prefix the App Group string with a team ID. This also avoids changing the app's default Keychain group and accidentally sharing unrelated items.
- Alternative, not selected: enable Keychain Sharing on both targets with **`keychain-access-groups`** containing **`$(AppIdentifierPrefix)juan-test.cal-macro-tracker.sharing-widget`**. `AppIdentifierPrefix` includes its trailing dot; do not append another. Resolve the fully expanded value for runtime `kSecAttrAccessGroup` via a build-expanded nonsecret Info.plist setting, never leave `$(...)` in a runtime string. Keep each target's original private group first to preserve default writes. `DEVELOPMENT_TEAM` is currently `NK3K87K955`, but legacy App ID prefixes can differ from Team ID [A6], so do not hardcode that prefix.
- With the selected App Group approach, existing `CODE_SIGN_ENTITLEMENTS` paths and team settings stay as-is. Verify both signed products actually contain the App Group. Do not edit `application-identifier` (generated by signing), remove HealthKit from the app, or add new capabilities speculatively.

This is smaller than introducing a server-minted, scoped widget token: it reuses the current refresh exchange and identity lifecycle and needs no token table, issuance, revocation, new JWT provider, or Worker deployment. Trade-off: a widget process holding the identity could perform the same authorized operations as the app; read-only behavior is enforced by this client's implementation, **not a cryptographic scope**. This is a trusted first-party extension already entitled to the app's shared local data. Relationship/privacy authorization remains mandatory on every server read. A scoped read-only credential would reduce that authority, but is a separate hardening project, not a claim made by this plan.

### Migration and refresh contract

- Extract a small Foundation/Security-only credential store to `Shared/SharingWidgetCredentials.swift`. Extend `SharingKeychainItem` with an optional explicit access group; keep the invite store private. Share only the types needed by both targets, not `SharingAuthService` or ConvexMobile.
- Use service `juan-test.cal-macro-tracker.sharing`, account `profile-identity`, with the explicit App Group access group for all canonical identity reads/writes/deletes; use a distinct account such as `widget-session` for JWTs. Legacy migration must read the old item's attributes and delete only its specific private access group after verification, never issue an unscoped `SecItemDelete` that could remove both copies.
- The **app alone** migrates: load the explicitly identified legacy private identity, copy it to the group Keychain item, read back and compare, then remove the legacy copy. Preserve the same key/secret and server profile. If a shared record already exists, reuse it only if any remaining legacy copy agrees; conflicting identities leave records untouched, disable widget access, and report a setup error rather than selecting a different server profile. Keep sharing disabled for the extension until migration succeeds. Partial-copy/deletion failures must be retryable and must not generate a new profile.
- The extension only loads an existing identity. It **never** calls `loadOrCreate`, registers a new identity, changes the display name, or performs mutations. Refresh POST includes `profileKey` and `profileSecret`, **omitting `displayName`**. The Worker accepts an absent name for an existing profile (`index.ts:61,68`; `bootstrap.ts:19-35`); it refuses creation without one.
- Persist `{token, expiresAt, identity/session identifier}` in a separate shared Keychain item, using the same after-first-unlock/device-only accessibility. The app may publish successful JWTs there; the extension can refresh independently when none exists or expiry is within five minutes. Validate the response's profile key and finite expiry. Do not log bodies, headers, JWTs, secrets, or Keychain data.
- Use one bounded token exchange and one query per timeline, with at most **one** exchange-and-query retry for an expired/rejected JWT. Never retry all permission or server errors as authentication errors. Coalesce concurrent requests within a process; independent app/extension JWT writes are safe because JWTs do not rotate/revoke each other. Honor 429/Retry-After, then return a timeline, not a retry loop.
- An expired JWT is never sent. A Keychain-locked result before first unlock renders “Unlock to update,” not “signed out,” and never deletes identity. Missing identity with sharing enabled renders “Open MACROS to reconnect.”
- On device disable/profile deletion/identity replacement, publish a disabled state and new session generation **before** clearing widget data, clear the JWT cache, then reload both shared kinds. Profile deletion also removes shared and legacy identities through existing cleanup ownership. Device disable retains the app identity for re-enabling, as current behavior does, but the extension must stop reading.
- Check session generation, control revision, enabled state, Pro access, selected person, and day again after awaits and before accepting/writing a result or using an offline fallback. A late request must not repopulate data after disable/delete/default change or an app-observed permission loss. Re-enable only after migration/authentication has succeeded.
- The Worker currently turns bootstrap credential failures into a generic 500 (`index.ts:104,120-121`). Do not pretend it returns a specific “credentials revoked” status. Transport/500 failure shows a safe offline/error state; a typed unavailable-profile result from Convex invalidates cached content. No Worker error-contract rewrite is required here.

## 3. Fetch: compact authorized query over the documented HTTP API

### Existing behavior to preserve

`sharing:personDay({otherProfileId, day, ownerToday})` already authenticates the viewer, rejects self/deleted/missing people and removed/absent relationships, checks the ≥1 Pro connection rule, and checks an open **inbound** macros grant. A paused connection returns no data; no inbound permission returns `notShared`. Goals are already part of its optional snapshot DTO.

Do not call the dashboard to find one person's macros: it reads every relationship. Do not use `personDay` unchanged as the widget's permanent endpoint: a foods-enabled connection would unnecessarily download foods.

### Additive backend change

Add **`sharing:widgetPersonDay`** with the same three arguments and explicit return validators. Factor only the common profile/relationship/grant/day/snapshot authorization into a small `convex/personDayRead.ts` helper used by both queries. Keep the existing `personDay` return shape, errors, and food behavior compatible. Do not duplicate the security checks or read foods then strip them.

Proposed widget result:

- `visibility`: `shared | paused | notShared | unavailable`.
- `profileId`, `displayName`: returned only for an authorized, current relationship; unavailable returns null identity fields.
- `snapshot`: the existing whitelisted DTO, with goals and source `updatedAt`, or null. No foods, local entry IDs, profile secrets, raw DB documents, or grant history.
- Typed auth failures for this new query: `AUTH_REQUIRED`, `PROFILE_UNAVAILABLE`, using Convex application errors (`errorData.code`). Preserve old public callers' error contracts. Reuse a profile lookup helper rather than parsing `Error.message` text.
- Invalid arguments/day remain errors. Missing/deleted/unrelated/removed target returns the same generic `unavailable` response to avoid a profile-existence oracle.
- The public argument identifies the **target**, never the viewer. Derive the viewer from `ctx.auth`. Recheck relationship and inbound grant even if the target came from the local people picker.

**Pause and sharing permission are enforced server-side**, with the same `activeConnection`, `openGrantBetween`, and interval visibility rules as `personDay`. `settings.sharingRequirePro=false` bypasses only the connection Pro restriction, never authentication, relationships, grants, or today checks. Do not turn that flag on as part of this feature.

The **widget product gate** uses the viewer's existing local `WidgetProAccessRecord`, just like backgrounds. It is distinct from ≥1 Pro for a connection: a free viewer connected to a Pro sender may use Sharing in-app but cannot display shared-person widget data. Do not add an unconditional server viewer-Pro check that breaks the requested existing access-record behavior or local StoreKit testing. The local record is not an authorization boundary for private sharing data.

### Extension request, no Convex Swift client

Use a small Foundation `URLSession` client, not a WebSocket subscription or an SDK dependency. The widget target currently links no Convex product (`project.pbxproj:121-125,202-209`); leave it that way. App-facing sharing models currently import ConvexMobile, so extract a small SDK-free Codable widget DTO instead of compiling all of `SharingSyncModels.swift` into the extension.

Verified Convex request [C1]:

```http
POST https://energized-pigeon-822.convex.cloud/api/query
Authorization: Bearer <user JWT from Keychain>
Content-Type: application/json

{
  "path": "sharing:widgetPersonDay",
  "args": {
    "otherProfileId": "<selected Convex profiles document ID>",
    "day": "<yyyy-MM-dd in the viewer's local calendar>",
    "ownerToday": "<the same local yyyy-MM-dd>"
  },
  "format": "json"
}
```

This is the **`.convex.cloud` Functions API**, not a `.convex.site` custom HTTP route, and it needs no `http.ts` route. `path` and `args` are body fields. The documented example puts `format` in the body. Decode the envelope: `{"status":"success","value":...}` versus `{"status":"error","errorMessage":...,"errorData":...}`. HTTP success alone is not query success. Never use a deploy key (`Authorization: Convex ...`) in either target. Convex documents user Bearer auth [C1, C2].

Use an ephemeral URLSession (no persistent HTTP cache/cookies), bounded response size (for example 32 KiB), a short request deadline (for example 8 seconds, with a bounded total timeline operation), cancellation, and strict DTO decoding. Reject nonfinite/negative totals/goals and mismatched returned day before rendering; malformed data is an error, not zero nutrition. Inline async requests are supported while providing a timeline [A8]; completion is not guaranteed if the OS kills the extension. Use last-good fallback instead of adding background-session machinery for this tiny read unless measured E2E failures justify it. Apple also documents background URLSession as the more durable option [A8].

## 4. Person picker, default setting, and App Group records

### Setting placement

Add a **Shared Widgets** section to **Sharing Settings (`SharingScreen`)**, with a Pro-gated “Default person” picker and explanation: “Widgets set to Default follow this person. Choose a different person in Edit Widget to keep a widget fixed.”

Why here: people, enable/disable, and identity lifecycle already live in Sharing Settings. `WidgetBackgroundSettingsSection` only controls appearance; importing sharing lifecycle/people there would couple unrelated settings. Avoid duplicate controls. The default picker offers **None** plus current connected people; do not silently choose the first person. Add a short disclosure that names and nutrition may appear while the device is locked. Non-Pro users see a `ProLockedRow`, using a new `.sharedPersonWidget` PaidFeature/paywall context rather than mislabeled “Widget backgrounds.”

### Storage and publication

Add `Shared/SharedPersonWidgetStorage.swift` and SDK-free `Shared/SharedPersonWidgetModels.swift`:

- App-written people cache contains **only profile document IDs and display names** in its people array. Envelope: schema version, current session generation, timestamp, and whether the list is authoritative. No macros/goals/foods in this picker cache. Maximum 100 people, matching the dashboard bound.
- Store selection (`defaultProfileId`, nullable), enabled state, session generation, and a control revision in a small separate nonsecret control record. Change the revision on default changes and app-observed permission loss/removal, before purging caches; an in-flight result carrying the old revision is discarded. Session generation changes on disable/identity replacement. Start disabled/unknown if missing or unsupported.
- On every **successful** dashboard update at `SharingSyncService.receiveDashboard`, atomically replace the people list, including renames/removals. Observe in the service, not only while a view is mounted. A subscription error or a transient dashboard clear during day changes is **not** proof that all people were removed.
- On a confirmed removal, purge that person's macro cache and clear the default if it referred to them. Leave explicit widget intent identifiers alone; show unavailable instead of substituting another person. Known paused/not-shared statuses purge cached macros too. Do not place those statuses or macros into the IDs/names-only people array.
- Successful incoming snapshot/goal/status/name changes trigger shared-widget reloads, even when the people IDs/names cache did not change. Compare the relevant dashboard projection and coalesce each delivered update, not a reload for every field. No new polling.
- Setting changes write the control record before requesting reload. Pro changes and background/palette changes must also reach shared widgets.
- Do not fill a widget cache with the viewer's own SwiftData snapshot. Keep remote shared nutrition separate from the local persistent model store.

### AppIntent contract

Add extension-only `SharedPersonWidgetIntent.swift`:

- `SharedWidgetPersonEntity: AppEntity`, stable `String` ID, `typeDisplayRepresentation = "Person"`, display representation from the cached name, `defaultQuery = SharedWidgetPersonQuery()`.
- Synthetic ID **`"default"`**, displayed **“Default”**. It is not a profile ID and is never sent to Convex. Real entity IDs are the server profile IDs, never the name or array position.
- `SharedPersonWidgetIntent: WidgetConfigurationIntent`, title “Choose Shared Person”, one `@Parameter(title: "Person")` entity selection. Initialize new configurations to the synthetic Default entity and use entity-query `defaultResult()` to suggest it, **not the currently resolved default person** [A1–A4]. Represent an unresolved selection as optional/nil in the provider-facing configuration so it can render unavailable, not silently resolve a deleted explicit selection as Default; validate this resolution behavior in the prewritten runtime acceptance case.
- `suggestedEntities()` returns Default first plus the current cache, sorted by localized name with stable ID tie-breaks. Include connected people even if paused or not currently sharing inbound, so selections do not vanish when permissions change.
- `entities(for:)` maps Default plus still-available cached IDs, using a dictionary/Set rather than repeated scans. Apple says to omit unavailable entities [A4]; do not invent a “removed” entity or fall back to Default.
- The provider independently resolves the actual selection each time. Default resolves against `defaultProfileId` in the current control record; explicit IDs stay explicit. Treat a missing/unresolved parameter conservatively as “Choose a person,” not Default. Return unavailable for a previously selected ID missing from an authoritative people list. Still check the server for cached current IDs.
- No network requests or Keychain token exchanges inside `EntityQuery`. Missing cache yields only Default. The app must be opened to populate current options; opening a widget must not enable sharing automatically.
- Re-query the App Group for every provider/picker request; do not retain a stale singleton copy. App Intents resolution of a removed selection is system-managed, so validate on the target iOS runtime that it never rewrites it into another person.

## 5. Timeline and cache policy

Add `SharedPersonWidgetProvider: AppIntentTimelineProvider`, used by both new widget declarations. Apple specifies this provider/configuration combination and async methods [A1, A2].

1. Resolve Pro/access, enabled/session state, and selected person. Access `.unknown` is fail-closed with “Open MACROS to check Pro,” distinct from known denied. **Accessory providers must also read Pro**; the existing own-day accessory provider uses `includesAppearance: false`, which currently makes its Pro value unknown.
2. Fetch the selected person's current local day from the server. Valid data uses real goals; absent/incomplete goal sets render empty rings and omit “of 0” goal labels. Keep actual totals visible with missing goals. For consistency with `SharedDailySnapshot.macroGoalsSnapshot`, require all four goals for the existing grouped-goals presentation; zero goals give zero progress, never division by zero.
3. Request the next refresh at **30 minutes** on success (roughly 48 requests/day/instance), or the next local midnight, whichever comes first. On transient errors request 30 minutes, honoring a longer Retry-After. The owner allows 15–30 minutes; choose 30 to fit Apple's typical 40–70/day budget. This is a request, **not a guarantee**; Apple may delay it [A7]. No timers, sockets, app background fetch dependency, pushes, or self-reloading loops.
4. Include a future **blank/new-day** entry at local midnight even when the server fetch is scheduled earlier. For a nutrition entry, the midnight entry contains no yesterday macros and says “No macros shared today,” awaiting a new fetch; preserve existing Pro/disabled/permission status instead of replacing those states with a data placeholder. This prevents old values persisting solely because the OS delays reload. Use calendar day addition, not `+86400`; account for DST. Re-evaluate current day/time zone after a network await. Discard a response that crossed the day boundary.
5. Match existing app day semantics: viewer-local `CalendarDay` sent as both `day` and `ownerToday`. The server only validates UTC today ±1 for worldwide time zones (`sharingModel.ts:70-79`); it does **not** prove a caller's actual local day. Do not describe it as exact owner-midnight enforcement. Preserve v2 semantics; never offer a history picker. Different viewer/sender zones can legitimately show “No macros shared today.” Returned `timeZoneId` is metadata, not permission to fetch yesterday.
6. Cache one last-good macros result per `(session generation, profileId, local day)` in a **separate protected file**, not the people cache. Store `sourceUpdatedAt`, `fetchedAt`, and last successful authorization time separately. Home Screen and accessory families can reuse a result fetched within the previous 60 seconds for the same person/day/control revision across near-simultaneous invocations; do not replace future network reads with app-only caching.
7. On offline/timeout/429/5xx, show a last-good value only for the same current session, person, and local day, with no known permission revocation and with previously allowed Pro. Use **“Updated 2:15 PM”** from the server's snapshot `updatedAt`, not the most recent failed attempt; also signal “Offline” where space permits. If no acceptable last-good result exists, show “Couldn't update” / “Open MACROS,” not misleading zeros.
8. On paused/notShared/unavailable/profile-unavailable, known Pro denial/unknown access, disable/delete, or a local confirmed removal, immediately discard relevant macro caches and return a status entry. An authoritative denial always beats stale success, even offline later. A generic malformed query/error envelope must not be interpreted as permission success.
9. Cached macro data expires at midnight at the latest. Without pushes or connectivity, remote revocation cannot erase an already-rendered timeline immediately; explicitly disclose this limit. A successful server read purges denied data, and app-observed denial requests a reload. Do not promise instant remote removal.

Extend `WidgetTimelineReloader`:

- Add `reloadSharedPersonWidgets()` for new kinds **`SharedPersonMacroWidget`** and **`SharedPersonMacroAccessoryWidget`**.
- Make existing `reloadMacroWidgets()` also reload shared kinds so Pro, appearance, and ring-palette changes already wired to it propagate. Keep existing own-widget kinds unchanged.
- Call shared-only reload after dashboard shared-data changes, authoritative removal/privacy changes, default selection changes, and sharing enable/disable/credential cleanup. Ensure writes/purges complete before reload, and suppress late-generation responses.
- `WidgetCenter.shared.reloadTimelines(ofKind:)` invalidates a kind, not a single configured person. Accept that both shared kinds may refresh all their instances; don't add configuration enumeration unless measured work warrants it.

The current Pro record has no expiry (`WidgetAppearanceStorage.swift:43-52`). Reuse it as requested; do not invent a server-verified entitlement from it or claim it notices expiry while the app remains closed. Refresh the projection through the existing app purchase/foreground lifecycle. Extending that record with expiry is optional hardening, not necessary to implement this feature.

## 6. Layout reuse, states, copy, and gallery

### Reuse without changing own-day behavior

The current content/background views are file-private. Make the smallest reusable view boundary inside `CalMacroWidget`, accepting totals/goals plus optional identity/freshness/status metadata. Both old and new widgets call the same layout code; existing own-day callers supply no person header and keep their current appearance.

- **Small:** preserve rings above P/C/F columns. Add a single-line name above the graphic and a compact freshness line; recalculate the available vertical space rather than placing new text over the current fixed 80-point ring. Truncate long names, not nutrition. No text below 11 points.
- **Medium:** preserve rings left, macro columns right; place name/freshness in a compact shared header. Reuse `DailyMacroWidgetBackground`, the local user's custom palette/appearance, and rendering-mode rules, not the sender's styling.
- **Inline:** one line prefixed with the person's name, then the existing compact calorie/macro summary as width permits. Prefer name and calories when the system truncates; never make the name an invisible accessibility-only property.
- **Circular:** reuse the existing calorie Gauge with actual shared calorie goal; add a short visible name label, calorie value, and meaningful accessibility label. Missing goals means zero gauge fill, not a guessed target. Do not cram three macro rings into this family.
- **Rectangular:** compact name/freshness header above the existing three `MacroSummaryColumnView` columns; absent goals omit the denominator. Monochrome/vibrant-safe.
- Home Screen rings remain `MacroRingSetView(... usesGlassEffect: false)` with existing accenting. Preserve container backgrounds, removable-background behavior, and custom backgrounds only in full-color modes. Keep StandBy/background-removed content legible. No new app-like controls.
- Accessories cannot legibly fit the entire timestamp plus all nutrition in every size. Full “Updated 2:15 PM” appears in small/medium/rectangular; inline/circular prioritize identity/value, use a short stale/offline indication and include the exact timestamp in VoiceOver. Do not claim inaccessible text is a visible timestamp.
- Placeholder: redacted neutral structure, no real names/data/network. Gallery preview: clearly synthetic “Alex” with realistic macros and actual sample goals, fast and local even for a non-Pro viewer. It is a preview, never persisted as real data.

### State table

Apply precedence: privacy redaction/locked storage; device/session unavailable; Pro gate; selection; server visibility/data; transient error. Preserve a resolved person ID for navigation where possible, but never show stale nutrition in gated states.

| State | Home Screen / rectangular copy | Compact accessory copy | Tap destination |
| --- | --- | --- | --- |
| Viewer not Pro (`denied`) | “Shared widgets need MACROS Pro” · “Upgrade” | “MACROS Pro” with lock | Upgrade link below |
| Pro unknown | “Open MACROS to check Pro” | “Open MACROS” | Shared Widgets settings |
| Sharing disabled on this device | “Sharing is off on this device” · “Open MACROS” | “Sharing off” | Sharing Settings; do not auto-enable |
| Missing identity / expired authentication that cannot recover | “Open MACROS to reconnect” | “Open MACROS” | Sharing Settings |
| Storage inaccessible before first unlock | “Unlock to update” | “Unlock to update” | Open app normally |
| Authoritative people list empty | “No people connected” · “Connect in Sharing” | “No people” | Sharing Settings |
| Default selected, people exist, no default set | “Choose a default person” · “Open Sharing Settings” | “Choose person” | Shared Widgets settings |
| Explicit person removed/unresolvable | “Person unavailable” · “Edit Widget to choose someone” | “Unavailable” | Sharing hub, no fabricated person screen |
| Paused | “Sharing paused” · “A connection needs MACROS Pro” | “[Name] · Paused” | Person screen if relationship exists |
| Inbound grant absent/ended | “[Name] isn't sharing with you” | “[Name] · Not shared” | Person screen |
| Shared permission, snapshot null | “[Name]” · “No macros shared today” | “[Name] · No data” | Person screen |
| Shared snapshot with entryCount 0 | Show real zero totals and real goals | Name and 0 cal | Person screen; not “no data” |
| Goals missing, snapshot present | Show totals, empty rings, no invented goal labels | Name/value, empty gauge | Person screen |
| Offline/error with eligible last-good | Nutrition plus “Updated 2:15 PM” and “Offline” | Short stale marker; spoken timestamp | Person screen |
| Offline/error, no eligible cache | “Couldn't update” · “Open MACROS” | “[Name] · Unavailable” | Person screen or Sharing Settings if no target |

Gallery:

- **Shared Macros**: “Follow a person's calories and macros for today. Requires MACROS Pro.”
- **Shared Macros Lock Screen**: “Check a person's shared macros from your Lock Screen. Requires MACROS Pro.”

Register both in `CalMacroWidgetBundle`; use `AppIntentConfiguration` with the same intent/provider, appropriate `includesAppearance` behavior, and exactly the five families above. Do not replace or rename existing widget kinds. Scope the new widgets/network credential path to iOS (`#if os(iOS)`) because the target also declares macOS support: this plan does not silently enable macOS networking/signing or change existing macOS widget behavior.

## 7. Deep links and navigation

Add explicit `AppOpenRequest` cases and round-trippable parsing/building:

- **Person:** `calmacrotracker://sharing/person/<profileId>` (percent-encoded path component).
- **Widget settings:** `calmacrotracker://sharing/widgets`.
- **Upgrade:** `calmacrotracker://sharing/widgets/upgrade`, optionally carrying a percent-encoded `person` query parameter to resume the selected person's screen after purchase.
- Existing `calmacrotracker://sharing` and invite links keep their semantics.

Put exactly one `.widgetURL(...)` on each **new** widget's content root [A9]. The person URL captures the **resolved profile ID in that displayed timeline entry**. If a Default changes before the next reload, tapping the old display opens the person actually shown, not someone different. No secrets, JWTs, names, or macros in URLs.

`AppRootView` gains ID-based person routing that shows the Sharing hub and a loading destination, authenticates/starts the existing dashboard feed, waits for an authoritative result, then opens **`SharingPersonScreen(person:)`** using the current person. Do not fabricate a `SharingPerson` from widget data. If disabled/missing credentials, show Sharing Settings. If the relationship is gone, show a friendly unavailable state in Sharing. Repeated taps must not stack duplicate routes; pending routing must survive cold-start setup and not get lost because the dashboard starts empty.

The upgrade route presents `ProPaywallSheet(context: .sharedPersonWidget)` from the Shared Widgets setting; after successful purchase/restore, existing entitlement projection reloads widgets and the route can resume the selected person. Add the enum case to `PaidFeature` and `ProPaywallContext`, with product copy that names shared widgets. No purchase handling inside the extension.

**Do not restore a generic `.widgetURL` on the own-day widgets.** `changes-log.md:143-148` documents why those URLs were removed: ordinary widget taps unexpectedly reset the app's current navigation. An explicit person deep link intentionally navigates to that person; own-day taps must still keep the user's place.

## 8. Privacy, persistence, and App Store impact

- No new upload category or sharing permission is required merely to display already-authorized macros/goals on-device. Do not widen grants, collect foods, query HealthKit in the extension, or add analytics.
- The app already collects sharing nutrition and identifiers for app functionality, linked to a sharing profile, not tracking (`docs/app-store/privacy-labels.md:11-13,20-25`). Update this mapping to explicitly include **shared goals**, recipient-side widget fetch/caching, and visible names; confirm accurate Name/User ID/Health classification against Apple's current questionnaire [A11]. Do not label the complete app “data not collected.”
- Review the extension privacy manifest: it currently declares no collected data and only required-reason APIs. Receiving already-shared values does not automatically constitute new developer collection. Account for actual auth/query metadata retained by Convex/Worker logs, preserve required-reason declarations, and make the final manifest/app label agree with real collection. Do not invent a new “widget data” category or tracking usage.
- Update Sharing Settings disclosure and `web/src/pages/privacy.astro:26-34` to mention protected local widget copies, background refresh, possible Lock Screen visibility, and best-effort revocation. App Store Connect label/review-note edits are release-owner actions, not unrequested writes during implementation.
- Mark the person's name and nutrition `.privacySensitive()` and respect system privacy redaction. Use redacted content before first unlock. Test the system “allow access when locked” setting [A10].
- Store people/default/control records and last-good macros under App Group `Library/Application Support/SharedPersonWidgets/` in separate versioned records. Atomic writes, bounded sizes, backup exclusion, and **`FileProtectionType.completeUntilFirstUserAuthentication`** on directories and each resulting file, including temporary replacement files [A12]. This permits Lock Screen operation after first unlock; `.complete` would block the requested locked-device refresh.
- Avoid UserDefaults for sensitive macro payloads and don't assume defaults APIs set per-file protection. Existing appearance/Pro preferences remain in their current store. The people cache has no macros, but names are still personal data and deserve protection.
- Only the app writes people/control records; the extension writes per-person snapshot cache records. Use a common coordinated directory operation for cross-process control updates/cache writes/purges, atomic replacement, and session-generation/control-revision checks inside the coordinated commit. Keep network awaits outside coordination and use operation-scoped `NSFileCoordinator` instances, not long-lived presenters [A16]. The app's disable/purge must not race a late extension write back into existence. No broad directory deletion.
- Clear snapshots on permission loss/paused/removal/disable/deletion/Pro denial/day rollover; remove obsolete owned day files on the next access. Do not retain yesterday as a fallback. Keep no food lists or auth secrets in these files.
- Keychain after-first-unlock/device-only records do not migrate to another device [A13]. After reinstall/restore, missing App Group control state disables widget fetching even if a Keychain item remains. App migration/setup must reconcile state explicitly.
- Simulator evidence cannot prove hardware data-protection or distribution provisioning correctness. Require a signed-device lock/reboot/first-unlock check before release, without using the owner's private fixture for destructive QA.

## 9. E2E-first validation and repeatable evidence

### Establish the failing acceptance run before implementation

First write `docs/evidence/shared-person-widget-e2e/README.md` (scenario/expected-output checklist) and a Bun-driven live HTTP acceptance script, proposed `convex-backend/scripts/sharedWidgetSmoke.ts`. Run it against **dev `energized-pigeon-822` only** and record the expected failure for the missing new query; record the current gallery's missing shared kinds. Do not write implementation and then invent tests to match it. If isolated tests are needed, enumerate their failure modes first (below), then write those tests **before** the relevant production code.

Use two available, unclaimed existing iPhone simulators for the app UI pairing (for example iPhone 17 and iPhone 17e, choose actual current UDIDs from inventory). Respect `AGENTS.md:59-65`: no new simulators, maximum four booted/one stock, never reset/seed the owner's `9843E820-3A2A-4599-9206-D224B3035A47`, and do not shut down unknown or active devices. If two suitable devices are unavailable, record the blocker rather than borrowing private state. Save all builds/evidence in this implementation worktree, never the excluded checkout or any `IGNOREDbuild/`.

### Prior evidence: useful scenarios, not a blanket pass

Remote evidence reference pinned during research: `origin/docs/asc-review-screenshots` **ec344e2ee30ffb09a52532b142177b8d98034221**. Its commit **4cc1262ad84eb125e1abc9b3ad15aa0482388a7b** adds 21 images in `docs/evidence/sharing-v2-e2e/`:

- `01-people-b.png`, `02-person-a-no-foods.png`, `03-a-sees-b-macros.png`: people and directional macros.
- `04-live-foods-b.png`, `05-edit-live-b.png`, `06-delete-live-b.png`, `07-macros-only-b.png`: mutation propagation and scope changes.
- `08-nothing-state-error-b.png`, `09-sharing-back-error.png`: **failure captures**, not proof of correct access-denied UX.
- `10-dark-ax3-person-b.png`, `11-remove-b-people-empty.png`, `12-empty-people-b.png`: appearance/removal/empty-state references.

Research opened `02-person-a-no-foods.png` and `08-nothing-state-error-b.png`: the latter visibly contains a server-error alert. That evidence commit contains images, not a reproducible E2E report. The separate `docs/evidence/sharing-ui/REPORT.md` on that remote explicitly says its ring-polish sharing screenshots used a temporary in-process mock, **not dev Convex/two-device pairing**. Do not treat those mock screenshots as network or authorization validation.

### Pairing and functional sequence

1. Install the same signed Debug build on A and B, open each app once (required for gallery discovery [A10]), finish onboarding, enable Sharing, and give test profiles identifiable synthetic names. Set different **real local goals** and nonzero logged macros. Use Settings > Developer Debug Pro or local StoreKit only for the local widget product gate; neither produces Apple-server-verified Pro.
2. Create an invite on A, accept on B, confirm the directional connection, and optionally enable reciprocal macros. Use actual UI and dev backend, no mock dashboard or production profile. Add a second person for picker/default tests via another disposable dev profile (HTTP-only is sufficient; a third simulator is unnecessary).
3. Write the default in B's Sharing Settings. Add both shared Home Screen sizes on B and all three accessory families. Check server values/goals versus A's app. Update A's macros/goals and put B's app in the background, then capture B's next **extension-originated** refresh. Record request/entry times and cache age with redacted diagnostics, not credentials. An app-triggered reload alone is not proof of extension-owned freshness.
4. With B backgrounded, observe a natural scheduled refresh window and record actual delay. A debugger-invoked timeline or app reload can speed diagnostic iteration but cannot count as the real cadence acceptance case. WidgetKit can exceed 30 minutes; report actual delivery, not a guaranteed SLA. Capture a second changed value so cached initial UI cannot masquerade as a fetch.
5. Edit Widget → Person: capture Default plus people. Configure two instances, one Default and one explicit A. Change the in-app default to the second person: only Default instances change. Rename, remove, and reconnect people; explicit stale selections must not switch to somebody else. Clear default with people present, then test no people.
6. A sets outbound scope to Nothing: B must show not-shared, discard macros, and stay denied if subsequently offline. Restore macros, remove relationship, then delete a disposable sender profile in a separate run. Verify cache purge, picker updates after app refresh, and friendly stale deep links.
7. Cover local non-Pro/unknown entitlement, sharing disabled, missing credentials, token refresh, current-day no snapshot versus legitimate zero snapshot, missing goals, error without cache, offline with eligible cache, and the midnight blank entry. Offline simulation must actually block the extension's network (a controlled Mac network rule/proxy for test traffic with explicit authorization and cleanup), not just hide the app's UI.
8. Test local-midnight/DST/time-zone math with a prewritten isolated clock test; also capture a natural or controlled test-device midnight rollover with the app backgrounded. Changing only a status-bar clock is **not** a clock/day test. Never change the Mac's global date for this.
9. For paused E2E, arrange server-verified test entitlements and coordinate the deployment-global `settings.sharingRequirePro` flag with the dev deployment owner. Capture neither-Pro paused and one-Pro resumed, then restore the original flag. Local Debug Pro/Xcode transactions are deliberately rejected by the backend verifier (`sharing-v2-plan.md:163-173`). Do not fake this as live proof. The isolated Convex tests cover this deterministically even if live fixture setup is blocked; label any missing live paused capture honestly.
10. Tap each family, cold and warm app: correct `SharingPersonScreen`, removal fallback, disabled setup, upgrade sheet, and no duplicate routes. Verify own-day widget taps still preserve Settings/Insights navigation. Place own-day and shared small widgets in one native stack, swipe/Smart Rotate, and confirm no custom toggle exists.

### Add widgets and capture actual simulator surfaces

Use Simulator's native SpringBoard UI through XcodeBuildMCP tap/long-press/swipe/keyboard controls (or manual Simulator interaction if system surfaces resist automation). No undocumented `simctl add-widget`, SpringBoard plist injection, or pretend SwiftUI preview as Home Screen evidence.

- **Home Screen:** open app once, press Home; long-press blank space → Edit → Add Widget → search MACROS → **Shared Macros** → swipe to Small or Medium → Add Widget → Done. Long-press the placed widget → Edit Widget → Person. Capture picker and resolved content. Stack same-sized own/shared widgets by dragging one onto the other, then Edit Stack/Smart Rotate [A14].
- **Lock Screen:** lock/wake the simulator, long-press wallpaper → Customize → Lock Screen. Tap the above-clock date slot for inline; use Add Widgets below the clock for circular and rectangular; choose **Shared Macros Lock Screen**. Tap a placed widget while customizing to configure Person, then Done. If the simulator cannot expose lock customization, report that family blocked, not passed from a preview.
- Capture each of the **five families** with shared data/goals, no-data, not-shared, removed, offline-stale, and Pro-locked states. Capture the remaining state-table rows in every family too, using compact copy variants, with a matrix mapping each cell to a real screenshot or explicit blocker. Configure separate wallpaper layouts if slot limits require it.
- Healthy-state appearance coverage: Home Screen light/dark/tinted/clear, accessory vibrant, long/duplicate/Unicode names, large text, VoiceOver name/macros/goals/freshness labels, reduced motion, and background-removed small/StandBy. Retain own-day baseline screenshots for regression comparison. Actual StandBy/Always-On behavior may need a physical device; state that limit.
- Save PNGs using `cd <absolute-implementation-worktree> && xcrun simctl io <UDID> screenshot <absolute-evidence-path>`, short interaction recordings, and a result matrix/report under `docs/evidence/shared-person-widget-e2e/`. Record commit SHA, Xcode/runtime, UDIDs, deployment, family/configured entity, fixture values, sourceUpdatedAt/fetchedAt, expected/observed result, and redacted HTTP envelopes. Never commit JWTs, profile secrets, invite tokens, real nutrition, or an environment file.

### Required live negative security test

The HTTP smoke script must use the **same `/api/query` transport and new query** as the extension, not only ConvexHttpClient:

1. Create disposable profiles A/B/C; upload distinguishable current-day sentinel snapshots.
2. Before any relationship, authenticate as B and request A's known profile ID. **Fail the run if any snapshot, goals, name, or target identity metadata is returned.** Knowing an ID is not authorization.
3. Connect A/B in only one direction. Ask in the ungranted direction and assert `notShared` with null snapshot. Enable the correct grant and assert only then that the sentinel is returned.
4. End the grant, remove the relationship, and tombstone the profile; retry with the **previously valid JWT** and assert no data each time. Test unauthenticated/expired JWTs and day mismatch as well. Add foods permission during a valid run and assert the widget response still never includes foods.
5. Run the installed widget against the denied case with a preexisting success cache and verify values disappear. The API assertions are the security proof; UI alone can hide a leaking response.
6. Cleanup only the disposable fixtures created by this run. Print sanitized assertions/counts, never credentials. Do not run the existing smoke unchanged and call it widget coverage.

### Isolated failure modes to enumerate before tests/code

| Boundary | Failure modes to write down and test first |
| --- | --- |
| Keychain/migration | Legacy-only install; shared-only install; denied copy; failed legacy deletion; conflicting identities; missing entitlement; locked-before-first-unlock vs missing item; invite stays private; device disable/delete during refresh; expiry ms/seconds mix-up; invalid response key; 429; no identity creation by extension. |
| Server query | Missing auth; wrong target table/ID; stranger; self; deleted viewer/target; removed relationship; outbound-only instead of inbound grant; grant ended today; paused with enforcement on; enforcement off; one Pro resumes; no snapshot; wrong/past day; accidental food/secret field inclusion; optional goals. Extend existing `convex/_qa/sharing.integration.ts`, preserving old query contracts. |
| Configuration/cache | Default sentinel mistaken for ID; absent default; duplicate names; removed explicit ID; stale cache vs authoritative empty; corrupted/oversized/new-version file; cross-profile cache collision; generation race during disable/default switch; stale success overriding denial; unsafe temporary-file permissions. |
| Timeline/presentation | Network failure with/without cache; permission denial after successful cache; local midnight/DST/zone shift; network response crossing midnight; missing/zero/partial goals; nonfinite totals; true zero vs absent snapshot; all five families; Pro unknown vs denied. |
| Routing | URL round trip/escaping; malformed URL; cold start before dashboard; unavailable person; disabled sharing; upgrade completion; repeated taps; existing invite/add-food links; own-day navigation-preservation regression. |

No unit tests are to be added after implementation. Existing tests still run. Build/format checks support E2E, not replace it.

Implementation validation commands must start from the implementation worktree and use its project, not copied absolute paths from old guidance. Prefix **every command** with `cd <absolute-dir> &&`. Run backend `bun run check`, `bun run test:integration`, live smoke, `make lint-js`, `make quality-format-check`, `make quality-build` (build only), then the existing serial bounded XCTest suite on the designated safe runner per `AGENTS.md`. Give xcodebuild an explicit derived-data path inside the worktree if needed. Check signed entitlements on device/distribution outputs before release. This planning-only change does not need an app build or simulator launch.

## 10. Ordered implementation tasks and ownership boundaries

Paths below are proposed additions unless already in the source map. Keep changes scoped; no new targets or app-wide view-model layer.

| Order | Work and files | Completion gate / risks | Parallelism |
| --- | --- | --- | --- |
| 0 | After ring-polish merges, refresh source references/interfaces. Write failing E2E checklist/script first: `docs/evidence/shared-person-widget-e2e/README.md`, `convex-backend/scripts/sharedWidgetSmoke.ts`, optional script entry in `convex-backend/package.json`. Enumerate isolated failure modes, then prewrite necessary isolated tests. | Red run recorded; two safe simulators and dev access available. No production data or secret-bearing artifacts. | Test-scenario design and docs can start before merge; do not edit overlapped Swift files yet. |
| 1 | Add compact authorized server read and shared helper: `convex-backend/convex/sharing.ts`, `convex/personDayRead.ts`, `convex/sharingValidators.ts`, optional reusable lookup in `convex/authHelpers.ts`, prewritten `convex/_qa/sharing.integration.ts`; regenerate API bindings via normal codegen. | Old contracts pass; live HTTP negative test rejects unshared IDs and never returns foods. No schema migration expected. Dev deploy only after authorization/configuration. | Backend can run beside tasks 2–3 once result/error DTO agreed. |
| 2 | Shared credentials migration/auth DTO: new `Shared/SharingWidgetCredentials.swift` (including shared identity/error types); existing `Features/Sharing/SharingSecureStorage.swift`, `SharingIdentityStore.swift`, `SharingAuthService.swift`, `SharingSyncService.swift`; optional configuration extraction to SDK-free `Shared/SharingWidgetConfiguration.swift`. Review both entitlements files; no new keys for selected App Group Keychain design. | Upgrade preserves identity, secrets remain Keychain-only, invite stays private, cleanup generations work. Confirm App Group availability in signed app and extension, not just simulator. | Can run alongside backend; one owner for overlapping shared model/project edits. |
| 3 | App Group control/people/last-good storage: new `Shared/SharedPersonWidgetModels.swift`, `Shared/SharedPersonWidgetStorage.swift`; publication/purge hooks in `Features/Sharing/SharingSyncService.swift`; default setting in `Features/Sharing/SharingScreen.swift`; feature/paywall copy in `Features/Purchases/PaidFeature.swift`, `ProPaywallSheet.swift`. | Default vs explicit semantics, true authoritative empty list, protected/backup-excluded atomic records, no cross-session resurrection. | Storage contract can be built beside backend; integrate after task 2 lifecycle contract. |
| 4 | Extension transport/provider/configuration: new `CalMacroWidget/SharedPersonWidgetClient.swift`, `SharedPersonWidgetProvider.swift`, `SharedPersonWidgetIntent.swift`; constants in `Shared/SharedAppConfiguration.swift`. | Independent authenticated HTTP reads, bounded refresh, midnight expiry, correct status states and no app SDK dependency. | Provider and task 5 layouts can proceed in parallel after DTO/entry contract; both depend on tasks 1–3 for integration. |
| 5 | Minimal common widget layout boundary from `CalMacroWidget/DailyMacroWidget.swift`, `DailyMacroAccessoryWidget.swift` (optional new `MacroWidgetContentView.swift`); new `SharedPersonMacroWidget.swift`, `SharedPersonMacroAccessoryWidget.swift`; update `CalMacroWidgetBundle.swift`, `Data/Services/WidgetTimelineReloader.swift`. | All families reuse current layouts/primitives, names visible, own-day unchanged, shared accessory Pro gate actually read, no glass in WidgetKit. | No redesign of `MacroRingSetView`; coordinate view extraction with merged ring-polish work. |
| 6 | Deep links: `Shared/AppOpenRequest.swift`, `App/AppRootView.swift`, optional feature-local `Features/Sharing/SharingPersonLinkDestination.swift`, Shared Widgets settings route/paywall presentation. Existing `Info-iOS.plist` scheme needs no new registration. | Cold/warm person routing, safe removal/disabled/upgrade behavior; existing own-day taps preserve place. | Can run beside provider/layout with fixed URL contract, but serialize edits to Shared Widgets settings. |
| 7 | Project membership and privacy review: `cal-macro-tracker.xcodeproj/project.pbxproj`, both entitlement files only if verified signing needs it, `CalMacroWidget/PrivacyInfo.xcprivacy`, app manifest if audit requires; `docs/app-store/privacy-labels.md`, `web/src/pages/privacy.astro`, short `changes-log.md` entry for implemented work. | Shared SDK-free files compile once into each intended target; widget-only files excluded from app; no ConvexMobile link in widget; manifests truthful. | Centralize project edits under one integrator. Privacy copy research can run in parallel. |
| 8 | Run fresh live two-simulator E2E matrix, actual SpringBoard widgets, scheduled refresh, default/explicit, authorization-negative, protected-device checks, and existing validators. Save complete repeatable artifacts in `docs/evidence/shared-person-widget-e2e/`. Review diff for duplicate layout/security logic and dead code. | Passing evidence or explicit blockers for every row/family. Never equate previews, mocks, builds, or app reloads with full E2E. Release owner handles distribution/privacy-label updates. | Avoid multiple agents claiming the same simulators; natural cadence observation can overlap static checks, not other destructive fixture work. |

### Project-file details to preserve

`project.pbxproj:178-181,202-205` gives both targets synchronized `Shared` membership; `53-76` excludes shared/extension files from the app's parent-folder traversal to avoid double compilation. New shared files need the same exception pattern; new widget-only files must also be excluded from the app traversal. Do not add hand-written PBXBuildFile entries blindly on top of synchronized groups. Keep ConvexMobile app-only. Shared types must be extension-safe and concurrency-correct under the existing MainActor-default settings (`505,598,640`); immutable Codable values/I/O actors should explicitly opt into appropriate isolation rather than importing main-app singletons.

### Merge overlap and primary risks

- **Known concurrent overlap:** `fix/sharing-ui-ring-polish` changes `SharingPersonScreen`, `SharingDashboardScreen`, and `MacroRingSetView`. Implementation starts **after** merge. Do not reapply the old person-screen layout, fork the ring renderer, or overwrite the new List/+ menu. Use the merged screen for ID-based routing; normally no feature change to `SharingPersonScreen` itself is needed.
- Authentication upgrade and partial cleanup can strand a nonrecoverable identity. Verify migration before deleting any old credential; never recover by silently creating another profile.
- Remote revocation and entitlement expiry cannot instantly retract an offline already-rendered widget. Document budget/network limits and reuse the existing Pro record honestly.
- Midnight/time-zone ambiguity is inherited from sharing v2; changing server day semantics is outside this feature.
- Widget text density, especially circular/inline names and stale indicators, needs actual installed-family evidence, not a generic medium preview.
- Dev configuration is absent in this new worktree; live deployment/flag/verified-purchase setup requires valid local configuration and explicit coordination. Do not copy secret files or use deploy credentials in app code.

## 11. Remaining owner/deployment questions

No fixed product decisions are reopened. One environment decision is needed **only to complete live paused-state E2E**: can the implementation run temporarily change the deployment-global `settings.sharingRequirePro` on `energized-pigeon-822`, and can it use server-verified Sandbox Pro fixtures there? The current code has no per-test flag override and deliberately rejects simulator/Xcode transactions. Without permission/fixtures, keep that live cell blocked and use the prewritten isolated server test as partial coverage, not a substitute passing screenshot.

Signing-prefix inspection, simulator availability, App Group Keychain access on a signed device, and dev environment configuration are verification gates, not new owner product choices.

## 12. Primary API references (verified during this research)

Apple documentation pages were read as Markdown where supported. These references substantiate the API behavior above, not just suggested search results.

- **[A1] Making a configurable widget:** `WidgetConfigurationIntent`, `@Parameter`, AppEntity/default query, `entities(for:)`, `suggestedEntities()`, `defaultResult()`, `AppIntentTimelineProvider`, and `AppIntentConfiguration` example. https://developer.apple.com/documentation/widgetkit/making-a-configurable-widget
- **[A2] AppIntentConfiguration:** unique kind, intent/provider/content contract, snapshot/timeline callbacks, availability iOS 17+. Existing project minimum iOS 26 needs no legacy fallback. https://developer.apple.com/documentation/widgetkit/appintentconfiguration
- **[A3] WidgetConfigurationIntent:** configuration parameters; no `perform()` implementation required for configuration-only intent. https://developer.apple.com/documentation/appintents/widgetconfigurationintent
- **[A4] AppEntity / EntityQuery:** persistent unique ID, display/query contract; omit identifiers for unavailable entities. https://developer.apple.com/documentation/appintents/appentity and https://developer.apple.com/documentation/appintents/entityquery
- **[A5] Keychain sharing / entitlement:** App Groups can themselves be Keychain access groups since iOS 8; `kSecAttrAccessGroup`, default-group ordering, and signing protection. https://developer.apple.com/documentation/security/sharing-access-to-keychain-items-among-a-collection-of-apps and https://developer.apple.com/documentation/bundleresources/entitlements/keychain-access-groups
- **[A6] App ID prefixes:** legacy prefix can differ from Team ID; changing prefixes can orphan existing Keychain data. https://developer.apple.com/library/archive/technotes/tn2311/_index.html ; signed-entitlement/provision inspection: https://developer.apple.com/library/archive/technotes/tn2415/_index.html ; Apple DTS explanation of automatic prefix selection: https://developer.apple.com/forums/thread/118773
- **[A7] Widget timelines/budget:** typical 40–70 daily refreshes, variable delivery, `.after`, future entries, and kind-based `WidgetCenter.reloadTimelines`. https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date
- **[A8] Extension networking:** network requests during snapshot/timeline, limited execution resources, background URLSession alternative. https://developer.apple.com/documentation/widgetkit/making-network-requests-in-a-widget-extension
- **[A9] Widget deep links:** one `widgetURL` per hierarchy; app receives URL through `onOpenURL`; default taps otherwise launch app. https://developer.apple.com/documentation/widgetkit/linking-to-specific-app-scenes-from-your-widget-or-live-activity
- **[A10] Widget extension, gallery, privacy:** launch containing app once for gallery discovery; privacySensitive/redaction; families/previews. https://developer.apple.com/documentation/widgetkit/creating-a-widget-extension
- **[A11] App privacy labels:** collection definition, on-device processing, functionality use, linked data, and no tracking assumptions. https://developer.apple.com/app-store/app-privacy-details/
- **[A12] File protection:** encrypted until first authentication, remains available on subsequent locks. https://developer.apple.com/documentation/foundation/fileprotectiontype/completeuntilfirstuserauthentication
- **[A13] Keychain accessibility:** after-first-unlock background access, device-only records do not migrate to another device. https://developer.apple.com/documentation/security/ksecattraccessibleafterfirstunlockthisdeviceonly
- **[A14] Native widget add/edit/stack UI:** https://support.apple.com/en-us/118610 and https://support.apple.com/guide/iphone/add-edit-and-remove-widgets-iphb8f1bf206/ios
- **[A15] Widget HIG:** glanceable family-specific layouts, constrained accessories, full-color/tinted/clear/vibrant/background-removed contexts. https://developer.apple.com/design/human-interface-guidelines/widgets
- **[A16] Protected cache I/O:** operation-scoped cross-process file coordination and backup exclusion. https://developer.apple.com/documentation/foundation/nsfilecoordinator and https://developer.apple.com/documentation/foundation/urlresourcevalues/isexcludedfrombackup
- **[C1] Convex HTTP API:** POST `/api/query`, body `{path,args,format}`, user Bearer auth, success/error envelopes, admin auth distinction. https://docs.convex.dev/http-api/
- **[C2] Auth in Convex functions:** `ctx.auth.getUserIdentity()` and Bearer-token authentication. https://docs.convex.dev/auth/functions-auth
- **[C3] Structured Convex application errors:** use `ConvexError` for typed public errors instead of string matching. https://docs.convex.dev/functions/error-handling/application-errors

## Planning validation

Plan-only verification: inspect all cited local source ranges, fetch primary API documentation, inspect remote evidence history and two actual screenshots, check whitespace and the staged plan-only diff. No app build, deploy, simulator mutation, live credentials, or E2E run is claimed by this document. Leave `changes-log.md` untouched until implementation actually ships; this tracker is the sole planning deliverable.
