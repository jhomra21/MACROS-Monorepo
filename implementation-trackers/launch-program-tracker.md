# Launch Program Tracker

Owner: parent orchestration thread. Workers: delegated subagents, one per workstream. This file is the single source of truth for scope, decisions, dependencies, and the branch/merge protocol. Per-workstream detail lives in the linked trackers.

## Locked product decisions (2026-10-25)

- Monetization: free core + **MACROS Pro**.
  - `macros.pro.yearly` — $19.99/year, 7-day free introductory trial.
  - `macros.pro.monthly` — $2.99/month, no trial.
  - `macros.pro.lifetime` — $49.99 one-time non-consumable, Family Sharing on.
  - Legacy `fullunlock001` stays recognized as a lifetime entitlement (never sold, but harmless and protects sandbox testers).
- Free forever (no caps on local data): all logging paths (manual, bundled foods, saved foods, saved meals, barcode, label OCR, online packaged search), History and calendar, widgets, daily share card, sharing circle, goal calculator, basic weight log entry, writing nutrition to Apple Health, one daily log reminder.
- Pro: Insights charts (7/14/30 day), weight trend charts, weight import from Apple Health, backup export/import, custom macro ring colors, multiple/smart reminders.
- Lean launch scope. Deferred post-launch: AI photo logging, Apple Watch, iCloud sync, adaptive target suggestions, meal slots, alternate app icons.
- Bundle identifier stays `juan-test.cal-macro-tracker` (registered in App Store Connect). App group, URL scheme, and quick-action types stay as they are.
- Service URLs stay on `workers.dev` and `convex.cloud` for launch. The App Store name "MACROS" is taken; the marketing name will change later, so the in-app brand string must be centralized (WS7) and never hardcoded in new code.
- Apple agreements (paid apps, tax, banking) are complete; sandbox and TestFlight purchases are possible once products exist in App Store Connect (WS9).

## Workstreams

Environment rule (2026-10-25): the Mac runs only work that needs Xcode or a simulator (Swift builds, XCTest, simulator QA, archive/TestFlight). TypeScript, Astro, data pipelines, and documentation run on Windows. A workstream that mixes both (for example WS4) runs on the Mac as one unit.

| ID | Tracker | Branch | Environment | Model / effort | Depends on | Phase |
|---|---|---|---|---|---|---|
| WS1 | [services-hardening-tracker.md](services-hardening-tracker.md) | `launch/ws1-services-hardening` | Windows (TypeScript only) | Luna high, Sol 6.1 medium review | none | 1 |
| WS2 | [pro-subscription-storekit-tracker.md](pro-subscription-storekit-tracker.md) | `launch/ws2-pro-storekit` | Mac | Sol 6.1 medium (payments), Sol review | none | 1 |
| WS3 | [goal-calculator-onboarding-tracker.md](goal-calculator-onboarding-tracker.md) | `launch/ws3-goal-calculator` | Mac | Luna high | none | 1 |
| WS4 | [bundled-food-database-tracker.md](bundled-food-database-tracker.md) | `launch/ws4-food-database` | Mac | Luna high | none | 1 |
| WS8 | [website-legal-metadata-tracker.md](website-legal-metadata-tracker.md) | `launch/ws8-website-legal` | Windows (Astro only) | Luna high | none | 1 |
| WS5 | [weight-health-reminders-tracker.md](weight-health-reminders-tracker.md) | `launch/ws5-weight-health-reminders` | Mac | Luna high, Sol review | WS2, WS3 merged | 2 |
| WS6 | [backup-export-import-tracker.md](backup-export-import-tracker.md) | `launch/ws6-backup` | Mac | Luna high | WS2, WS3, WS5 merged | 2 |
| WS7 | [retention-polish-tracker.md](retention-polish-tracker.md) | `launch/ws7-retention-polish` | Mac | Haiku high or Luna high | WS2, WS4 merged | 2 |
| WS9 | [app-store-connect-products-tracker.md](app-store-connect-products-tracker.md) | `launch/ws9-asc-products` | Windows (docs only) | Luna high | none (manual ASC entry by the owner) | any |
| WS10 | [testflight-release-tracker.md](testflight-release-tracker.md) | n/a (main) | Mac | Luna high + Sol review | all of the above merged | 3 |

Phase 1 runs in parallel. The parent merges Phase 1 branches into `main` in the order WS1, WS8, WS2, WS3, WS4, then starts Phase 2 from the merged `main`.

## Branch and merge protocol (every worker)

