# 03. Health authorization completion

**Verdict: BLOCKED (live).** No app change or temporary hook.

## Trigger order and expected user impact

1. Pro entitlement allows Health weight import, and the user enables Health weight reading.
2. The settings view starts an asynchronous Health authorization request.
3. While authorization is suspended, Pro expires or becomes unavailable.
4. Authorization returns; the completion path calls `restartWeightObservation` based on the pre-await setting decision.
5. App-level service refresh may later stop observation after it re-reads effective entitlement.

If real, Health weight observation may start briefly after entitlement has expired, before refresh stops it. This needs measurement; the code does not establish an unauthorized Health read.

## Evidence and live attempt

- `cal-macro-tracker/Features/Health/HealthSettingsSection.swift:32–39` awaits authorization and then restarts observation using the earlier condition. The observer import itself checks `healthWeightReadEnabled` in `cal-macro-tracker/Features/Health/HealthKitService.swift:273–278`; app refresh also checks current Pro before starting it.
- The clean simulator app was launched, but Health settings and entitlement controls could not be driven without a touch interface. `simctl` does not expose HealthKit permission grants or sample injection; `onboarding-state.png` is the only captured UI state.
- No access to live Health data or Pro expiry was simulated. A device-level entitlement toggle and HealthKit fixture are required.
