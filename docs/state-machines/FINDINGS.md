# Source replay and decisions

These are static source replays, not app tests or observed production incidents. Main citations refer to `da00befaae3d9954c7046f80570bda4936f918d7`; paths beginning `cal-macro-tracker/` are app sources. All paths below are repository-relative. The widget snapshot is separately pinned in the README. Owner approval of the proposed rules is still required.

## Confirmed conflicts first

Four defect families explain five failed model rules. “Confirmed” means each transition has a matching source operation and no intervening source guard prevents the path. Runtime reproductions below are proposed, not executed.

### F1. Deletion acknowledgment is the only doorway to local cleanup

**Rule:** `DeletionRecoverable`, “Retry Delete must still be able to finish local credential cleanup.”

**Path:** `profile-deletion/report.md`, steps 0–4.

| Step | Source replay |
|---|---|
| 0–1 | Device enabled, cleanup marker false. `cal-macro-tracker/Features/Sharing/SharingSyncService.swift:474–480` authenticates, then awaits deletion. |
| 2 | `convex-backend/convex/sharing.ts:283–295` replaces the secret hash, sets `deletedAt`, schedules deletion, and returns. Server commit and delivery of its acknowledgment are separate events. |
| 3 | Lose that acknowledgment, or terminate before the client continues. The marker write at `SharingSyncService.swift:481` has not happened. Relaunch therefore has no deletion journal. |
| 4 | Retry enters authentication again at line 479. `convex-backend/convex/bootstrap.ts:19–22` rejects the tombstoned identity; `worker/auth/src/index.ts:67–68,106–128` rejects the exchange. `SharingAuthService.swift:129–145` logs in from cache through its auth provider; token exchange is at lines 63–92. Local cleanup at `SharingSyncService.swift:509–525` requires the marker that was never written. |

**Impact:** stuck deleted sharing identity and stale local device state. This is not deletion of the owner's nutrition database. A still-valid token does not provide a durable recovery design: the client explicitly authenticates again, and deleted profiles are rejected by backend profile guards.

**Proposed boundary:** persisted `DeletionState = active | requested(operationID) | remoteDeleted | cleaning | cleanupFailed | off`. Record intent before I/O and make retry resolve remote deletion idempotently without requiring a live profile. Do not simply delete credentials on every network error: a failed request does not establish remote deletion.

**Future reproduction:** use isolated credentials and a transport fault after server commit, relaunch, retry Delete, inspect only nonsecret journal states. Not run here.

### F2. A partially copied SQLite store is treated as migrated

**Rule:** `CompleteBeforeOpen`, “An opened migrated store must include all committed legacy data.”

**Path:** `store-migration/report.md`, steps 0–4.

| Step | Source replay |
|---|---|
| 0–1 | `cal-macro-tracker/Shared/SharedModelContainerFactory.swift:67–78` checks for destination **base file**, not a completed migration. |
| 2 | Lines 85–92 copy artifacts separately. Lines 95–100 put the base first, shared-memory second, WAL last. |
| 3 | Interrupt or fail after the base copy, before WAL copy. Original artifacts remain intact. |
| 4 | On retry/relaunch, the destination base exists, so line 74 skips all remaining copies. Lines 32–46 open that destination. Widget read-only opening also checks only the base, lines 49–64. |

**Condition and impact:** a source WAL containing committed, uncheckpointed transactions must exist. Missing committed rows, or inability to open consistently, is possible. No data loss was observed, and the original legacy files remain recoverable. `-shm` is not equivalent to durable WAL state; the model intentionally concentrates on base plus WAL.

