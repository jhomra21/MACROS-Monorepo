# Shared-person widget validation report

Work in progress on `feat/shared-person-widget`, base `8ebd989` (build 28).
This is not a release sign-off.

The current fixes and new evidence are in [fix round 1](fix-round-1/REPORT.md).
The sections below describe the earlier validation, not new proof.

## Live results

- All five families were installed through SpringBoard, not rendered as app
  previews: small, medium, inline, circular, and rectangular.
- Shared captures show Test B's actual dev-backend totals: 650 calories,
  P40/C80/F20; macro goals 160/220/70 and calorie goal 2200. The viewer's own
  goals differ (2440/180/250/80).
- Changing B's outgoing grant to Nothing produces not-shared states in all five
  families. The App Group directory then contains only `control.json`, proving
  the last-good nutrition file was purged. B's original Macros + Foods grant was
  restored afterward. No global backend Pro flag was changed.
- All five Pro-locked states were captured using the existing Debug Pro
  projection. Debug Pro does not survive entitlement refresh on app foreground;
  it was re-granted through Settings as needed, not persisted by a test bypass.
- Medium stays on Default; small was explicitly set to Test B in native Edit
  Widget. With app Default changed from Test B to None, medium says “Choose a
  default person” and small keeps Test B's 650 calories. Default was restored.
- The earlier direct native URL opens reached Test B, but `27-cold-link.png`
  and `28-warm-link.png` are byte-identical and do not independently prove
  cold/warm behavior. Fix round 1 replaces that claim with distinct captures
  after actual installed-widget taps.
- The installed small layout initially truncated calories. A shared-only ring
  size/type adjustment fixed it; the final screenshot displays `650` fully.
  Own-day dimensions and font defaults remain unchanged.
- Natural refresh was observed with the app force-quit. The extension requested
  `sharing:personDay` at 00:20:45.694Z, 30m 19s after the 23:50:26Z force-quit,
  then emitted a new timeline entry at 00:20:46.379Z. The widget's displayed
  “Updated” advanced from 4:40 PM (`01-small-shared.png` / `02-medium-shared.png`)
  to 5:46 PM (`26-after-refresh.png`). The widget still displayed 650 kcal,
  P40/C80/F20, goals 2200/160/220/70; no separate server-side nutrition change
  was made or observed. See `26-extension-refresh.txt` for exact timestamps and
  the limitation.

Filenames/statuses are in `README.md`. Repeated full-screen captures intentionally
show several families together; the family named by each filename is the
assertion target. Gallery Alex data and the earlier redacted installed placeholder
are diagnostic captures only, never passed live evidence.

## Simulator App Intents dependencies

The repository slim profile disables services required by App Intents widgets.
Recommend keeping `com.apple.linkd` and `com.apple.siriactionsd` available for
App Intents widget testing in a separate profile change.
`tools/sim/macros-slim.json` is unchanged.
The owner's Air and B were not modified during this service experiment.

Owner authorized only `com.apple.linkd` on A:

```sh
cd /Users/juan/.t3/worktrees/cal-macro-tracker/shared-widget && simslim enable 918D29B9-97D3-42C0-9C47-00605E01E8DB com.apple.linkd > build/shared-widget/linkd-enable.log 2>&1
```

`launchctl print-disabled system` inside A reported `com.apple.linkd => disabled`
before and `enabled` after. `launchctl print system/com.apple.linkd` then reported
`state = running`. The enable command reported exactly one service started.
Native Edit Widget became available; `21-person-picker.png` shows Default and
Test B from the actual connected-person cache.

With only linkd enabled, installed nutrition remained blocked. WidgetKit failed before the
provider: `INAppIntent linkAction` cannot reach
`com.apple.siri.VoiceShortcuts.xpc` (bootstrap lookup error 3; Cocoa error 4099),
then returns an empty view collection (CHSErrorDomain 1101). This also happens
after reinstalling the branch in place and adding a fresh real widget. The
runtime launch plist maps that endpoint to `com.apple.siriactionsd`, which
`launchctl print-disabled system` reported disabled. No additional daemon had
been enabled at that point.

