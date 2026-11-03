# 08. Onboarding permission cancellation

**Verdict: BLOCKED (live).** No app change or temporary hook.

## Trigger order and expected user impact

1. In reminder onboarding, select a reminder and continue.
2. Let the view set `isRequestingPermission = true` and suspend awaiting notification settings or the system permission prompt.
3. Navigate away so `onDisappear` cancels `authorizationTask`.
4. Return to the same view instance.

If cancellation takes the early return, the task does not clear `isRequestingPermission`; the user may see a permanently disabled Continue button/spinner.

## Evidence and live attempt

- `cal-macro-tracker/Features/Onboarding/OnboardingFlow.swift:439–456` sets the busy flag and has cancellation returns after awaits. `253–255` cancels on disappearance; the shown early returns do not reset the flag.
- The clean install showed first-run welcome (`onboarding-state.png`); I could not advance through onboarding or interact with the system permission prompt because no simulator touch driver was available.
- Whether navigation can remove and later reuse this same view instance remains unconfirmed. No permission setting was modified.
