# Architecture Refactor Implementation Tracker

Working tracker for the uncommitted architecture cleanup pass across food draft editing, food logging, secondary nutrient repair, remote lookup, repositories, and sharing sync. Update this file as implementation progresses with task status, bugs, quirks, findings, validation notes, and new decisions.

## Shared Understanding

- Goal: Deepen shallow Modules without changing product behavior, concentrating domain behavior behind smaller Interfaces with better Locality and Leverage.
- Product intent: Preserve the existing iPhone-first calorie/macro tracking flows while making future food logging, saved food, repair, remote lookup, repository, and sharing changes easier to reason about.
- Scope discipline: This pass is architecture cleanup only. It does not add new user-facing features, change Convex schemas, change Convex functions, alter nutrition rules, or introduce new backend behavior.
- Validation: The app should continue to pass the documented iOS validation workflow: `make quality-format-check` and `make quality-build`.
- Build discipline: macOS builds are intentionally deferred while the iOS app is the active product focus.

## Core Decisions

### Architecture Direction

- Prefer deeper Modules with domain-specific Interfaces over pass-through helpers.
- Keep behavior at existing seams when possible, but move scattered state or mapping logic into the Module that owns it.
- Avoid artificial protocols or hypothetical seams when there is only one Adapter.
- Preserve public caller contracts unless a small caller change improves Locality.
- Keep refactors focused and behavior-preserving; validation should be the proof that the cleanup did not change runtime contracts.

### Food Draft Editing

- `FoodDraftNumericText` should own numeric text presentation and editing state for nutrient fields.
- `FoodDraftFormSections` should no longer coordinate nutrient text through a separate bridge Module.
- `FoodDraftNutrientEditingBridge` was shallow after the cleanup and was removed.
- Nutrient text sync, invalidation, and presented-value behavior now live closer to the form state that uses them.

### Food Draft Logging

- Logging/edit validation, quantity mode, quantity amount, reusable-food persistence mode, and quantity multiplier should travel together as one action.
- `FoodDraftLoggingAction` is the single Interface for logging a draft from UI and repository call sites.
- The action stays widget-target-safe and does not reference app-only nutrition types unavailable to the widget target.
- Existing UI flows should route through the action instead of reassembling validation and quantity math independently.

### Secondary Nutrient Repair

- Historical repair lookup should be built once and reused across manual refresh, repair execution, classification, and normalization.
- `SecondaryNutrientRepairHistory.historicalRepairLookup(modelContext:)` is the shared lookup seam.
- Repair maintenance should not duplicate historical lookup construction.

### Remote Food Lookup

- Proxy URL/path/query/request construction belongs in `HTTPJSONClient`, not duplicated in each provider client.
- Provider clients should still preserve provider-specific unavailable-configuration errors.
- `HTTPJSONClient.makeProxyRequest(...)` is the shared request-construction Interface for packaged food search, USDA details, and Open Food Facts barcode lookup.
- Remote lookup behavior, endpoints, and response handling remain unchanged.

### Repository Split

- `FoodItemRepository` should expose its public query facade from the root repository file instead of being a pure shell.
- Internal reusable-food lookup helpers can remain in the query file.
- `LogEntryRepository` root should hold repository identity and dependencies only.
- Food logging, meal logging, and log-entry mapping are separate responsibilities and should live in separate files.
- The generic `LogEntryRepositoryOperations.swift` file name was replaced by responsibility-oriented files.

### Sharing Sync

- `SharingSyncService` should orchestrate observable app state and sync/subscription lifecycle, not own every storage and remote-call detail.
- Convex call construction belongs in a small remote Adapter: `SharingRemoteClient`.
- UserDefaults-backed local sharing metadata belongs in `SharingLocalStateStore`.
- Sharing DTOs, snapshot payload hashing, and day-key formatting belong in `SharingSyncModels`.
- No Convex schema or function changes were needed for this pass; the friction was in the Swift app Module shape.

## Current Code Context

- `cal-macro-tracker/App/FoodDraftFormSections.swift` now contains the deeper `FoodDraftNumericText` behavior.
- `cal-macro-tracker/Data/Models/FoodDraftBehavior.swift` now contains `FoodDraftLoggingAction`.
- `cal-macro-tracker/Data/Services/SecondaryNutrientRepairHistory.swift` now exposes shared historical repair lookup construction.
- `cal-macro-tracker/Data/Services/HTTPJSONClient.swift` now centralizes proxy request creation.
- `cal-macro-tracker/Data/Services/FoodItemRepository.swift` now owns the public reusable-food query facade.
- `cal-macro-tracker/Data/Services/LogEntryRepository.swift` is now a slim root Module.
- `cal-macro-tracker/Features/Sharing/SharingSyncService.swift` is now the sharing sync orchestrator rather than the owner of every sharing concern.
- `AGENTS.md` now documents `make quality-build` as the CLI build workflow and defers macOS builds unless explicitly requested.

