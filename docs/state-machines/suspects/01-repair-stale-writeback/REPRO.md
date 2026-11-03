# 01. Repair stale writeback

**Verdict: CONFIRMED, with a temporary timing hook. Severity: medium.**

## Repeatable event order

1. Use the Debug build and isolated iPad setup in the [run notes](../README.md#repeating-the-investigation). In Settings > Developer, use the temporary **Seed Repair Pair** control. It inserts common-food Banana and Apple entries, one serving each, with missing secondary nutrients and `needsRepair`.
2. Set `suspect-repair-delay` in the app's `tmp` directory to `90`, then tap **Start Repair Probe**.
3. Banana's repair is accumulated at one serving. The hook pauses the loop **before the next entry's lookup**, when `repairs.count == 1`. This is not an edit made before Banana's own calculation.
4. Return to Today, open Banana > Edit Entry, use the serving stepper to change `1` to `1.25`, and tap **Save Changes** while repair is paused.
5. Let the repair continue and inspect the stored quantity, per-serving fiber, consumed fiber, and repair state.

## Observed result and artifacts

[The trace](live-repro.log) records the pause at `1793703633.0808249`, resume at `1793703728.64896`, and application at `1793703728.653157` with `quantity=1.25 fiber=3.1`. [The final store](store-after.log) contains:

```text
Banana: servings=1.25, fiberPerServing=3.1, fiberConsumed=3.1, state=current
Apple:  servings=1.00, fiberPerServing=4.4, fiberConsumed=4.4, state=current
```

Banana should have `3.1 × 1.25 = 3.875 g` consumed fiber. The quantity edit survived, but repair wrote the earlier consumed amount and marked it current. [Dashboard after saving the edit while repair was paused](edited-during-repair.png).

## Source, impact, and minimal proposed fix

Baseline `cal-macro-tracker/Data/Services/SecondaryNutrientRepairExecution.swift:111–164` accumulates computed repairs across later awaits; `168–191` re-finds rows by ID and writes those values without checking the captured source/quantity revision.

Users can retain a new quantity with stale secondary-nutrient totals. Capture and compare the entry revision/source/quantity before applying a repair, skipping/retrying changed entries. If the source is still valid and only quantity changed, recompute consumed nutrients from the current quantity at commit. Do not merely add a guard before the first lookup.

## Exact temporary hook

The [archived patch](../temporary-hooks.patch.txt) added this at the start of the existing entry loop, plus nonsecret logging after application:

```swift
#if DEBUG
if repairs.count == 1 { await SuspectProbe.pause("repair-delay") }
#endif
```

The fixture controls called the existing repair service with bundled common-food records. They did not implement a repair fix. All app hooks were discarded and the uninstrumented app reinstalled.
