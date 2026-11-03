# 07. Root deferred deep link

**Verdict: CONFIRMED with a widened deferred-append window. Severity: low. Natural one-run-loop reproduction was not established.**

## Repeatable event order

1. Complete onboarding on the locked iPhone 17 A using the Debug app. Do not erase its existing data or use its existing sharing credentials for backend tests.
2. First try sequential sharing links without a timing delay. The latest route appeared normally; this did not reproduce the race.
3. Set the DEBUG route delay to `10` seconds. Open `calmacrotracker://sharing/invite/repro-C`, then about one second later open `calmacrotracker://sharing/invite/repro-D`.
4. Wait for both deferred appends. Inspect the top route and then tap its navigation Back button.
5. These are deliberately invalid, nonsecret invite inputs. No backend invite creation or acceptance is required.

## Observed result and artifacts

[Trace](live-repro.log):

```text
1793702952.003319  route requested 1
1793702952.913331  route requested 2
1793702962.5033932 route appended 1 latest=2 count=1
1793702962.985145  route appended 2 latest=2 count=2
```

[The top route](replaced-route.png) was the latest D input. [Back returned to obsolete C](obsolete-route-return.png), demonstrating the two-route stack after replacement. This is not evidence that the old request became topmost, or that a real invitation was accepted.

## Source, impact, and minimal proposed fix

Baseline `cal-macro-tracker/App/AppRootView.swift:212–227` resets presented navigation, increments `openRequestToken`, and queues an append containing the captured request ID. The deferred closure does not compare it to the current token.

An obsolete invitation screen can remain in navigation history after a newer link replaces it, confusing Back navigation or showing an outdated prompt. Check the captured request ID against the latest token inside the deferred closure, and invalidate queued sharing requests when another replacement route supersedes them.

## Exact timing hook and confidence limit

The DEBUG hook replaced the normal `DispatchQueue.main.async` append with `DispatchQueue.main.asyncAfter(deadline: .now() + delay)` only while `route-delay > 0`. It kept the existing reset, token increment, route payload, and append, and logged request/latest IDs and path count. [Exact patch](../temporary-hooks.patch.txt).

This deliberately changes scheduling from one turn to ten seconds. It proves stale-append acceptance under that interleaving and the resulting live navigation defect, not its natural frequency or reachability at unmodified timing. No fix was implemented. The uninstrumented app was reinstalled on A; its service profile was verified, then the owned boot was shut down and its lock released.
