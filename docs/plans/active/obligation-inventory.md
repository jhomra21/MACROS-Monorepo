# Plan obligation inventory

Snapshot: 2026-11-05 before the tracker moves. Six unchecked boxes and 195 prose/checkbox candidate lines were scanned conservatively; the exact per-file counts appear below. Some candidates are past failures, requirements, or resolved findings, not new blockers. Nothing in this inventory closes them. See [owners and closure conditions](release-follow-ups.md).

## app-store-connect-products-tracker.md

Moved source: [app-store-connect-products-tracker.md](app-store-connect-products-tracker.md). Before/after unchecked count: 0/0.

- Original line 12: - Each product needs a review screenshot (use the paywall screenshot from WS2's QA artifact) and review notes before submission. The first subscription must be submitted together with a new app version.

## architecture-refactor-implementation-tracker.md

Moved source: [architecture-refactor-implementation-tracker.md](../archive/architecture-refactor-implementation-tracker.md). Before/after unchecked count: 0/0.

- Original line 11: - Build discipline: macOS builds are intentionally deferred while the iOS app is the active product focus.
- Original line 34: - The action stays widget-target-safe and does not reference app-only nutrition types unavailable to the widget target.
- Original line 46: - Provider clients should still preserve provider-specific unavailable-configuration errors.
- Original line 48: - Remote lookup behavior, endpoints, and response handling remain unchanged.
- Original line 53: - Internal reusable-food lookup helpers can remain in the query file.
- Original line 151: - [x] Preserve provider-specific unavailable-configuration errors.
- Original line 179: - [x] Document that macOS builds are deferred unless explicitly requested.
- Original line 188: - Post-implementation simplify accepted scoped cleanup for `FoodDraftLoggingAction` normalization ownership, an unused sharing import, food-only secondary-repair normalization, and repeated meal repository construction; the suggested `NutritionMath` reuse was intentionally skipped because `FoodDraftBehavior.swift` also compiles in the widget target where `NutritionMath` is unavailable.
- Original line 190: - Final follow-up validation passed `git diff --check`, `make quality-format-check`, and `make quality-build`.
- Original line 208: ## Follow-Up Candidates

## backup-export-import-tracker.md

Moved source: [backup-export-import-tracker.md](../archive/backup-export-import-tracker.md). Before/after unchecked count: 0/0.

- Original line 7: Implementation is complete. Formatting, build, `BackupRoundTripTests` (15/15), and `MealSchemaMigrationTests` (1/1) pass. Prior simulator QA verified export to Files, uninstall/reinstall, Replace and Merge automatic dismissal, and two-day meal/weight/settings parity across Dashboard, History, Insights, and Settings. Review follow-up validates profile/settings/date bounds before mutation and independently verifies destination settings restoration. Evidence and limits: `build/ws6-qa-2026-10-26/QA.md`.
- Original line 55: 5. [x] Validation and simulator E2E. Full fixture export, uninstall/reinstall, Replace/Merge completion, document parity, and Dashboard/History/Insights/Settings comparisons pass. Reproduction steps, screenshots, and unverified external effects are in `build/ws6-qa-2026-10-26/QA.md`.

## bundled-food-database-tracker.md

Moved source: [bundled-food-database-tracker.md](bundled-food-database-tracker.md). Before/after unchecked count: 0/0.

- Original line 3: Branch `launch/ws4-food-database`. Mac (pipeline is Bun; app side needs Xcode). Read `AGENTS.md`, `Data/Services/CommonFoodSeedLoader.swift`, `Data/Services/AppBootstrap.swift`, `Data/Models/FoodItem.swift` (`FoodItemLocalSearch`), `Features/AddFood/AddFoodSearchResults.swift`, `Features/AddFood/AddFoodScreen.swift`, `changes-log.md` sections "Food Search" and "Local Food Search Token-Match Follow-up", and `(original tracker directory)/launch-program-tracker.md`.
- Original line 24: - Source: USDA FoodData Central FNDDS (public domain). Download the latest FNDDS CSV release from `https://fdc.nal.usda.gov/download-datasets` (verify the exact URL at run time and record it with the release date). Fall back to SR Legacy only if FNDDS is unavailable.

## camera-inline-details-plan.md

Moved source: [camera-inline-details-plan.md](../archive/camera-inline-details-plan.md). Before/after unchecked count: 0/0.

- Original line 3: Status: implemented and simulator-validated. Evidence, exact limitations and deferred device checks: [`../docs/evidence/camera-inline-details/README.md`](../../evidence/camera-inline-details/README.md). Base: `origin/main` d53a313 (includes the camera card layout-shift fix). All historical `file:line` cites are at that commit.
- Original line 7: - Native iOS 27 dismissalConfirmationDialog did not intercept the dashboard zoom-cover swipe. Verified fallback: interactiveDismissDisabled while dirty on both OS versions; explicit Close/Scan again/Retake dialogs remain available. Clean zoom swipe dismisses normally. No custom gesture or presentation rewrite.
- Original line 11: - Final offscreen Next/Previous passed after explicit scroll requests plus Form-row appearance focus. The reader-only and immediate-focus failures are preserved. Non-camera replay still has four pixel-identical pairs; four final raw tree comparisons are unavailable after the driver changed backend, not claimed identical.
- Original line 12: - Final serial suite: 242 tests, zero failures; format/build/JS lint pass. Defensive cleanup removed only four unused wrapper inputs. Hardware camera lifecycle checks remain deferred to TestFlight.
- Original line 17: - D6 ships with owner device verification deferred to TestFlight. Keep the frozen still through restart until startScanning succeeds, then fade. The preview remains torn down after Log until Scan again. No simulator claim substitutes for hardware verification (R1).
- Original line 21: - D8 kept: dirty-only “Discard changes?” on Scan again, Retake and Close, with “Discard Changes” and “Keep Editing”. Confirm before softenCameraForDismissal. In one small modifier, iOS 27 uses dismissalConfirmationDialog(_:shouldPresent:actions:message:); iOS 26 uses interactiveDismissDisabled(isDirty). Apply inside FoodCameraSheet. Verify clean/dirty swipe dismissal with the zoom transition and report any limitation (R5).
- Original line 28: - Order: commit 0 contract; commit 1 behavior-preserving extraction; spikes; failure modes then red isolated tests for D8/D9; feature; evidence, checks and cleanup. Use focused follow-up commits as needed.
- Original line 29: - Validation: quality-format-check, quality-build, lint-js, full serial iPad suite excluding PurchaseStoreStoreKitTests under /Applications/Xcode-26.4.1.app/Contents/Developer, then defensive-code-review. Evidence must distinguish observed passes, expected reds, blocked scenarios, and owner-only hardware checks.
- Original line 56: | D10 | No collapse control in v1. Exits are Log (to Logged) and Scan again. | The owner listed no collapse. A cheap follow-up if wanted. |
- Original line 146: - The Form's `keyboardNavigationToolbar` (`FoodDraftEditorForm.swift:82`) needs a toolbar host. The camera already sits in a `NavigationStack` with only the nav bar hidden (`FoodCameraSheet.swift:84`). Verified in S2.

## dependency-update-tracker.md

Moved source: [dependency-update-tracker.md](../archive/dependency-update-tracker.md). Before/after unchecked count: 0/0.

- Original line 29: | `convex-backend` | `convex` | 1.37.0 → 1.48.0 | [Convex JavaScript docs](https://docs.convex.dev/client/javascript), [Convex releases](https://github.com/get-convex/convex-backend/releases) | No API edits; code check and 23 registered integration tests passed. Codegen could not run without a configured Convex deployment; no deployment was created or contacted with a valid deployment identifier. |
- Original line 44: | `tools/food-db` | `yauzl` | 3.2.0 → 3.4.0 | [yauzl 3.4.0 API and change history](https://github.com/thejoshwolfe/yauzl) | 3.4 adds Promise wrappers and async iteration; existing consumers remain supported. |
- Original line 61: | `convex-backend` | `bun run check` passed (8 tests / 16 expectations); `bun run test:integration` passed (23/23). `bunx convex codegen` was attempted but blocked because there is no configured `CONVEX_DEPLOYMENT`; the synthetic name probe was rejected by the Convex API and did not create a deployment. |
- Original line 96: Follow-up 2026-10-29: `cf migrate` for `web/` was tried and reverted. `cf build` delegates to `astro build` for Astro projects and never writes Worker Build Output, and the Cloudflare docs say Astro 6+ does not build with `cf` during the beta. Wrangler stays the build and deploy tool for `web/`. Workers Issues and full observability sampling were enabled in `web/wrangler.jsonc`.

## goal-calculator-onboarding-tracker.md

Moved source: [goal-calculator-onboarding-tracker.md](../archive/goal-calculator-onboarding-tracker.md). Before/after unchecked count: 0/0.

No open-box or prose-blocker candidates in the original scan.

## insights-implementation-tracker.md

Moved source: [insights-implementation-tracker.md](../archive/insights-implementation-tracker.md). Before/after unchecked count: 0/0.

No open-box or prose-blocker candidates in the original scan.

## insights-long-ranges-tracker.md

Moved source: [insights-long-ranges-tracker.md](../archive/insights-long-ranges-tracker.md). Before/after unchecked count: 0/0.

- Original line 6: - All ranges above 7D remain gated by `PaidFeature.nutritionInsights`.
- Original line 7: - Use a compact native menu picker for all six ranges so labels remain legible at accessibility text sizes. The free affordance lists every range, marks 7D selected, and opens the existing Pro paywall for locked choices.
- Original line 50: - Daily chart aggregation now filters unlogged days without changing summary inputs. The All threshold uses six calendar months. The weight query includes the seven-day comparison baseline before the range start while chart/trend points remain inside the selected range.
- Original line 57: - [x] Long ranges remain Pro-gated; all nutrition chart ranges now keep distinct daily totals at calendar-day x positions, with a 30-day visible scrolling window for longer ranges.
- Original line 65: - Binary from `a5b0d34b118c50f655d51ceb05f173a744e3ef3f`: SHA-256 `c7cd0351dfbdb33b69b0f69f00a059f31bae2f63bab68d22bb72219d0f860585`, Mach-O UUID `C2765AA1-0AC5-3B7A-9484-421ABFFC74BB`. The Mach-O entitlement payload includes the expected application identifier, app group, and HealthKit entitlement; the previous report calling this a signing blocker was incorrect.
- Original line 68: - Calorie Lines, macro Lines, and Fiber Lines render. Macro selection on Oct 27 reads `P 40g • C 51g • F 22g`; Fiber selection reads `18 g`, with All-range coverage `300/400 logged days`. Fiber panning changes the visible domain from day indices 350–400 to 300–350; selecting an earlier visible point reads Aug 12, 6 g. A macro-chart pan attempt navigated back to Dashboard, so long-range macro panning remains unverified. The action log and screenshots are in the ignored QA artifact. Exhaustive nutrient/style/range combinations remain unverified.

## launch-program-tracker.md

Moved source: [launch-program-tracker.md](../archive/launch-program-tracker.md). Before/after unchecked count: 0/0.

- Original line 14: - Lean launch scope. Deferred post-launch: AI photo logging, Apple Watch, iCloud sync, adaptive target suggestions, meal slots, alternate app icons.
- Original line 44: 5. Report: branch, head SHA, files changed, validation results (what ran, what failed, what was skipped), and the QA artifact path.
- Original line 49: - Simulator ownership and presentation: at most three booted simulators across all work, preferably fewer. Use T3's in-app Device panel only, never launch external Simulator.app. Use `device_list`, `device_open`, its pinned agent-device CLI, and T3 screenshots. If access fails, report the blocker rather than switching externally. Reuse an existing device only with authorization; never erase or delete a pre-existing device. Shutdown/delete only a device whose creation and ownership were verified for the task. Preserve user devices and other threads' panels.
- Original line 78: - 2026-10-29: App Store name is now "MACROS: Nutrition Tracker" (in-app brand stays MACROS). Builds 10 shipped. Polish batches 1 through 3c are on `feature/camera-zoom-transition`. TestFlight build 11 is pending the E2E pass.
- Original line 80: - 2026-10-28: Camera zoom glass-preserving fix on `feature/camera-zoom-transition`: one local source-container boundary candidate preserves native interactive capsule glass and shows pill-origin opening plus dashboard return on the owned iPhone 18 Pro simulator; Add Food Barcode/Label reach camera but their morphs, Reduce Motion, Quick Action, and History remain unverified. Xcode 27 signed build and formatting passed. Evidence: `build/camera-zoom-glass-fix-2026-10-28/QA.md`.
- Original line 81: - 2026-10-27: Merged `feature/camera-inline-results` (`7685e53`) into `main` with merge commit `5c35ccf`: idle viewfinder hint without spinner, editable label review and explicit logging above the preview, preserved edits on save failure, bounded review panel, and secondary Edit details beside Log. Sol review found no remaining source bugs after fixes. Native T3 E2E passed complete-label logging at two servings (300 kcal, 10 P, 54 C, 6 F), incomplete-label warnings/editor quantity and keyboard-visible controls, and barcode logging (400 kcal, 10 P, 74 C, 8 F); combined dashboard totals matched 700 kcal, 20 P, 128 C, 14 F. Prior 25 flow and 3 barcode tests passed; the final styling-only change passed formatting and an Xcode 27 build, without rerunning unchanged logic tests. Evidence: Mac `build/camera-inline-t3-qa-2026-10-27/QA.md`, with selected JPEGs transferred to Windows `build/visual-2026-10-27/inline-r5-*.jpg`. Large Dynamic Type, live camera/torch, and runtime save-failure retry remain unverified. The existing user device/session remain running inside T3. Zoom-transition work is still separate and unmerged.
- Original line 82: - 2026-10-27: Merged `fix/dashboard-legend-accessibility` into `main` with merge commit `807cb75`: the dashboard macro legend (`MacroLegendView`) drops its fixed 102 pt `GeometryReader` frame for a content-sized `AnyLayout` (horizontal columns normally, one macro per row with 8 pt vertical padding at accessibility sizes), which removes the build 8 "macro labels overlap the Today heading" finding at AX sizes. Sol low review: merge as-is (spacing nit applied). Simulator evidence on a dedicated iPhone 17 Pro / iOS 27.0 (`build/legend-ax-2026-10-27/QA.md`): default and XXXL horizontal with no overlap; AX5 stacked with icon-only pills. The first AX5 capture was taken after another branch's build had been installed on the same simulator and showed the old layout; it was redone with the legend build. Framing the lower legend together with the Today / items header at AX5 remains unverified because the simulator list would not scroll under agent-device.
- Original line 85: - 2026-10-26: Merged `launch/insights-long-ranges` into `main` with merge commit `b6c18d4`: Insights ranges 7D/14D/30D/90D/1Y/All (free stays 7D; locked ranges open the Pro paywall), menu picker legible at accessibility sizes, weekly/monthly chart buckets averaged over logged days, one bounded fetch per range. Sol review found three P2s (daily charts plotted unlogged days as zero, the 7D weight comparison could never find its baseline, the All threshold used 180 days instead of six calendar months), fixed tests-first (21/21 `InsightsAnalyticsTests`); `InsightsScreen.swift` was split into focused files as pure moves (all Insights files under 400 lines). The post-fix seeded simulator checks were not run (simulator slots busy) and move to the build 8 pre-flight.
- Original line 86: - 2026-10-26: Merged `chore/dependency-updates` into `main` with merge commit `7936f83` (all seven Bun packages at latest stable; Wrangler held at 4.116.0 because 4.117+ depends on Miniflare 5 prereleases; Sol review fixes: Convex nested `tsconfig` gets `types: ["node"]` for TypeScript 7, oxlint TypeScript pin exact). Regenerated Convex bindings for convex 1.48 (`63dac57`). Post-merge: frozen installs 7/7, Convex typecheck, check, 23/23 integration tests; deployed Convex dev `energized-pigeon-822`, `macros-auth` `f9863b24`, `cal-macro-tracker-usda-proxy` `bf5f2d4c`, `macros-web` `a1f722bf` (no D1 migrations pending); live smoke on packaged search, barcode, USDA search/detail, JWKS, site pages, and the Convex sharing smoke all passed. `convex-swift` is already at its latest release (0.8.1).
- Original line 88: - 2026-10-26: Merged `launch/paywall-success-flow` (`a671a15`..`258d2e9`) onto `main`: the Pro paywall opens at the large detent only and shows a transition-only success state after purchase, restore, or redeem; Sol review found one P2 (the weight-trends presenter lived inside the Insights locked branch and was torn down on activation), fixed by hoisting it to `InsightsScreen`. Simulator E2E on the branch covered Settings/Insights entry points, lifetime, yearly trial, and accessibility sizes; the post-fix purchase E2E was skipped (simulator slots full) and is on the build 8 device checklist.
- Original line 89: - 2026-10-26: Backends deployed from `main` (`b619a53`): `cal-macro-tracker-usda-proxy` version `9f52f065-11d3-4393-8c20-ca52767d61b0` (rate limits, USDA budget Durable Object, 8 s deadline), `macros-auth` version `165985d3-447b-48f7-8a45-72f1b1740af0` (token rate limit), Convex dev deployment `energized-pigeon-822` pushed (`profileQuotas.by_profile_id_and_day_key` index added); `macros-web` was already current with no D1 migrations pending. Live smoke: barcode lookup, unknown barcode, JWKS, invite redirect all pass.
- Original line 90: - 2026-10-26: Simulator StoreKit repair merged (`40e8353`): the blocker was the iOS 26.4 simulator runtime, not the app; Xcode 26.4 + iOS 27.0 activates the local catalog. `ProEntitlementTests` 18/18; `PurchaseStoreStoreKitTests` 11/14 with four cases (cancellation feedback, legacy unlock, expiry removal, Ask to Buy hang) under investigation on `launch/storekit-test-failures`. Real-price paywall screenshots for in-app purchase review are on `docs/asc-review-screenshots` (`b268110`).
- Original line 95: - 2026-10-26: Phase 1 and Phase 2 merged linearly into `main` except WS6: WS1, WS8, WS9 docs, WS3 (`1accf82`), WS2 (`a0d6a64`), WS7 (`3461878`), WS5 (`e6d6687`, five review rounds; Health nutrition operations run through one serial queue with enqueue-time snapshots), WS4 (`4900a9e`, five review rounds; bundled foods reconcile by stable `fndds:<food code>` / `legacy:<slug>` identifiers with single-claim, deterministic backfill and capped names). WS6 is in progress on `launch/ws6-backup`; merged-`main` validation is running on the Mac. Unverified items are consolidated in `testflight-release-tracker.md`.
- Original line 96: - 2026-10-25: WS2 local StoreKit repair remains blocked by a pre-existing setup failure. Fresh iOS 26.4 (23E244) simulator, shutdown-all/erase retry with live `storekitd` logging, and a minimal XCUITest launch all failed to activate local products on Xcode 26.4 (17E192), macOS 27.0.1 (26A434). Error: `SKInternalErrorDomain Code=3`; `OctaneSaveConfigurationRequest` not entitled. T3 screenshot confirms all three plans unavailable under XCUITest. No payment assertions waived or production signing changed. Apple references FB22237318 / FB22500243; newer matching toolchain/runtime or WS9 device sandbox/TestFlight remains required. Full commands and evidence: `build/ws2-qa-2026-10-25/QA.md`; WS2 tracker updated.
- Original line 97: - 2026-10-25: Program created. Decisions locked. Phase 1 dispatch pending.

## meals-implementation-tracker.md

Moved source: [meals-implementation-tracker.md](meals-implementation-tracker.md). Before/after unchecked count: 1/1.

- Original line 22: - Creating meals from already logged Dashboard/History entries is deferred; first-version components are added through the meal editor's search/select flow only.
- Original line 30: - Deleting a `FoodItem` used by any saved meal should be blocked with a clear message telling the user to remove it from meals first.
- Original line 31: - Saving a meal should require a non-empty name and at least one valid component with calories and primary macros.
- Original line 59: - Saved meals should be editable in the first version from the meal review/log screen via an `Edit Meal` action. Settings-based management remains deferred.
- Original line 63: - Meal-level logging should be servings-only in the first version, such as `0.5 meal`, `1 meal`, or `2 meals`; grams remain available only at the component level when supported by the linked food.
- Original line 141: Extend logged data so a logged meal can remain one Dashboard/History row:
- Original line 158: - Secondary nutrients should be summed and stored when available, but secondary nutrient display is deferred.
- Original line 212: - [x] Include recent meals in the empty-query On Device list so saved meals remain discoverable without typing.
- Original line 222: - [x] Keep logged meal editing deferred; first-version logged meal rows open read-only detail.
- Original line 225: - [ ] Add saved-meal management in Settings if the first Add Food creation path is not enough.
- Original line 233: ## Explicitly Deferred From First Version
- Original line 261: - Phase 5 referenced-food safety is implemented and validated: reusable food deletion is blocked when a food is used by saved meals, the food editor warns that edits affect future meal totals but not past logged meals, and saving referenced foods refreshes searchable text for meals that include them.
- Original line 278: - Linked component updates are useful for saved meal totals, but logged meal history must remain snapshot-based to avoid retroactive nutrition changes.
- Original line 281: - Broader reuse follow-ups remain optional: local food candidate search and remote search session handling are still duplicated between normal Add Food and meal component picking, but were left unchanged to avoid widening this first-version cleanup.

## packaged-food-search-reliability-tracker.md

Moved source: [packaged-food-search-reliability-tracker.md](../archive/packaged-food-search-reliability-tracker.md). Before/after unchecked count: 0/0.

- Original line 91: - Open Food Facts API docs require a custom `User-Agent`; the Worker already uses `OPEN_FOOD_FACTS_USER_AGENT`.
- Original line 204: - Cached OFF results remain provider `openFoodFacts` regardless of whether they came from Search-a-licious or legacy OFF.
- Original line 210: - Implemented `timed_out: true` handling to return available hits, but treat a timeout with no hits as retryable/unavailable.
- Original line 216: - Post-implementation simplify review tightened the OFF outcome type into a discriminated union, removed the now-obsolete legacy request-budget plumbing, and changed legacy OFF fallback to fetch only the requested page now that nutrition filtering no longer requires backfilling skipped products.
- Original line 228: - Follow-up review fixed the Swift Load More button to trust the Worker `hasMore` contract even when a filtered page has no visible results; the final defensive pass removed one unused Worker telemetry metadata field.
- Original line 229: - Follow-up review fixed missing-nutrition Open Food Facts search selections to pass required review nutrients into `LogFoodScreen`, preventing immediate logging of all-zero manual-review drafts.
- Original line 231: - A follow-up cleanup pass shared the Swift missing-nutrition review predicate and clarified OFF name-token matching terminology; stale fallback metadata plumbing was left unchanged to avoid broad cache/telemetry contract churn.
- Original line 238: - A durable stale-cache strategy likely requires KV/R2/D1 and was deferred instead of forced into this first pass.

## pro-subscription-storekit-tracker.md

Moved source: [pro-subscription-storekit-tracker.md](pro-subscription-storekit-tracker.md). Before/after unchecked count: 0/0.

- Original line 3: Branch `launch/ws2-pro-storekit`. Mac only. Read `AGENTS.md`, `docs/development/swift.md`, `changes-log.md` sections "App Store and TestFlight Release Prep", "Follow-up: Full Unlock sheet Liquid Glass button edge", "Follow-up: Full Unlock custom macro ring colors", "StoreKit Validator Path Correction", and `(original tracker directory)/launch-program-tracker.md`. Activate the `swiftui-liquid-glass`, `apple-design`, and `write-swift` skills if available.
- Original line 57: - Cancelled subscriptions must say Expires, grace must use its grace deadline rather than an old billing date, and unavailable/unverified status must not imply renewal.
- Original line 59: - The production selection reducer must reject unverified/revoked/upgraded/unrelated or wrong-type facts, preserve subscription dates and grace-period access, select lifetime in either input order, recognize legacy lifetime, and yield Free for empty input.
- Original line 64: - Review fix 3: Verified `Product.SubscriptionInfo.Status.all` group statuses supply `willAutoRenew`, renewal state, and grace deadline for Settings. Cancelled subscriptions say Expires, verified renewals say Renews, and missing/unverified status falls back to Active. Grace uses `gracePeriodExpirationDate`; billing retry alone never claims continued access, per Apple's renewal-state contract. Entitled family-shared statuses outrank expired personal statuses. Concurrent refreshes cannot overwrite newer snapshots.
- Original line 65: - Review fix 4: StoreKit tests start the production listeners for refund, expiry, Ask-to-Buy approval, cancellation, and renewal; `withObservationTracking` waits have a five-second XCTest deadline, no polling or manual refresh in those paths, and teardown stops listeners. `build-for-testing` passes. The full integration suite remains blocked and is not reported as passing.
- Original line 76: - Validation: 18 `ProEntitlementTests` + 6 `InsightsAnalyticsTests` pass (24 total); format/build/catalog/diff checks pass. Catalog activation probe still fails setup, exit 65 (`SKInternalErrorDomain Code=3`, `WS2.StoreKitSetup Code=1`), so the full StoreKit suite and purchase-path E2E remain blocked. Evidence: `build/ws2-qa-2026-10-25/coalescing-*.log` / `.xcresult` and `QA.md`. Swift Task awaiting/cancellation semantics verified against https://developer.apple.com/documentation/swift/task.
- Original line 78: ### 2026-10-26 StoreKit test failure follow-up
- Original line 86: - Catalog network failure must leave all plans unavailable and allow a successful retry.
- Original line 87: - Purchase network failure, cancellation, and Ask to Buy pending must never grant Pro.
- Original line 89: - Refunded lifetime must revoke Pro; legacy lifetime must remain recognized.
- Original line 94: - Unverified, revoked, and unrelated transactions must not grant access.
- Original line 98: - Enumerate failure modes before touching code: products fail to load then retry; purchase network failure; user cancels; purchase pending (Ask to Buy); yearly trial purchase grants Pro with expiration; subscription expiry removes Pro (use `SKTestSession.timeRate` or `expireSubscription`); refund of lifetime revokes; legacy `fullunlock001` grants `legacyFullUnlock`; lifetime beats an expiring subscription when both exist; restore with no purchases reports status; intro-offer eligibility false after a prior subscription.
- Original line 115: - Products unavailable (no network, App Store Connect products missing): paywall shows benefits, disabled primary button with "Loading…" then an inline error; Restore stays enabled.
- Original line 124: - 2026-10-25 WS2 implementation is in place. Build/format/catalog checks pass and native UI QA confirms real summary values and debug grant/revoke gates. Payment validation is **not complete**: the dedicated iOS 26.4 simulator rejects `SKTestSession` catalog activation (`SKInternalErrorDomain Code=3`; `storekitd`: not entitled for `OctaneSaveConfigurationRequest`). Xcode Run and both installed toolchains were attempted. Tests fail at catalog setup rather than silently passing purchase assertions. See `build/ws2-qa-2026-10-25/QA.md` for exact attempts and pending paths.
- Original line 126: - 2026-10-25 time-boxed repair follow-up: **still blocked**, and owner confirms the same rejection predates WS2 (October 13 baseline: four StoreKit setup failures). On macOS 27.0.1 (26A434), Xcode 26.4 (17E192), newest installed iOS 26 runtime 26.4 (23E244), a never-booted fresh simulator and then `simctl shutdown all` / erase each produced 12 catalog setup failures (`SKInternalErrorDomain Code=3`, `WS2.StoreKitSetup Code=1`, `OctaneSaveConfigurationRequest` not entitled). Live daemon log preserved. A minimal isolated XCUITest successfully launched/held the app, but visible T3 QA still showed all three plans unavailable; screenshot `t3-xcuitest-paywall-unavailable.png`. Explicit signature `get-task-allow` also failed to provide a runnable test environment; no production signing changes retained. Apple documents related fixes in iOS 26.5 (172583218 / FB22237318) and 26.6 (174738526 / FB22500243), neither installed here; forum thread https://developer.apple.com/forums/thread/826971 includes reports after advertised fixes. Exact commands, versions, failures, logs, and isolated probe source: `build/ws2-qa-2026-10-25/QA.md`. Purchase/trial/cancel/restore/manage/redeem/family paths remain unvalidated, not waived.
- Original line 130: - 2026-10-26 simulator repair: catalog activation passed with Xcode 26.4 (17E192) + iOS 27.0 (24A434), but Xcode 27.0 (27A266a) hung on iOS 27.0 and returned `SKInternalErrorDomain Code=3` on iOS 26.4. With the passing pair, `ProEntitlementTests` passed 18/18. The StoreKit run restarted after `testAskToBuyApprovalUnlocksThroughListener` exceeded its allowance; the final 14-test run reported 11 passes and 3 failing cases: `testCancellationDoesNotGrantPro`, `testLegacyGrantsLifetime`, and `testTrialGrantsProWithExpirationAndExpiryRemovesIt`. The Ask to Buy listener case timed out separately. Real-price light/dark paywall screenshots show the selected yearly $19.99/year plan, “7 days free · Best value,” $2.99/month, and $49.99 lifetime at 1206×2622. Full evidence: `build/storekit-repair-2026-10-26/QA.md`. Sandbox purchase/restore on another device, lifetime Family Sharing, and legacy App Store purchase validation still need a real device/account.

## retention-polish-tracker.md

Moved source: [retention-polish-tracker.md](retention-polish-tracker.md). Before/after unchecked count: 0/0.

- Original line 12: Status: WS7 implementation and code validation complete on `launch/ws7-retention-polish`; barcode 429 simulator E2E remains unverified because the simulator camera feed is blank.
- Original line 32: - Recorded simulator evidence and the barcode-camera limitation in `build/ws7-qa-2026-10-25/QA.md`.
- Original line 34: ## Close-out (deferred until WS4, WS5, and WS6 merge)
- Original line 36: - [x] Checked the WS4 “Search online for …” prompt against the pinned glass action bar with an empty query, local results, no local results, and the keyboard up. The prompt and pinned actions remain visible and do not collide; no spacing or safe-area change was needed.
- Original line 39: - [x] Confirmed free and Debug Pro states, and opened/dismissed the visible paywalls. Purchase products are unavailable in this simulator; purchase completion remains covered by the existing StoreKit limitation.
- Original line 41: - [x] Recorded the remaining simulator limitation: barcode lookup `429` camera handling must be verified on a TestFlight device (non-retryable response and `Retry-After` feedback); see [TestFlight Release Tracker](testflight-release-tracker.md#carried-over-verification-items-must-pass-on-the-testflight-device).

## services-hardening-tracker.md

Moved source: [services-hardening-tracker.md](../archive/services-hardening-tracker.md). Before/after unchecked count: 0/0.

- Original line 24: - Add a per-request deadline of 8,000 ms created once in the route handler (`AbortSignal.timeout`) and threaded into every upstream fetch through the existing `withTimeout` fetcher (`src/http.ts` already composes signals with `AbortSignal.any`). When the deadline fires, return what has been collected so far or the existing unavailable response.
- Original line 58: - Write `worker/usda-proxy/tests/hardening.test.ts` cases before code: limit exceeded returns 429 with Retry-After; limit ok passes through; USDA budget exhausted skips USDA and still returns OFF results; deadline expiry returns partial/unavailable within 8.5 s; restaurant scan stops at 3 pages / 3 attempts; missing `cf-connecting-ip` uses fallback key.
- Original line 93: - Added bounded quota-row cleanup during sharing-profile deletion and documented the remaining iOS 429 handling as a WS7 follow-up.

## shared-person-widget-implementation.md

Moved source: [shared-person-widget-implementation.md](shared-person-widget-implementation.md). Before/after unchecked count: 0/0.

- Original line 5: Release stays blocked until 1.0 approval and the production cutover.
- Original line 53: first-unlock protection. Those checks remain release gates.

## shared-person-widget-plan-review.md

Moved source: [shared-person-widget-plan-review.md](../archive/shared-person-widget-plan-review.md). Before/after unchecked count: 0/0.

- Original line 15: | `entities(for:)` omits unavailable entities | Correct | https://developer.apple.com/documentation/appintents/entityquery ("If the entity ... is no longer available, omit it from the returned array"). What the provider receives for a non-resolving stored selection is not documented; the plan's optional parameter plus on-device validation is the right hedge. |
- Original line 30: 5. **Reuse `personDay` with an optional `includeFoods` argument instead of `widgetPersonDay` + `personDayRead.ts` + typed error codes.** `sharing.ts:380-420` already performs every check the plan lists; add `includeFoods: v.optional(v.boolean())` (default true) and skip the `sharedFoodDays` read when false, returning `foods: []`. The return validator (`sharingValidators.ts:50-53`) is unchanged, so build-25 callers are untouched. The "profile-existence oracle" the plan guards against does not exist: missing, deleted, self, stranger, and removed all throw the same `"Relationship unavailable."` (`sharing.ts:391,396`); malformed IDs fail argument validation, which is the same for any ID-typed arg. Display name comes from the people cache, not the query. Extension rule, needing no codes: a decoded `status:"error"` envelope after one token refresh and retry is authoritative (treat as unavailable, purge that person's cache); non-JSON body, transport failure, 429, 5xx are transient (keep last-good). `AUTH_REQUIRED`/`PROFILE_UNAVAILABLE` add a helper, a ConvexError path, and client parsing for a distinction the extension never acts on differently (viewer profile deletion is app-initiated and already purges locally).
- Original line 55: | E2E matrix | Simplify (change 11) | Hundreds of cells, many blocked by Simulator Lock Screen automation, dilute the proof. |
- Original line 67: **Recommendation: no, not while pigeon serves the 1.0 build in App Review and TestFlight.** The flag is deployment-global (`proModel.ts:10-12`); flipping it pauses every connection without a server-verified Pro on both ends, including any pair App Review is exercising, and blocks invite creation for build-25 users for the window (`sharing-v2-plan.md:181`; `sharing-v2-backend-validation.md:63-65` already records that pigeon must not be touched for this reason). The widget's paused rendering is a copy branch on the `visibility` value with the same client path as `notShared`; the server decision is already proven deterministically in `convex/_qa/sharing.integration.ts:182-202`. Mark the live paused cell blocked with that test as coverage. Revisit after the puffin cutover, when pigeon becomes a true dev deployment; then a short owner-coordinated flip with Sandbox-verified fixtures is reasonable.

## shared-person-widget-plan.md

Moved source: [shared-person-widget-plan.md](../archive/shared-person-widget-plan.md). Before/after unchecked count: 0/0.

- Original line 13: - Reuse existing widget layouts and `MacroRingSetView`; add the person's name. Use the native Home Screen Smart Stack to switch between own-day and shared-person widgets, not an in-widget toggle. Lock Screen families remain separate placements, not a custom stack.
- Original line 41: Live-tool limitation: the Convex status tool returned **`No CONVEX_DEPLOYMENT set, run npx convex dev to configure a Convex project`** for this new worktree. No configuration, deploy, or live database write was attempted. The endpoint is verified from `SharingConfiguration.swift`; the flag's current off state is owner-provided, not independently queried here.
- Original line 48: 2. `SharingKeychainItem` currently has **no `kSecAttrAccessGroup`**; it uses the app's private default group. New items use `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. Pending invite secrets use a separate private account, `pending-invite`.
- Original line 75: - The Worker currently turns bootstrap credential failures into a generic 500 (`index.ts:104,120-121`). Do not pretend it returns a specific “credentials revoked” status. Transport/500 failure shows a safe offline/error state; a typed unavailable-profile result from Convex invalidates cached content. No Worker error-contract rewrite is required here.
- Original line 91: - `visibility`: `shared | paused | notShared | unavailable`.
- Original line 92: - `profileId`, `displayName`: returned only for an authorized, current relationship; unavailable returns null identity fields.
- Original line 95: - Invalid arguments/day remain errors. Missing/deleted/unrelated/removed target returns the same generic `unavailable` response to avoid a profile-existence oracle.
- Original line 143: - On a confirmed removal, purge that person's macro cache and clear the default if it referred to them. Leave explicit widget intent identifiers alone; show unavailable instead of substituting another person. Known paused/not-shared statuses purge cached macros too. Do not place those statuses or macros into the IDs/names-only people array.
- Original line 154: - `SharedPersonWidgetIntent: WidgetConfigurationIntent`, title “Choose Shared Person”, one `@Parameter(title: "Person")` entity selection. Initialize new configurations to the synthetic Default entity and use entity-query `defaultResult()` to suggest it, **not the currently resolved default person** [A1–A4]. Represent an unresolved selection as optional/nil in the provider-facing configuration so it can render unavailable, not silently resolve a deleted explicit selection as Default; validate this resolution behavior in the prewritten runtime acceptance case.
- Original line 156: - `entities(for:)` maps Default plus still-available cached IDs, using a dictionary/Set rather than repeated scans. Apple says to omit unavailable entities [A4]; do not invent a “removed” entity or fall back to Default.
- Original line 157: - The provider independently resolves the actual selection each time. Default resolves against `defaultProfileId` in the current control record; explicit IDs stay explicit. Treat a missing/unresolved parameter conservatively as “Choose a person,” not Default. Return unavailable for a previously selected ID missing from an authoritative people list. Still check the server for cached current IDs.
- Original line 172: 8. On paused/notShared/unavailable/profile-unavailable, known Pro denial/unknown access, disable/delete, or a local confirmed removal, immediately discard relevant macro caches and return a status entry. An authoritative denial always beats stale success, even offline later. A generic malformed query/error envelope must not be interpreted as permission success.
- Original line 195: - Home Screen rings remain `MacroRingSetView(... usesGlassEffect: false)` with existing accenting. Preserve container backgrounds, removable-background behavior, and custom backgrounds only in full-color modes. Keep StandBy/background-removed content legible. No new app-like controls.
- Original line 201: Apply precedence: privacy redaction/locked storage; device/session unavailable; Pro gate; selection; server visibility/data; transient error. Preserve a resolved person ID for navigation where possible, but never show stale nutrition in gated states.
- Original line 212: | Explicit person removed/unresolvable | “Person unavailable” · “Edit Widget to choose someone” | “Unavailable” | Sharing hub, no fabricated person screen |
- Original line 219: | Offline/error, no eligible cache | “Couldn't update” · “Open MACROS” | “[Name] · Unavailable” | Person screen or Sharing Settings if no target |
- Original line 239: `AppRootView` gains ID-based person routing that shows the Sharing hub and a loading destination, authenticates/starts the existing dashboard feed, waits for an authoritative result, then opens **`SharingPersonScreen(person:)`** using the current person. Do not fabricate a `SharingPerson` from widget data. If disabled/missing credentials, show Sharing Settings. If the relationship is gone, show a friendly unavailable state in Sharing. Repeated taps must not stack duplicate routes; pending routing must survive cold-start setup and not get lost because the dashboard starts empty.
- Original line 253: - Avoid UserDefaults for sensitive macro payloads and don't assume defaults APIs set per-file protection. Existing appearance/Pro preferences remain in their current store. The people cache has no macros, but names are still personal data and deserve protection.
- Original line 257: - Simulator evidence cannot prove hardware data-protection or distribution provisioning correctness. Require a signed-device lock/reboot/first-unlock check before release, without using the owner's private fixture for destructive QA.
- Original line 265: Use two available, unclaimed existing iPhone simulators for the app UI pairing (for example iPhone 17 and iPhone 17e, choose actual current UDIDs from inventory). Respect `AGENTS.md:59-65`: no new simulators, maximum four booted/one stock, never reset/seed the owner's `9843E820-3A2A-4599-9206-D224B3035A47`, and do not shut down unknown or active devices. If two suitable devices are unavailable, record the blocker rather than borrowing private state. Save all builds/evidence in this implementation worktree, never the excluded checkout or any `IGNOREDbuild/`.
- Original line 288: 9. For paused E2E, arrange server-verified test entitlements and coordinate the deployment-global `settings.sharingRequirePro` flag with the dev deployment owner. Capture neither-Pro paused and one-Pro resumed, then restore the original flag. Local Debug Pro/Xcode transactions are deliberately rejected by the backend verifier (`sharing-v2-plan.md:163-173`). Do not fake this as live proof. The isolated Convex tests cover this deterministically even if live fixture setup is blocked; label any missing live paused capture honestly.
- Original line 296: - **Lock Screen:** lock/wake the simulator, long-press wallpaper → Customize → Lock Screen. Tap the above-clock date slot for inline; use Add Widgets below the clock for circular and rectangular; choose **Shared Macros Lock Screen**. Tap a placed widget while customizing to configure Person, then Done. If the simulator cannot expose lock customization, report that family blocked, not passed from a preview.
- Original line 297: - Capture each of the **five families** with shared data/goals, no-data, not-shared, removed, offline-stale, and Pro-locked states. Capture the remaining state-table rows in every family too, using compact copy variants, with a matrix mapping each cell to a real screenshot or explicit blocker. Configure separate wallpaper layouts if slot limits require it.
- Original line 298: - Healthy-state appearance coverage: Home Screen light/dark/tinted/clear, accessory vibrant, long/duplicate/Unicode names, large text, VoiceOver name/macros/goals/freshness labels, reduced motion, and background-removed small/StandBy. Retain own-day baseline screenshots for regression comparison. Actual StandBy/Always-On behavior may need a physical device; state that limit.
- Original line 310: 6. Cleanup only the disposable fixtures created by this run. Print sanitized assertions/counts, never credentials. Do not run the existing smoke unchanged and call it widget coverage.
- Original line 320: | Routing | URL round trip/escaping; malformed URL; cold start before dashboard; unavailable person; disabled sharing; upgrade completion; repeated taps; existing invite/add-food links; own-day navigation-preservation regression. |
- Original line 334: | 2 | Shared credentials migration/auth DTO: new `Shared/SharingWidgetCredentials.swift` (including shared identity/error types); existing `Features/Sharing/SharingSecureStorage.swift`, `SharingIdentityStore.swift`, `SharingAuthService.swift`, `SharingSyncService.swift`; optional configuration extraction to SDK-free `Shared/SharingWidgetConfiguration.swift`. Review both entitlements files; no new keys for selected App Group Keychain design. | Upgrade preserves identity, secrets remain Keychain-only, invite stays private, cleanup generations work. Confirm App Group availability in signed app and extension, not just simulator. | Can run alongside backend; one owner for overlapping shared model/project edits. |
- Original line 357: No fixed product decisions are reopened. One environment decision is needed **only to complete live paused-state E2E**: can the implementation run temporarily change the deployment-global `settings.sharingRequirePro` on `energized-pigeon-822`, and can it use server-verified Sandbox Pro fixtures there? The current code has no per-test flag override and deliberately rejects simulator/Xcode transactions. Without permission/fixtures, keep that live cell blocked and use the prewritten isolated server test as partial coverage, not a substitute passing screenshot.
- Original line 368: - **[A4] AppEntity / EntityQuery:** persistent unique ID, display/query contract; omit identifiers for unavailable entities. https://developer.apple.com/documentation/appintents/appentity and https://developer.apple.com/documentation/appintents/entityquery

## sharing-implementation-tracker.md

Moved source: [sharing-implementation-tracker.md](sharing-implementation-tracker.md). Before/after unchecked count: 1/1.

- Original line 13: - Local-first rule: SwiftData foods/logs remain authoritative and local. Sharing flows must never delete local food/log data.
- Original line 55: - One active pending outgoing invite per inviter. Creating a new invite revokes the previous pending invite with clear copy.
- Original line 56: - Accepting someone else’s invite does not revoke the accepter’s own pending outgoing invite.
- Original line 58: - Pending invite status may show creation/expiry, but not recipient/open metadata.
- Original line 80: - While a privacy action is pending, show pending UI; only finalize after server confirmation.
- Original line 82: - “Remove person” tombstones/deletes the relationship and grant history for both participants; reconnecting requires a new invite.
- Original line 84: - If a counterpart deleted their sharing profile, re-enable is unavailable; require a new invite if they set up a new identity.
- Original line 98: - Dashboard/shared queries include relationship entries even if today’s snapshot is unavailable, returning `snapshot: null`.
- Original line 139: - Timezone conversion is display-only in MVP; server queries remain owner-day based.
- Original line 152:   - pending invite status
- Original line 172: - Expired/revoked/invalid invites show neutral “This invite is unavailable.”
- Original line 221: - [x] Add basic abuse protections: one pending invite, expiry, single-use, snapshot bounds, simple cooldowns if practical.
- Original line 259: - [ ] Accept invite flow with valid-invite name confirmation.
- Original line 283: - [x] Persist the locally-created pending invite link while it remains pending so leaving the Sharing screen does not lose it.
- Original line 296: - Locally-created pending invite links are persisted in `UserDefaults` until expiry, revocation, replacement, or sharing-profile deletion so leaving the Sharing screen no longer loses the link.
- Original line 299: - Invite app deep links now present a “Start Sharing?” confirmation dialog with Yes/No before accepting. Repeated invite links are routed by clearing and re-applying the pending open request so links still work while the app is already open.
- Original line 302: - Threat/privacy review completed. Follow-up fixes added server-side invite hash format validation, constant-time bootstrap secret comparison, and Swift display-name truncation aligned to the backend 40-character limit.
- Original line 332:   - Sharing cloud delete must remain separate from SwiftData model containers and never delete local `FoodItem`/`LogEntry`.
- Original line 353:   - Sharing screen now requires a display name before first auth bootstrap and can save display-name changes through `sharing:updateDisplayName`.
- Original line 359: - Optional polish: valid-invite name confirmation means the recipient would see a confirmation screen like “Accept invite from Juan?” after the app verifies the invite token but before creating the relationship. This is intentionally separate from the current MVP because invalid/expired invite responses must stay neutral, and adding preview metadata requires a new privacy-safe backend endpoint that reveals inviter name only for a valid pending invite.
- Original line 364: - 2026-10-13 two-device follow-up: actual invite acceptance, one-way/reciprocal grants, live totals changing from 100/P10/C10/F2 to 125/P12.5/C12.5/F2.5 without recipient navigation or forced refresh, outgoing pause/resume, named removal confirmation and Cancel, bilateral removal/reconnect, global stop, device off/on, foreground recovery, and profile deletion passed. Both temporary development profiles were deleted; local QA logs remained. Evidence: `build/sharing-qa-2026-10-13/QA.md`. Exact subscription counts, day rollover, network failure/retry, and invalid/expired/replayed invites remain NOT RUN.

## sharing-v2-backend-validation.md

Moved source: [sharing-v2-backend-validation.md](sharing-v2-backend-validation.md). Before/after unchecked count: 0/0.

- Original line 61: ## Deployment: skipped by owner instruction
- Original line 67:   real Sandbox transaction is also skipped in this phase.
- Original line 107: ## Owner follow-up
- Original line 114: 2026-11-01 review fixes (`fix/sharing-v2-backend-review`): retained per-transaction anti-replay state, independent renewal ordering, five-profile links, scheduled reactive Pro expiry, REFUND_REVERSED, active-only 100-person dashboard, and dead quota job removal; 22 regression tests (15 initially failing, then 3 additional edge cases reproduced), 19/19 unit and 63/63 integration tests, TypeScript/offline codegen and root Oxlint clean (make unavailable; used `bun tools/oxlint/node_modules/oxlint/bin/oxlint --config .oxlintrc.json`); grace requires an unrevoked latest subscription period; rejected sixth-profile submissions still commit verified purchase updates; no deployment, real Sandbox purchase, or live subscription transport verified. Owner-requested follow-up: sharedFoodDays stores one capped, whitelisted array per owner/day, with canonical no-write retries, unique person-day reads and bounded pre-today cleanup/deletion; public API unchanged; 19/19 unit and 66/66 integration tests, TypeScript/offline codegen and root Oxlint passed; nothing deployed.

## sharing-v2-plan.md

Moved source: [sharing-v2-plan.md](sharing-v2-plan.md). Before/after unchecked count: 0/0.

- Original line 162:    - Production and Sandbox each need a notification URL in App Store Connect.
- Original line 164:    - The `environment` field is read from the unverified payload only to choose the verifier. Every other environment is rejected before verification.

## state-machine-fixes.md

Moved source: [state-machine-fixes.md](../archive/state-machine-fixes.md). Before/after unchecked count: 0/0.

- Original line 5: remain a separate live-reproduction workstream.
- Original line 20: - Corrupt legacy store, unavailable directory, SQLite busy/locked, protection/permission failure:
- Original line 39: 5. Red: original totals remain. Green: no totals or foods; clear removed state.
- Original line 50: - [x] Required checks and full serial iPad suite except StoreKit; 234 tests passed, 0 failures. Evidence review and push remain.
- Original line 56: bytes remain unchanged. The app reads legacy SQLite read-only, finishes backup,
- Original line 68: paused/notShared checks remain. Loading and dashboard failure have separate
- Original line 76: Full serial iPad suite: 234 tests passed, 0 failures; StoreKit tests skipped.

## testflight-release-tracker.md

Moved source: [testflight-release-tracker.md](testflight-release-tracker.md). Before/after unchecked count: 3/3.

- Original line 10: 4. [x] Build 8: archived merged `main` commit `6d6ce5054eabbe845a739e0fe5f9f1e2b1d6ae3d` as version 1.0; Xcode rejected the duplicate build 7, managed the upload number to 8, and App Store Connect accepted the package for processing. Archive entitlements include HealthKit and `group.juan-test.cal-macro-tracker`. Automated pre-flight passed formatting, build, StoreKit catalog validation, and 60/60 targeted tests. Follow-up simulator verification on `cd91f42` completed onboarding using label-based controls on a dedicated iPhone 17 Pro / iOS 27.0 simulator, subsequently deleted; no product changes. Detailed steps and local ignored evidence: `build/build8-preflight-2026-10-26/ui/QA.md` (supersedes the earlier onboarding-blocked UI results).
- Original line 11:    - 2026-10-27 simulator barcode follow-up: the real EAN resolved and logged at 2 servings (400 kcal, 10 g protein, 8 g fat, 74 g carbs), all-zero recovery actions passed, and dismissing after a cached real-code lookup preserved the single dashboard entry without a crash. The earlier “no product” result came from selecting the all-zero fixture. Details and screenshots: `build/sim-barcode-e2e-2026-10-27/QA.md`.
- Original line 16: 5. [ ] Owner: after App Store Connect finishes processing version 1.0/build 8, add it to the internal TestFlight group and complete the physical-device sandbox checks in `build/testflight-qa-2026-10-26/QA.md`.
- Original line 18: 6. [ ] Owner: fill in and retain device results and defects in `build/testflight-qa-2026-10-26/QA.md`.
- Original line 19: 7. [ ] Owner: complete the submission checklist: App Privacy labels (from WS8 mapping), screenshots (WS8 shot list), review notes, support and privacy URLs, subscription review screenshots, and age rating.
- Original line 27: Device results are pending in `build/testflight-qa-2026-10-26/QA.md`.
- Original line 32: - WS7 (`retention-polish-tracker.md`): barcode lookup 429 handling (non-retryable, `Retry-After` wording) needs a camera; Build 8 simulator had no camera.
- Original line 35: - Build 8 paywall: simulator lifetime weight-card/context-action/unlock and Settings yearly date checks pass; physical-device sandbox verification remains pending (see `build/build8-preflight-2026-10-26/ui/QA.md`).
- Original line 36: - Build 8 camera: live scanning, torch, real-package OCR, barcode 429 recovery, and EAN-13 Photos lookup remain pending; Photos fixtures fell through to OCR even after the larger retry (see `build/build8-preflight-2026-10-26/ui/QA.md`).
- Original line 37: - Build 8 Insights/layout: simulator Pro 14D gaps, long-range rendering, icon-only pills, and scrollable range menu pass. Today/eight-days-ago baseline acceptance fails because comparison requires an exact-seven-day record. Dashboard layout passes at default and XXXL with horizontal columns and no Today-header overlap; AX5 shows a stacked legend and compact icon-only bottom pills, with no overlap against the Today navigation title. The simulator would not scroll to frame the lower legend, streak line, and Today / items header together, so that combined view remains unverified (`build/legend-ax-2026-10-27/QA.md`).

## unified-camera-tracker.md

Moved source: [unified-camera-tracker.md](unified-camera-tracker.md). Before/after unchecked count: 1/1.

- Original line 17: - Apple's torch documentation does not establish that an independently obtained `AVCaptureDevice` is the device owned by `DataScannerViewController`. Do not ship an unverified/dead torch toggle; verify on device or omit it and report the limitation.
- Original line 33: | Logging same product twice | Each explicit Log tap is a separate user action; disable while save is pending and show logged state without automatic timer. |
- Original line 34: | Unsupported/unavailable camera | Use still-image camera picker when available; otherwise keep library picker accessible. |
- Original line 42: - [x] Verify the glass-preserving dashboard Camera pill-origin zoom; exact native onset evidence is in `build/camera-zoom-glass-fix-2026-10-28/QA.md`. Follow-up confirms downward swipe returns to Today, Add Food Barcode/Label X dismissal returns to Add Food, and a recognized scanner deep link opens from History and returns to the same History date. Swipe landing on the exact pill, Add Food morph classification, Reduce Motion, and actual Home Screen Quick Action remain unverified.
- Original line 56: - [ ] Complete unknown-product lookup dismissal/recovery E2E; supplied QR is outside packaged-food symbologies.
- Original line 58: - [x] Replace the nested black camera scaffold with an 8-point-inset rounded preview inside a transparent 90%-height sheet, exposing the underlying app around the camera. Guidance and results overlay the preview, with 38-point glass secondary controls in 44-point hit targets and a 68-point shutter. Default-size and dark fallback contrast pass; accessibility XXXL removes the redundant centered fallback copy to avoid overlap. OCR/review/log flows remain unverified. See `build/camera-borderless-2026-10-28/QA.md`.
- Original line 64: - Dashboard fallback open and X dismissal returned to the intact two-item dashboard. The 2026-10-28 follow-up additionally verified native downward-swipe dismissal back to Today and X dismissal from both Add Food Scan Barcode and Scan Label back to Add Food; only Barcode open/return were recorded, and its morph was not separately classified. The recognized camera deep link opened from History and Close returned to the same History date; this does not verify a Home Screen Quick Action. Add Food source-origin, Reduce Motion, and live-camera behavior remain unverified.
- Original line 65: - Apple documents `.navigationTransition(.zoom(sourceID:in:))` for a view in a stack or sheet and shows a matched source on the button or its label. The observed center-origin result matches the documented fallback when the source cannot be resolved. Remaining lead: isolate whether the source is unavailable across the presentation boundary or lost inside `GlassEffectContainer`; neither was isolated within the three-build limit.
- Original line 72: - Barcode and label results remain in the camera panel. Label scans can have their name corrected, servings adjusted, and be logged there without automatic logging; missing required nutrients route the prominent action to Edit details. `LogFoodScreen` is reached only through Details, Edit details, or Enter manually.
- Original line 73: - Removed the separate Barcode/Label screens and option-list UI after rerouting all entry points. Shared resolver, barcode image scanner, camera picker, parser and fallback draft logic remain.
- Original line 77: - `MACROS-CAMERA2-2026-10-26` (iPhone 17 Pro, iOS 27.0) was created, shut down, and deleted; a second same-named simulator was later created for the focused test, then shut down by xcodebuild and deleted. The other pre-existing simulator was left untouched. Live scanning and torch remain device-only. A no-result QR and nutrition label fixture were generated under ignored `build/unified-camera-qa-2026-10-26/fixtures/` and added to Photos. The simulator launched the app and verified the default-size dashboard pills. Picker/product-result scenarios could not be completed; exact status and screenshot paths are in the matching QA.md.
- Original line 80: - Round 3 failure-mode map: inactive image barcode/OCR completion, shutter effect order/recovery shutter, all-phase scene pause/dismiss, library replacement/cancel quantity, inactive library cancel, and navigation result preservation are covered by reducer tests. Label import, review navigation/back, and Retake were exercised in the simulator. Lookup dismissal during async work, image-import background recovery, Add Food entry-point parity, and largest Dynamic Type remain E2E/device checks.
- Original line 98: | Unknown QR → recovery / lookup dismissal | not verified: QR is unsupported; imports reach incomplete label review instead. Supplemental EAN fixture also reached incomplete label review, not lookup. |
- Original line 105: Accessibility follow-up: `MACROS-AX2-2026-10-26` verified the Camera/Add Food icon-only pills before and after dashboard scrolling and the wrapping still-camera fallback copy at accessibility-extra-extra-extra-large; screenshots and results are in ignored `build/unified-camera-qa-2026-10-26/r4-ax/QA.md`.

## website-legal-metadata-tracker.md

Moved source: [website-legal-metadata-tracker.md](website-legal-metadata-tracker.md). Before/after unchecked count: 0/0.

- Original line 59: - Do not promise iCloud sync, AI, or Watch anywhere; they are deferred.

## weight-health-reminders-tracker.md

Moved source: [weight-health-reminders-tracker.md](weight-health-reminders-tracker.md). Before/after unchecked count: 0/0.

- Original line 52: 5. Validation: format, build, targeted tests, `git diff --check`; E2E in a simulator with the Health app: log a food and confirm Dietary Energy appears in Health; add a weight in Health and confirm it appears in the app; schedule a reminder, verify pending requests, and tap it from the simulator notification; all screenshots and steps in `build/ws5-qa-<date>/QA.md`. Changes-log entry.
- Original line 64: - Logged days are skipped in the app calendar/time zone.
- Original line 66: - A day with any log is skipped even when multiple reminders are configured.
- Original line 79: - Simulator QA verified onboarding, manual weight persistence, the free Insights weight card and locked Pro trend state, a food log, and the daily-reminder permission/setup UI. Health sample write/readback and delivered-notification interaction were not verified; see `build/ws5-qa-2026-10-25/QA.md`.