1. Start: `git fetch origin`. If the worktree is freshly created, clean, and the branch has no commits of its own, `git reset --hard origin/main`, then `git switch -c <branch>` if the branch name differs from the table.
2. Work only inside the workstream's scope. Do not edit files owned by another active workstream unless the tracker says so; when a shared file (for example `SettingsScreen.swift`) must change, keep the change to a few lines and put new UI in a new file.
3. Commit in small, scoped commits. Match the existing message style (`feat:`, `fix:`, `docs:`, `refactor:`), and include the trailer `Co-authored-by: factory-droid[bot] <138933559+factory-droid[bot]@users.noreply.github.com>`.
4. Before finishing: `git fetch origin && git rebase origin/main`, re-run the validation set, then `git push -u origin <branch>`. Never push to `main`, never force-push a branch you did not create, never rewrite published history.
5. Report: branch, head SHA, files changed, validation results (what ran, what failed, what was skipped), and the QA artifact path.

## Validation standard

- Swift: `make quality-format-check`, `make quality-build`, `make quality-storekit` (if StoreKit files changed), `git diff --check`. Targeted XCTest classes through the documented `xcodebuild ... -only-testing:` command in `AGENTS.md`. Never use simulator `39FE5E39-17CE-4395-B141-9E70EBA594BC`. Prefer a dedicated simulator per workstream: `xcrun simctl create "MACROS-<WS>" "iPhone 17 Pro"`, delete it when done. Run simulator QA through the T3 device tools (`t3-code___device_list`, `device_open`, the returned agent-device CLI for taps and typing, `device_screenshot` for evidence, `device_close` with shutdown) so the simulator streams in the owner's Device panel; fall back to `xcrun simctl io <udid> screenshot` only if device access is off.
- Simulator keyboard: the on-screen keyboard stays hidden while Simulator's "Connect Hardware Keyboard" is on, and Simulator re-enables it per device on boot, so typed values can silently fail. Before booting a QA device: `osascript -e 'quit app "Simulator"'`, `defaults write com.apple.iphonesimulator ConnectHardwareKeyboard -bool false`, then `defaults export com.apple.iphonesimulator /tmp/sim.plist`, `/usr/libexec/PlistBuddy -c "Add :DevicePreferences:<UDID>:ConnectHardwareKeyboard bool false" /tmp/sim.plist` (or `Set … false` if it exists), `defaults import com.apple.iphonesimulator /tmp/sim.plist`. Fallback in a running Simulator: ⇧⌘K. Sheet action buttons can sit below the medium detent; scroll or use the large detent before reporting a tap as failed.
- TypeScript: `bun run check` and `bun test` in the touched package, `make lint-js` from the repo root, `make qa-network` when Worker or Convex contracts change.
- E2E evidence: every workstream that changes user-facing behavior records a repeatable QA pass under `build/<ws>-qa-<YYYY-MM-DD>/QA.md` with the exact steps, simulator, build, screenshots, and observed totals. This mirrors the existing `build/*/QA.md` convention.
- Test philosophy: E2E first. When an isolated test is justified (pure math, parsers, migrations, StoreKit state), write the list of failure modes first, then the tests, then the implementation. Do not bolt unit tests on after the fact.
- Changes log: one concise entry per workstream in `changes-log.md` under a dated heading, following the existing format. No routine validation command lists.

## Design rules (iOS native, Liquid Glass where Apple would use it)

- Read `swift-dev.mdc`. Activate the `swiftui-liquid-glass`, `apple-design`, and `write-swift` skills before UI work when they are available in the environment; `swift-concurrency-expert` for new services.
- Liquid Glass belongs to the control layer that floats above content: toolbars, pinned action bars, floating buttons, sheet actions, pickers in onboarding. Content inside scrolling lists and forms stays on standard grouped backgrounds. Do not wrap list cells in glass.
- Reuse the existing primitives before writing new ones: `AppAccentActionButton`, `BottomPinnedActionBar`, `BottomPinnedDualActionBar`, `GlassEffectContainer`, `appGlassRoundedRect(cornerRadius:)`, `.buttonStyle(.glass)`, `PlatformColors.groupedBackground`, `.inlineNavigationTitle()`, `.appTopBarLeading` / `.appTopBarTrailing`, `errorBanner(message:)`, `keyboardNavigationToolbar(focusedField:fields:)`, `AppNumericTextField`, `.sensoryFeedback`.
- Known rule from `changes-log.md`: a glass control in a compact sheet detent can lose its refractive edge; do not fake the edge with strokes.
- Respect Reduce Motion and Reduce Transparency. Keep Dynamic Type working. Every new interactive element gets an accessibility label.
- Keep state local (`@State`, `@Observable`), no view-model layer, async/await only.

## User prerequisites (outside the repo)

