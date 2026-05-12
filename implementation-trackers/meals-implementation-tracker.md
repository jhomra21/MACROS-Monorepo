# Meals Implementation Tracker

Working tracker for the saved meals feature. Update this file as implementation progresses with task status, bugs, quirks, findings, validation notes, and new decisions.

## Shared Understanding

- Goal: Let users save a named meal made from multiple existing foods, such as eggs, ham, and butter.
- Product intent: Meals total calories, macros, and secondary nutrients from their components, appear in Add Food search like normal on-device foods, and open a meal-specific review UI that shows the component foods before logging.
- First complete loop: create a meal from `Add Food → Manual`, add saved/on-device foods as components with quantities, save it, find it in On Device search, review component breakdown plus totals, and log it as one meal row with a serving multiplier.
- Architecture: Keep meals native Swift/SwiftUI, local-first, and backed by SwiftData records. No backend, Worker, Convex, account, remote sync, paywall, or entitlement changes are part of this feature.
- Scope discipline: Preserve the existing manual custom-food flow, avoid broad food/log refactors, and keep historical logged meals snapshot-based so past rows do not change when saved meals or linked foods change.

## Core Decisions

### Scope

- Logged meals should appear as one row named after the meal in Dashboard and History.
- Meals should support an overall serving multiplier, such as 0.5x, 1x, or 2x the saved meal.
- Meal creation should start in Add Food under Manual.
- Meal creation should support both saved/on-device foods and online packaged-food results; online results must be resolved into saved `FoodItem` records before they become linked meal components.
- Online meal components should use the existing review/resolve flow before attaching, but should only block when calories or primary macros are missing. Missing secondary nutrients should not block meal creation or logging.
- Creating meals from already logged Dashboard/History entries is deferred; first-version components are added through the meal editor's search/select flow only.
- Meals are local SwiftData records only; no backend, Worker, Convex, account, or sync changes are part of this feature.
- Meals are free and should not be behind a paywall or entitlement.

### Data and Persistence

- Meal components should stay linked to saved foods and update meal totals when linked foods change.
- Each meal component should use the same quantity contract as normal food logging: store `quantityMode` plus amount, always allow servings, and allow grams only when the linked food has `gramsPerServing`.
- Deleting a `FoodItem` used by any saved meal should be blocked with a clear message telling the user to remove it from meals first.
- Saving a meal should require a non-empty name and at least one valid component with calories and primary macros.
- Meal name uniqueness is not required.
- Meal components should be unique by `FoodItem.id`; adding an already-present food should route the user to edit the existing component quantity instead of creating a duplicate row.
- Meal component quantities should be edited in a dedicated add/edit sheet or screen that reuses existing serving/grams quantity controls as much as possible; the meal editor list should show summaries, not inline numeric fields.
- `MealEditorScreen` should show live aggregate calories and macros before saving.
- First-version meal UI should show calories and primary macros only, while still computing/storing secondary nutrient totals and snapshots when available.
- Meal creation should not allow ad-hoc unlinked ingredients in the first version; custom ingredients must be saved as foods before they can be meal components.
- Adding meal components should reuse the existing Add Food search experience in a component-picking mode instead of building separate inline search inside the meal editor.
- Meals cannot be nested inside other meals in the first version; component-picking mode should select foods only.
- Meal search rows should use the existing food row layout with a subtle subtitle like `Meal • Egg, Ham, Butter`, capped to a few component names.
- Meal `searchableText` should include the meal name plus component food names; meal-name matches rank above component-name matches.
- Editing a `FoodItem` used by meals should refresh or repair those meals' cached `searchableText` so ingredient-based meal search stays current.
- Editing a `FoodItem` referenced by saved meals should warn that future meal totals will update while past logged meals will not change.
- Logged meals should store component snapshots at log time and should not update historical entries by default when a saved meal or linked food changes.
- Logged meal component snapshots should be created in the same transaction as the aggregate `LogEntry`.
- Persisted common seed foods are valid direct meal components and do not need to be copied into custom saved foods first.
- SwiftData schema migration is a validation-only concern for the first version; existing local stores must open after model registration, but no user-facing migration/recovery UI is planned.

### Search and Ranking

- On Device search should combine foods and meals using the same ranking tiers, then sort by rank and name without giving meals artificial priority.
- Empty Add Food search should show recent saved meals alongside recent on-device foods, sorted by `updatedAt` descending and capped to the existing local result limit.
- Food suggestion pills should not include meals in the first version.

### UI and Navigation

