---
name: defensive-code-review
description: Review completed GPT-model implementation diffs for overtly defensive code, redundant guards, impossible-state branching, and duplicated validation. Use after a GPT-5.4/GPT-5.5 plan has been fully implemented and validators have passed, or when the user explicitly asks for a defensive-code pass.
user-invocable: true
disable-model-invocation: false
---

# Defensive Code Review

Use this as a final cleanup pass after implementation work is complete, especially when the implementing model was GPT-5.4, GPT-5.5, or another GPT coding model. Do not use it at task start, after every edit, for trivial one-file fixes, or before normal validators have run.

## Goal

Find and remove only high-confidence defensive code that is redundant in the real execution path:

- guards for states already proven impossible by the caller, fetch descriptor, initializer, schema, parser, or UI contract
- repeated filters or validations immediately after equivalent filtering/validation
- optional wrappers around child components/helpers that already hide, normalize, or reject empty input
- dead fallback variables assigned only before an immediate throw/return
- `guard let` / `if let` branches after non-empty checks where the API cannot return `nil`
- duplicated local checks that reimplement an existing model, repository, or view helper contract

The output should make the code smaller and easier to trace without weakening real safety, data integrity, UX, or persistence migration behavior.

## Research basis

Treat this as a model-risk mitigation pass, not a style pass.

- Prior local sessions on this repository showed GPT-5.4/GPT-5.5 implementation passes adding extra guards around already-handled states in `LogFoodScreen`, `EditLogEntryScreen`, `OpenFoodFactsClient`, `DailyGoalsRepository`, and `SecondaryNutrientRepairMaintenance`.
- Public agent-evaluation research also highlights a related "failure to abstain" pattern: coding agents often keep changing or "fixing" code even when the correct outcome is to leave it alone. Defensive-code cleanup should counter that tendency by requiring concrete proof before each simplification.

## Required context

Before proposing or editing anything:

1. Read `AGENTS.md`, `SOFTWARE_PATTERNS.md`, and relevant local guidance.
2. Inspect the current diff with `git diff --stat`, `git diff --name-only`, and targeted file diffs.
3. Read changed files plus the helpers/callers that prove whether a state is possible.
4. Check project history such as `changes-log.md` when it explains why a guard exists.
5. Confirm validators already passed for the completed plan, or run the relevant validators before doing cleanup if they have not.

## Review rules

Only flag a defensive branch when all of these are true:

1. The impossible/redundant state is proven by real code, not intuition.
2. The simplification preserves behavior for all reachable paths.
3. The removed code is not documenting or enforcing an important boundary contract.
4. The removal does not rely on force-unwrapping query-backed, persistence-backed, network-backed, OCR-backed, or user-input-backed data unless the invariant is genuinely guaranteed.
5. The cleanup does not introduce a new helper, abstraction, or parallel validation path.

Reject or keep code when it protects:

- persistence/schema migration and legacy stores
- external/network/OCR/barcode/search payload ambiguity
- user-editable review flows and explicit confirmation gates
- widget/read-only/fallback display paths
- async cancellation, stale result ordering, and lifecycle races unless proven impossible
- preview/bootstrap/test paths that reuse a helper outside the main app-ready path

## Workflow

1. Group changed files by feature/layer.
2. For large diffs, spawn parallel `worker` subagents by group. Ask them to return only high-confidence redundant-defense candidates with file, line, proof, and proposed simplification.
3. Independently validate every candidate against the actual code.
4. Reject speculative candidates clearly.
5. Implement only validated simplifications.
6. Run relevant validators again.
7. Do a final diff review for regressions, dead code, and duplicate logic.

## Output format

### Defensive-code review
- Scope:
- Model-risk reason:

### Candidates
- File:
- Redundant defense:
- Proof:
- Decision: Remove / Keep
- Why:

### Implementation
- Changed:
- Left unchanged:

### Validation
- Commands run:
- Results:

### Final review
- Findings:
- LGTM / Follow-up needed
