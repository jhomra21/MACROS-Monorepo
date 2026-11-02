# Shared person screen: no flash when reopening

Branch `fix/sharing-ui-ring-polish`. Dev Convex `energized-pigeon-822` only (never prod). Simulators: iPhone 17 `918D29B9` (device A, "Test A") and iPhone 17e `F976E800` (device B, "Test B"), iOS 27.0.

## Root cause (confirmed)

`SharingPersonScreen`'s `.task(id:)` set `personDay = nil` at the start of every run, then awaited `sharing.personDayUpdates`. That call ran `authenticateForOperation()`, and that always ran `remoteClient.authenticate`, which is `SharingAuthService.authenticate` -> `client.loginFromCache()` -> `SharingAuthProvider.tokenExchange`, a `POST v1/token` to the auth worker on **every call** (no local session reuse; `loginFromCache` is not cached here). A new `sharing:personDay` Convex subscription then had to deliver its first value. Until it did, the screen rendered the empty-state card, then swapped to rings and foods. Nothing survived between visits.

One correction to the brief: the dashboard snapshot also needed a fallback on the first visit, not just a cache. The server already returns `snapshot` per person in `sharingDashboard`, so the first visit now draws the rings from that.

## Fix

- `SharingSyncService` owns an in-memory `[profileId + dayKey: SharingPersonDay]` cache. `cachePersonDay` stores only `.shared` values (a `paused` or `notShared` value evicts) and refuses writes when device sharing is off.
- Eviction, all in the same places the dashboard data is already cleared or updated:
  - `receiveDashboard` prunes: person removed, `incomingActive == false`, or `connectionPaused` drops the entry; `foodsShared == false` keeps the macros but empties the foods.
  - `stopDashboardSubscription(clearDashboard: true)` clears everything. That covers day rollover (`startDashboardSubscription` with a new day), `disableLocalSharing` (sign-out, delete profile, stop on device), and sharing off.
  - `removePerson` drops that person's entries.
  - The screen reads with `dayContext.today`, and the key includes the day, so an old day can never be read.
