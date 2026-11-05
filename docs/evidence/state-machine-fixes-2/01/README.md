# 01. Quantity edit during nutrient repair

Media removed in the repo cleanup; retrieve with `git show 074b10994f1b68d9d7a8d6c54ed7effb90d5f1f5:docs/evidence/state-machine-fixes-2/01/red-edited.png`.

## Exact live sequence

1. Apply only the archived `SecondaryNutrientRepairExecution.swift` timing/log hooks and Developer **Seed Repair Pair** / **Start Repair Probe** controls, plus the root probe helper. Seed Banana and Apple at one serving with missing secondary nutrients.
2. Arm `repair-delay` to `90`, then tap **Start Repair Probe**.
3. While the loop pauses before the next entry's lookup, return to Today, open Banana, increment servings from 1 to 1.25, and save.
4. Wait for the hook to resume, then inspect the store. Remove/reseed only these synthetic entries before repeating GREEN.

Exact timing hook at the beginning of the entry loop:

```swift
#if DEBUG
if repairs.count == 1 { await SuspectProbe.pause("repair-delay") }
#endif
```

After writeback the hook logged `repair applied quantity=... fiber=...`. The fixture controls call the normal common-food seed loader and repair service; they do not calculate the fix.

## Result

- RED: [store](red-store.log), [trace](red-trace.log), quantity edit screenshot. At `1793715321.475556`, Banana has 1.25 servings but 3.1 g consumed fiber, marked current.
- GREEN: [store](green-store.log), [trace](green-trace.log), same edit screenshot. At `1793715592.6776152`, Banana has 1.25 servings, 3.1 g per-serving fiber, and **3.875 g consumed fiber**, marked current.

Fix: `SecondaryNutrientRepairExecution.swift:99–184` captures the existing `FoodDraftImportedData` snapshot, rejects deleted/food-edited rows at writeback, and computes consumed nutrients from the current quantity with no intervening await. Quantity-only edits remain eligible for repair. The same snapshot check prevents stale `.notRepairable` writes.
