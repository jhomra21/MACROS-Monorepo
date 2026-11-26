# Nutrition5k bake-off: Apple on-device and Private Cloud Compute (2026-11-26)

Research only. No app code changed. First real run of the meal-photo harness in `tools/food-photo-eval`, on public weighed ground truth because the owner has not yet weighed home meals.

## Summary

- **Apple on-device (`SystemLanguageModel`) is not accurate enough to auto-fill portions or calories.** Dish-level calorie MAPE is 75.2% (median 60.7%), and only 9 of 60 dishes (15.0%) land within ±20% kcal. For reference, always guessing the sample's median dish (221 kcal) gives 101.5% MAPE and 11 of 60 within ±20%, and always guessing the median mass (202 g) gives 37.5% mass MAPE against the model's 50.0%.
- **Recognition is the first problem, portion size the second.** The model finds 48.1% of true ingredient mass and 22.0% of ingredients by count, with 63.8% count precision. When told the true ingredient list, recognition errors disappear but calorie MAPE only falls to 58.4% (25.0% within ±20%), so grams are also poor (median error 55.7% on items of 10 g or more).
- **Private Cloud Compute produced no results.** `PrivateCloudComputeLanguageModel().availability` reports `.available` on this Mac (macOS 27.2), but all 120 requests (60 photos, free and known-identity) fail with `ModelManagerServices.ModelManagerError` code 1046. A text-only request in a separate probe fails the same way, so it is not image-specific. The cause is not determined (quota, entitlement for a command-line tool and account state are all untested). Nothing was substituted.
- **Cloud arms were not run.** No keys are present. The dry run skipped all four arms.

## Setup

