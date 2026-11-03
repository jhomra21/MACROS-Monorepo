# 06. Scope response versus subscription echo

**Verdict: CONFIRMED against the dev backend, with a temporary response-delay hook. Severity: medium.**

## Repeatable event order

1. Establish the fresh Owner/Peer relationship from the [run notes](../README.md#repeating-the-investigation), with Peer visible on the app's Sharing Dashboard. Open Peer's detail screen. Owner's initial outgoing scope is **Macros**.
2. Set `suspect-scope-delay` to `45`, then tap **Macros + Foods** in the real picker. The hook pauses after the remote mutation returns, before the service method returns to the view.
3. Let the dashboard subscription echo `macrosAndFoods`.
4. From the second HTTP client authenticated as the **same Owner**, call `setOutgoingScope(..., scope: "off", ...)` for Peer. Let the app's subscription echo `off`.
5. Keep the detail screen open until the older app operation resumes. Compare its picker with a fresh authoritative dashboard query.

## Observed result and artifacts

[Trace](live-repro.log):

```text
1793704197.2873712 scope mutation returned macrosAndFoods
1793704197.290084  pause scope-delay begin
1793704197.3014421 scope echo macrosAndFoods
1793704199.2672238 scope echo off
1793704245.178015  pause scope-delay end cancelled=false
1793704245.178255  scope confirmed macrosAndFoods
```

The [newer-echo screenshot](newer-echo.png) and [UI snapshot](newer-echo-ui.log) precede the stale completion. After it resumed, the [picker screenshot](stale-confirmation.png) and [UI snapshot](stale-confirmation-ui.log) showed **Macros + Foods** selected. The [authoritative query](authoritative-after.log) still returned `outgoingScope=off`. [Remote write result](backend-newer-scope.log).

## Source, impact, and minimal proposed fix

Baseline `cal-macro-tracker/Features/Sharing/SharingPersonScreen.swift:229–244` accepts subscription updates independently of async write completion. `SharingScopeSelection.confirmWrite` at `278–281` overwrites both selected and confirmed values; `acceptServerScope` at `289–292` supplies no ordering/version fence.

The picker misrepresents the actual sharing setting. In this run the server remained more restrictive: no new server disclosure was established. Preserve authoritative updates observed after a write began. Use a server revision or an operation/echo version, and reconcile from current authoritative state before confirming an older completion. Merely disabling another tap on this screen cannot stop a second client.

## Exact temporary hook

In `SharingSyncService.setOutgoingScope`, immediately after the existing `accountActions.setOutgoingScope` await:

```swift
#if DEBUG
SuspectProbe.trace("scope mutation returned \(scope.rawValue)")
await SuspectProbe.pause("scope-delay")
#endif
```

DEBUG logs in the detail screen recorded server echoes and final confirmation. The second client used the real dev mutation. [Archived patch](../temporary-hooks.patch.txt). All hooks were discarded; [both profiles were deleted](../backend-cleanup.log).
