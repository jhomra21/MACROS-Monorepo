# 08. Onboarding permission cancellation

**Verdict: NOT REPRODUCIBLE as the suspected same-instance cancellation failure in the attempted UI paths. This is not a proof against every future presentation path.**

## Repeatable event order and live attempts

The suspected sequence is: reminder permission task becomes busy → `onDisappear` cancels it during an await → the **same** reminder view instance returns with its busy flag still set.

On the isolated iPad:

1. Relaunch Debug with `-hasCompletedGoalSetup NO` to expose onboarding, then use **Get Started > I already know my numbers > Continue** to reach **Stay on track**. This is an onboarding-entry override, not a cancellation injection.
2. Enable **Daily reminder**, set `suspect-onboarding-delay` to `30`, and tap Continue. Try Back during the pause, then Home and reopen the app.
3. Back made no navigation change. The Back control disappeared and reminder controls/Continue were disabled. Home/return did not cancel the paused task: [the trace](live-repro.log) says `cancelled=false`.
4. Relaunch and reach the reminder screen again. [The fresh view](fresh-view.png) and [its UI snapshot](fresh-view-ui.log) show enabled controls, not the previous instance's stuck busy state.
5. Repeat with a 15-second pause and DEBUG logs around notification settings/disappearance. The settings await returned with `cancelled=false status=2` (authorized), before a later disappearance. No cancellation early return followed by reuse of that same instance was observed.

[After-background UI](after-background-ui.log) and [busy-screen capture](permission-after-background.png) record the attempted waiting state, not proof of a canceled task. The launch-argument override can also prevent normal completion from being reflected by an AppStorage read; do not interpret that forced-onboarding screenshot as a natural completion hang.

## Why the attempted paths do not establish the suspect

Baseline `cal-macro-tracker/Features/Onboarding/OnboardingFlow.swift:236–255` disables reminder controls/Continue while requesting, hides navigation Back, and cancels on disappearance. `430–456` sets busy and checks cancellation after awaits. The apparent missing busy reset on a canceled return is real in source, but the required same-instance removal/return was not reached.

A normal background transition is not itself `onDisappear` cancellation. Popping/recreating onboarding or killing/relaunching the process creates fresh state. The later trace's `onboarding disappear busy=true` occurs **after** an uncanceled authorized settings return; it does not demonstrate the required canceled-await path.

No app fix is proposed from these attempts. If a supported presentation path is later found that preserves this same instance across cancellation, retest it before adding lifecycle cleanup.

## Temporary hooks and limitations

The [patch](../temporary-hooks.patch.txt) inserted `await SuspectProbe.pause("onboarding-delay")` at the beginning of the existing authorization task, plus DEBUG settings/authorization/disappearance logs. It did not force a cancel or reset busy state. An added Developer **Show Onboarding Probe** button was not successfully invoked and is not evidence. All hooks were discarded. No physical-device notification cancellation test was run.