| Item | Value |
|---|---|
| Dataset | Google Nutrition5k, overhead `rgb.png` (640×480), 60 dishes. License: Creative Commons 4.0 (CC BY 4.0), as stated in the [repo README](https://github.com/google-research-datasets/Nutrition5k#license--contact). GitHub's license API reports none, so the README is the only source; cite Thames et al., CVPR 2021. |
| Sampling | Seed 5002026 (mulberry32). 20 dishes each from 1–2, 3–5 and 6+ ingredients. Eligible: 2,315 dishes with overhead RGB, 100–800 g, all ingredient grams > 0, ingredient grams within 2% of total mass, and ingredient grams × kcal/g within 2% of the published dish calories. The calorie check removes Cafe 2 rows whose calories are 0. List: [`dataset/nutrition5k.selection.json`](../dataset/nutrition5k.selection.json). Rebuild: `bun run dataset/nutrition5k.ts`. |
| Truth | Per-ingredient grams from Nutrition5k. Truth kcal = grams × the dataset's per-ingredient kcal/g (USDA-derived). It reproduces the published dish calories to 1e-7. |
| Model calories | Never requested. Predicted kcal = predicted grams × kcal/g of the matched truth ingredient, or, for an unmatched food, of the best-matching entry in the 554-row Nutrition5k ingredient table. Predicted foods with no table match are left out of kcal and reported as unpriced mass (6.3% of predicted mass on-device, 0% known-identity). |
| Prompt, schema | Repo `prompt.md` and `schema.json` unchanged. Known-identity arms append one sentence: the meal contains exactly these foods (true ingredient names), use these names, estimate grams of each. |
| Runner | `apple/` Swift package, release build, Xcode 26.4.1 toolchain with the macOS 27 SDK, macOS 27.2. One run per photo, fresh session each, no repeats, default sampling. Added flags: `--known-identity`, `--arms`. |
| Matching | Greedy one-to-one over (truth, prediction) pairs ranked by method: exact normalized name, then alias group (hand-written table in `nutrition5k-score.ts`, written before scoring and not tuned afterwards), then token containment ("cheese" in "cheddar cheese"), then edit-distance similarity ≥ 0.8. Normalization lowercases, singularizes, and drops preparation words such as cooked or sliced. Model `foodKey` values are ignored (the model invents strings such as `MACROS CommonFoods/sausage`). Method counts are in the tables. |

## Results

Metrics are computed on dishes where the model returned a usable answer. For on-device, that is all 60. "Within ±20% (all dishes)" counts failures as misses.


#### Calories and mass (answered dishes)

| Arm | Dishes | Answered | Failed | Refused/empty | kcal MAPE | kcal median APE | kcal bias | Within ±20% | Within ±20% (all dishes) | Mass MAPE | Mass bias |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| apple-on-device | 60 | 60 | 0 | 0 | 75.2% | 60.7% | 7.6% | 15.0% | 15.0% | 50.0% | -3.0% |
| apple-on-device-known | 60 | 60 | 0 | 0 | 58.4% | 51.5% | 12.0% | 25.0% | 25.0% | 54.5% | 9.5% |
| apple-private-cloud | 60 | 0 | 60 | 0 | n/a | n/a | n/a | n/a | 0.0% | n/a | n/a |
| apple-private-cloud-known | 60 | 0 | 60 | 0 | n/a | n/a | n/a | n/a | 0.0% | n/a | n/a |

#### Recognition and portions (answered dishes)

| Arm | Count recall | Count precision | Mass recall | Mass precision | Matched-item gram median APE | …for items ≥ 10 g | Unpriced predicted mass | p50 / p95 ms |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| apple-on-device | 22.0% | 63.8% | 48.1% | 66.6% | 60.0% | 57.9% | 6.3% | 2925 / 6419 |
| apple-on-device-known | 98.6% | 99.5% | 100.0% | 99.9% | 89.4% | 55.7% | 0.0% | 4651 / 21088 |
| apple-private-cloud | n/a | n/a | n/a | n/a | n/a | n/a | n/a | n/a / n/a |
| apple-private-cloud-known | n/a | n/a | n/a | n/a | n/a | n/a | n/a | n/a / n/a |

#### kcal MAPE by ingredient count (n answered)

| Arm | 1-2 | 3-5 | 6+ |
|---|---:|---:|---:|
| apple-on-device | 69.3% (20) | 74.5% (20) | 81.8% (20) |
| apple-on-device-known | 43.1% (20) | 60.8% (20) | 71.2% (20) |
| apple-private-cloud | n/a (0) | n/a (0) | n/a (0) |
| apple-private-cloud-known | n/a (0) | n/a (0) | n/a (0) |

#### Name-match methods (matched pairs)

| Arm | exact | alias | contains | fuzzy |
|---|---:|---:|---:|---:|
| apple-on-device | 52 | 15 | 14 | 0 |
| apple-on-device-known | 363 | 1 | 0 | 0 |
| apple-private-cloud | 0 | 0 | 0 | 0 |
| apple-private-cloud-known | 0 | 0 | 0 | 0 |

#### Failure analysis


#### apple-on-device

- Most missed truth ingredients: olive oil ×21 (83 g), salt ×18 (9 g), garlic ×13 (20 g), onions ×10 (123 g), pepper ×9 (16 g), vinegar ×9 (15 g), broccoli ×7 (171 g), parsley ×7 (5 g), wheat berry ×6 (266 g), lemon juice ×6 (4 g)
- Most frequent unmatched predictions: meat ×4, cherry tomato ×3, roasted vegetable ×3, crouton ×3, cheese ×3, cucumber ×2, lettuce ×2, apple ×2, vegetable ×2, blueberry ×2

#### apple-on-device-known

- Most missed truth ingredients: salt ×2 (0 g), olive oil ×1 (4 g), vinaigrette ×1 (3 g), pepper ×1 (0 g)
- Most frequent unmatched predictions: chicken ×1, apple ×1

#### apple-private-cloud

- Most missed truth ingredients: none
- Most frequent unmatched predictions: none
- Failure messages: `Error Domain=FoundationModels.LanguageModelError Code=-1 "The operation couldn’t be completed. (FoundationModels.LanguageModelError error -1.)" UserInfo={NSMult`; `Error Domain=FoundationModels.LanguageModelError Code=-1 "The operation couldn’t be completed. (FoundationModels.LanguageModelError error -1.)" UserInfo={NSLoca`

#### apple-private-cloud-known

- Most missed truth ingredients: none
- Most frequent unmatched predictions: none
- Failure messages: `Error Domain=FoundationModels.LanguageModelError Code=-1 "The operation couldn’t be completed. (FoundationModels.LanguageModelError error -1.)" UserInfo={NSLoca`; `Error Domain=FoundationModels.LanguageModelError Code=-1 "The operation couldn’t be completed. (FoundationModels.LanguageModelError error -1.)" UserInfo={NSMult`


### Reference baselines (same 60 dishes, computed from truth only)

| Predictor | Result |
|---|---|
| Always the median dish, 221 kcal | kcal MAPE 101.5%, 11/60 within ±20% |
| Always the median mass, 202 g | mass MAPE 37.5% |
| True mass × median density (0.94 kcal/g) | kcal MAPE 61.7%, 13/60 within ±20% |

These show how little the on-device calorie numbers beat naive guesses. The last row is an oracle that knows the exact mass but not the food.

## Example dishes

Truth versus on-device prediction, free and known-identity. Source images are not committed; fetch them with the converter.

**dish_1567801520 (6+ ingredients, mixed plate)**
Truth, 919 kcal, 600 g: pork 270 g, caesar salad 196 g, white rice 39 g, bok choy 39 g, sugar 29 g, soy sauce 15 g, garlic 10 g, salt 2 g, pepper 1 g.
Free: 495 kcal, "chicken 300 g" and nothing else. One wrong protein, one item.
Known: 715 kcal, 550 g. Names are right; pork 120 g (truth 270 g) and rice 200 g (truth 39 g) are the big misses.

**dish_1566415520 (1–2 ingredients, hidden oil)**
Truth, 75 kcal, 143 g: green beans 139 g, olive oil 4 g.
Free: 47 kcal, green beans 150 g. Right food and portion, oil missed (this is why kcal is -37%).
Known: 31 kcal, green beans 100 g. Told the truth list, the model returned a worse gram estimate and dropped the oil.

**dish_1562875870 (6+, small mixed salad bowl)**
Truth, 257 kcal, 233 g: couscous 90 g, fish 94 g, then corn, carrot, sour cream, arugula, jicama, nopales, lime, olive oil and seasonings (under 20 g each).
Free: 568 kcal, 190 g: croutons 20 g, 40 g and 50 g (three entries), salmon 60 g, tomato 15 g, garlic 5 g. Invented croutons and tomato, missed couscous, so kcal is +121%.
Known: 244 kcal, 246 g. Close in total, but through offsetting errors (fish 100 g is right, couscous 40 g is half).

**dish_1559845745 (1–2, a good case)**
Truth, 208 kcal, 322 g: pears 201 g, potatoes 121 g.
Free: 178 kcal. "Apple 120 g, potato 150 g". Wrong fruit, similar energy, within ±20% by luck of similar density.
Known: 223 kcal. Pears 120 g (truth 201 g), potatoes 200 g.

## Where on-device fails

- **Scale, not names, drives most error.** Free-run mass has a wide spread: signed error percentiles (min, p25, median, p75, max) are -89%, -50%, -12%, +33%, +169%. With names given, they are -89%, -39%, +1%, +42%, +407%. Averages hide this: mean mass bias is only -3.0% (free) and +9.5% (known).
- **Oils, dressings and sauces are essentially invisible.** 27 truth items were oils, dressings, sauces or butter, and 0 were matched by the free arm. The top missed ingredients by count are olive oil (21 dishes), salt (18), garlic (13), onions (10), pepper (9), vinegar (9). Most are small, so they cost recall by count more than kcal; olive oil is 83 g over 21 dishes and is calorie-dense (about 8.8 kcal/g).
- **Mixed and composite dishes collapse to one guess.** 8 of the 20 plates with 6+ true ingredients got a single food back (the median is 2 foods against 14 true ingredients), so the stratum gets worse as complexity rises (kcal MAPE 69.3% for 1–2, 74.5% for 3–5 and 81.8% for 6+).
- **Hallucinated additions.** Unmatched predictions include meat, cherry tomato, roasted vegetable, crouton and cheese. Count precision is 63.8%.
- **Latency.** On-device p50 2.9 s and p95 6.4 s. The known-identity arm is slower (p50 4.7 s, p95 21.1 s) because it writes longer lists.
- **Failure and refusal rate.** The on-device arm had 0 failures and 0 refusals. Output always parsed against the schema (guided generation), so a valid-looking answer says nothing about accuracy.

## Recommendation

**Not good enough on its own for a "suggest foods and grams, the user confirms" v1 if the suggested grams or calories are shown as defaults.** On this dataset the on-device grams are worse than a constant, and 85% of dishes miss by more than 20% kcal. Users would correct almost every number, and a wrong default is quicker to accept than to fix.

What on-device can plausibly support, pending a check on home meals:
- **Food-name suggestions as a search shortcut** on simple plates (1–2 items), with the user choosing the food and entering or confirming the quantity. Mass recall of 48% and count precision of 64% mean the list is a starting point only. Offer "add missing" as the main path.
- **Do not seed quantity from the model.** Use the food database's default serving until the user edits it.
- Keep "unclear" and "not food" paths. Nothing here tested negatives.

**What cloud has to beat.** These are my proposed bars, not owner-set; each needs at least a 60-dish rerun with confidence intervals (n = 60 gives roughly ±10 points on a proportion):
- Mass recall well above 48% and count precision above 64%, on the same truth with the same matcher.
- Mass MAPE below the constant-guess baseline of 37.5%. On-device is at 50.0%.
- Known-identity gram error below on-device's 55.7% median APE, which is the number that isolates portion estimation.
- Dish-level kcal MAPE below about 40% and over 40% of dishes within ±20%, versus 75.2% and 15.0% for on-device.
- Recognition of oils and dressings, or an explicit "likely added fat" flag that the app turns into a prompt for the user.
- Latency and cost that fit a scan flow. `pricing.json` has the price snapshot; no threshold has been set.

**Private Cloud Compute is unresolved.** Until a request succeeds, it cannot be compared. Next step is to test it from a signed app target (with whatever entitlement it needs), not the command-line runner, and to check the Apple Intelligence account and region state.

## Cloud arms (dry run only)

`bun run cloud/run.ts --dataset dataset/nutrition5k --dry-run` with no keys set printed "Skipped … required credential(s) missing" for `gemini-3.5-flash-lite`, `gemini-3.8-flash`, `openai-gpt-5.4-mini` and `cloudflare-clairic`. With keys, each would send all 60 photos (downscaled to 1024 px JPEG), 240 requests in total. Needed variables: `GEMINI_API_KEY`, `OPENAI_API_KEY`, and `CLOUDFLARE_ACCOUNT_ID` with `CLOUDFLARE_API_TOKEN`. The cloud runner has no known-identity mode yet, so cloud arms can only be compared on the free task until that is added. Nutrition5k is public CC BY data, so sending it to providers raises no privacy concern; home photos would.

## Caveats

- **Cafeteria food is not home food.** Plates come from a few Google cafeterias in California, with a cuisine bias the dataset authors acknowledge. Portions are cafeteria-served, not home-plated.
- **Overhead, low resolution, fixed rig.** 640×480 overhead RGB under rig lighting. A phone photo at 45° has more detail and more occlusion. Overhead views hide height, which hurts portion estimates.
- **Labels are not perfect.** Nutrition5k grams come from incremental weighing, and kcal/g comes from USDA values per ingredient, not from lab analysis. Some ingredient labels are generic ("fish") or unusual ("wheat berry", "nopales"), which depresses recall.
- **Truth includes items nobody would log.** Salt, pepper, parsley and similar seasonings count as ingredients. This lowers count recall (22.0%), so mass recall (48.1%) is the fairer figure.
- **Sample size.** 60 dishes, one run, default sampling, no repeats. Differences of a few points between arms are noise. Stratum cells hold 20 dishes each. Incremental scans of the same plate could in principle both be drawn, which would reduce independence; none was checked for.
- **Matcher is mine.** Alias and containment rules decide what counts as correct; "contains" treats "rice" as matching "fried rice". Method counts are reported so the effect is visible (on-device: 52 exact, 15 alias, 14 contains, 0 fuzzy).
- **Known-identity is a diagnostic.** It leaks the answer, so it bounds portion skill and says nothing about what a user would see.
- **Toolchain.** Xcode 26.4.1 reporting the macOS 27 SDK on macOS 27.2. Results may change with OS releases.

## Reproduce

```sh
cd tools/food-photo-eval
bun install
bun run dataset/nutrition5k.ts                 # downloads ~28 MB of images into dataset/nutrition5k (gitignored)
cd apple && swift build -c release
.build/release/FoodPhotoEval --dataset ../dataset/nutrition5k --results ../results/nutrition5k-apple
.build/release/FoodPhotoEval --dataset ../dataset/nutrition5k --results ../results/nutrition5k-apple --known-identity
cd .. && bun run score.ts --dataset dataset/nutrition5k --results results/nutrition5k-apple
```

Raw per-photo results and per-dish scores are in [`2026-11-26-nutrition5k-apple-results/`](2026-11-26-nutrition5k-apple-results/).
