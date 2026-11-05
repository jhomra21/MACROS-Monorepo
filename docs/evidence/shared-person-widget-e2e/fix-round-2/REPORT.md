# Shared-person widget fixes, round 2

Media removed in the repo cleanup; retrieve with `git show 074b10994f1b68d9d7a8d6c54ed7effb90d5f1f5:docs/evidence/shared-person-widget-e2e/fix-round-2/00-personal-native-before.png`.

2026-11-03, `feat/shared-person-widget`, starting at `50fa3b9`.
The cancelled worker's two finished commits were retained: `359a54c` (NB1)
and `a3bac47` (NS1/NS2). `102ccf9` fixes all ten nits.
No subagents, backend changes, deployment, production access, build bump, or merge.

## Findings confirmed and fixed

Paths below are relative to `cal-macro-tracker/`.

| Finding | Confirmed failure | Smallest scoped fix |
| --- | --- | --- |
| NB1 | The global getter expired `.allowed` at a past billing date even though grace kept app Pro enabled. Personal backgrounds and photo import both read that getter. | `Shared/WidgetAppearanceStorage.swift:86` is raw again. `CalMacroWidget/SharedPersonWidgetProvider.swift:228` alone checks expiration, including its in-flight recheck. `Features/Purchases/PurchaseStore.swift:226,237,257` carries verified grace and auto-renew facts. `Features/Purchases/AppEntitlements.swift:33,113,128` passes a separate widget deadline through the resolution and stores it: later billing/grace date in grace, nil for unknown renewal state, no deadline for lifetime/legacy. |
| NS1 | A person-day-only denial survived an active dashboard emission, so the later revoke was subtracted as already denied and did not rotate generation. | `Features/Sharing/SharingSyncService.swift:324-326`: compute newly denied first, then intersect person-day denials with the dashboard denial set. Same-day trace below. |
| NS2 | A decode error aborted both control publication and sign-out invalidation before either could overwrite the file. | `Features/Sharing/SharingSyncService.swift:580` and `Shared/SharedPersonWidgetStorage.swift:30` use `(try? loadControl()) ?? nil` (with the storage qualifier at publication). Write/protection errors still propagate to the existing error handling. |
| Nit 1 | Ring/background/backup callers refreshed only personal kinds. | `Data/Services/WidgetTimelineReloader.swift:14` adds appearance reload for personal kinds plus the shared Home Screen kind. Callers: `App/MacroRingColorPickerPresenter.swift:17`, `Features/Settings/SettingsScreen.swift:170,251`, `Features/Settings/WidgetBackgroundSettingsSection.swift:151,156,185,191,227`, `Features/Backup/BackupSettingsSection.swift:134`. Food/goal-only reloads stay personal-only. |
| Nit 2 | Mid-flight invalidation reused `.openApp`, whose next refresh was midnight. | `CalMacroWidget/SharedPersonWidgetProvider.swift:8,110,243` gives it a distinct `.invalidated` status with the same copy and the normal 30-minute refresh. Missing control remains a real `.openApp` with midnight refresh. |
| Nit 3 | Nil intent person produced `.unavailable` until midnight. | `CalMacroWidget/SharedPersonWidgetProvider.swift:159` maps nil to `"default"`. |
| Nit 4 | Named inline cached data looked live. | `CalMacroWidget/DailyMacroAccessoryWidget.swift:106` shows name + Offline when cached, name + calories otherwise. |
| Nit 5 | `data(for:)` buffered arbitrary response sizes before the limit. | `CalMacroWidget/SharedPersonWidgetClient.swift:152-169` reads response headers before the body, rejects known lengths over 32 KiB, and caps streamed bodies even with unknown or dishonest lengths. 429/5xx bodies are not read. |
| Nit 6 | Persistent migration errors aborted authentication despite a usable legacy identity. | `Features/Sharing/SharingAuthService.swift:68-73` catches/logs the migration error and continues to `loadOrCreate`. The widget can still request reconnection; migration retries on later exchanges. |
| Nit 7 | Default change invalidated every profile cache and extension token. | `Features/Sharing/SharingSyncService.swift:564` publishes without generation invalidation. Control comparison still reloads widgets; `isCurrent` checks Default. |
| Nit 8 | Future expiry retained allowed photo access; midnight retained today's layout totals. | `CalMacroWidget/SharedPersonWidgetProvider.swift:53,108,128` prepares both future entries with unknown access and no snapshot, yielding zero totals/empty goals without a second photo decode. |
| Nit 9 | AppRootView's required sharing environment was absent from the preview. | `ContentView.swift:19` injects SharingSyncService. |
| Nit 10 | Disabling sharing while the person link screen remained stacked left a perpetual spinner. | `Features/Sharing/SharingPersonLinkDestination.swift:10-17` displays Sharing is off with an Open Sharing deep link before dashboard/loading branches. |

