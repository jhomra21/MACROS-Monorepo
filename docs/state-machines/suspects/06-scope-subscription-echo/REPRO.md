# 06. Scope response versus subscription echo

**Verdict: BLOCKED (live).** No app change or temporary hook.

## Trigger order and expected user impact

1. Start outgoing-scope write W1 from the detail screen; keep its response delayed after the server commits it.
2. A second client commits a newer scope W2.
3. The live subscription emits W2; `acceptServerScope` adopts it.
4. W1's older response arrives; `confirmWrite` unconditionally adopts W1.

If real, the scope picker can show an older confirmed scope than the server, misleading the user about what is shared.

## Evidence and live attempt

- `cal-macro-tracker/Features/Sharing/SharingPersonScreen.swift:220–230` accepts dashboard and scope updates independently. `234–248` confirms the write result; `278–291` does not order it against a server echo.
- A clean Debug install was launched, but there was no touch driver for the sharing screen and the dev backend URL could not be verified for safe use. No second identity was created.
- Exact response/echo scheduling and a real detail screen are required; `onboarding-state.png` does not exercise sharing.