A was returned to its committed slim profile before requesting another decision:

```sh
cd /Users/juan/.t3/worktrees/cal-macro-tracker/shared-widget && simslim on 918D29B9-97D3-42C0-9C47-00605E01E8DB --profile tools/sim/macros-slim.json > build/shared-widget/slim-restore-linkd.log 2>&1 && simslim verify 918D29B9-97D3-42C0-9C47-00605E01E8DB --profile tools/sim/macros-slim.json > build/shared-widget/slim-verify-linkd.log 2>&1 && xcrun simctl spawn 918D29B9-97D3-42C0-9C47-00605E01E8DB launchctl print-disabled system > build/shared-widget/simulator-services-restored.log
```

Restore and verification exited 0. Verification: “matches the profile: all
expected disable overrides are applied.” Final overrides show both `linkd` and
`siriactionsd` disabled.

The owner then authorized both dependencies on A, and further services only if
clearly justified by App Intents/WidgetKit errors. Exactly these two were needed:

| Service | Before | Temporary state | Evidence/reason |
| --- | --- | --- | --- |
| `com.apple.linkd` | disabled | enabled | WidgetKit cannot index `SharedPersonWidgetIntent`; missing `com.apple.linkd.registry`, lookup error 3 |
| `com.apple.siriactionsd` | disabled | enabled | `INAppIntent linkAction` cannot reach `com.apple.siri.VoiceShortcuts.xpc`; lookup error 3 and Cocoa 4099 |

```sh
cd /Users/juan/.t3/worktrees/cal-macro-tracker/shared-widget && xcrun simctl spawn 918D29B9-97D3-42C0-9C47-00605E01E8DB launchctl print-disabled system > build/shared-widget/services-before-two.log && simslim enable 918D29B9-97D3-42C0-9C47-00605E01E8DB com.apple.linkd com.apple.siriactionsd > build/shared-widget/services-enable-two.log 2>&1 && xcrun simctl spawn 918D29B9-97D3-42C0-9C47-00605E01E8DB launchctl print-disabled system > build/shared-widget/services-after-two.log
```

Enable exited 0 and reported exactly two services started. Both launch overrides
changed disabled → enabled. Successful independent extension requests and
generation/day-bound nutrition files followed, without any identity replacement
or re-pairing. B did not need service changes.

After the capture, A was restored with `simslim on` and passed `simslim verify`;
the logs are `build/shared-widget/slim-restore-A-final.log` and
`build/shared-widget/slim-verify-A-final.log`. A was shut down. B was restored,
verified, and shut down before this capture; see `slim-restore-B-final.log` and
`slim-verify-B-final.log`. The restore outputs are summarized in
`34-simslim-restore.txt`. `tools/sim/macros-slim.json` was not changed.

Local detailed logs are under `build/shared-widget/`:
`simulator-disabled-services.log`, `linkd-enable.log`,
`simulator-services-after-linkd.log`, `linkd-running.log`,
`intent-helper-failure.log`, `widget-diagnostic.log`,
`slim-restore-linkd.log`, `slim-verify-linkd.log`,
`simulator-services-restored.log`. These are diagnostics, not passing widget data.

## Backend and authentication

Only the optional `personDay.includeFoods` argument and conditional food-day read
changed in deployable backend code. Omitted/true behavior is preserved.
Deployment was dev `energized-pigeon-822` only, using:

```sh
cd /Users/juan/.t3/worktrees/cal-macro-tracker/shared-widget/convex-backend && CONVEX_DEPLOYMENT=dev:energized-pigeon-822 bunx convex dev --once --typecheck enable --tail-logs disable
```

It exited 0 and reported functions ready at 15:09:26 local on 2026-11-02.
No production deployment, Worker update, schema change, global flag flip, build
number change, or App Store upload occurred.

