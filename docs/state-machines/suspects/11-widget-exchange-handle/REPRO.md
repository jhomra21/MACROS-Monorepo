# 11. Widget exchange handle

**Verdict: BLOCKED-live; static analysis only, as requested for the in-flux widget branch.**

## Branch and static event order

Fetched `origin/feat/shared-person-widget` during this investigation. Its head remained:

```text
50fa3b90e95d3f5341f4aba7d47fe74e14c855d6
```

At that revision, `cal-macro-tracker/CalMacroWidget/SharedPersonWidgetClient.swift:96–127` shares a token exchange by profile key/generation, then unconditionally clears the exchange handle and saves the awaited token cache.

1. Request A starts an exchange for generation A and suspends in network I/O.
2. Control/identity generation changes; request B enters the actor and installs a new exchange handle for B.
3. A resumes while B is pending. A's `defer { exchange = nil }` can clear B's handle, allowing another B waiter to start redundant work.
4. Alternatively, B saves its token first; A resumes later and overwrites the single token cache with its old-generation cache.

Actor isolation serializes individual actor turns, not the whole method across an await. A same-generation waiter can also clear a handle without proving it still owns that handle.

## Impact limits and safeguards

The source supports a redundant-exchange/cache-churn hypothesis, not a confirmed runtime incident or data disclosure.

- `Shared/SharingWidgetCredentials.swift:17–21` requires matching profile key, generation, deployment URL, and sufficient token lifetime before cached-token reuse.
- The provider rechecks current control around publication. `CalMacroWidget/SharedPersonWidgetProvider.swift:233–237` compares generation, enablement, Pro access, default person, roster, and current day.
- Generation-bound cache selection must not be confused with physically erasing all older cache bytes or immediately redrawing an already-rendered widget.

A stale token cache is rejected for the new generation on later reuse. Do not claim an unauthorized macro read or display leak from this handle race.

## Proposed follow-up, not an implemented fix

When the branch stabilizes, assign each exchange an operation ID and let only its owner clear/publish the current exchange/cache. Keep generation-bound usability and publication checks. Test reverse completion and multiple waiters with controlled transport before assigning a runtime severity.

No widget build, installation, timeline run, backend mutation, or delay hook was attempted for this item. The inherited `onboarding-state.png` and `live-attempt.log` are historical common setup artifacts, not widget execution evidence.
