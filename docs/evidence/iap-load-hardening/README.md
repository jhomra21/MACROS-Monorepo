# IAP product-loading hardening

## Failure modes to cover

- StoreKit returns an empty product list on a cold launch, then returns products on a later request.
- StoreKit throws a transient network error, then succeeds on retry.
- StoreKit returns only some requested products; those products must remain usable while missing products are retried.
- StoreKit remains empty or partial through the bounded automatic retries; the existing error and manual Retry control remain available.
- A product request does not finish promptly; the paywall must remain in its loading state until completion rather than presenting a false unavailable state.
- The paywall opens before the launch prefetch completes; both callers must share one request sequence.
- Repeated manual Retry taps or a new request must not overlap the active request or publish stale results.
- The paywall disappears while a retry backoff is pending; cancellation must stop the remaining attempts.
- The app returns to the foreground after products failed while offline; missing products should be requested again.
- A user with Pro entitlement must retain the existing purchase, restore, and entitlement behavior while products refresh.
- The unavailable/loading/error states must remain usable in the iPad layout and with its larger available width.

## Diagnostic

On 2026-11-11, a Debug simulator build was made and the shared scheme was copied temporarily with its `StoreKitConfigurationFileReference` removed. The simulator is the existing iPhone 17e (`F976E800-DA1F-4F20-B755-DFD964E33975`), locked for this task. The diagnostic XCTest reported:

- Requested: `macros.pro.yearly`, `macros.pro.monthly`, `macros.pro.lifetime`
- Returned: all three IDs
- Error: none
- Storefront country: `USA`
- `AppTransaction` environment: `Xcode`

This was **not a valid Apple sandbox result**. Despite removing the scheme reference, StoreKit reported the Xcode environment, indicating the simulator's StoreKit Testing configuration remained active. The result does not establish whether the simulator can reach Apple's sandbox; a true sandbox product response could not be captured in this run. The temporary scheme and probe test were removed. The local StoreKit configuration remains enabled for StoreKit tests.

## Implementation and validation

The five new XCTest cases were added before the loading implementation. Their first build failed because `PurchaseStore` had no product-source injection seam. After adding the seam and retry behavior, all five passed:

- Empty response, then products: loaded without user Retry and cleared feedback.
- Thrown request, then success: loaded all products.
- Partial response, then full response: merged all three products.
- Empty for three attempts: showed the existing error; a later manual Retry succeeded.
- Two overlapping callers: one product request sequence.

Validation on the existing iPhone 17e, serially:

- `PurchaseStoreStoreKitTests`: 20/20 passed.
- Unit suite excluding `PurchaseStoreStoreKitTests`: 263/263 passed.
- `cal-macro-trackerUITests`: 18/18 passed.
- `make quality-build`, `make quality-storekit`, `make quality-format-check`, strict `swift-format lint` on changed Swift files, and `git diff --check`: passed.

The shared test run first encountered an Xcode diagnostics-collection timeout after one test exceeded its allowance; rerunning that case with `-collect-test-diagnostics never` passed. The final StoreKit, unit, and UI suite runs used that setting and passed.

The release build number is set to 37 in all project targets. Archive/export/upload status is recorded in the release tracker when available.

## Review fixes

The follow-up review corrections keep StoreKit diagnostics off the product-loading critical path, race each request against an injectable hard deadline without structured-task-group waiting, guard state writes after awaited retry/eligibility work, and show “Loading…” for unavailable plan prices while products are loading. Product IDs and errors are logged synchronously; storefront and App Store environment diagnostics run asynchronously.

Four regression tests were added first. The initial red run failed at compile time because the timeout/diagnostics injection seams and paywall label helper did not yet exist. After implementation, `PurchaseStoreStoreKitTests` passed 24/24, the serial unit suite excluding that class passed 263/263, and `cal-macro-trackerUITests` passed 18/18. `make quality-build`, `make quality-format-check`, strict `swift-format lint` on changed Swift files, and `git diff --check` passed.
