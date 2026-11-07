---
title: "Serving size vs. the whole package: log what you ate"
description: "Check whether Nutrition Facts lists values per serving or per package. Learn how to scale calories and macros by servings or grams."
published: 2026-11-07
updated: 2026-11-07
draft: true
image: ../../assets/app-images/app-scan-review.png
imageAlt: "MACROS label scan result for a demo cereal label: 190 kcal, Servings stepper set to 1, 1 cup (40g) each, 40 g total, with Edit details and Log buttons"
related:
  - blog/label-calories-4-4-9
  - guides/how-to-set-macro-goals
---

Nutrition Facts usually lists calories and nutrients per serving, though some labels also show a per-package column. Check the column heading, then multiply per-serving values by the servings you ate.

To log by weight, divide the grams you ate by the grams in one serving and multiply the per-serving values by that.

MACROS checked the FDA pages and regulations below on November 7, 2026.

## Find the serving line first

The serving size and the number of servings per container sit at the top of the label. Serving size is usually shown as a household measure, such as a cup or a piece, followed by grams for solid foods or milliliters for fluids. Single-serving containers may omit that parenthetical amount ([FDA, Serving Size on the Nutrition Facts Label](https://www.fda.gov/food/nutrition-facts-label/serving-size-nutrition-facts-label); [21 CFR 101.9(b)(7)](https://www.ecfr.gov/current/title-21/chapter-I/subchapter-B/part-101/subpart-A/section-101.9)).

In the per-serving column, the calorie and nutrient amounts refer to the listed serving size. FDA puts it this way: "all the nutrient amounts shown on the label, including the number of calories, refer to the size of the serving" ([FDA, How to Understand and Use the Nutrition Facts Label](https://www.fda.gov/food/nutrition-facts-label/how-understand-and-use-nutrition-facts-label)).

A serving is not advice on how much to eat. By regulation, it is the "amount of food customarily consumed per eating occasion" by people 4 and older ([21 CFR 101.9(b)(1)](https://www.ecfr.gov/current/title-21/chapter-I/subchapter-B/part-101/subpart-A/section-101.9)). Makers start from FDA's reference amounts for each food category ([21 CFR 101.12(b)](https://www.ecfr.gov/current/title-21/chapter-I/subchapter-B/part-101/subpart-A/section-101.12)). A few of them:

| Food category | Reference amount per eating occasion |
| --- | --- |
| Cookies | 30 g |
| Grain-based bars, such as granola bars | 40 g |
| Yogurt | 170 g |

## Do the math

The rule is the same for every nutrient:

- By servings: label value × servings eaten.
- By weight: label value × (grams eaten ÷ grams per serving).

FDA's sample lasagna label lists 1 cup (227 g) per serving, 280 calories, and 15 g protein, with 4 servings in the package ([FDA, How to Understand and Use the Nutrition Facts Label](https://www.fda.gov/food/nutrition-facts-label/how-understand-and-use-nutrition-facts-label)). It is FDA's teaching example, not a product you can buy. Here is how different portions work out:

| What you ate | Servings | Calories (kcal) | Protein (g) |
| --- | --- | --- | --- |
| 1 cup | 1 | 280 | 15 |
| 2 cups | 2 | 560 | 30 |
| Half the package | 2 | 560 | 30 |
| The whole package | 4 | 1,120 | 60 |
| 340 g, weighed | 340 ÷ 227 = 1.4978 | 280 × 1.4978 = 419 | 15 × 1.4978 = 22.5 |

The first four rows match FDA's own figures for one serving, two servings, and the whole package. The last row applies the same math to a weighed portion.

## Read "servings per container" with care

Servings per container is generally rounded to a whole number, or to the nearest half serving between 2 and 5. "About" indicates rounding. Random-weight products have separate rules ([21 CFR 101.9(b)(8)](https://www.ecfr.gov/current/title-21/chapter-I/subchapter-B/part-101/subpart-A/section-101.9)). A package that says "about 2.5 servings" may hold a little more or a little less than that.

If the label values and package weight describe the same form of the food, dividing package weight by serving weight can give a closer estimate. For foods labeled on a drained basis, use the drained food's weight, not the weight including discarded liquid. The rule for foods packed in liquid you normally pour off is to declare nutrition "based on the drained solids" ([21 CFR 101.9(b)(9)](https://www.ecfr.gov/current/title-21/chapter-I/subchapter-B/part-101/subpart-A/section-101.9)).

## Single-serving packages and two-column labels

Two rules make some packages simpler to log.

- If a package sold on its own holds less than 200% of the reference amount, the whole package must be labeled as one serving ([21 CFR 101.9(b)(6)](https://www.ecfr.gov/current/title-21/chapter-I/subchapter-B/part-101/subpart-A/section-101.9)).
- Individually sold packages containing 200% through 300% of the reference amount generally need both per-serving and per-package columns. The regulation lists exceptions, including some small packages and products with other permitted labeling formats ([21 CFR 101.9(b)(12)(i)](https://www.ecfr.gov/current/title-21/chapter-I/subchapter-B/part-101/subpart-A/section-101.9)). FDA calls these "dual-column" labels ([FDA, Serving Size on the Nutrition Facts Label](https://www.fda.gov/food/nutrition-facts-label/serving-size-nutrition-facts-label)).

With a dual-column label, use the per-package column if you ate the whole thing. Use the per-serving column for anything less.

## Household measures or grams

If the label gives grams and you weigh your food, use the gram figure. Then you don't have to guess how full your cup or spoon was.

Some labels give only a volume, such as fluid ounces or milliliters for drinks. A volume does not tell you the weight, so log those by servings unless the label also gives grams.

## How MACROS handles it

To log by servings:

1. Scan the label. The card shows one serving's size and grams, such as "1 cup (40g) each", and the total grams for your portion.
2. Set the Servings stepper to what you ate. It starts at 1, not at the servings per container, and moves in quarter servings from 0.25 to 20. Half a pack of a 2-serving package is 1 serving.
3. Check that calories, protein, carbs, and fat changed with it, then tap Log.

<!-- visual:scan-review -->

To log by weight:

1. Tap Edit details and choose Grams.
2. Set the Grams stepper to the weight you ate. It moves in 5 g steps and stops at 1 g. For a food labeled on a drained basis, use the drained weight.
3. Tap Log.

Servings move in quarter servings and grams in 5 g steps, so an exact weighed amount may fall between two steps. Pick the closest one. Leave the serving's gram amount as printed on the label, because changing it to reach your weight changes the calories in every gram you log.

If the label gives only a volume, Grams stays off until you enter the serving's gram weight yourself. Otherwise, log by servings.

<!-- visual:scan-grams -->

The calories and macros on screen follow the same math as above: label value × servings, or label value × (grams eaten ÷ grams per serving).

## How this was checked

- [FDA, Serving Size on the Nutrition Facts Label](https://www.fda.gov/food/nutrition-facts-label/serving-size-nutrition-facts-label): where the serving line sits, what a serving means, per-package information on some containers, and dual-column labels.
- [FDA, How to Understand and Use the Nutrition Facts Label](https://www.fda.gov/food/nutrition-facts-label/how-understand-and-use-nutrition-facts-label): the sample lasagna label and its 1, 2, and 4 serving figures.
- [21 CFR 101.9](https://www.ecfr.gov/current/title-21/chapter-I/subchapter-B/part-101/subpart-A/section-101.9), paragraphs (b)(1), (b)(6), (b)(7), (b)(8), (b)(9), and (b)(12)(i): serving definition, single-serving packages, how serving size is expressed, rounding of servings per container, the drained-solids basis, and the per-package column with its exceptions.
- [21 CFR 101.12(b)](https://www.ecfr.gov/current/title-21/chapter-I/subchapter-B/part-101/subpart-A/section-101.12): reference amounts for cookies, grain-based bars, and yogurt.

MACROS publishes this site. This post uses the eCFR text as amended through November 5, 2026. MACROS checked the app steps against the current app on November 7, 2026. No dietitian reviewed this post.

<!-- TODO (owner): optionally add 2 or 3 worked examples from real packages you own, with label photos and the product name, before publishing. -->