- Logged meal rows should follow the existing `LogEntryRow`/`FoodNutritionRow` design: meal name on the left, a serving/time subtitle underneath, calories and macros on the right, with only a subtle meal indicator if needed.
- Tapping a logged meal in the first version should open a read-only logged meal detail/breakdown, not an editable aggregate log.
- Saved meals should be editable in the first version from the meal review/log screen via an `Edit Meal` action. Settings-based management remains deferred.
- Saved meals should be deletable from `MealEditorScreen` after confirmation; deletion removes the meal from future search but does not alter past logged meal rows.
- Daily totals, widgets, and sharing should not need special meal aggregation because logged meals write aggregate consumed nutrients into `LogEntry` like foods.
- Failed online component resolution should not save partial invalid components; keep the unsaved meal draft in memory, show the error, and allow saving only after every component is a valid linked `FoodItem`.
- Meal-level logging should be servings-only in the first version, such as `0.5 meal`, `1 meal`, or `2 meals`; grams remain available only at the component level when supported by the linked food.
- Logged meals should reuse `QuantityMode.servings` with `servingDescription = "1 meal"` and explicit meal identity/routing fields, not a new quantity mode.
- `Add Food → Manual → Create Meal` should push `MealEditorScreen` onto the existing Add Food navigation stack, not open a separate modal sheet.
- In component-picking mode, users should be able to select multiple local saved foods in one picker session, confirm with a native check action, and then edit quantities from the meal editor if needed.
- The multi-select confirm action should be a native circular `.borderedProminent` toolbar button tinted with the app accent color, containing only a `checkmark` icon. Do not draw custom nested circles or glass/backgrounds inside the label.
- Online component selection should run review/resolve, save as `FoodItem`, then open component quantity editing before returning to `MealEditorScreen`.
- Saving a new meal should navigate directly to `LogMealScreen` for immediate logging instead of returning to Add Food search.
- `Save Meal` should use native disabled button behavior until both a non-empty meal name and at least one component food are present.
- Saving edits to an existing meal should return to the same `LogMealScreen` with refreshed live totals, not pop back to search.
- Deleting a saved meal from `MealEditorScreen` while opened from `LogMealScreen` should pop back to Add Food search or the previous screen and must not leave a stale log screen.
- The existing Manual custom-food flow should stay intact; add `Create Meal` as an additional Manual action instead of replacing Manual with a choice screen.
- Meal search rows and logged meal rows should include simple accessibility labels that identify them as meals and include core nutrition context.
- Meal names do not need to be unique; meal IDs are the source of truth, and duplicate names can be distinguished by component preview or updated date where needed.
- The meal editor can suggest a generated name from components, but should not keep auto-mutating the field after the user edits it.
- Meal component order does not matter in the first version; components can use deterministic name sorting instead of user-controlled reordering.

## Current Code Context

- `cal-macro-tracker/Data/Models/FoodItem.swift` is the persisted reusable food model used for on-device search.
- `cal-macro-tracker/Data/Models/LogEntry.swift` is the persisted logged-food snapshot and currently represents one logged row.
- `cal-macro-tracker/Data/Models/FoodDraft.swift` is the transient single-food logging/editing bridge.
- `cal-macro-tracker/Data/Services/NutritionMath.swift` centralizes deterministic quantity scaling and should be reused for component totals.
- `cal-macro-tracker/Features/AddFood/AddFoodSearchResults.swift` fetches local `FoodItem` rows, shows them in the On Device section, and routes selection to `LogFoodScreen`.
- `cal-macro-tracker/Features/AddFood/LogFoodScreen.swift` currently logs one `FoodDraft` into one `LogEntry`.
- `cal-macro-tracker/Shared/SharedModelContainerFactory.swift` registers the SwiftData schema and must include any new meal models.
- `cal-macro-tracker/Features/Settings/SettingsScreen.swift` currently manages saved custom/external foods; meal management can be added later if needed.

## Proposed File Shape

New files:

- `cal-macro-tracker/Data/Models/Meal.swift`
- `cal-macro-tracker/Data/Models/MealComponent.swift`
- `cal-macro-tracker/Data/Models/LoggedMealComponentSnapshot.swift`
- `cal-macro-tracker/Data/Services/MealRepository.swift`
- `cal-macro-tracker/Features/AddFood/LogMealScreen.swift`
- `cal-macro-tracker/Features/AddFood/LoggedMealDetailScreen.swift`
- `cal-macro-tracker/Features/AddFood/MealEditorScreen.swift`
- `cal-macro-tracker/Features/AddFood/MealComponentRemoteSelectionScreen.swift`
- `cal-macro-tracker/Features/AddFood/MealComponentFoodPickerScreen.swift`
- `cal-macro-tracker/Features/AddFood/MealComponentQuantityScreen.swift`

