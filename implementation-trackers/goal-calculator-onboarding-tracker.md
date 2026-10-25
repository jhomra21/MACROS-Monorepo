# Goal Calculator and Onboarding Implementation Tracker (WS3)

Branch `launch/ws3-goal-calculator`. Mac only. Read `AGENTS.md`, `swift-dev.mdc`, `changes-log.md` section "First-Run Goal Setup Onboarding", `Features/Onboarding/GoalSetupScreen.swift`, `Features/Settings/DailyGoalsSection.swift`, `Data/Models/DailyGoals.swift`, `Data/Services/DailyGoalsRepository.swift`, `Shared/SharedModelContainerFactory.swift`, `Data/Services/AppModelContainerFactory.swift`, and `implementation-trackers/launch-program-tracker.md`. Activate `swiftui-liquid-glass`, `apple-design`, and `write-swift` skills if available.

## Shared Understanding

- First run currently shows `GoalSetupScreen` (four numeric fields, Continue) gated by `@AppStorage("hasCompletedGoalSetup")` in `cal_macro_trackerApp.swift`. Goals persist through `DailyGoalsRepository.saveGoals(from:to:operation:)` using `DailyGoalsNumericText` / `DailyGoalsDraft`.
- There is no body profile, no calculator, no explanation of what the numbers mean, and no way to skip. Most new users do not know their targets; this is the largest drop-off risk at launch.
- WS5 (weight log, Apple Health) will reuse the body profile created here. Keep the model general.

## Core Decisions

### Data

- New `@Model final class BodyProfile` in `Data/Models/BodyProfile.swift`: `id: UUID`, `sexRaw: String` (`female`, `male`, `unspecified`), `birthYear: Int?`, `heightCm: Double?`, `weightKg: Double?`, `activityLevelRaw: String` (`sedentary`, `light`, `moderate`, `active`, `veryActive`), `goalCalorieOffset: Double` (kcal/day; -750, -500, -250, 0, 250, 500), `macroPresetRaw: String` (`balanced`, `highProtein`, `lowCarb`, `custom`), `unitSystemRaw: String` (`metric`, `imperial`), `createdAt`, `updatedAt`. Typed accessors via enums, same pattern as `FoodItem.sourceKind`.
- Register `BodyProfile.self` in both `SharedModelContainerFactory` configurations and `AppModelContainerFactory.makePreviewContainer`. Adding a model is an additive schema change; verify an existing store opens (reuse the fixture approach in `MealSchemaMigrationTests`).
- `BodyProfileRepository` with `activeProfile(modelContext:)` and `save(_:operation:)` through `PersistenceReporter.persist`.

### Calculator (pure, deterministic)

- `Features/Onboarding/GoalCalculator.swift`, enum with static functions, no SwiftUI or SwiftData imports:
  - `bmr(sex:ageYears:heightCm:weightKg:)` Mifflin-St Jeor; `unspecified` averages the male and female constants.
  - `tdee(bmr:activity:)` multipliers 1.2, 1.375, 1.55, 1.725, 1.9.
  - `targetCalories(tdee:offset:sex:)` returns the value and `isBelowSafeMinimum` when under 1,200 (female/unspecified) or 1,500 (male); clamp to the minimum.
  - `macroGrams(calories:preset:)` using 4/4/9 kcal per gram; presets as protein/carb/fat percentages: balanced 30/40/30, highProtein 40/30/30, lowCarb 35/20/45. Round grams to the nearest 5; recompute calories from the rounded grams so the displayed numbers add up; return `DailyGoalsDraft`.
  - Unit helpers: `kg(fromPounds:)`, `cm(fromFeet:inches:)` and inverses use exact constants with no rounding; `BodyProfileDraft` rounds only when it builds display text.
- Failure modes to list and test first (in `cal-macro-trackerTests/GoalCalculatorTests.swift`): zero or negative height/weight/age; age over 120; NaN/infinite input; below-minimum clamp for each sex; preset percentages sum to 100; grams rounding keeps calories within 2% of target; imperial round-trip stability; `unspecified` sex midpoint.