Primary SQLite documentation: [The WAL File](https://www.sqlite.org/wal.html#the_wal_file) states that the WAL is part of persistent database state and must accompany the database when copied or moved. Merely copying a live multi-file database is not a consistent-snapshot guarantee either.

**Proposed boundary:** `MigrationState = legacy | preparing | copiedAndValidated | published | failed`. Use a consistent SQLite backup/checkpoint strategy, staging, and a durable completion/publish protocol. Coordinate widget readers so a base file cannot expose unfinished staging.

**Future reproduction:** isolated legacy fixture with uncheckpointed committed rows; interrupt each copy boundary; reopen and compare row counts and content. Never run against the owner's store. Not run here.

### F3. Removed relationship revives the detail screen's original snapshot

**Rule:** `RemovedMeansHidden`, “Once removal reaches this device, that person's macros must disappear.”

**Path:** `dashboard-person/report.md`, steps 0–1.

| Step | Source replay |
|---|---|
| 0 | Open detail from a visible dashboard person containing macros. `cal-macro-tracker/Features/Sharing/SharingPersonScreen.swift:20–32` falls back to the original value if the roster/cache has no replacement. |
| 1 | Removal arrives in dashboard. `SharingSyncService.swift:280–308,350–359` prunes missing people from cache. `SharingPersonScreen.swift:220–227` clears only `personDayVisibility`; line 21 then returns the original person, whose `incomingActive` and snapshot are still true/present. Lines 29–32 display it. |
| Later | The person query can fail because `convex-backend/convex/sharing.ts:387–390` rejects a missing relationship. The catch at `SharingPersonScreen.swift:211–214` sets error/loading, not membership or the original snapshot. The task identity at lines 195–201 does not include roster membership. |

**Impact:** stale, previously obtained macros remain locally visible after authoritative removal. This is **not** evidence of a new unauthorized server read. Explicit `.notShared` visibility and active/incoming guards prevent a different stale-display path; do not remove those guards.

**Proposed boundary:** `PersonAvailability = loading | available(person, day) | paused | notShared | removed | failed(lastGood?)`. Absence from an authoritative roster is `removed`, never a fallback to an initially captured visible person.

**Future reproduction:** isolated two-person relationship, leave detail open, remove from the other client, wait for roster update, verify macro redaction even if person-day subscription subsequently errors. Not run here.

### F4. A valid invite is replaced early, and a lost reply leaves the revoked link cached

**Rules:** `KeepValidLink`, “Create Invite keeps the same link until it expires or you revoke it”; `CachedLinkIsLive`, “A link the app offers as current must not already have been replaced.”

**Paths:** `invites/report.md`, steps 0–3 and 0–4.

| Step | Source replay |
|---|---|
| 0–1 | A seven-day link remains unexpired but enters its final hour. `cal-macro-tracker/Features/Sharing/SharingScreen.swift:85–86` promises the same link while valid and explicit revocation before replacement. |
| 2 | Create Invite reuses only links with **more than an hour** remaining, `SharingSyncService.swift:366–377`. It requests a replacement instead. |
| 3 | `convex-backend/convex/sharing.ts:69–84` revokes all pending links and inserts the new one in the mutation. The old externally shared link is now unusable, although its advertised expiry is in the future. |
| 4 | If the new reply is lost, client persistence at `SharingSyncService.swift:379–380` never happens. `SharingLocalStateStore.swift:70–106` checks owner binding, local expiry, and token presence, not server revocation. Previously loaded UI state also survives the request's error. |

**Impact:** early revocation contradicts the UI contract; loss of the reply can leave an apparently current but dead link. A subsequent Create Invite can retry replacement, so this is not a permanent inability to recover.

**Proposed boundary:** `InviteState = none | valid(link) | revoking | creating(operationID) | reconciling | failed`. First choose the contract: preserve the exact validity window, or disclose renewal/replacement. Then use operation identity and server reconciliation for an uncertain create result.

**Not a defect:** accepting an invite does not consume it. `sharing.ts:105–167` deliberately permits reusable acceptance and establishes the owner's outgoing grant. Do not convert that into one-shot acceptance as an incidental “fix.”

**Future reproduction:** isolate a final-hour invite, request creation, check old-token validity; separately drop the replacement response and reload invite UI. Not run here.

## Policy question, not a confirmed privacy-read bug

### Q1. Does pausing for Pro expiry require immediate physical food deletion?

`scope-pro/report.md`, `ImmediatePurgeOnPause`, steps 0–3: Macros → Macros and Foods → upload → neither person has active Pro.

`convex-backend/convex/sharing.ts:182–210` updates grant scope and purges on deliberate scope reduction. `foodSharing.ts:31–40,98–144` gates eligible food upload and cleanup. `proStatus.ts:34–65` updates derived Pro status but does not immediately delete food rows. `sharing.ts:338–363,392–411` gates dashboard/person-day reads before returning food data. Daily cleanup exists in `foodCleanup.ts` and `crons.ts`.

The bytes can remain hidden until a later upload or cleanup. This fails an **immediate purge policy**, not the implemented read-access policy. `NoUnauthorizedRead` holds in the model because it transcribes those gates; it is not an independent end-to-end security proof. `proModel.ts:6–21` also makes Pro gating deployment-configurable; the model assumes that gating is enabled. Deployment settings were not queried.

**Owner decision:** retain hidden foods for resumption/current-day cleanup, or guarantee immediate deletion on last-Pro expiry? If immediate deletion is required, add an explicit purge transition/job, document its delay, and distinguish “read blocked” from “bytes deleted.”

## Dismissed model-only failures and prevented paths

| Diagnostic | Report path | Why it is not a confirmed bug |
|---|---|---|
| `LocalEqualsCloud` | purchases 0–2 | `PurchaseStore.swift:187–214` commits verified StoreKit entitlements locally before optional backend purchase submission. `AppEntitlements.swift:73–109` derives local access from verified facts. Offline-first local unlock and eventual cloud verification are intentionally separate. “Always equal” is an invalid invariant. |
| `NoObsoleteFiles` | widget-control 0–5 | **IN FLUX.** Provider checks current control before writing (`SharedPersonWidgetProvider.swift:135`) and again before returning (174); app invalidation can interleave between check and disk write. Cache filenames/read keys include generation/person/day, so old files are inert. `isCurrent` at 188–192 rejects changed generation, enablement, Pro, roster/default, and day. Old-file nonexistence is stronger than publication safety. |
| Stale upload acknowledgment after disable | no failing path | `SharingSyncService.swift:169,191–208` checks attempt/generation/cancellation and re-reads payload after authentication. A network mutation already committed cannot be undone by local cancellation, explicitly noted at 200–201. The model permits that remote commit but not a stale local success acknowledgment. |
| Old person-day stream value after cancellation | no failing path | `SharingPersonScreen.swift:206` checks cancellation before writing the cache. The model's old-day reply is ignored. Membership fallback, F3, is a different path. |
| Losing the only identity during successful migration | no failing path | **IN FLUX.** `SharingWidgetCredentials.swift:75–110` copies, verifies equality, then deletes the specifically scoped old item. `PreserveIdentity` holds for that success-only abstraction. Keychain errors, duplicate records and interrupted rerun choice remain outside it. |

The widget model was corrected before publication: an earlier coarse model wrote on every late reply, even one rejected by the first control check. The final model separates response checking, cache writing, and final return checking. Its obsolete-file path now requires the real check/write interleaving. `OnlyCurrentDataSelected` concerns logical eligibility at these modeled checkpoints, not immediate removal of an already-rendered WidgetKit entry. Invalidation logically revokes selection in the abstraction; physical redraw, existing timeline retention, and the last-check-to-return race are not modeled. No instantaneous widget-redaction guarantee is claimed.

Primary [Apple access-group documentation](https://developer.apple.com/documentation/security/ksecattraccessgroup.md) says `SecItemCopyMatching`, update and delete search all accessible groups unless an access group is specified. Do not assume an unscoped lookup is limited to the default group. No Keychain migration data-loss bug is claimed.

## Unconfirmed follow-ups, excluded from the confirmed count

This list preserves the original static triage. The [live follow-up results](suspects/README.md) now supersede its investigation status: seven behaviors reproduced with the documented timing/policy limits, three suspected user-facing failures were not reproduced in attempted paths, and the widget item remains static-only. The original model-conflict count above is unchanged.

1. **Repair stale writeback:** `Data/Services/SecondaryNutrientRepairExecution.swift:111–164` accumulates repairs across awaits; lines 168–200 re-find by ID but do not validate the original source/quantity version. Reproduce an edit to an earlier entry while a later lookup waits before deciding whether a version guard is needed.
2. **Backup/Health reconciliation:** `Features/Backup/BackupImporter.swift:210–223` replaces weights; `Features/Health/HealthKitService.swift:273–306` independently retains/advances `healthWeightAnchor`. `BackupSettingsSection.swift:129–137` refreshes widgets/sharing/reminders but not Health reconciliation. Determine whether imported Health UUIDs/backup semantics intentionally define a reset boundary before calling missing historical re-import a defect.
3. **Health authorization completion:** `HealthSettingsSection.swift:32–39` restarts weight observation after permission await without rereading Pro; import checks read enablement, not Pro, at `HealthKitService.swift:262–298`. App service refresh may stop it. Needs an event-order reproduction, not a privacy claim.
4. **Backup decode overlap:** `BackupSettingsSection.swift:76–92` lacks the export's `isWorking` gate and task identity. Two decodes or an export completion can overwrite presentation. Reachability through actual picker dismissal needs confirmation.
5. **Two invite creators:** separate callers may commit/receive in different orders, persisting a revoked response last. Screen-local busy flags do not establish service-wide ordering. Model/reproduce two callers before reporting another defect.
6. **Scope response versus subscription echo:** `SharingPersonScreen.swift:261–292` independently accepts server scope and confirms an in-flight write. Needs a precise echo/write order trace to determine whether stale confirmation can replace a newer server scope.
7. **Root deferred deep link:** `AppRootView.swift:212–227` increments a request token but does not compare it inside the deferred append. Rapid replacement requests could append obsolete routes. SwiftUI delivery timing remains untested.
8. **Onboarding permission cancellation:** `OnboardingFlow.swift:439–456` returns on cancellation without clearing `isRequestingPermission`. Determine whether the same screen instance can reappear after its on-disappear cancellation.
9. **Camera busy cancellation:** `FoodCameraFlow.swift:190–198` distinguishes scene inactivity from navigation away. Navigation cancels work without resetting every busy phase; prove navigation/back reachability before asserting a stuck screen.
10. **Persisted uploading:** `SharingSyncService.swift:73–76` restores upload status without a task. It can represent uploading after process death, but current UI exposure/next-event normalization must be established before claiming user impact.
11. **Widget exchange handle:** **IN FLUX.** `SharedPersonWidgetClient.swift:84–122` shares an exchange by identity/generation, but each waiter unconditionally clears `exchange` and saves its token after awaiting. An older generation may clear a newer handle or overwrite its token cache. Generation-bound usability/publication checks prevent assuming a display leak. Investigate redundant exchanges/cache churn separately.

## Refactor order and approval gates

1. Approve F1/F2 recovery contracts; write isolated failure scenarios **before** implementing a deletion journal or migration protocol.
2. Fix authoritative membership presentation (F3), then invite contract/reconciliation (F4).
3. Let the widget branch land or agree ownership first. Rebase this research against its final revision; carry publication generation and scoped Keychain semantics forward.
4. Decide Q1 retention policy; only then unify grant/Pro/food-retention transitions.
5. Extract small pure transitions from existing upload/auth/dashboard service fields without weakening existing attempt fences.
6. Keep StoreKit facts, local access, cloud submission, and widget Pro persistence as separate regions.
7. Investigate Health/import and repair versioning with isolated, deterministic event traces.
8. Consolidate repeated search/presentation reducers only where the inventory shows the same contract. Do not wrap every view flag in a global architecture.

All proposed line estimates in the inventory are rough changed-line ranges, exclude future validation fixtures, and are not permission to implement. Source replay is cleanly separated from model diagnostics; no production behavior has been changed.
