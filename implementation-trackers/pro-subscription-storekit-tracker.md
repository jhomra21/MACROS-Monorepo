# MACROS Pro Subscription (StoreKit 2) Implementation Tracker (WS2)

Branch `launch/ws2-pro-storekit`. Mac only. Read `AGENTS.md`, `swift-dev.mdc`, `changes-log.md` sections "App Store and TestFlight Release Prep", "Follow-up: Full Unlock sheet Liquid Glass button edge", "Follow-up: Full Unlock custom macro ring colors", "StoreKit Validator Path Correction", and `implementation-trackers/launch-program-tracker.md`. Activate the `swiftui-liquid-glass`, `apple-design`, and `write-swift` skills if available.

## Shared Understanding

- Current purchase code: `Features/Purchases/{PurchaseStore,AppEntitlements,PaidFeature,PaidFeatureGate,FullUnlockPaywallSheet}.swift`; Settings sections `FullUnlockSettingsSection` and `MacroRingColorSettingsSection` inside `Features/Settings/SettingsScreen.swift`; Insights gating in `Features/Insights/InsightsScreen.swift` (`PaidFeatureGate(.nutritionInsights)`, `InsightsLockedPreview` with fake `InsightsPreviewChart` bars); custom ring palette gates in `DashboardScreen` and `SharingDashboardScreen` (`entitlements.canUse(.customMacroRingColors)`).
- StoreKit test config: root `FullUnlock.storekit`, referenced from the shared scheme as `../../FullUnlock.storekit`, validated by `tools/quality/validate_storekit_config.py` (`make quality-storekit`), and loaded by `cal-macro-trackerTests/PurchaseStoreStoreKitTests.swift` from the test bundle.
- Entitlements are injected at the app root in `cal_macro_trackerApp.swift` (`AppEntitlements`, `PurchaseStore`) and read through `@Environment`.

## Core Decisions

### Products

- Subscription group reference name `MACROS Pro`; products `macros.pro.yearly` ($19.99, 1 year, introductory offer: free, 1 week, new subscribers), `macros.pro.monthly` ($2.99, 1 month); non-consumable `macros.pro.lifetime` ($49.99, family shareable). Legacy `fullunlock001` kept in the config for compatibility tests.
- New StoreKit configuration file `MACROSPro.storekit` at the repo root (replace `FullUnlock.storekit`): subscription group with both subscriptions and the intro offer, the lifetime non-consumable, and the legacy product. Update the scheme reference to `../../MACROSPro.storekit`, the single `project.pbxproj` file reference, the test bundle resource, and the validator (expected product set, scheme identifier, project reference name, and the `PurchaseStore` constants it greps for).

### Entitlement model

- `PaidEntitlement.pro` replaces `.fullUnlock`.
- `PaidFeature` cases: `nutritionInsights`, `customMacroRingColors`, `weightTrends`, `healthWeightImport`, `backup`, `multipleReminders`. All require `.pro`. WS5 and WS6 consume `weightTrends`, `healthWeightImport`, `backup`, `multipleReminders`; define them now so later workstreams do not touch this file.
- `AppEntitlements`: `private(set) var hasPro`, `private(set) var proSource: ProSource?` (`monthly`, `yearly`, `lifetime`, `legacyFullUnlock`), `private(set) var proExpirationDate: Date?`. `canUse(_:)` unchanged in shape. `update(pro:source:expiration:)`.
- `PurchaseStore` keeps its name. Public surface: `ProPlan` enum (`yearly`, `monthly`, `lifetime`) with `productID`; `products: [ProPlan: Product]`; `loadProducts()`; `purchase(_ plan: ProPlan)`; `restorePurchases()`; `refreshEntitlements()`; `isEligibleForIntroOffer: Bool` (from `Product.SubscriptionInfo.isEligibleForIntroOffer`); feedback enum unchanged; `Transaction.updates` listener unchanged; DEBUG `setDebugPro(_:)`.
- `refreshEntitlements()` iterates `Transaction.currentEntitlements`, ignores `revocationDate != nil`, picks the strongest source (lifetime or legacy beats subscription), records `expirationDate` for subscriptions.

