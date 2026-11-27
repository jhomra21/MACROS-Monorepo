# Meal photo live Worker scan, iPhone 17e, 2026-11-27

Branch under test: `feature/meal-photo-app` at `8d7b9fec59f87c264f576538ba7e35d546ee6946`.
Device: iPhone 17e (`F976E800-DA1F-4F20-B755-DFD964E33975`), iOS 27.0 simulator, Debug build with Pro fixture.
Scans hit the production Worker `https://cal-macro-tracker-usda-proxy.jhonra121.workers.dev`, `POST /v1/meal-photo/estimate`. The `-MealPhotoMockResponse` argument was not passed.

## Test photos (Wikimedia Commons)

1. Grilled plated salmon fillet: https://upload.wikimedia.org/wikipedia/commons/f/f1/Grilled_plated_salmon_fillet.jpg (page: https://commons.wikimedia.org/wiki/File:Grilled_plated_salmon_fillet.jpg)
2. Bacon cheeseburger with French fries on plate: https://upload.wikimedia.org/wikipedia/commons/6/62/Bacon_Cheeseburger_with_French_Fries_on_plate.JPG (page: https://commons.wikimedia.org/wiki/File:Bacon_Cheeseburger_with_French_Fries_on_plate.JPG)
3. Spaghetti Bolognese with vegetables: https://upload.wikimedia.org/wikipedia/commons/3/3a/Liat_Portal_for_Foodie_Disorder_-_Spaghetti_Bolognese_with_vegetables.jpg (page: https://commons.wikimedia.org/wiki/File:Liat_Portal_for_Foodie_Disorder_-_Spaghetti_Bolognese_with_vegetables.jpg)

## Results

| # | Photo | Oil prompt | Items (grams, matched food, kcal) | Total | Scan tap to review | Review to Log enabled | Logged |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | Salmon | Yes (adds Olive Oil 14 g, 126 kcal) | Grilled salmon 200 g, Fish, Salmon, Grilled, 518 kcal; Avocado 60 g, Avocado, 96 kcal; Cherry tomatoes 50 g, Cherry Tomatoes, 173.2 kcal (see flags); Mixed greens salad 40 g, Mixed greens salad, 41.3 kcal; Lemon wedge 25 g, "Crisp, zesty lemon wedge cookies dusted with powdered sugar", 116.7 kcal (see flags); Balsamic glaze 10 g, Balsamic glaze, 20 kcal | 965.2 kcal before oil; 1091.2 kcal with oil (computed, not seen on screen) | 4.64 s | 1.10 s | Yes, Today count went to 11 items |
| 2 | Cheeseburger | No | Cheeseburger with bacon 320 g, matched to a garden-salad item, 339.2 kcal (see flags); French fries 150 g, Potato, French Fries, 468 kcal; Ketchup 30 g (my entry, see notes), 32.7 kcal | 839.9 kcal | 2.74 s | 1.11 s | Yes (Ketchup found on Today; other names not matched) |
| 3 | Spaghetti | Skip | "Spaghetti with meat and vegetable sauce": no catalog match. Picked "Spaghetti with meat sauce and mixed vegetables" 350 g (picker took the first search result). | Macros on Today P 7.2, C 30.0, F 12.4 for 350 g, which gives about 260 kcal (derived, not displayed) | 2.69 s | 1.06 s | Yes |

Timings come from XCUITest wall clock on the test runner, so they include UI automation overhead. Earlier a curl probe with a 1024 px JPEG got HTTP 200 from the Worker in 2.4 s.

## Errors and odd matches

- Scan failures before the fix: the Debug simulator build defaults `PACKAGED_FOOD_SEARCH_BASE_URL` to `http://127.0.0.1:8787` (`project.pbxproj` line 587). Nothing listens there, so the app showed "Scan didn't work. Couldn't scan this photo." The test was then pointed at production with the DEBUG-only `PACKAGED_FOOD_SEARCH_BASE_URL_OVERRIDE`. This is a QA setup issue, not an app bug. The app's error screen does show correctly.
- Production route: the deployed Worker answers the estimate route, but this branch's `worker/` source does not contain it, and `changes-log.md` says the Worker is "not deployed yet". Source and deployed code are out of sync. A probe with an all-zero install ID returned `400 missing_install_id`. A probe with a valid UUID and a real 1024 px JPEG returned HTTP 200 with foods.
- Wrong or odd matches:
  - Salmon: Lemon wedge matched to powdered-sugar cookies (116.7 kcal). Cherry tomatoes matched to a 173.2 kcal item with 41 g carbs for 50 g, which is implausible for tomatoes. I read this from the accessibility tree, not a screenshot.
  - Cheeseburger: run 1 matched "Bacon cheeseburger" (989.9 kcal, 320 g). Run 2 matched a garden-salad item (339.2 kcal, 320 g). The Worker's suggested name changed between runs, so the matcher result is not stable.
- Missing items: pasta had no catalog match, so the user must pick a food. The app blocks Log until they do, which is correct.
- Volume-only ketchup ("About 30 ml") needed grams. I entered 30 g as the test input. This is not a value from the app.
- Oil prompt: Yes added Olive Oil 14 g (126 kcal). No and Skip both logged without it.
- Offline error path: skipped. The 127.0.0.1:8787 failure above was the only error state seen, and it was not a planned test.

## Limits

- Today-name checks are weak. The XCUI check matched only Ketchup; the cheeseburger and fries names were not found, and the pasta Today row is cut off in the screenshot. I did not confirm those rows on screen.
- Burger and pasta amounts were filled by the test (30 g ketchup, picker first result, 350 g pasta default).
- Screenshots were resized to max 900 px for the 2 MiB limit.

## Files

- `screenshots/01-salmon-review-total.png`: review before oil, total 965.2 kcal
- `screenshots/02-salmon-oil-added.png`: Olive Oil row after Yes
- `screenshots/03-salmon-today.png`: Today after logging salmon
- `screenshots/04-burger-review-total.png`: burger review after ketchup, total 839.9 kcal
- `screenshots/05-burger-today.png`: Today after logging burger (top of list only)
- `screenshots/06-pasta-review.png`: pasta review with "has no match" before the pick
- `screenshots/07-pasta-today.png`: Today after logging pasta (row cut off)
- `runs/*.txt`: per-run timings and grams fields from the test