No findings were rejected. The final source diff was reviewed for duplicate
logic, redundant guards and unused code; no further cleanup was needed.

### NB1 renewal trade-off

The comment at `Features/Purchases/AppEntitlements.swift:38` records the choice:
verified `.subscribed` + `willAutoRenew` gets a **24-hour allowance** after billing
expiry. This avoids an immediate monthly lockout for an unseen renewal while
bounding stale shared-widget eligibility. Known nonrenewing subscriptions get no
allowance. Grace uses Apple's later grace deadline without another buffer.
If renewal status is unknown, currentEntitlements remains authoritative and no
expiration is guessed. After a known deadline plus allowance, shared widgets
still require the app to refresh StoreKit; this is not a server entitlement check.
Personal background/photo-import access never expires merely from this record.

### NS1 same-day trace (code trace, not a new live revoke test)

Let B be active in the dashboard, and let G0 be the generation.

1. Person-day emits notShared: person-day denials `{B}`, generation G1.
2. B re-shares while the person screen is closed. The next active dashboard has
   `denied = {}`. Newly denied is empty, then intersection clears person-day
   denials to `{}`. Generation remains G1.
3. B revokes/pauses that same day. Dashboard `denied = {B}`; previous dashboard
   and person-day denial sets are both empty. Newly denied is `{B}`, so
   `publishWidgetControl(invalidate: true)` rotates to G2.
4. Repeated denied emissions see B in the dashboard set, so no further rotation.

This prevents offline fallback from using G1 data after the observed revocation.

## Focused simulator E2E

Only A, iPhone 17 `918D29B9-97D3-42C0-9C47-00605E01E8DB`, was used for UI.
It was never erased/uninstalled/re-paired. Existing Test B identity/grants were
preserved. The existing small explicit-Test-B and medium Default widgets were
retained. One personal small widget was added on page 1 for the regression check.
AXe CLI calls explicitly passed A's UDID; XcodeBuildMCP UI tools were not used
because their loaded schemas do not accept a simulator ID.

| Check | Result and evidence |
| --- | --- |
| Personal background with past Pro expiration and grace | PASS with temporary DEBUG fixture, not a real sandbox purchase. `00-personal-native-before.png` is the original native widget. `01-personal-past-expiry-grace.png` shows the same personal widget with the blue color background. `past-record.json` proves allowed + past stored expiration. `grace-probe.txt` records billing `1793719126.120261`, grace/resolved widget deadline `1793809126.120261`, app hasPro true, raw access allowed. |
| Shared expiry remains scoped/fail-closed | PASS: `02-shared-expired-record.png` shows shared widgets asking to check Pro for that deliberately expired projection while the personal widget in 01 retains its background. |
| Shared widgets still render Test B | PASS for live **no-data state**, not fresh nutrition totals. After removing the hook, rebuilding/reinstalling the final source, and granting ordinary Debug Pro, `03-shared-test-b-final-source.png` shows small + medium with Test B and No macros shared today. The app's real person screen agreed. Nothing was seeded or backdated to make this look like a nutrition pass. |
| Ring edit reloads shared Home Screen kind | PASS for reload, not visible colored nutrition rings. `04-ring-color-picker.png` and `05-ring-color-setting.png` show the real protein picker changing blue to yellow. `ring-action.json` records `#FEFB41` and action start 16:24:34 UTC. `ring-after-extension.txt` records exactly two new provider requests/timelines at 10:25:23.992/24.174 local (16:25 UTC), before the preceding 30-minute refresh deadlines; 06 shows both installed shared widgets. The other shared accessory kinds were not appearance-reloaded. Test B has no snapshot today, so a visual ring-pixel change is not claimed. |