### Onboarding flow

- Replace the single `GoalSetupScreen` entry with `OnboardingFlow` (a `NavigationStack` kept inside the same root slot so the existing handoff transition in `cal_macro_trackerApp.swift` still applies):
  1. Welcome: brand name from the existing display strings (do not hardcode new "MACROS" literals; WS7 centralizes the brand constant, use `Bundle.main` display name for now), three short lines (no account, scan anything, data stays on your phone), primary "Get started".
  2. Choice: two glass rows: "Calculate my targets" and "I already know my numbers" (the second pushes the existing `GoalSetupScreen` editor, unchanged except for navigation).
  3. About you: sex (segmented), age, height, weight with a metric/imperial toggle that converts in place, activity level (menu `Picker` with one-line descriptions), goal (segmented Lose / Maintain / Gain, and a rate picker shown for Lose/Gain: 0.25, 0.5, 0.75 kg/week mapped to the offsets above, imperial labels in lb/week).
  4. Targets: computed calories as the headline, a static `MacroRingSetView` preview with the proposed grams, preset picker (Balanced, High protein, Low carb), the safe-minimum notice when clamped, "Adjust manually" (pushes the editor prefilled), and "Continue" which saves `BodyProfile` and `DailyGoals` then calls the existing completion closure.
- Use `appGlassRoundedRect` rows inside `GlassEffectContainer` for the inputs, `BottomPinnedActionBar` for the primary action, `keyboardNavigationToolbar` for numeric fields, `AppNumericTextField` for numbers, `.sensoryFeedback(.success)` on completion. Reduce Motion safe.
- Settings: in `DailyGoalsSection.swift` add a "Recalculate targets" row that presents steps 3 and 4 in a sheet prefilled from the active `BodyProfile`; saving updates both records. Do not restructure `SettingsScreen.swift`.

## Proposed File Shape

- `Data/Models/BodyProfile.swift`, `Data/Services/BodyProfileRepository.swift`.
- `Features/Onboarding/GoalCalculator.swift`, `OnboardingFlow.swift`, `OnboardingWelcomeScreen.swift`, `OnboardingChoiceScreen.swift`, `BodyProfileFormScreen.swift`, `TargetReviewScreen.swift`, `GoalSetupScreen.swift` (kept as the manual editor).
- `Features/Settings/DailyGoalsSection.swift` (one new row), `cal_macro_trackerApp.swift` (swap the root view type only).
- `cal-macro-trackerTests/GoalCalculatorTests.swift`.

## Milestones and Tasks

1. Failure list, then `GoalCalculatorTests`, then `GoalCalculator`.
2. `BodyProfile` model, repository, container registration, store-open check.
3. Onboarding screens and navigation; keep `hasCompletedGoalSetup` semantics.
4. Settings recalculate sheet.
5. Validation: `make quality-format-check`, `make quality-build`, targeted tests (`GoalCalculatorTests`, `MealSchemaMigrationTests`), `git diff --check`; E2E on a fresh simulator install: both onboarding paths, imperial and metric, below-minimum case, recalculate from Settings; dashboard rings reflect the new goals; screenshots in `build/ws3-qa-<date>/QA.md`. Changes-log entry.

## Edge Cases

- Existing users (goal setup already completed) never see the new onboarding; the Settings entry is their path.
- Age unknown: allow blank age with a default of 30 and a note; do not block.
- Keyboard covering the pinned action bar: reuse the fix already in `BottomPinnedActionBar`.

## Status

- WS3 review fixes: seven scoped commits on `launch/ws3-goal-calculator` (macro calorie floor, localized body profile parsing, full-precision unit toggles, recalculation target push, visible proposed macro values, imperial height focus fields, independent BMR references). Validation complete: `make quality-format-check`, `make quality-build`, `git diff --check`, 10 `GoalCalculatorTests`, 8 `BodyProfileDraftTests`, and decimal-comma, macro-review, safe-floor, settings-back, and relaunch E2E checks passed. Screenshots are in `build/ws3-qa-2026-10-25/`.