Focused edits to existing files:

- `cal-macro-tracker/Data/Models/LogEntry.swift`
- `cal-macro-tracker/Data/Services/NutritionMath.swift`
- `cal-macro-tracker/Data/Services/LogEntryRepositoryOperations.swift`
- `cal-macro-tracker/Data/Services/FoodItemRepositoryPersistence.swift`
- `cal-macro-tracker/Data/Services/AppModelContainerFactory.swift`
- `cal-macro-tracker/Shared/SharedModelContainerFactory.swift`
- `cal-macro-tracker/Features/AddFood/AddFoodComponents.swift`
- `cal-macro-tracker/Features/AddFood/AddFoodSearchResults.swift`
- `cal-macro-tracker/Features/AddFood/AddFoodRows.swift`
- `cal-macro-tracker/App/AppRootView.swift`
- `cal-macro-tracker/App/LogEntryListSection.swift`
- `cal-macro-tracker/Features/Dashboard/LogEntryRow.swift`
- `cal-macro-tracker/Features/Settings/ReusableFoodEditorScreen.swift`

Potential next edits:

- `cal-macro-tracker/Features/Dashboard/EditLogEntryScreen.swift`
- `cal-macro-tracker/Features/AddFood/RemoteSearchSelectionScreen.swift`
- `cal-macro-tracker/Features/AddFood/AddFoodScreen.swift`

## Data Model

Add persisted SwiftData models:

- `Meal`
  - `id`, `name`, `searchableText`, `createdAt`, `updatedAt`
  - relationship to ordered `MealComponent` records
  - derived totals from linked component foods and stored component quantities
  - no persisted nutrition total cache in the first version
- `MealComponent`
  - stable `id`
  - link to `FoodItem`
  - quantity mode and quantity amount for that component

Extend logged data so a logged meal can remain one Dashboard/History row:

- Add optional meal identity fields to `LogEntry`, such as `mealID`, `mealName`, and a source value or boolean identifying a meal log.
- Reuse existing `LogEntry` quantity fields for meal servings instead of adding a meal-specific quantity mode.
- Store consumed totals on `LogEntry` at log time, as today, so historical logged totals do not change if component foods are edited later.
- Add a persisted component snapshot for logged meals so read-only historical details show exactly what was logged.
- Snapshot rows should be persisted with the logged aggregate row, not generated lazily later.

## Nutrition Rules

- Component totals are computed by applying each component's quantity through `NutritionMath`.
- Component quantity scaling should reuse the same `QuantityMode` and `NutritionMath.quantityMultiplier` behavior as `LogFoodScreen`.
- The meal's base totals represent one saved meal serving.
- Logging a meal applies the user-selected meal multiplier to the aggregate base totals.
- Whole-meal gram logging is out of scope for the first version.
- Optional secondary nutrients should sum only known component values; if no component has a value for a secondary nutrient, the meal total remains `nil`.
- Calories and primary macros are required for every meal component; secondary nutrients are optional.
- Secondary nutrients should be summed and stored when available, but secondary nutrient display is deferred.
- Empty meals are invalid and should not be saved or logged.
- Meal drafts with unresolved online components are invalid and cannot be saved.
- Duplicate component rows for the same `FoodItem` are invalid; quantities should be represented by one component row per food.
- Common seed foods can be used directly as linked components when they exist as persisted `FoodItem` records.
- Unlinked ad-hoc ingredients are invalid as meal components.
- Meals are invalid as meal components in the first version.
- Linked saved-food edits update saved meal search/detail totals going forward, but already logged meal rows keep their logged snapshot totals.
- A future enhancement can offer a user choice when editing a saved meal: update future logs only, or intentionally recalculate existing logged entries that used the meal.
- Saved meal search rows should derive aggregate calories and macros from linked components at display time. The first version should cache only `searchableText`, not nutrition totals.

## Search and UI Plan

