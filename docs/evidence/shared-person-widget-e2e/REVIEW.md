# Final implementation and defensive-code review

Reviewed the complete feature diff from `8ebd989`, its callers, shared storage,
identity lifecycle, native widget screenshots, and final validation output.
No subagents were used for this completion pass.

## Required review changes 1–11

| Change | Result and primary implementation evidence |
| --- | --- |
| 1. Add-only Keychain scope | `SharingWidgetCredentials.swift`: reads/updates/deletes stay unscoped; only insertion and migration verification/deletion specify a group. Verified legacy bytes are copied before scoped deletion. |
| 2. Fresh identity placement | `SharingIdentityStore` supplies the App Group for insertion. The fresh-identity/private-invite test passes. |
| 3. Upgrade/downgrade contract | `31-migration.md` records a build-28 in-place upgrade without re-pairing. Byte equality, idempotence, and legacy operations pass in the prewritten Keychain tests. Build-25 downgrade behavior is justified by unscoped operations, not claimed as a separate TestFlight run. |
| 4. One deployment constant/cutover | Both clients read `SharedAppConfiguration`; cached JWTs include and validate the deployment URL. This branch deliberately remains on pigeon, pending 1.0 approval and the separately authorized production cutover. No production or Worker change. |
| 5. Reuse personDay | Only an optional `includeFoods` argument and conditional food-day read changed in deployable backend source. Existing authorization/validators/default food behavior remain intact. Live dev metadata confirms the optional boolean. |
| 6. Extension-private JWT | Only the widget client creates its ungrouped `widget-session` item. The app never publishes tokens. Moving the SDK-free payload/policy into Shared permits the prewritten expiry checks, not shared JWT storage. |
| 7. One generation/control file | App-only atomic protected `control.json`; generation/person/day cache names; post-await control/Pro/day checks; obsolete-cache purge. No coordinator, revision, separate people cache, authorization-age field, or cross-family reuse. |
| 8. One person route | `calmacrotracker://sharing/person/<id>` resolves a current dashboard person; other action states use existing Sharing. Own-day widgets remain URL-free. Cold/warm direct native URL captures pass; they are not claimed as actual widget-tap recordings. |
| 9. Isolation | Entity/query/provider/DTOs are explicitly nonisolated and Sendable. **Deliberate spelling deviation:** the configuration intent directly conforms to Sendable, with nonisolated synchronous members, instead of type-level nonisolated. The latter incorrectly propagates to SDK reference-backed `@Parameter` storage. The strict Swift 6 off-main compiler probe passes without unsafe annotations or settings changes; see `intent-concurrency.txt`. |
| 10. Release/privacy | The tracker and history retain approval/cutover/signing gates. Privacy-label documentation adds goals and recipient caching; names/nutrition are privacy-sensitive. No website, upload, bump, or main merge. |
| 11. Focused E2E | All installed families have shared/denied/Pro-locked screenshots, plus picker, Default isolation, migration, links and raw API negatives. **Explicit gaps:** Network Link Conditioner is absent, so all five offline cells are blocked; genuinely signed expired JWT unavailable; no deployment-global Pro flag flip. Natural-refresh outcome is recorded separately, never inferred from app reloads. |

The simplification table is implemented: no new server query/helper/error codes,
app-published token, conflicting-identity branch, extra deep-link routes, or
cross-family reuse. Midnight blank entries, fail-closed unknown Pro, inline
networking with last-good, isolated paused-state coverage, and signed-device
first-unlock release gates remain.

## Defensive-code review

Scope: credentials, app publication/lifecycle, storage, extension transport and
provider, layouts, routing, backend optional argument and smoke.
Reason: remove only redundancies proven by the real contracts, not protective
checks around external data or asynchronous state.

| Candidate | Proof and decision |
| --- | --- |
| Migration read-back, duplicate-add recovery and scoped delete checks | **Keep.** Keychain operations can fail independently or a prior migration can stop after copying. These protect persisted identity. |
| Network snapshot validation and cache validation | **Keep.** They guard separate external boundaries: a new HTTP response versus a persisted file. Neither proves the other's input. |
| Control checks before cache write and before return | **Keep.** Other processes/app lifecycle may change generation, people, Pro, enabled state or day across awaits and local I/O. A stale write must remain inert and a stale result must not render. |
| Picker/setter membership and provider membership | **Keep.** The setter consumes app input; the provider consumes independently persisted App Intent configuration that can become unresolved. |
| File-name, size and version checks | **Keep.** App Group records and stored intent IDs are persistence boundaries, not invariant local constants. |

No high-confidence redundant guard, duplicate validation on the same proven
input, dead code, duplicate security check, or new parallel layout renderer was
found. No speculative cleanup was applied. The existing pending implementation
fixes were retained: HTTP 401 refresh, tested JWT freshness policy, Swift 6
intent isolation, and shared-only small-ring legibility.

## Validation

Final app build, formatting, JS lint, backend TypeScript/20 tests, 76 registered
integration tests, raw dev smoke, and 232 serial iPad tests all pass. StoreKit
class excluded as requested. The four shared-widget tests pass. See
`validation-final.txt` and `smoke-final.txt`.

LGTM for branch integration with the recorded E2E blockers and release gates,
not release approval.