### Paywall

- New `ProPaywallSheet` replaces `FullUnlockPaywallSheet` everywhere it is presented (Settings, Insights, ring colors row). Accepts `context: ProPaywallContext` (`insights`, `ringColors`, `weightTrends`, `healthWeightImport`, `backup`, `reminders`, `general`) which orders the benefit list so the triggering feature is first.
- Layout (native, sheet with `.medium` and `.large` detents, drag indicator): hero symbol, title "MACROS Pro", one-line value statement; benefit list of six rows (SF Symbols: `chart.xyaxis.line`, `scalemass`, `heart.text.square` (row text "Weight import from Apple Health"; writing nutrition is free and not listed as Pro), `arrow.down.doc`, `paintpalette`, `bell.badge`); plan picker of three rows rendered with `appGlassRoundedRect` selection styling (yearly preselected, badge "7 days free" when eligible and "Best value"; monthly; lifetime "once"); primary `AppAccentActionButton` whose title is "Start 7-day free trial" (eligible yearly), "Subscribe for <price>/year|month", or "Buy lifetime for <price>"; Restore Purchases; Redeem Code (`offerCodeRedemption(isPresented:)`); legal footer with the required auto-renewal sentence and links to Terms of Use (`https://www.apple.com/legal/internet-services/itunes/dev/stdeula/`) and Privacy Policy (`https://macros-web.jhonra121.workers.dev/privacy`). Put the two URLs in one `ProLegalLinks` enum so WS8 can swap them later.
- Prices and periods come from `Product.displayPrice` and `Product.subscription?.subscriptionPeriod`; never hardcode price strings.
- Honor the compact-sheet glass-edge rule from the changes log; do not add strokes.

### Settings

- New file `Features/Purchases/ProSettingsSection.swift` replacing `FullUnlockSettingsSection`: status row (Free / Pro Yearly renews <date> / Pro Monthly renews <date> / Pro Lifetime / Full Unlock (legacy)); "Manage Subscription" (`manageSubscriptionsSheet(isPresented:)`, only for subscriptions); Restore Purchases; Redeem Code; DEBUG grant/revoke. `SettingsScreen.swift` changes only the section call and sheet type.
- `MacroRingColorSettingsSection` locked copy: "Included with MACROS Pro."

### Insights locked state (conversion)

- Replace the fake preview with the user's real data for the 7-day range: `InsightsSummaryTiles` fully visible (free teaser), the three cards rendered with real 7-day data under `.blur(radius: 6)` and `allowsHitTesting(false)`, and a centered CTA card "Unlock Insights" opening `ProPaywallSheet(context: .insights)`. The 14D and 30D segments in the locked state are disabled with a lock glyph. This intentionally reverses the earlier "no user data in the locked preview" decision; record that in the changes log.

## Proposed File Shape

- `MACROSPro.storekit` (new, root), delete `FullUnlock.storekit`.
- `cal-macro-tracker.xcodeproj/xcshareddata/xcschemes/cal-macro-tracker.xcscheme`, `project.pbxproj` (file reference rename, test target resource).
- `tools/quality/validate_storekit_config.py`.
- `Features/Purchases/PaidFeature.swift`, `AppEntitlements.swift`, `PurchaseStore.swift`, `ProPaywallSheet.swift` (new), `ProSettingsSection.swift` (new), `ProLegalLinks.swift` (new), `PurchaseFeedbackText` stays where it is or moves to its own file.
- `Features/Settings/SettingsScreen.swift` (minimal), `Features/Insights/InsightsScreen.swift` (locked state), `Features/Dashboard/DashboardScreen.swift` and `Features/Sharing/SharingDashboardScreen.swift` (only if the entitlement API name changes).
- `cal-macro-trackerTests/PurchaseStoreStoreKitTests.swift` (rewrite), `cal-macro-trackerTests/ProEntitlementTests.swift` (new, pure logic).

