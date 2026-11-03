# 07. Root deferred deep link

**Verdict: BLOCKED (live).** No app change or temporary hook.

## Trigger order and expected user impact

1. Keep the app in a state where a sharing route is deferred (for example, onboarding is not complete).
2. Deliver sharing invite request A.
3. Before the queued main-thread append for A runs, deliver request B.
4. Allow both queued appends to run. The request token is recorded on each route, but the queued closure does not compare it with the latest token.

If real, the navigation stack can contain an obsolete invite route; the user may be routed to or prompted about the earlier invite instead of the latest one.

## Evidence and live attempt

- `cal-macro-tracker/App/AppRootView.swift:212–227` increments `openRequestToken`, schedules `path.append` asynchronously and clears the pending request; the deferred closure has no token comparison.
- On a clean Debug install, I sent `calmacrotracker://sharing/invite/live-attempt`, then `calmacrotracker://sharing`, then `calmacrotracker://add-food/scan-barcode` using `simctl openurl`. Capture: `openurl-attempt.png`. Onboarding remained the visible route; this did not prove or disprove the queued-route race.
- No touch driver was available to complete onboarding and inspect navigation. The commands are repeatable from `live-attempt.log`'s device setup plus those three `simctl openurl` URLs.
