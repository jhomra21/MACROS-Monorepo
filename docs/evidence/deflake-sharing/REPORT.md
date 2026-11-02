# Sharing reliability test deflake

## Root cause

The sharing reliability tests used a `PassthroughSubject` to drive a service
subscription consumed through `AsyncPublisher.values`. The test remote's
`dashboardStarted(count:)` helper only waited for Combine's
`receiveSubscription`. That proves the publisher has a subscriber, but not
that the async iterator has requested its first element. Sending the dashboard
at that point can lose the first value because `PassthroughSubject` does not
replay values. The tests then waited for Observation callbacks that could
never arrive.

The test helper now waits for both subscription and downstream demand for
each individual stream. The observation helper performs the action first,
checks the requested production-state predicate, then arms Observation and
checks again before suspending. It keeps observing until the actual condition
is true, and fails instead of hanging if the condition never arrives.

The invite-reuse test also compared two `Date` values using exact equality
after persisting the expiration as a `Double` in `UserDefaults`. The failure
logged identical dates to the displayed second, but exact floating-point
equality is not preserved through that round trip. The comparison now allows
at most 1 ms difference, preserving the same expiration intent.

No app code changed and no tests were added.

## Before evidence

- Build 26 serial-suite log,
  `release-b26/build/testflight-b26/test.log`: 34 tests in
  `SharingReliabilityTests`, one failure. `testPausedConnectionBlocksFoodUpload`
  failed with `Asynchronous wait failed: Exceeded timeout of 2 seconds, with
  unfulfilled expectations: "production observable state changed"`; the test
  took 2.776 seconds.
- Build 27 serial-suite log,
  `release-b27/build/testflight-b27/serial-tests.log`: 37 tests, three
  failures. `testFoodUploadHashInvalidatesWhenEligibilityEndsAndReturns` and
  `testPausedConnectionBlocksFoodUpload` failed on the same 2-second
  Observation timeout (2.044 and 2.041 seconds). The invite-reuse test failed
  its exact `Date` equality at line 603 even though both values printed as
  `2026-11-09 15:38:43 +0000`.
- The build 27 report records three consecutive targeted-class retries passing
  after the suite failure, demonstrating the intermittent behavior.

## After validation

All test runs used only iPad simulator
`E91B597B-CE57-4C0B-A8A4-51CBDC3386AB`, serial execution, and the 30/45-second
per-test allowances.

- `SharingReliabilityTests`, 20 consecutive runs without extra load:
  **20/20 passed**, 37 tests per run, zero failures.
- `SharingReliabilityTests`, 20 consecutive runs with one low-priority
  `yes > /dev/null` CPU-load process:
  **20/20 passed**, 37 tests per run, zero failures.
- Full serial suite, skipping `PurchaseStoreStoreKitTests`:
  **3/3 passed**, 228 tests per run, zero failures.
- `make quality-format-check`: passed.

Individual xcodebuild logs are retained under this directory as
`sharing-1.log` through `sharing-20.log`, `loaded-1.log` through
`loaded-20.log`, and `full-1.log` through `full-3.log`.
