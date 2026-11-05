# StoreKit test timing, 2026-11-05

## Scope and reproduction

Baseline: `c60626d`. Xcode 27.0 (27A266a), selected with
`DEVELOPER_DIR=/Applications/Xcode-26.4.1.app/Contents/Developer`, iOS 27.0,
iPad runner `E91B597B-CE57-4C0B-A8A4-51CBDC3386AB`. The runner was Shutdown
before this task. Only this runner may be used, under its atomic directory lock.
No production services, owner simulator, or real purchase accounts are involved.
Raw output belongs in ignored `build/evidence/2026-11-05-storekit-test-timing/`.

## Failure inventory (written before code changes)

### Legacy lifetime

- `SKTestSession.buyProduct` can return before `Transaction.currentEntitlements`
  exposes its new purchase. One immediate refresh then commits an empty snapshot.
- Unlike the other successful-purchase tests, the legacy test never starts the
  transaction listener or observes delivery, so a later update cannot repair it.
- A real cold-refresh app bug could omit `fullunlock001`: wrong product mapping,
  catalog product type, verification, filtering, or resolution priority.
- An unfinished transaction could affect delivery, or a previous test's session
  state could leak through reset/clear ordering.
- A concurrent listener refresh could commit a stale snapshot or overwrite state.
- A stopped store's in-flight task could publish after teardown or retain the
  previous session; cancellation is requested, not synchronously joined.

### Ask to Buy

- The initial `start()` scan, product loading, or `purchase(.monthly)` can stall
  before the test reaches its five-second observation wait.
- Pending purchase state might not yet appear in `allTransactions()`, or that
  synchronous StoreKitTest IPC call could block the main actor.
- Synchronous `approveAskToBuyTransaction` can block the main actor while delivery
  needs it. The existing helper awaits the action before starting its bounded wait.
- Approval could fail, target the wrong transaction, never emit an update, or
  arrive before a listener is active.
- A refresh could read before approved entitlement visibility, miss an event, or
  commit a stale subscription status.
- Main-actor starvation, unfinished transactions, session cleanup, or listener
  cancellation across tests could interfere with StoreKitTest IPC/delivery.
- The helper's observation callback could miss a mutation or fulfill too early.
- Xcode/runtime StoreKitTest services could hang independently of app behavior.

### Initial source findings, not runtime conclusions

`ProSource` maps `fullunlock001` to `.legacyFullUnlock`; the resolver accepts its
verified nonconsumable and does not require a loaded product or subscription
status. `refreshEntitlements()` reads current entitlements even without `start()`.
`start()` installs update tasks before refreshing; `stop()` cancels all three
tasks, and canceled refreshes cannot commit. Each test creates a new session,
resets/clears it before building the store, then stops the store before clearing
transactions in teardown. No stored shared `PurchaseStore` is reused.
Runtime evidence is still required to distinguish publication timing from an app
defect or StoreKitTest service blocking.

## Diagnosis and fix

**Legacy: test publication timing, not a demonstrated app bug.** In
`diagnostic.log`, the first refresh returned no access, then a direct enumeration
contained a verified `fullunlock001` nonconsumable and a newly constructed store's
cold refresh resolved `.legacyFullUnlock`, all within the same second (the whole
test took 0.070 seconds). The fixed test starts the listener and uses the existing
five-second observation helper before asserting. It also checks a separate store
that has never called `start()`, preserving cold-refresh coverage. There is no
change to `PurchaseStore` or `AppEntitlements`.

**Ask to Buy: test-harness timing hazards; the original 45-second blocking site
remains unproven.** It did not time out during this investigation. Temporary logs
covered start, purchase, pending lookup, approval, and observation. A 100-iteration
diagnostic stopped on iteration 55: access was already granted before approval,
and the pending identifier repeated from the preceding iteration. This proves
session/cache isolation can fail, not which call caused the owner's earlier
timeout. The fix syncs StoreKit after clearing session state and moves synchronous
pending lookup and approval IPC to detached tasks so they cannot block the
main-actor listener. The SDK declares both StoreKitTest session and transaction
objects Sendable. The purchase path and listener-based approval assertion remain
real; no fake purchase, delay, timeout increase, or polling was introduced.

**Completion versus observation is a second real ordering hazard.**
`PurchaseStore.handle` publishes entitlements before awaiting `transaction.finish()`.
The old helper could therefore return and mutate/reset the session while a finish
was still running. Baseline and diagnostic logs contain finish failures crossing
test boundaries. The existing helper now finishes verified transactions from
`Transaction.unfinished` after observing the expected state, before a caller
changes or clears the session. No new helper was added.

Repeated whole-class validation also exposed existing refund, cancellation,
lifetime-priority, and renewal listener flakes. A refund trace showed no revocation
event reaching either the app-host listener or test listener on the failed
iteration, rather than a reducer rejecting a delivered revocation. These simulated
mutations now explicitly sync StoreKit, matching the existing expiry test.
Syncs alone did not pass the gate; the final independent ten-run pass includes the
unfinished-transaction drain. Individual causal contributions cannot be isolated
from these finite runs, so none is claimed as a proven explanation of the original
Ask to Buy timeout.

No evidence showed a missing legacy product mapping, wrong catalog type,
verification rejection, a stopped refresh publishing late, or an observation
callback losing an actual entitlement mutation. Main-actor starvation and service
hangs remain possible explanations of the historical timeout, not reproduced facts.
Temporary app/test timing logs were removed before final validation.

