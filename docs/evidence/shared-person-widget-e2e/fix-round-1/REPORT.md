# Shared-person widget fixes, round 1

Media removed in the repo cleanup; retrieve with `git show 074b10994f1b68d9d7a8d6c54ed7effb90d5f1f5:docs/evidence/shared-person-widget-e2e/fix-round-1/01-legacy-before.png`.

Branch: `feat/shared-person-widget`, rebased onto `origin/main` `da00bef`.
No subagents, production calls, deployments, website edits, uploads, build bumps,
or main merge. No unit tests were added; one existing fixture was adapted to
the consolidated identity-store initializer.

## Confirmed failures and fixes

Paths below are relative to `cal-macro-tracker/`, except the smoke script.
These are scoped fixes, not a claim that the project has no dead code.
The S3/S4/S5/N15 rows include the corrections from [round 2](../fix-round-2/REPORT.md);
the E2E results below remain historical round-1 evidence.

| Finding | Confirmed failure mechanism | Fix |
| --- | --- | --- |
| B1 | Init cached one Keychain failure for the lifetime of the service and disabled widget control. | `Features/Sharing/SharingAuthService.swift:66`: migrate at each token exchange; no cached error or control mutation on failure. |
| S1 | Match-one could hide legacy items; duplicate-add left divergent bytes and failed verification forever. | `Shared/SharingWidgetCredentials.swift:76`: match-all attributes/data/persistent references, unscoped duplicate update from legacy bytes, verify group bytes, delete only legacy references. Only add is access-group scoped. |
| S2 | Any dashboard change while anyone was denied regenerated all widget caches/tokens; repeated denied person-day values did too. | `Features/Sharing/SharingSyncService.swift:324,373`: compare denial-ID sets, coordinate dashboard/person-day transitions, invalidate newly denied or removed IDs only. |
| S3 | Personal food/goal reloads also refreshed shared widgets over the network. Round 1 missed appearance callers. | Personal food/goal reloads stay personal-only. Round 2 adds `Data/Services/WidgetTimelineReloader.swift:14`: appearance edits/backup restore reload personal kinds plus the shared Home Screen kind. Entitlement, control and sign-out events still reload shared kinds explicitly. |
| S4 | View rendering built layout twice and read defaults/photos even for accessories. | `CalMacroWidget/SharedPersonWidgetProvider.swift:53,101`: prepare layout outside rendering; accessories skip appearance, palette and photos. Future midnight/expiry layouts now use zero totals and unknown access. Shared Home Screen widgets currently reuse the personal widget background, but this is an **owner decision pending**, not an approved intentional design. Accessories keep the existing accessory background. |
| S5 | Round 1 globally expired raw Pro access at the billing date, breaking personal backgrounds/photo import and shared access during grace; unseen renewals also locked out. | Round 2 restores raw `Shared/WidgetAppearanceStorage.swift:86`; only `CalMacroWidget/SharedPersonWidgetProvider.swift:228` applies expiry. `Features/Purchases/AppEntitlements.swift:33,128` records the later billing/grace deadline, nil for unknown renewal state, and a 24-hour allowance for verified auto-renewing subscriptions. The shared fail-closed expiry entry remains. Lifetime/legacy records have no expiry. Real StoreKit sandbox grace/renewal remains unverified. |
| S6 | A failed control-file invalidation prevented identity deletion. | `Features/Sharing/SharingAuthService.swift:149`: best-effort invalidation cannot abort credential cleanup. |
| N1 | App-owned states woke every 30 minutes even though only app events could resolve them. | `CalMacroWidget/SharedPersonWidgetProvider.swift:108`: use next midnight, still bounded by entitlement expiry. |
| N2 | Missing/in-flight-invalidated control incorrectly claimed sharing was disabled. | `CalMacroWidget/SharedPersonWidgetProvider.swift:140,241`: neutral Open MACROS status. |
| N3 | Dashboard success cleared the widget-file error immediately. | `Features/Sharing/SharingSyncService.swift:28,568`: keep publication errors separate from dashboard-feed errors, clear only after successful publication. Default write failures also reach the settings error banner. |
| N4/N5 | Default existed twice; its setter duplicated write/purge/reload. | `Features/Sharing/SharingSyncService.swift:14,559,575`: computed Default and one control publication path. |
| N6 | Public dashboard resolution was a redundant alias. | `Features/Sharing/SharingSyncService.swift:61`: expose the original state with private setter. |
| N7 | Keychain identity service/account defaults were duplicated. | `Features/Sharing/SharingIdentityStore.swift:6`: default item is `.identity`; fixture passes an isolated item. |
| N8 | Duplicate persisted person IDs crashed intent lookup. | `CalMacroWidget/SharedPersonWidgetIntent.swift:17`: `uniquingKeysWith`, first item wins. |
| N9 | Intent init and query both set Default. | `CalMacroWidget/SharedPersonWidgetIntent.swift:22,43`: only the query supplies Default. |
| N10 | Byte-at-a-time reads, per-response formatter creation and unbounded Retry-After. | `CalMacroWidget/SharedPersonWidgetClient.swift:45,152`: data response plus 32 KiB check, one static formatter, retry capped at calendar midnight; provider also caps refresh there. |
| N11 | Name-level privacy modifiers duplicated whole shared-widget privacy. | Inner modifiers removed from both daily layout files; whole shared content retains `.privacySensitive()`. |
| N12 | Personal accessory got an empty accessibility value. | `CalMacroWidget/DailyMacroAccessoryWidget.swift:36`: apply freshness accessibility only when present. |
| N13 | Disabled person deep link stacked Sharing settings above the people screen. | `App/AppRootView.swift:232`: disabled case routes directly to one settings destination. |
| N14 | Stored Default had no picker tag before dashboard loaded. | `Features/Sharing/SharingScreen.swift:121`: picker uses the same persisted people as the Default. |
| N15 | Inline nutrition truncated; circular offline label combined too much text. Round 1 accidentally removed the named inline offline marker. | `CalMacroWidget/DailyMacroAccessoryWidget.swift:106`: round 2 uses name + Offline for cached inline entries, name + calories for live entries; circular stays Offline only. Live offline rendering remains unverified, not a visual pass. |
| N16 | Smoke allowed only one hard-coded deployment. | `convex-backend/scripts/sharingSmoke.ts:16`: `MACROS_SMOKE_DEPLOYMENT` allowlist, dev pigeon by default. This run used dev only. |
| N17 | Every dashboard emission rewrote control. | `Features/Sharing/SharingSyncService.swift:575`: compare proposed and persisted control before write/purge; sharing-data changes may still request a reload without rewriting control. |