1. Add a Manual option for creating a meal from saved/on-device foods and online packaged-food results.
2. Build `MealEditorScreen` for naming the meal and adding/removing components, with component quantity editing in a reusable dedicated sheet/screen.
3. Add a component-picking mode to the existing Add Food search flow so selected saved foods can be multi-selected and returned to the meal editor, while selected online results run review/resolve, save as `FoodItem`, collect quantity, then return as components.
4. Add a local meal repository/search path parallel to `FoodItemLocalSearch`.
5. Widen Add Food local results from `LocalFoodSearchResult` to an enum that can render either a food row or meal row, with shared rank/name sorting.
6. Show meals in the existing On Device section using the same calories/protein/carbs/fat row presentation as foods.
7. Route meal selection to `LogMealScreen`, not `LogFoodScreen`.
8. In `LogMealScreen`, show meal name, meal serving multiplier, aggregate nutrition, and component rows with each component's nutrition contribution.
9. Include an `Edit Meal` action from the saved meal review/log screen that opens `MealEditorScreen`.
10. Log the meal as one `LogEntry` row with aggregate consumed totals and meal identity metadata.
11. Render logged meals through the same Dashboard/History row structure as foods, using a meal-serving subtitle such as `1 meal` or `0.5 meal`.
12. Keep component snapshots as detail-only metadata; existing daily total, widget, and sharing aggregation should continue reading `LogEntry` consumed totals.

## Milestones and Tasks

### Milestone 1 — Model and Math

- [x] Add `Meal` and `MealComponent` SwiftData models.
- [x] Register meal models in the shared and preview model containers.
- [x] Add meal aggregate helpers that reuse existing quantity math.
- [x] Add local meal search/ranking using normalized searchable text.
- [x] Rank exact/prefix meal-name matches above component-name-only matches.
- [x] Add a meal searchable-text repair/update path for referenced food renames.
- [x] Validate the iOS simulator build opens the registered schema after adding meal models.

### Milestone 2 — Meal Creation

- [x] Add a Manual entry point for creating a meal.
- [x] Preserve the current manual custom-food creation path.
- [x] Implement a meal editor that lets users pick existing saved foods and set each component quantity.
- [x] Show live aggregate calories/macros in the meal editor before saving.
- [x] Save linked components and update meal searchable text.
- [x] After saving a new meal, route directly to meal review/log.
- [x] Reuse Add Food search row/review patterns in component-picking mode.
- [x] Local component selection supports selecting multiple saved foods before returning to the editor.
- [x] Online component selection collects quantity after review/resolve saves the selected result as a reusable food.
- [x] Keep meal creation in the existing Add Food navigation stack.

### Milestone 3 — Search and Log

- [x] Merge foods and meals into Add Food's On Device local result list.
- [x] Include recent meals in the empty-query On Device list so saved meals remain discoverable without typing.
- [x] Render meal search rows with aggregate calories and macros.
- [x] Add a meal-only component preview subtitle in search rows to distinguish meals and duplicate names without changing the overall row design.
- [x] Add basic meal-specific accessibility labels for search rows.
- [x] Add basic meal-specific accessibility labels for logged rows.
- [x] Implement meal review/log screen with a meal multiplier and component breakdown.
- [x] Persist logged meals as one `LogEntry` with aggregate snapshot totals.

### Milestone 4 — Edit and Management

- [x] Keep logged meal editing deferred; first-version logged meal rows open read-only detail.
- [x] Allow saved meal editing from the meal review/log screen.
- [x] Saving existing meal edits refreshes the originating meal review/log screen.
- [ ] Add saved-meal management in Settings if the first Add Food creation path is not enough.
- [x] Add saved meal deletion in `MealEditorScreen` without deleting historical logs.
- [x] After deleting the saved meal being reviewed, dismiss the stale review/log route.
- [x] Add logged meal detail/snapshot display.
- [x] Add saved food deletion blocking and saved food edit warnings for meal references.

Each milestone should be reviewable independently and should pass validators before moving to the next milestone.

## Explicitly Deferred From First Version

- Backend, Worker, Convex, account, or remote sync changes.
- Settings-based meal management.
- Meal suggestion pills.
- Creating meals from logged entries.
- Nested meals.
- Secondary nutrient meal UI.
- Whole-meal gram logging.
- Editing logged meal snapshots.
- Advanced meal deletion/history behavior beyond preserving already logged rows.
- Bulk updating/recalculating historical meal logs after a saved meal or linked food edit.

## Validation Plan

- Run `make quality-format-check`.
- Run `git diff --check`.
- Build the iOS simulator target.
- Validate that existing local SwiftData stores open after registering the new meal models.
- Manually validate creating a meal, finding it in search, opening the meal review UI, logging 0.5x/1x/2x, and confirming Dashboard/History totals.
- Do not add a new test target as part of this feature; keep pure logic testable for future test infrastructure.

## Progress Log