## Milestones and Tasks

### Payments-review failure inventory (2026-10-25, before fixes)

- Expiry, grace ending, and foreground resume must refresh access without a new transaction or restart; stopped stores must cancel both listeners.
- Lifetime (including family-shared) must not hide management of a separate active subscription.
- Cancelled subscriptions must say Expires, grace must use its grace deadline rather than an old billing date, and unavailable/unverified status must not imply renewal.
- Listener tests must start the store and observe refund, expiry, Ask-to-Buy approval, and renewal without manual refresh.
- The production selection reducer must reject unverified/revoked/upgraded/unrelated or wrong-type facts, preserve subscription dates and grace-period access, select lifetime in either input order, recognize legacy lifetime, and yield Free for empty input.

Review fix 1: `PurchaseStore` now observes both `Transaction.updates` and `Product.SubscriptionInfo.Status.updates`, cancels both on `stop()`/deinit, and refreshes on app-root active scene transitions. Access still comes from `Transaction.currentEntitlements`, including grace, without a wall-clock expiration cutoff. Apple APIs verified: https://developer.apple.com/documentation/storekit/product/subscriptioninfo/status-swift.struct/updates and https://developer.apple.com/documentation/storekit/transaction/currententitlements.

- Review fix 2: `hasActiveSubscription` comes from any accepted auto-renewable current entitlement, independent of `proSource`. Lifetime/legacy access no longer hides Manage Subscription while another subscription remains active.
- Review fix 3: Verified `Product.SubscriptionInfo.Status.all` group statuses supply `willAutoRenew`, renewal state, and grace deadline for Settings. Cancelled subscriptions say Expires, verified renewals say Renews, and missing/unverified status falls back to Active. Grace uses `gracePeriodExpirationDate`; billing retry alone never claims continued access, per Apple's renewal-state contract. Entitled family-shared statuses outrank expired personal statuses. Concurrent refreshes cannot overwrite newer snapshots.
- Review fix 4: StoreKit tests start the production listeners for refund, expiry, Ask-to-Buy approval, cancellation, and renewal; `withObservationTracking` waits have a five-second XCTest deadline, no polling or manual refresh in those paths, and teardown stops listeners. `build-for-testing` passes. The full integration suite remains blocked and is not reported as passing.
- Review fix 5: `AppEntitlements.resolve(from:)` is the deterministic selection reducer used by production. Immutable transaction facts include verification/type/revocation/upgrade/expiration and optional verified renewal state. Direct tests cover both enumeration orders, duplicate-date tie-breaking, lifetime and legacy, subscription dates, all rejection cases, empty input, grace with past billing expiration, missing-status fallback, and non-entitled renewal states. Only reducer results (plus an explicit DEBUG override) update observable access.
- Review validation: 15 `ProEntitlementTests` pass, including renewal/cancellation/grace text decisions and direct reducer coverage. App build, format, catalog validator, and diff checks pass. A fresh simulator catalog probe still fails setup with `SKInternalErrorDomain Code=3`, `WS2.StoreKitSetup Code=1`, and `OctaneSaveConfigurationRequest` rejection; listener runtime tests and purchase-path E2E are not validated. Evidence: `build/ws2-qa-2026-10-25/review-*.log` / `.xcresult` and `QA.md`.

Additional Apple APIs checked: https://developer.apple.com/documentation/storekit/product/subscriptioninfo/status-swift.struct/all, https://developer.apple.com/documentation/storekit/product/subscriptioninfo/renewalstate, https://developer.apple.com/documentation/storekit/product/subscriptioninfo/renewalinfo/graceperiodexpirationdate, https://developer.apple.com/documentation/storekittest/sktestsession/forcerenewalofsubscription(productidentifier:), https://developer.apple.com/documentation/storekittest/sktestsession/approveasktobuytransaction(identifier:), and https://developer.apple.com/documentation/observation/withobservationtracking(_:onchange:).

