# 03. Authorization completing after Pro revocation

Media removed in the repo cleanup; retrieve with `git show 074b10994f1b68d9d7a8d6c54ed7effb90d5f1f5:docs/evidence/state-machine-fixes-2/03/red-pro-revoked.png`.

## Exact live sequence

1. Apply only the archived Health authorization pause and observer/import-count logs, plus the helper.
2. Grant Debug Pro, enable **Read weight from Health**, and complete native Weight authorization including past history.
3. Arm `health-delay` to `60`. Toggle weight reading off/on to request authorization again.
4. During the post-authorization pause, scroll to Developer and **Revoke Debug Pro**.
5. Wait for the old authorization completion, then capture its current entitlement and observer calls. Rebuild with the guard and repeat identically.

Exact hook immediately after the authorization await:

```swift
#if DEBUG
await SuspectProbe.pause("health-delay")
SuspectProbe.trace("health authorization completion pro=\(entitlements.canUse(.healthWeightImport))")
#endif
```

## Result

- RED: [trace](red-trace.log), revoked screenshot. The final attempt pauses at `1793715826.909082`, stops at `1793715834.208098`, resumes with `pro=false` at `1793715890.757762`, and nevertheless starts observation at `1793715890.758247`.
- GREEN: [trace](green-trace.log), revoked screenshot. The new attempt pauses at `1793715965.238078`, stops at `1793715969.378555`, and resumes with `pro=false` at `1793716029.08141`. There is **no subsequent restart or import** in that run. Earlier RED lines remain in this cumulative trace.

Fix: `HealthSettingsSection.swift:37` rereads the current read setting and effective Health-weight entitlement after authorization, before either restarting observation/import or notifying the app-level service refresh. This proves Debug entitlement revocation, not an actual StoreKit expiry or unauthorized OS read.