Primary API references:
[current entitlements](https://developer.apple.com/documentation/storekit/transaction/currententitlements),
[test purchase](https://developer.apple.com/documentation/storekittest/sktestsession/buyproduct(identifier:options:)),
[approval](https://developer.apple.com/documentation/storekittest/sktestsession/approveasktobuytransaction(identifier:)).

## Before and after

`baseline.log` uses `-test-iterations 10 -run-tests-until-failure`. Xcode repeats
each method, not the whole class: 134 executions, 132 passed, two failed methods
(legacy 1/2 failed; intro eligibility 1/2 failed); Ask to Buy passed 10/10.
The separate `before-1.log` through `before-10.log` each ran all 15 tests in a
new xcodebuild/test-host run, without changing source.

| Test | Failures in ten independent baseline runs |
| --- | --- |
| Ask to Buy approval | 0/10 (historical owner result: 1/2 timed out) |
| Legacy lifetime | 5/10 |
| Cancellation status | 1/10 |
| Lifetime beats subscription | 1/10 |
| Refund | 1/10 |
| Each of the other ten methods | 0/10 |

Only baseline runs 1 and 7 passed the complete class. Later diagnostic Ask to Buy
results were 54/55 passes (one premature-access assertion failure, no timeout).
The diagnostic legacy test failed its original assertions and passed the new
cold-refresh probe.

Intermediate candidates are retained locally, not omitted from the outcome:
`after-3` failed refund; `final-3` and `verify-5` failed renewal.
`stress-candidate` failed cancellation once and intro eligibility nine times.
After the unfinished-transaction drain, `drain-candidate` still failed intro
eligibility nine times in **same-process method repetitions**, while all other
140 executions passed. That cache-sensitive stress mode is not a clean class-run
gate; no assertion was weakened to make it pass. Use separate runs (below), or
`-test-repetition-relaunch-enabled YES`; the earlier relaunch diagnostic passed
150/150 but preceded the final drain change and is not final-code evidence.

Final code: ten consecutive independent whole-class runs (`drain-1` through
`drain-10`), **150/150 passed, zero failures for every method**:

| Run | Passed | XCTest class seconds | Ask to Buy seconds | Legacy seconds |
| --- | --- | --- | --- | --- |
| 1 | 15/15 | 1.445 | 0.400 | 0.047 |
| 2 | 15/15 | 1.847 | 0.198 | 0.157 |
| 3 | 15/15 | 2.142 | 0.318 | 0.188 |
| 4 | 15/15 | 2.106 | 0.308 | 0.082 |
| 5 | 15/15 | 1.840 | 0.360 | 0.095 |
| 6 | 15/15 | 2.159 | 0.344 | 0.104 |
| 7 | 15/15 | 1.772 | 0.205 | 0.131 |
| 8 | 15/15 | 1.736 | 0.261 | 0.093 |
| 9 | 15/15 | 2.019 | 0.384 | 0.120 |
| 10 | 15/15 | 2.473 | 0.622 | 0.105 |

Worst individual test: 0.622 seconds. These are XCTest execution times, not build
or process-launch durations.

## Repeatable validation

Run from this task's worktree. Acquire the lock with atomic `mkdir`; if claimed,
retry every 120 seconds, at most 60 retries (two hours), never remove another
task's lock. Record initial state before use. Every test command was foreground,
bounded by `timeout 1800`, and used these arguments:

```sh
cd /Users/juan/.t3/worktrees/cal-macro-tracker/storekit-tests && timeout 1800 env DEVELOPER_DIR=/Applications/Xcode-26.4.1.app/Contents/Developer xcodebuild \
  -project cal-macro-tracker.xcodeproj -scheme cal-macro-tracker \
  -destination 'platform=iOS Simulator,id=E91B597B-CE57-4C0B-A8A4-51CBDC3386AB' \
  -parallel-testing-enabled NO -test-timeouts-enabled YES \
  -default-test-execution-time-allowance 30 -maximum-test-execution-time-allowance 45 \
  -collect-test-diagnostics never \
  -only-testing:cal-macro-trackerTests/PurchaseStoreStoreKitTests test
```

For the final gate, invoke this command ten separate times, each with a unique
`-resultBundlePath` before `test`; do not retry a failed run into the pass count.
For the rest of the suite, replace `-only-testing` with
`-skip-testing:cal-macro-trackerTests/PurchaseStoreStoreKitTests`.

- Final StoreKit class: ten consecutive 15/15 passes, exit 0 each.
- Full suite excluding StoreKit: **262/262 passed**, zero failures, exit 0
  (`full-suite.log`, 16.069 XCTest seconds).
- `make quality-format-check`: pass, official formatter present, not skipped.
- Explicit strict swift-format lint of the changed test file: pass.
- `DEVELOPER_DIR=/Applications/Xcode-26.4.1.app/Contents/Developer make quality-build`:
  pass; this is compilation, not test evidence.
- `make quality-storekit`: pass.
- `git diff --check` and changed-document Markdown link check: pass.
- Review: app source unchanged; no temporary logs, extra helpers, polling, sleeps,
  timeout changes, or unrelated refactors.

The runner was already Shutdown at cleanup (a targeted shutdown returned
CoreSimulator code 405, already Shutdown); its owned directory lock was released.
No simulator was created, erased, or deleted. Raw logs and xcresult bundles remain
ignored local artifacts, not a durable archive. Sandbox purchases, real-account
legacy access, second-device restore, and Family Sharing were not tested.