## Proposed / Implemented File Shape

Deleted files:

- `cal-macro-tracker/App/FoodDraftNutrientEditingBridge.swift`
- `cal-macro-tracker/Data/Services/LogEntryRepositoryOperations.swift`

New files:

- `cal-macro-tracker/Data/Services/LogEntryRepositoryEntryMapping.swift`
- `cal-macro-tracker/Data/Services/LogEntryRepositoryFoodLogging.swift`
- `cal-macro-tracker/Data/Services/LogEntryRepositoryMealLogging.swift`
- `cal-macro-tracker/Features/Sharing/SharingLocalStateStore.swift`
- `cal-macro-tracker/Features/Sharing/SharingRemoteClient.swift`
- `cal-macro-tracker/Features/Sharing/SharingSyncModels.swift`

Focused edits to existing files:

- `AGENTS.md`
- `cal-macro-tracker/App/FoodDraftFormSections.swift`
- `cal-macro-tracker/Data/Models/FoodDraftBehavior.swift`
- `cal-macro-tracker/Data/Services/FoodItemRepository.swift`
- `cal-macro-tracker/Data/Services/FoodItemRepositoryQueries.swift`
- `cal-macro-tracker/Data/Services/HTTPJSONClient.swift`
- `cal-macro-tracker/Data/Services/LogEntryRepository.swift`
- `cal-macro-tracker/Data/Services/SecondaryNutrientRepairExecution.swift`
- `cal-macro-tracker/Data/Services/SecondaryNutrientRepairHistory.swift`
- `cal-macro-tracker/Data/Services/SecondaryNutrientRepairMaintenance.swift`
- `cal-macro-tracker/Data/Services/USDAFoodDetailsClient.swift`
- `cal-macro-tracker/Features/AddFood/LogFoodScreen.swift`
- `cal-macro-tracker/Features/AddFood/MealComponentRemoteSelectionScreen.swift`
- `cal-macro-tracker/Features/AddFood/PackagedFoodSearchClient.swift`
- `cal-macro-tracker/Features/Dashboard/EditLogEntryScreen.swift`
- `cal-macro-tracker/Features/Scan/Barcode/OpenFoodFactsClient.swift`
- `cal-macro-tracker/Features/Sharing/SharingSyncService.swift`

## Milestones and Tasks

### Milestone 1 — Food Draft Editing Lifecycle

- [x] Identify nutrient editing bridge as a shallow Module.
- [x] Move nutrient text presentation/editing state into `FoodDraftNumericText`.
- [x] Route `FoodDraftFormSections` through the deeper numeric text state.
- [x] Delete `FoodDraftNutrientEditingBridge.swift`.
- [x] Validate formatting and iOS build.

### Milestone 2 — Food Draft Logging Action

- [x] Add `FoodDraftLoggingAction`.
- [x] Add `FoodDraft.loggingAction(...)` convenience construction.
- [x] Centralize logging validation and quantity multiplier on the action.
- [x] Route `LogFoodScreen` through `FoodDraftLoggingAction`.
- [x] Route `EditLogEntryScreen` through `FoodDraftLoggingAction`.
- [x] Route `MealComponentRemoteSelectionScreen` can-save validation through `FoodDraftLoggingAction`.
- [x] Add action-based repository overloads in log entry persistence.
- [x] Remove now-unused duplicate `FoodDraft.canLog(...)`.
- [x] Keep the action safe for files compiled into widget targets.
- [x] Validate formatting and iOS build.

### Milestone 3 — Secondary Nutrient Repair Lookup

- [x] Add `historicalRepairLookup(modelContext:)`.
- [x] Route manual refresh target construction through the shared lookup.
- [x] Route historical repair execution through the shared lookup.
- [x] Route classification through the shared lookup.
- [x] Route unrepairable-state normalization through the shared lookup.
- [x] Validate formatting and iOS build.

### Milestone 4 — Remote Food Lookup Request Construction

- [x] Add `HTTPJSONClient.makeProxyRequest(pathComponents:queryItems:unavailableConfigurationError:)`.
- [x] Route packaged food search through the shared proxy request helper.
- [x] Route USDA food details through the shared proxy request helper.
- [x] Route Open Food Facts barcode lookup through the shared proxy request helper.
- [x] Preserve provider-specific unavailable-configuration errors.
- [x] Remove local barcode lookup URL construction from `OpenFoodFactsClient`.
- [x] Validate formatting and iOS build.

