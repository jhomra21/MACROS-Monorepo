# 01. Repair stale writeback

**Verdict: BLOCKED (live).** No app change or temporary hook.

## Trigger order and expected user impact

1. A log entry has `needsRepair` secondary nutrients and a resolvable external source.
2. Start `repairLogEntrySecondaryNutrientsIfNeeded`; it captures the entry's source, nutrient and quantity values, then suspends while `historicalRepairDraftResolution` awaits the source lookup.
3. Edit that same entry's source identity, quantity, or secondary nutrients while the lookup is pending.
4. Let the lookup complete. The repair re-finds the row by persistent ID and writes the captured repair values without checking that the source/quantity revision still matches.

If real, the entry can display nutrients recalculated from stale source or quantity values, overwriting the user's edit.

## Evidence and live attempt

- `cal-macro-tracker/Data/Services/SecondaryNutrientRepairExecution.swift:111–164` gathers repair drafts across awaits; `168–200` re-finds by ID and writes them without comparing an original revision.
- Reproduction requires a deliberately delayed source lookup plus an edit to the same row in that await window. A clean Debug app was launched on the iPhone 17e, but this simulator has no touch driver; no such lookup or row edit could be initiated. Screenshot: `onboarding-state.png`.
- Repeatable setup evidence: build/run notes in `live-attempt.log`. A launch screenshot does not exercise this race.