`29-smoke-red.txt` records rejection of the unknown argument before deployment.
`30-smoke-green.txt` records raw HTTP negatives and `includeFoods:false` after
deployment, including a bad-signature JWT rejected at HTTP 401 with
`InvalidAuthHeader`. Function authorization errors returned HTTP 200 error
envelopes; ungranted/ended grants returned `notShared`. Disposable profiles were
cleaned up.

The genuinely signed expired-JWT live cell is **blocked**, as owner-approved.
No signing/admin/deploy credential was obtained. The prewritten token-freshness
test checks expired, 299-second, exactly-300-second, nonfinite, wrong identity,
wrong generation, and wrong deployment cache entries, plus a usable 301-second
entry. The client refreshes inside five minutes and retries a rejected token once.

Convex's [Custom JWT documentation](https://docs.convex.dev/auth/advanced/custom-jwt)
requires `exp` and describes signed tokens valid for a limited period.
The [OIDC documentation](https://docs.convex.dev/auth/advanced/custom-auth) says the
backend ensures token validity. Convex's
[authentication implementation](https://github.com/get-convex/convex-backend/blob/main/crates/authentication/src/lib.rs)
additionally shows the custom-JWT path invoking temporal validation against server
time (five-second tolerance), after signature/issuer/audience checks. This is
primary-source support for server expiry validation, not a substitute for the
blocked live signed-expiry test.

Final dev insights list two OCC retry warnings in `profileDeletion.js:deleteBatch`:
`shareRelationships` at 12:57:22Z and `shareGrantIntervals` at 21:03:26Z on
2026-11-02. The handoff's initial baseline listed only the first, so final
insights must not be called unchanged. Both timestamps precede the 21:09:26Z
additive deployment. Neither concerns `personDay`; their cause is not established
by this task. See `backend-validation.txt`.

## Isolation and release risks

SDK-free DTOs, the entity, query, and provider are nonisolated/Sendable.
The configuration intent retains Sendable and explicit nonisolated synchronous
members, but not type-level `nonisolated`: that spelling propagates incorrectly
to the SDK's reference-backed `@Parameter` storage and produces a Swift 6 error.
SE-0466 excludes direct Sendable conformers from default MainActor inference.
The earlier standalone intent probe used strict Swift 6 flags, warnings-as-errors,
MainActor defaults, off-main access, and stubbed project dependencies. It was not
a project build. The app/extension build uses Swift 5 mode, and existing
SharingRemoteClient Swift-concurrency warnings remain. The changed intent has
not been re-proven by that historical probe.

Offline last-good captures are **blocked** because Network Link Conditioner is
not installed. No alternate network hack was substituted. Live paused coverage
is blocked by the owner-approved no-global-flag rule; existing registered
integration coverage remains green.

Simulator signing has empty entitlement dictionaries and does not prove
distribution provisioning or real first-unlock protection. Release remains
blocked until 1.0 approval, pigeon → puffin cutover, signed-device first-unlock
validation, and distribution entitlement verification. Cached access cannot
notice remote revocation instantly while offline; that limitation is disclosed.

## Completion validation

The final full serial iPad run passed 232 tests, zero failures, including all four
shared-widget tests. The StoreKit class was explicitly excluded. The iPad is
shut down; the result bundle independently confirms the counts. Format, build,
JS lint, backend TypeScript/20 tests, 76 integrations, and the fresh dev HTTP smoke
all passed. See `validation-final.txt` and `smoke-final.txt`.

The earlier defensive review missed duplicated state/publication/constants and
redundant modifiers subsequently identified by REVIEW-OPUS.md. Fix round 1 removes
those specific redundancies; no project-wide absence of dead code is claimed.
TestFlight downgrades remain untested, and simulator checks do not prove
distribution signing or real first-unlock behavior.

B was re-applied to the unchanged slim profile, verified, and shut down.
A's post-capture restore and verification passed, and A was shut down. The only
services temporarily enabled for the feature on A were `com.apple.linkd` and
`com.apple.siriactionsd`; B required no service changes. Both are disabled
again by the unchanged slim profile.
