# 03. Health authorization completion

**Verdict: CONFIRMED transient entitlement-ineligible restart, not an unauthorized Health read. Severity: low.**

## Repeatable event order

1. On the isolated iPad, grant Debug Pro, enable Health weight reading, and complete the native Health authorization UI, granting Weight read access including past history.
2. Set `suspect-health-delay` to `60`. The temporary hook pauses immediately after `requestAuthorization(readWeight: true)` returns and before the existing restart.
3. While that completion is paused, return to Settings > Developer and tap **Revoke Debug Pro**. The app-level refresh stops weight observation.
4. Let the old authorization completion resume. Record the current entitlement, observer start/stop calls, and any applied samples.

## Observed result and artifacts

[Trace](live-repro.log), in order:

```text
1793703569.8326359 pause health-delay begin
1793703594.068263  health stop observation
1793703632.894059  health authorization completion pro=false
1793703632.8941379 health stop observation
1793703632.894222  health start observation
1793703632.935127  health stop observation
```

The old completion restarted observation with Pro false. App refresh stopped it approximately **41 ms** later. No sample application was logged in that interval. The synthetic sample imported only after Debug Pro was granted again, at `1793703709.9891682`. [Pro-revoked screenshot](pro-revoked.png).

This verifies the client entitlement transition using the existing Debug control, not an actual StoreKit expiry event.

## Source, impact, and minimal proposed fix

Baseline `cal-macro-tracker/Features/Health/HealthSettingsSection.swift:32–39` awaits authorization and then restarts without rereading effective Pro. App-level refresh at `cal-macro-tracker/cal_macro_trackerApp.swift:229–235` checks effective access and stops observation. Health import has read-setting/lifecycle checks, but this completion lacks the entitlement recheck.

The confirmed impact is a brief unnecessary observer restart after access is revoked. No durable Pro bypass, unauthorized OS permission, or Health-data disclosure was demonstrated. Re-read both effective entitlement and the current weight-read setting after the await, before restarting or publishing the settings change, as the nutrition path already does.

## Exact temporary hook

[Archived patch](../temporary-hooks.patch.txt):

```swift
#if DEBUG
await SuspectProbe.pause("health-delay")
SuspectProbe.trace("health authorization completion pro=\(entitlements.canUse(.healthWeightImport))")
#endif
```

It was placed after the existing authorization await. Separate DEBUG logs recorded observer start/stop and applied sample counts. Hooks were discarded; synthetic sample cleanup is recorded in suspect 02.
