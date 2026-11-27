# Meal photo live check (2026-11-27)

Checked with the iPhone 17e simulator against the production meal-photo estimate Worker. The temporary UI test used the `UITestFixture` camera image path and the DEBUG-only `PACKAGED_FOOD_SEARCH_BASE_URL_OVERRIDE`; no mock response was enabled. Images were resized to 900 px wide.

## Grilled salmon photo

- Grilled salmon steak → Fish, salmon, grilled: 570 kcal
- Avocado slices → Avocado, raw: 96 kcal
- Cherry tomatoes → Tomatoes, raw: 10 kcal
- Lemon wedge → Lemon, raw: 9 kcal
- Review total shown: 724 kcal

## Bacon cheeseburger photo

- Cheeseburger with bacon → Cheeseburger, on white bun, 1 small patty: 954 kcal
- French fries → Potato, french fries, restaurant: 347 kcal
- Ketchup → Ketchup: 33 kcal
- Review total shown: 1,333 kcal

The worker returned the USDA generic matches for tomatoes, lemon, and the cheeseburger. Other reviewed foods used the on-device catalog where it had an applicable result. The cheeseburger meal was logged and is shown in `screenshots/today.png`.

## Screenshots

- `screenshots/salmon-review-top.png`
- `screenshots/salmon-review-bottom.png` (scrolled to include the review total)
- `screenshots/burger-review-top.png`
- `screenshots/burger-review-bottom.png` (scrolled to include the review total)
- `screenshots/today.png`

The production endpoint was read-only for estimation; no service configuration or deployment was changed.
