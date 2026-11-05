# Final cleanup review

Media removed in the repo cleanup; retrieve with `git show 074b10994f1b68d9d7a8d6c54ed7effb90d5f1f5:docs/evidence/unified-food-search/green-ax5-stacked.png`.

## Scope and reason

Reviewed the Swift search/session/selection changes, Worker adapters/orchestration/cache/cursor/budget changes, legacy v1 extraction, tests, and evidence. This pass counters unnecessary GPT-added defenses and stale abstractions. It ran after normal Worker and Swift validators, locally without subagents.

## Candidates and decisions

- **Remove:** `RemoteSearchResult.makeDraft()` declared `throws`, but its only operation now composes nonthrowing `FoodDraftImportedData` and `FoodDraft` initializers. Removed the declaration and call-site `try`s, including the new parity test. Repository lookups still throw and still present retry recovery.
- **Keep:** cancellation checks and generation comparisons in `FoodSearchSession`. SwiftUI task cancellation and cancellation-ignoring transport completions are reachable; the stale-result test exercises this.
- **Keep:** minimum query checks at UI/session, client, and Worker boundaries. The client and pure Worker orchestrator are also callable independently; route validation rejects invalid queries before dependencies and rate-limit I/O.
- **Keep:** optional nutrient parsing and finite/nonnegative checks. Upstream values are untrusted and missing/partial nutrition must remain reviewable, not fabricated.
- **Keep:** separate source positions, fail-closed coordination, and abort wrappers. Source failure, quota denial, nonsettling RPCs and nonsettling adapters are real tested paths.
- **Keep:** legacy v1 mapping/filtering and unchanged provider response/caches. Removing those alongside the new normalized contract would break shipped clients.

## Other final refinements

- Reused the existing stacked nutrition-row layout for remote AX5 results after the screenshot exposed cramped horizontal layout.
- Retained a completed query across view-task restarts so returning from review does not refetch it. Explicit submit/retry/load-more still bypass this reuse.
- Old provider enums, fallback controls, duplicate controllers and packaged-search client were removed; no extra source switch was introduced in Swift.

## Validation and outcome

Worker: 83 passing tests, 278 assertions; type check and 106-file JS lint pass. Swift format/build pass. After the final cleanup, the serial iPad xcresult reports 252 passing non-StoreKit tests, no failures/skips/runtime warnings. Existing test files are unchanged. Live v2/v1 probes, paused typing, real unreachable-base retry, camera Search, meal picker/review, navigation return and AX5 artifacts are indexed in README.md.

No further high-confidence redundant defenses found. Open operational/policy and hardware-validation limits are recorded in README.md.