- `SharingPersonScreen` no longer owns `personDay`. It reads the cache, falls back to `currentPerson.snapshot` for the rings, shows a `ProgressView` (not "No foods" or "isn't sharing with you") while the first value is pending, and writes each live value into the cache. It no longer clears anything at the start of `.task`.
- `authenticateForOperation` skips the token exchange when the current identity generation is already authenticated (set by a successful exchange or by the dashboard subscription's authentication). `enableSharing` and `updateDisplayName` pass a display name and still always authenticate. The identity-generation checks are unchanged; a new identity gets a new generation, so the skip no longer applies. The Convex client refreshes its own token through its `loginFromCache` bridge.

## Failure modes (written first), and their tests

All in `SharingReliabilityTests` (8 new tests; total 225, all passing).

| Failure mode | Test |
| --- | --- |
| Flash on re-entry (no last-known day) | `testReopenedPersonReadsLastKnownDayAndOnlyForThatPersonAndDay`; E2E below |
| A wrong person shown, or a wrong day | same test (other profile and next day return nil) |
| Stale after share is revoked, paused, or the person is removed | `testDashboardEvictsRevokedPausedAndRemovedPeopleAndStripsFoodsWhenScopeDrops`, `testNonSharedValueEvictsCachedDay`, `testRemovePersonDropsCachedDay` |
| Foods shown when scope is macros-only | `testDashboardEvictsRevoked...StripsFoods...` (macros kept, foods empty); E2E below |
| Stale after midnight | `testDayRolloverDropsCachedDays` |
| Stale after sign-out or sharing disabled | `testSignOutAndDisabledSharingDropCachedDaysAndRefuseNewOnes` |
| Repeat token exchange | `testPersonDayUpdatesSkipsAuthenticationWhileIdentityIsUnchanged`, `testDashboardAuthenticationAlsoCoversPersonDayUpdates` |

## Convex (dev, `energized-pigeon-822`)

- The Convex MCP in this session had no deployment configured ("No CONVEX_DEPLOYMENT set"), so I used the CLI with `CONVEX_DEPLOYMENT=dev:energized-pigeon-822`.
- `bunx convex insights`: **"No issues found. The deployment is healthy over the last 72 hours."** No read amplification, OCC, or limit insights for `sharing:personDay` or `sharing:sharingDashboard`. Saved in `convex-insights.txt`.
- Latency from `bunx convex logs --history 400 --success` (`convex-logs-personDay-dashboard.txt`; server execution time, which includes the E2E session):
  - `sharing:personDay`: n=43, min 1 ms, median 1 ms, p90 41 ms, max 116 ms.
  - `sharing:sharingDashboard`: n=123, min 1 ms, median 13 ms, p90 66 ms, max 310 ms.
- `personDay` reads (`convex/sharing.ts`): one profile by key, the other profile, relationships by `by_pair_key`, `openGrantBetween` (`by_from_to_ended`), `dailySnapshots` and `sharedFoodDays` (`by_owner_day`, `.unique()`), plus the settings row and optionally `proStatus` (`by_profile`). Every read is indexed and bounded. The only `.collect()` is on `by_pair_key` (one pair, a handful of rows). No wasteful index or read found, and no backend bug, so I changed and deployed nothing.
- Client-visible cost before the fix was not the query. It was the token exchange: `POST v1/token` round trip to the auth worker about 0.13 to 0.15 s from this Mac (measured with an invalid body, 5 samples), plus a fresh subscription.

## E2E on two simulators against dev Convex

Pairing: the `docs/evidence/sharing-v2-e2e/REPORT.md` named in the brief does not exist on `origin/docs/asc-review-screenshots` (only screenshots are there). I paired through the UI: sharing on for both, Create Invite on A from the `+` menu, token read from A's Sharing settings and typed into B's Accept Invite, then B logged Chicken and rice bowl and Banana (705 kcal, P 49, C 97, F 14) and set A's scope to Macros + Foods.

Recordings are of A: open Test B, wait 3.5 s, back, wait 2 s, four times. "Before" is a build of `origin/main` (9761515, old blue-link list); "after" is this branch. Both ran in the same session, same data, app already warm (dashboard loaded).

Empty-state frames, counted by `count_empty.py` (pixel difference of the Today card against a known empty-state frame, 30 fps, 1.6 s window from each tap):

| Entry | Before (origin/main) | After (this branch) |
| --- | --- | --- |
| 1 | 8 frames (0.27 s) | 0 |
| 2 | 7 frames (0.23 s) | 0 |
| 3 | 5 frames (0.17 s) | 0 |
| 4 | 6 frames (0.20 s) | 0 |
| Cold (app relaunched, empty cache) | not recorded | 0 |

- Before: `before-warm/sheet-enter{1..4}.png`. Each sheet is 30 tiles at 15 fps, left to right and top to bottom, starting at the entry. The tiles after the push show "No macros shared today" for about 4 tiles, then rings and foods pop in.
- After: `after-warm/sheet-enter{1..4}.png`. The first tile that shows the person screen already has rings and legend, and the foods appear in the same position with no layout jump. No empty-state tile on any re-entry.
- Cold: `after-cold/sheet-cold-entry.png`. Rings and legend from the dashboard snapshot from the first push frame.
- Small videos: `*/video-small.mp4` (360 px wide). Full-size `.mov` files stay in `build/`.

Scope change: with A on Test B's screen showing both foods, B set the scope to Macros. On A the foods were gone at the 5 s check (`scope/a-1-foods-visible.png`, `scope/a-2-live-after-macros-only.png`). Two re-entries right afterwards, with the cache present, show rings and no Foods section (`scope/a-3-reentry-1.png`, accessibility check: 0 food nodes both times).

## Create Invite from the `+` menu (real, dev Convex)

On A, `+` -> Create Invite created a new invite (expires Nov 8, 2026, 7:06 PM, a new token), and the system share sheet opened with the link. The token appeared in A's Sharing settings and B accepted it ("Start Sharing?" -> pairing worked, A then listed Test B). I did not pick a share target. Note: the dev settings table is empty, so `sharingRequirePro` is false on the server; the Pro gate here is client-side only. A used the DEBUG "Grant Debug Pro" button.

## Validation

- `make quality-format-check`: clean.
- `make quality-build`: succeeded.
- Full suite on iPad `E91B597B`, serial, AGENTS.md options, skipping `PurchaseStoreStoreKitTests`: 225 tests, 0 failures (217 plus the 8 new). The one flaky dashboard-subscription test did not fail.

## Not verified

- Not run on a real iPhone. The owner's report came from a real device on a real network; these runs used simulators on this Mac's network, where the flash lasted 0.17 to 0.27 s.
- The loading placeholder (spinner while foods arrive) never showed on video. Data arrived within the push animation on this network, so I did not capture it, and I did not throttle the network.
- Pause by Pro loss and removal were covered by unit tests only, not on devices.
- Day rollover and sign-out were covered by unit tests only.
- The share sheet was not taken to a real recipient.
- Side effects left on the simulators: device B's text size was reset to default, A has Debug Pro and sharing on, both are paired in dev Convex with B's two logged foods, and B's scope for A is Macros. Dev data was not cleaned up.
- Tooling notes: `axe tap` does not flip a SwiftUI switch on these simulators (touch down/up with a hold does), and this ffmpeg has no `drawtext`, so the contact sheets are not labelled.