## E2E results

| Requested check | Status | New evidence and limits |
| --- | --- | --- |
| (a) Legacy build-28-equivalent upgrade | PASS, simulator | `01-legacy-before.png`, `03-migration-retry.png`, `migration-and-retry.txt`. Existing `build/shared-widget/build28` was built from `8ebd989`; origin/main's later commits do not change native app sources. No erase, uninstall, re-pairing or identity replacement. A temporary DEBUG helper found both old/group copies with equal bytes, removed only the group copy, then the baseline still displayed Test B. The branch restored group access; final installed widgets fetched Test B's real dev data. Not TestFlight/distribution proof. |
| (b) B1 same-process retry | PASS | `02-migration-failure.png`, `03-migration-retry.png`, `migration-and-retry.txt`: one injected -25308 failure, then success in PID 1972 without relaunch. Control SHA-1 remained `047a5d945b1b3354369c69fc0ba9b81a7ff66e19` across failure. Temporary DEBUG arguments/helpers/logging were removed, rebuilt and reinstalled before final family captures. |
| S1 divergent duplicate | PASS, simulator diagnostic | `duplicate-recovery.txt`: temporary helper created a divergent scoped group copy alongside the real legacy identity, ran production migration, then required exactly one remaining item in the group and original legacy bytes. Passed. No credential bytes were printed; helper removed. |
| (c) Personal food does not request personDay | PASS, bounded observation | `06-own-food.png`, `own-food-reload-isolation.txt`: A logged Test yogurt, 120 kcal, at 19:46:52 local. Shared access had been allowed before logging. Last extension requests were at 19:46:06; none followed the edit before the deliberate next widget tap at 19:47:19. Control mtime/size remained `1793670253 203`. Foregrounding the app later refreshed the Debug Pro projection, causing app-owned-state timelines, not personDay requests. |
| (d) Invalidate once, unrelated changes do not invalidate | PASS for live not-sharing; BLOCKED for server Pro pause | `07-not-sharing.png`, `08-unrelated-while-denied.png`, `denial-generation.txt`: B changed its real grant to Nothing. A generation changed once, `62C20C6E-EDDF-4809-92DF-971889D86994` → `B75BA775-192B-4A59-9BCE-DB9CA4AB602F`, with dashboard and person-day feeds active. A then changed its own outgoing scope while still denied: same generation. Repeated denied emissions and B's restoration kept it unchanged. Both original scopes were restored. A real server-driven Pro pause requires changing dev-global enforcement, not done in this scoped re-check. The paused condition shares the dashboard denial-set code but is not claimed as a live pass. |
| (e) Small/medium | PASS | `04-small-medium.png`: final production-source build, Test B 650 kcal, P40/C80/F20, actual goals 2200/160/220/70, fetched independently by the extension. |
| (e) Inline/circular/rectangular | PASS | `05-accessory-families.png`: one genuine full-screen capture contains all three installed families. Inline is Test B · 650 cal, not the old overflowing macro string. These are not gallery previews or three duplicated files. |
| (e) Locked privacy redaction | BLOCKED, observation recorded | The simulator's unauthenticated Lock Screen shows name/nutrition, as `05-accessory-families.png` demonstrates. It does not reproduce passcode-authenticated redaction. Whole content remains privacy-sensitive; Settings now says iOS privacy settings control visibility instead of guaranteeing hiding. Real locked-device redaction remains a release gate. |
| (e) Circular offline label | BLOCKED, code fixed | No Network Link Conditioner or live offline capture. Caption now uses just Offline, not name + Offline; no visual offline pass is claimed. |
| (f) Real cold and warm taps | PASS | Installed small widget was tapped by coordinate, not openurl. Cold: app terminated first, then `09-cold-widget-tap.png` showed Test B at 7:44. Warm: existing app stayed alive, Debug Pro was regranted, then `10-warm-widget-tap.png` showed Test B at 7:47. Distinct SHA-1 values are in `widget-taps.txt`; new captures are not the prior identical direct-URL images. A medium tap while its Pro-locked state was current correctly opened Sharing settings, not a named person; this is not used as the warm-person pass. |