- App Store Connect: create the subscription group and three products (WS9 has the checklist, or provide an App Store Connect API key with the App Manager role so a worker can script it).
- Developer portal: enable the HealthKit capability on the App ID (Xcode automatic signing can do this when the worker adds the entitlement).
- Pick the final marketing name; the in-app string will be one constant after WS7.
- Fill App Store privacy labels from the mapping WS8 produces.

## Status log

- 2026-10-26: Simulator StoreKit repair merged (`40e8353`): the blocker was the iOS 26.4 simulator runtime, not the app; Xcode 26.4 + iOS 27.0 activates the local catalog. `ProEntitlementTests` 18/18; `PurchaseStoreStoreKitTests` 11/14 with four cases (cancellation feedback, legacy unlock, expiry removal, Ask to Buy hang) under investigation on `launch/storekit-test-failures`. Real-price paywall screenshots for in-app purchase review are on `docs/asc-review-screenshots` (`b268110`).
- 2026-10-26: WS10 merged (`7eecb83`): version 1.0 build 7 archived from `44e9551` with automatic signing (HealthKit and app group entitlements present) and uploaded to App Store Connect; `CURRENT_PROJECT_VERSION` is 7 and Xcode manages TestFlight build numbers. Remaining: owner device pass per `build/testflight-qa-2026-10-26/QA.md`, App Store Connect products and submission checklist, backend deploys, WS8 listing placeholders.
- 2026-10-26: WS7 close-out merged (`6dd20ff`): Add Food search-row spacing verified against the pinned action bar, every Pro entry point audited with matching contexts and brand copy, paywall plan rows fixed at accessibility text sizes. All Phase 1 and Phase 2 workstreams are on `main`; WS10 (TestFlight) is next.
- 2026-10-26: WS6 merged linearly (`22adef4`; three commits, two review rounds): versioned JSON backup and log CSV export, atomic Merge/Replace import in a background `ModelActor` with whole-document validation before any mutation, bundled-food references restored by `sourceIdentifier`, Pro-gated Backup section. Simulator E2E (Files export, uninstall/reinstall Replace, overlapping Merge, document parity) passed; evidence in ignored `build/ws6-qa-2026-10-26/`. WS7 close-out is in progress on `launch/ws7-closeout`.
- 2026-10-26: Merged `main` validated on the Mac at `4900a9e`: formatting, build, StoreKit config, and JS lint pass; 100 XCTests across 13 classes with 98 passing and the two known `LocalConfidenceTests` Vision baseline failures; Windows `tools/food-db` typecheck and tests and oxlint pass. Fresh-install UI smoke with the T3 device tools passes (goal setup in metric and imperial, bundled food log, dashboard, History, free Insights with weight summary, Settings sections, Insights paywall); evidence in ignored `build/main-validation-2026-10-26/`. WS6 is applying review fixes (atomic Replace in a `ModelActor`, bundled-food remap by `sourceIdentifier`, sheet dismissal).
- 2026-10-26: Phase 1 and Phase 2 merged linearly into `main` except WS6: WS1, WS8, WS9 docs, WS3 (`1accf82`), WS2 (`a0d6a64`), WS7 (`3461878`), WS5 (`e6d6687`, five review rounds; Health nutrition operations run through one serial queue with enqueue-time snapshots), WS4 (`4900a9e`, five review rounds; bundled foods reconcile by stable `fndds:<food code>` / `legacy:<slug>` identifiers with single-claim, deterministic backfill and capped names). WS6 is in progress on `launch/ws6-backup`; merged-`main` validation is running on the Mac. Unverified items are consolidated in `testflight-release-tracker.md`.
- 2026-10-25: WS2 local StoreKit repair remains blocked by a pre-existing setup failure. Fresh iOS 26.4 (23E244) simulator, shutdown-all/erase retry with live `storekitd` logging, and a minimal XCUITest launch all failed to activate local products on Xcode 26.4 (17E192), macOS 27.0.1 (26A434). Error: `SKInternalErrorDomain Code=3`; `OctaneSaveConfigurationRequest` not entitled. T3 screenshot confirms all three plans unavailable under XCUITest. No payment assertions waived or production signing changed. Apple references FB22237318 / FB22500243; newer matching toolchain/runtime or WS9 device sandbox/TestFlight remains required. Full commands and evidence: `build/ws2-qa-2026-10-25/QA.md`; WS2 tracker updated.
- 2026-10-25: Program created. Decisions locked. Phase 1 dispatch pending.
- 2026-10-25: Launch decisions applied: `macros.pro.lifetime` is $49.99 (was $39.99); Apple Health split, with writing nutrition free and weight import from Apple Health Pro (`PaidFeature.healthWeightImport`); Terms of Use governed by the State of Texas, USA, and applicable US federal law. `docs/research/monetization-market-validation.md` informed these decisions.
