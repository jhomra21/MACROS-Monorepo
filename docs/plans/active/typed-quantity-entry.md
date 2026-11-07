# Typed quantity entry

Status: proposed, 2026-11-07. Not started.

## Problem

Users can't type an exact amount. `cal-macro-tracker/App/FoodQuantitySection.swift` shows the Servings and Grams values as plain text beside a `Stepper`:

- Servings step by 0.25, with a 0.25 minimum (lines 132–142).
- Grams step by 5 g, with a 1 g minimum (lines 144–154).

Someone who weighed 137 g can't log 137 g; the nearest stepper values are 136 g and 141 g. The camera scan card's Servings stepper (`Features/Scan/Camera/FoodCameraResultPanel.swift`) has the same limit. People work around it by changing grams per serving, which corrupts the saved food.

## Goal

Let users tap the Servings or Grams value and type the exact amount, while keeping the steppers for quick changes. This applies everywhere `FoodQuantitySection` is used (log editor, camera Edit details, meal component quantity) and on the camera card's Servings value.

## Requirements to settle before building

- Validation: positive, finite values only; decide the upper bounds; servings allow decimals; grams allow decimals or whole numbers only.
- Locale decimal separators and the number pad's missing minus key.
- What a stepper tap does after a typed value: step from the typed value.
- Keep the deterministic math: servings × per-serving values, or grams ÷ grams per serving. Never infer grams for volume-only servings.
- VoiceOver and Dynamic Type for the editable value.

## Validation

Write the failure modes first, then the code. Run E2E on the media or disposable simulator, covering typed servings, typed grams, invalid input, switching modes after typing, and the camera card.

## Website follow-up

The blog draft "Serving size vs. the whole package" (branch `web/blog-drafts`) tells readers that the steppers may not land on their weighed amount. Update that line when this ships.
