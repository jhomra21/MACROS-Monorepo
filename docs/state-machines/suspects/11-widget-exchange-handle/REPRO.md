# 11. Widget exchange handle

**Verdict: BLOCKED-live (static analysis only; required in-flux branch).**

## Trigger order and expected user impact

1. Widget request A starts token exchange for profile identity/generation A and suspends in the network request.
2. Credentials or the control generation changes; request B starts exchange for generation B and replaces the shared `exchange` handle.
3. A completes while B is still pending: A's unconditional deferred cleanup clears the B handle. Or B completes first and saves token B, then A completes and overwrites the shared cache with token A.

If real, a later widget fetch may repeat token exchange or use a token cache bound to a stale generation, causing transient stale/empty widget data. The source alone does not show a macro disclosure.

## Evidence and live attempt

- Static inspection only at current `origin/feat/shared-person-widget` head `50fa3b90e95d3f5341f4aba7d47fe74e14c855d6`: `SharedPersonWidgetClient.swift:96–127` shares the exchange by identity/generation, then unconditionally clears `exchange` and saves the awaited cache. This branch is in flux.
- No widget build, installation, or live request was attempted: user instructions require static analysis for this item unless trivial. `onboarding-state.png` is only a common simulator capture, not evidence of widget execution.
- Do not treat this static interleaving as a confirmed runtime defect; check generation ownership before accepting a cache write on the stabilized widget branch.