### Temporary hook and cleanup

The only temporary source change was inside the already DEBUG-only
`Features/Settings/DeveloperSettingsSection.swift`: an environment reference to
AppEntitlements and a Probe Billing Grace button, with OSLog/StoreKit imports.
The action resolved a yearly auto-renewable grace fact with billing `now - 1h`
and grace `now + 24h`, called the production entitlement updater, selected color
`#243B6B`, then deliberately overwrote the widget record with allowed + the past
billing date. That last override tests compatibility with an old/past projection,
not the normal new grace deadline. It logged only times/access/color, then
reloaded appearance and shared widgets. No credentials, food, grants or network
responses were modified. The first diagnostic build needed a missing StoreKit
import; it was corrected before the probe was run.

The hook/imports/environment reference were removed, `git diff --exit-code`
verified the developer file exactly matched committed source, and the final
normal app/extension was rebuilt and reinstalled before captures 03–06.
No probe is committed or left installed. Restore evidence records default ring
colors, native background, and ordinary allowed Debug Pro without expiration.
The extra personal widget remains usable. No user data was replaced.

### Simulator restoration

Only com.apple.linkd and com.apple.siriactionsd were temporarily enabled through
`simslim enable`, without saving/changing the profile. The initial manual
launchctl kickstart found no loaded service; simslim performed the proper
bootstrap. `simslim on` then `simslim verify` used the unedited
`tools/sim/macros-slim.json`. Verification: **matches the profile: all expected
disable overrides are applied** (`simslim-restore.txt`, `simslim-verify.txt`).
A was shut down and its lock released immediately after restoration. The iPad
was independently claimed after two 120-second lock waits, tested, shut down,
and released by the test command's trap. No other worker's locks/services or
reserved devices were modified.

## Validation and test changes

- `make quality-format-check`: PASS (`format-check.txt`).
- `make quality-build`: PASS, including the final hook-free rebuild
  (`validation.txt`). Build is not test evidence.
- `make lint-js`: 93 files, zero warnings/errors (`lint-js.txt`).
- `cd convex-backend && bun run check`: TypeScript + **20 passed, 0 failed**,
  37 expectations (`backend-check.txt`). No backend source changed.
- Full serial iPad suite: **232 passed, 0 failed, 0 skipped**,
  PurchaseStoreStoreKitTests explicitly excluded. Xcode at
  `/Applications/Xcode-26.4.1.app/Contents/Developer`; parallel testing disabled,
  test timeouts enabled, default allowance 30 seconds, maximum 45 seconds.
  Primary local result `/tmp/shared-widget-r2-suite.xcresult`;
  compact primary summary `ipad-suite-summary.json`.
- No new unit tests were written. Before the production fix, the prior worker
  adjusted only these existing tests for the intentional new projection policy:
  `ProEntitlementTests.testReducerPreservesGraceEvenAfterBillingExpiration`
  (grace widget deadline), `testReducerDoesNotGuessExpiryWhenRenewalStatusIsUnavailable`
  (nil widget deadline), and
  `WidgetAppearanceStorageTests.testStorageRoundTripsAndReaderDoesNotRepairMissingRecord`
  (raw allowed access despite a persisted past expiration).
- No StoreKit sandbox renewal/grace, live offline families, passcode redaction,
  signed/TestFlight migration, or fresh Test B nutrition-ring rendering was
  verified in this round. Those earlier release limits remain open.

## Report corrections and product decision

The historical round-1 S3/S4/S5/N15 rows now name the appearance omission,
grace/unseen-renewal regression, accidental inline marker removal and evidence
limits. **Owner decision pending: shared Home Screen widgets reuse the personal
widget background.** This is current implementation, not an approved product
choice. Nothing in this report is release approval.

Every delivered file is below 5 MB. Full build/test logs and the xcresult remain
local; the folder contains compact summaries and filtered credential-free logs.
Artifact sizes/SHA-256 and the scoped secret scan are recorded separately.