### Milestone 5 — Repository Split

- [x] Move public `FoodItemRepository` reusable-food query facade methods into the root repository Module.
- [x] Keep context-specific reusable-food lookup helpers in `FoodItemRepositoryQueries.swift`.
- [x] Move log-entry value mapping into `LogEntryRepositoryEntryMapping.swift`.
- [x] Move meal logging into `LogEntryRepositoryMealLogging.swift`.
- [x] Rename generic log operations into `LogEntryRepositoryFoodLogging.swift`.
- [x] Keep `LogEntryRepository.swift` as a slim dependency/root Module.
- [x] Validate formatting and iOS build.

### Milestone 6 — Sharing Sync Split

- [x] Inspect Swift sharing sync and Convex sharing modules.
- [x] Confirm no Convex schema or function changes are needed.
- [x] Extract Convex mutation/query/subscription calls into `SharingRemoteClient`.
- [x] Extract UserDefaults-backed sharing state into `SharingLocalStateStore`.
- [x] Extract sharing models, snapshot payload hashing, and `CalendarDay.sharingDayKey` into `SharingSyncModels`.
- [x] Slim `SharingSyncService` down to orchestration of upload, dashboard subscription, invite, relationship, and cleanup flows.
- [x] Preserve existing UI call sites and behavior.
- [x] Validate formatting and iOS build.

### Milestone 7 — Build Workflow Cleanup

- [x] Replace the documented macOS CLI build command with `make quality-build`.
- [x] Document that macOS builds are deferred unless explicitly requested.
- [x] Keep validation focused on the iOS simulator workflow.

## Validation Notes

- `make quality-format-check` passed after each completed architecture surface.
- `make quality-build` passed after each completed architecture surface.
- A macOS build was run once during the early pass and failed because widget provisioning is not configured for that destination; this was treated as irrelevant to the iOS workflow and `AGENTS.md` was updated accordingly.
- Defensive code review passes were run after the multi-step implementation passes; no additional high-confidence cleanup remained after the final repository and sharing sync passes.
- Post-implementation simplify accepted scoped cleanup for `FoodDraftLoggingAction` normalization ownership, an unused sharing import, food-only secondary-repair normalization, and repeated meal repository construction; the suggested `NutritionMath` reuse was intentionally skipped because `FoodDraftBehavior.swift` also compiles in the widget target where `NutritionMath` is unavailable.
- Post-implementation defensive-code review removed redundant pre-normalization at `FoodDraftLoggingAction` call sites and simplified the non-optional secondary-repair lookup path after the empty-entry case is handled explicitly.
- Final follow-up validation passed `git diff --check`, `make quality-format-check`, and `make quality-build`.
- A repeat post-implementation simplify pass found no additional scoped reuse, quality, or efficiency cleanup.
- A repeat defensive-code review found no additional high-confidence redundant guards, duplicated validation, or impossible-state branches.

## Current Uncommitted Work Summary

- The current uncommitted refactor includes edits across food draft editing, logging action construction, secondary nutrient repair, remote lookup, repository split, sharing sync, and build guidance.
- Current deleted files:
  - `cal-macro-tracker/App/FoodDraftNutrientEditingBridge.swift`
  - `cal-macro-tracker/Data/Services/LogEntryRepositoryOperations.swift`
- Current new files:
  - `cal-macro-tracker/Data/Services/LogEntryRepositoryEntryMapping.swift`
  - `cal-macro-tracker/Data/Services/LogEntryRepositoryFoodLogging.swift`
  - `cal-macro-tracker/Data/Services/LogEntryRepositoryMealLogging.swift`
  - `cal-macro-tracker/Features/Sharing/SharingLocalStateStore.swift`
  - `cal-macro-tracker/Features/Sharing/SharingRemoteClient.swift`
  - `cal-macro-tracker/Features/Sharing/SharingSyncModels.swift`

## Follow-Up Candidates

- Add focused tests when a test target exists; there is currently no documented CLI test command in the Xcode project.
- Consider a later UI-level sharing cleanup if `SharingScreen` and `SharingDashboardScreen` continue to duplicate relationship command handling.
- Consider a later Convex sharing Module review only if backend invariants start leaking into Swift callers; this pass did not need backend changes.
- Keep future architecture passes scoped to one domain surface at a time and validate with `make quality-format-check` plus `make quality-build`.