### Refresh-coalescing re-review fix (2026-10-25)

- Replaced competing generation-guarded refreshes with one shared `Task<EntitlementResolution, Never>`. Requests during its source read or intro-eligibility read set a dirty flag; the task rereads until clean, then publishes one final snapshot and returns that immutable result to every waiter. Purchase/restore feedback uses the returned result, not a potentially stale shared `hasPro`.
- Extracted a StoreKit snapshot source closure for listener-free testing. Before implementation, tests enumerated superseded early returns, overlapping scans, events during the dirty reread, completed-task reuse, and late cancelled publication. Three continuation-gated tests exercise those paths deterministically, without SKTestSession, sleeps, polling, or new production listeners.
- `stop()` cancels/clears the shared task. A cancelled source returning late cannot publish or clear a newer task. Cancellation results derive from the actual committed observable entitlement, avoiding duplicate cached state. Normal concurrent refreshes perform no competing reads.
- Validation: 18 `ProEntitlementTests` + 6 `InsightsAnalyticsTests` pass (24 total); format/build/catalog/diff checks pass. Catalog activation probe still fails setup, exit 65 (`SKInternalErrorDomain Code=3`, `WS2.StoreKitSetup Code=1`), so the full StoreKit suite and purchase-path E2E remain blocked. Evidence: `build/ws2-qa-2026-10-25/coalescing-*.log` / `.xcresult` and `QA.md`. Swift Task awaiting/cancellation semantics verified against https://developer.apple.com/documentation/swift/task.

### WS2 failure inventory (2026-10-25, before implementation)

- Catalog network failure must leave all plans unavailable and allow a successful retry.
- Purchase network failure, cancellation, and Ask to Buy pending must never grant Pro.
- Verified yearly trial must grant yearly Pro with an expiration; expiry must remove it.
- Refunded lifetime must revoke Pro; legacy lifetime must remain recognized.
- Lifetime must outrank a subscription regardless of enumeration order.
- Empty restore must report no purchases; failed restore must preserve the current entitlement.
- Intro eligibility must be read from StoreKit, and become false after prior subscription use.
- All six features must follow Pro; revocation must clear source and expiration.
- Unverified, revoked, and unrelated transactions must not grant access.

### Milestone 1 — Failure list and tests first

- Enumerate failure modes before touching code: products fail to load then retry; purchase network failure; user cancels; purchase pending (Ask to Buy); yearly trial purchase grants Pro with expiration; subscription expiry removes Pro (use `SKTestSession.timeRate` or `expireSubscription`); refund of lifetime revokes; legacy `fullunlock001` grants `legacyFullUnlock`; lifetime beats an expiring subscription when both exist; restore with no purchases reports status; intro-offer eligibility false after a prior subscription.
- Write the XCTest cases for those, then implement until green. Keep `SKTestSession` setup faithful to the existing file (resource from test bundle, `disableDialogs`).

### Milestone 2 — Products, config, validator

### Milestone 3 — Entitlements and store

### Milestone 4 — Paywall, Settings, Insights locked state

### Milestone 5 — Validation and docs

- `make quality-format-check`, `make quality-build`, `make quality-storekit`, targeted tests (`PurchaseStoreStoreKitTests`, `ProEntitlementTests`, `InsightsAnalyticsTests`), `git diff --check`.
- Simulator E2E with the local StoreKit configuration selected in the scheme: purchase each plan, trial flow, cancel, restore, manage subscriptions sheet, redeem code sheet opens, Insights locked and unlocked states, ring colors gate, Settings status strings. Screenshots and steps in `build/ws2-qa-<date>/QA.md`.
- Changes-log entry under a dated heading.

## Edge Cases