The simulator-only diagnostic setup initially hit duplicate-add (-25299), denied
group (-34018), and match-item-list delete (-50) errors. It did not alter identity
bytes. The successful setup reused the existing equal legacy item and used a
persistent-reference delete; production migration uses that verified delete form.
The earlier assertion that legacy was always removed had been overstated: this
round actually found both copies before the fix.

## Validation and scope

- `make quality-format-check`, `make quality-build`, `make lint-js`: PASS.
- `convex-backend`: `bun run check`, 20 tests, PASS; 76 registered integrations, PASS.
- Dev-only disposable HTTP smoke: PASS. Genuinely signed expired-JWT fixture still unavailable.
- Full serial iPad suite: 232 tests, 0 failures, StoreKit class excluded; bounded
  30/45-second options and parallel testing disabled. Result:
  `build/shared-widget/fix-suite-complete.xcresult`. The iPad was shut down.
- No new unit tests. Existing fixture initializer changed only.
- App/extension built in Swift 5 language mode. Existing `SharingRemoteClient`
  concurrency warnings are not fixed or hidden here. The historical standalone
  strict Swift 6 intent probe used stubbed project dependencies and does not prove
  the final project in Swift 6 mode.
- TestFlight upgrades/downgrades, distribution entitlements, first-unlock/prewarm
  hardware behavior, live offline families, and authenticated lock redaction
  remain untested. This is not release approval.
- `simslim on` then `simslim verify` passed on A and B with the unchanged committed
  profile. Both are shut down; the iPad is shut down. Only linkd and siriactionsd
  were temporarily enabled on A. B needed no extra services.
- Evidence scan excludes credentials, tokens and env files; every delivered
  artifact is under 5 MB. Full local build/test logs remain ignored, with compact
  result summaries and filtered extension logs here.

## Repeatable checks

Use A without erasing it. Install the build-28 app in place, confirm the existing
people relationship, install the branch in place and open the same person. For
normal final-source E2E, grant Debug Pro in Settings, return Home, then inspect
the installed widgets. Debug Pro is reset by entitlement refresh on foreground,
so regrant before a later widget-tap check. Log one personal food while Pro is
allowed and compare info-level SharedWidget timestamps/control metadata. On B,
temporarily choose Nothing, observe A, change A's outgoing scope, then restore
both scopes. Never change dev-global flags just to make a paused screenshot.

The removed DEBUG-only migration diagnostics are described above for audit;
they are not permanent launch arguments or production test bypasses.
