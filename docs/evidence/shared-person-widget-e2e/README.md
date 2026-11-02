# Shared-person widget E2E

Branch-only implementation, based on main `8ebd989` (build 28). The plan review's
required changes 1–11 override the original plan. Do not release before 1.0
approval and the production cutover. Only dev `energized-pigeon-822` is in scope.

## Failure modes, written before production code

- Raw `/api/query` must reject strangers, missing authentication, expired JWTs,
  removed relationships, and tombstoned profiles. An ungranted or ended inbound
  direction must return `notShared` with no snapshot or foods.
- `includeFoods:false` must never return foods, even with a live foods grant.
  Omitting the argument must preserve existing callers' food behavior and goals.
- A private build-28 identity must migrate without changing either credential.
  Fresh identities must be added to the App Group; invites must stay private.
  Failed verification must not delete the original. Repeated migration must be
  harmless. Legacy unscoped reads, updates, and deletes must still work.
- Unknown/denied Pro, disabled sharing, locked Keychain, missing identity,
  missing defaults, unresolved explicit selections, removed people, pauses, and
  grant denial must never expose cached nutrition or substitute a different person.
- A late request must not restore data after a generation change. Only today's
  cache may be used. Deployment changes must invalidate extension-private JWTs.
- Transient failures retain eligible last-good data, with its original source
  timestamp. Authoritative decoded errors after one refresh/retry purge it.
- Calendar midnight must blank yesterday's nutrition, including DST days (23/25
  hours), without changing an existing status state. Refresh requests use 30
  minutes or midnight, whichever is sooner; no polling or push.
- Default changes must affect only Default instances. Explicit instances remain
  fixed. The App Intent picker must contain Default and current connected people.
- Both cold and warm person links wait for the current dashboard before routing.
  Own-day widgets must remain URL-free and visually unchanged.
- Names and nutrition must be privacy-sensitive; missing goals never borrow the
  viewer's goals. Each supported family must fit its actual SpringBoard surface.

## Required artifacts

Statuses below start **pending**, not passed. Record filenames and results as
evidence is collected. Every committed artifact must be under 5 MB; larger output
belongs under `build/shared-widget/`.

| Artifact | Expected filenames | Status |
| --- | --- | --- |
| Shared with goals, five families | `01-small-shared.png`, `02-medium-shared.png`, `03-inline-shared.png`, `04-circular-shared.png`, `05-rectangular-shared.png` | pending |
| Not shared, five families | `06-small-not-shared.png` through `10-rectangular-not-shared.png` | pending |
| Pro locked, five families | `11-small-pro-locked.png` through `15-rectangular-pro-locked.png` | pending |
| Offline with last-good, five families | `16-small-offline.png` through `20-rectangular-offline.png` | pending |
| Native Edit Widget Person picker | `21-person-picker.png` | pending |
| Default and explicit before/after default change | `22-default-before.png`, `23-explicit-before.png`, `24-default-after.png`, `25-explicit-after.png` | pending |
| Natural extension refresh, request and entry timestamps | `26-extension-refresh.txt` | pending |
| Cold and warm person links | `27-cold-link.png`, `28-warm-link.png` | pending |
| Raw API negatives, red then green | `29-smoke-red.txt`, `30-smoke-green.txt` | pending |
| Build-28 in-place migration, no re-pairing | `31-migration.md`, `32-migration-before.png`, `33-migration-after.png` | pending |

## Repeatable procedure

Use A `918D29B9-97D3-42C0-9C47-00605E01E8DB` (Test A, never erase),
B `F976E800-DA1F-4F20-B755-DFD964E33975` (Test B), and the iPad runner
`E91B597B-CE57-4C0B-A8A4-51CBDC3386AB`. At most two task simulators besides
the owner's Air may be booted. Shut down devices this task boots.

1. Install build 28 on A, enable sharing, pair with B through + > Create Invite
   and `simctl openurl`, then Start Sharing. Capture the existing relationship.
2. Install the branch over build 28 without uninstalling or re-pairing. Enable
   local Debug Pro. Add real small/medium widgets in SpringBoard; add Lock Screen
   accessory families only if the simulator permits it. Configure Default and
   explicit Person through native Edit Widget.
3. Capture the matrix using actual sharing grants and the existing Pro projection.
   Change the default and prove the explicit instance remains unchanged.
4. Leave the app closed and observe a natural extension request and new entry.
   Open cold and warm person links and verify the resolved person screen.
5. For offline capture use macOS Network Link Conditioner **100% Loss**, if
   installed, restoring it immediately. If absent, mark these cells blocked.
6. Run `CONVEX_DEPLOYMENT=dev:energized-pigeon-822 bun run smoke:sharing`.
   The script uses disposable profiles, raw HTTP queries, and cleans up. Never
   log credentials or JWTs. A genuinely signed expired JWT may be supplied through
   `MACROS_EXPIRED_JWT_FILE`; without it the cryptographic-expiry cell is blocked.
7. Run the repository validators and serial full iPad suite, skipping
   `PurchaseStoreStoreKitTests`. Save sanitized summaries, not user data.

Paused is covered by existing registered Convex integration tests. Do not enable
the deployment-global `sharingRequirePro`. Signed-device first-unlock protection
and distribution entitlements remain release gates, not simulator claims.

Optional notes: tinted/clear/vibrant, long/Unicode names, large text, VoiceOver,
reduced motion, StandBy, and physical midnight rollover. DST/midnight calculations
are checked in prewritten isolated clock tests before their implementation.
