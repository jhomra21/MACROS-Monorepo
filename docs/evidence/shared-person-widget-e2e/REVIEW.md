# Final implementation and defensive-code review

Media removed in the repo cleanup; retrieve with `git show 074b10994f1b68d9d7a8d6c54ed7effb90d5f1f5:docs/evidence/shared-person-widget-e2e/01-small-shared.png`.

This earlier review missed the findings in REVIEW-OPUS.md. Its conclusions are
superseded by [fix round 1](fix-round-1/REPORT.md), including fresh real widget
taps, retry/duplicate diagnostics, and explicit remaining device gates.

Reviewed the complete feature diff from `8ebd989`, its callers, shared storage,
identity lifecycle, native widget screenshots, and final validation output.
No subagents were used for this completion pass.

## Required review changes 1–11

| Change | Result and primary implementation evidence |
| --- | --- |
| 1. Add-only Keychain scope | `SharingWidgetCredentials.swift`: reads/updates/deletes stay unscoped; only insertion specifies a group. Migration enumerates all attributes/data/references, repairs the duplicate group item from legacy bytes, verifies it, then deletes legacy persistent references. |
| 2. Fresh identity placement | `SharingIdentityStore` supplies the App Group for insertion. The fresh-identity/private-invite test passes. |
| 3. Upgrade/downgrade contract | `31-migration.md` records a simulator build-28 in-place upgrade without re-pairing. TestFlight upgrades/downgrades and distribution provisioning remain untested. Unscoped legacy operations support the intended compatibility, not a proof on hardware. |
| 4. One deployment constant/cutover | Both clients read `SharedAppConfiguration`; cached JWTs include and validate the deployment URL. This branch deliberately remains on pigeon, pending 1.0 approval and the separately authorized production cutover. No production or Worker change. |
| 5. Reuse personDay | Only an optional `includeFoods` argument and conditional food-day read changed in deployable backend source. Existing authorization/validators/default food behavior remain intact. Live dev metadata confirms the optional boolean. |
| 6. Extension-private JWT | Only the widget client creates its ungrouped `widget-session` item. The app never publishes tokens. Moving the SDK-free payload/policy into Shared permits the prewritten expiry checks, not shared JWT storage. |
| 7. One generation/control file | App-only atomic protected `control.json`; generation/person/day cache names; post-await control/Pro/day checks; obsolete-cache purge. No coordinator, revision, separate people cache, authorization-age field, or cross-family reuse. |
| 8. One person route | `calmacrotracker://sharing/person/<id>` resolves a current dashboard person; disabled sharing routes directly to settings. Own-day widgets remain URL-free. Earlier direct-URL screenshots were byte-identical and did not independently prove cold/warm behavior; fix-round-1 contains distinct actual widget-tap captures. |
| 9. Isolation | Entity/query/provider/DTOs are explicitly nonisolated and Sendable. The intent directly conforms to Sendable with nonisolated synchronous members. `intent-concurrency.txt` describes a historical standalone Swift 6 probe with project dependencies stubbed, not a Swift 6 project build. The app and extension are built in Swift 5 mode; existing SharingRemoteClient concurrency warnings remain. |
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
| Migration read-back, duplicate repair and persistent-reference delete checks | **Keep.** The earlier implementation detected duplicates but did not recover divergent bytes. Fix round 1 implements repair and verifies it with a temporary simulator diagnostic, removed from the final source. |
| Network snapshot validation and cache validation | **Keep.** They guard separate external boundaries: a new HTTP response versus a persisted file. Neither proves the other's input. |
| Control checks before cache write and before return | **Keep.** Other processes/app lifecycle may change generation, people, Pro, enabled state or day across awaits and local I/O. A stale write must remain inert and a stale result must not render. |
| Picker/setter membership and provider membership | **Keep.** The setter consumes app input; the provider consumes independently persisted App Intent configuration that can become unresolved. |
| File-name, size and version checks | **Keep.** App Group records and stored intent IDs are persistence boundaries, not invariant local constants. |

The earlier cleanup missed duplicate Default state, publication code, constants,
an alias, and inner privacy modifiers. Fix round 1 removes these proven
redundancies. This is not a project-wide dead-code audit. HTTP 401 refresh,
JWT freshness checks, and shared-only small-ring legibility remain.

## Validation

Final app build, formatting, JS lint, backend TypeScript/20 tests, 76 registered
integration tests, raw dev smoke, and 232 serial iPad tests all pass. StoreKit
class excluded as requested. The four shared-widget tests pass. See
`validation-final.txt` and `smoke-final.txt`.

This earlier sign-off is withdrawn in favor of the fix-round report and its
explicit unverified release gates.