- Phase 1 model/math foundation is implemented and validated: meal models, repository scaffolding, aggregate nutrition helpers, local meal search ranking, and model-container registration.
- Phase 2 meal creation is implemented for saved/on-device foods and validated: Manual now exposes `Create Meal`, `MealEditorScreen` supports naming, generated-name suggestion, live aggregate calories/macros, component deletion, save/delete repository calls, `MealComponentFoodPickerScreen` supports multi-select saved-food picking while excluding duplicates, and `MealComponentQuantityScreen` reuses `FoodQuantitySection` for serving/gram quantities.
- Phase 3 meal logging foundation is implemented and validated: saved new meals route to `LogMealScreen`, meal logging writes one aggregate `LogEntry` with `mealID`, uses servings-only `1 meal` semantics, records component snapshots at log time in `LoggedMealComponentSnapshot`, reloads widgets, and cleans up snapshots when log entries are deleted.
- Phase 4 Add Food search integration is implemented and validated: On Device results now include both foods and meals, empty search shows recent meals alongside recent foods, meal rows use the existing nutrition row with `Meal • components` subtitles and accessibility labels, and tapping a meal opens `LogMealScreen`.
- Phase 5 referenced-food safety is implemented and validated: reusable food deletion is blocked when a food is used by saved meals, the food editor warns that edits affect future meal totals but not past logged meals, and saving referenced foods refreshes searchable text for meals that include them.
- Phase 6 logged meal review is implemented and validated: logged meal rows now identify meals in subtitles/accessibility, Dashboard/History meal taps open read-only snapshot detail, saved meals can be edited from meal review/log screens with refreshed totals after save, and deleting the reviewed meal dismisses the stale review route.
- Phase 7 online component selection is implemented and validated: the meal component picker can search online packaged foods, review/resolve nutrition into a reusable `FoodItem`, collect component quantity, and attach the saved food as a meal component.
- Defensive-code review pass completed after validators; removed redundant fallback/guard code in the meal editor and remote component selection screen.
- Meal save routing fix is implemented and validated: saving a new meal now routes to the log screen by saved meal ID instead of holding a persisted model instance in navigation state, preserving success haptic feedback before navigation.
- Meal save validation uses native disabled behavior: Save Meal stays disabled until both a meal name and at least one food are present.
- Meal component multi-select confirm button is implemented and validated: the toolbar confirm action is a native circular `.borderedProminent` checkmark button tinted with the app accent color, avoiding custom nested circles or label backgrounds.
- Post-implementation simplify pass completed and validated: `MealRepository.foodsByID` now batches component food fetches, Add Food mixed local search sorts foods and meals together by shared rank/name or recent `updatedAt`, and component quantity editing reuses `FoodQuantityState.syncInactiveAmount` instead of duplicating conversion helpers.
- Post-implementation defensive-code review completed and validated: removed the redundant disabled check from filtered meal component picker rows; kept persistence, remote payload, snapshot, and missing-data guards intact.
- Second post-implementation review pass completed and validated: meal search now batches nutrition summaries for local search rows, referenced-food searchable-text refresh batches affected meals/components/foods, remote search cached-food lookup is shared, meal search normalization uses `TextNormalization`, repeated quantity summary formatting uses `QuantityMode.formattedSummary`, and unused meal model helpers were removed.
- Second defensive-code review completed and validated: simplified single-meal summary lookup, made new/existing meal save branching explicit, removed an unreachable local meal search optional fallback, and kept log serving validation at the repository boundary while UI gating depends only on loaded summary state.
- Final repeated simplify and defensive-code review passes returned LGTM after cleanup: `NutritionMath.summedNutrients` now uses a single-pass accumulator, meal rows hide `Log Again` until meal re-logging can preserve meal metadata/snapshots, validated component-name mapping no longer silently drops missing foods, and `LogEntry.quantitySummary` reuses shared quantity formatting for non-meal rows.

## Open Risks

- SwiftData schema changes need careful validation against existing stores.
- The current `FoodDraft` flow is intentionally single-food; forcing meals through it would blur responsibilities, so meals should get a dedicated screen and repository path.
- Linked component updates are useful for saved meal totals, but logged meal history must remain snapshot-based to avoid retroactive nutrition changes.
- Food deletion must check meal component references so linked saved meals cannot end up with broken components.
- Saved food editing should surface meal-reference impact when nutrition changes can affect future saved meal totals.
- Broader reuse follow-ups remain optional: local food candidate search and remote search session handling are still duplicated between normal Add Food and meal component picking, but were left unchanged to avoid widening this first-version cleanup.