- Products unavailable (no network, App Store Connect products missing): paywall shows benefits, disabled primary button with "Loading…" then an inline error; Restore stays enabled.
- Revoked or refunded transactions arriving through `Transaction.updates` must downgrade immediately (existing behavior, keep).
- Family Sharing for the lifetime product: `Transaction.ownershipType == .familyShared` counts as Pro.
- Do not gate anything new that was free before except custom ring colors (already gated).

## Open Questions / Blockers

- Rebase picked up the owner-approved $49.99 lifetime price and `healthWeightImport` gate. Implemented those updated tracker decisions instead of the original dispatch's $39.99 and broad `healthSync`; writing nutrition to Apple Health is not a Pro benefit.

- 2026-10-25 WS2 implementation is in place. Build/format/catalog checks pass and native UI QA confirms real summary values and debug grant/revoke gates. Payment validation is **not complete**: the dedicated iOS 26.4 simulator rejects `SKTestSession` catalog activation (`SKInternalErrorDomain Code=3`; `storekitd`: not entitled for `OctaneSaveConfigurationRequest`). Xcode Run and both installed toolchains were attempted. Tests fail at catalog setup rather than silently passing purchase assertions. See `build/ws2-qa-2026-10-25/QA.md` for exact attempts and pending paths.

- 2026-10-25 time-boxed repair follow-up: **still blocked**, and owner confirms the same rejection predates WS2 (October 13 baseline: four StoreKit setup failures). On macOS 27.0.1 (26A434), Xcode 26.4 (17E192), newest installed iOS 26 runtime 26.4 (23E244), a never-booted fresh simulator and then `simctl shutdown all` / erase each produced 12 catalog setup failures (`SKInternalErrorDomain Code=3`, `WS2.StoreKitSetup Code=1`, `OctaneSaveConfigurationRequest` not entitled). Live daemon log preserved. A minimal isolated XCUITest successfully launched/held the app, but visible T3 QA still showed all three plans unavailable; screenshot `t3-xcuitest-paywall-unavailable.png`. Explicit signature `get-task-allow` also failed to provide a runnable test environment; no production signing changes retained. Apple documents related fixes in iOS 26.5 (172583218 / FB22237318) and 26.6 (174738526 / FB22500243), neither installed here; forum thread https://developer.apple.com/forums/thread/826971 includes reports after advertised fixes. Exact commands, versions, failures, logs, and isolated probe source: `build/ws2-qa-2026-10-25/QA.md`. Purchase/trial/cancel/restore/manage/redeem/family paths remain unvalidated, not waived.

- Real sandbox testing on a device needs WS9 products in App Store Connect. Local StoreKit configuration is present, but **not operational on this Mac's tested simulator/toolchain**. Next action is a matching newer Xcode/iOS 26 runtime pair or device sandbox/TestFlight after WS9.

- 2026-10-26 simulator repair: catalog activation passed with Xcode 26.4 (17E192) + iOS 27.0 (24A434), but Xcode 27.0 (27A266a) hung on iOS 27.0 and returned `SKInternalErrorDomain Code=3` on iOS 26.4. With the passing pair, `ProEntitlementTests` passed 18/18. The StoreKit run restarted after `testAskToBuyApprovalUnlocksThroughListener` exceeded its allowance; the final 14-test run reported 11 passes and 3 failing cases: `testCancellationDoesNotGrantPro`, `testLegacyGrantsLifetime`, and `testTrialGrantsProWithExpirationAndExpiryRemovesIt`. The Ask to Buy listener case timed out separately. Real-price light/dark paywall screenshots show the selected yearly $19.99/year plan, “7 days free · Best value,” $2.99/month, and $49.99 lifetime at 1206×2622. Full evidence: `build/storekit-repair-2026-10-26/QA.md`. Sandbox purchase/restore on another device, lifetime Family Sharing, and legacy App Store purchase validation still need a real device/account.
