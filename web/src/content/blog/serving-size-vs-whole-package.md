---
title: "Serving size vs. the whole package: log what you ate"
description: "Nutrition Facts numbers are per serving, not per package. Multiply by the servings you ate, or scale by grams. FDA rules and worked math."
published: 2026-11-07
updated: 2026-11-07
draft: true
image: ../../assets/app-images/app-scan-review.png
imageAlt: "MACROS label scan result for a demo cereal label: 190 kcal, Servings stepper set to 1, 1 cup (40g) each, 40 g total, with Edit details and Log buttons"
imageCaption: "A MACROS label scan of a demo label. The Servings stepper scales calories and macros, and the gram total updates with it."
---

The calories and nutrients on a Nutrition Facts label are for one serving, not the whole package. To log what you ate, multiply the label numbers by the servings you ate, or divide the grams you ate by the grams in one serving and multiply by that.

I checked the FDA pages and regulations below on November 7, 2026.

## Find the serving line first

The serving size and the number of servings per container sit at the top of the label. The serving size is a household measure, such as a cup or a piece, followed by its weight in grams ([FDA, Serving Size on the Nutrition Facts Label](https://www.fda.gov/food/nutrition-facts-label/serving-size-nutrition-facts-label)).

Every number below that line is per serving. FDA says so directly: "all the nutrient amounts shown on the label, including the number of calories, refer to the size of the serving" ([FDA, How to Understand and Use the Nutrition Facts Label](https://www.fda.gov/food/nutrition-facts-label/how-understand-and-use-nutrition-facts-label)).

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

The first four rows match FDA's own figures for one serving, two servings, and the whole package. The last row is my arithmetic.

## Read "servings per container" with care

The servings count is rounded. Labels round it to the nearest whole number, except between 2 and 5 servings, where they round to the nearest half serving and use the word "about" ([21 CFR 101.9(b)(8)(i)](https://www.ecfr.gov/current/title-21/chapter-I/subchapter-B/part-101/subpart-A/section-101.9)). A package that says "about 2.5 servings" may hold a little more or a little less than that.

If you ate the whole package, a closer count is the net weight divided by the serving weight. Then multiply the label values by that number.

## Single-serving packages and two-column labels

Two rules make some packages simpler to log.

- If a package sold on its own holds less than 200% of the reference amount, the whole package must be labeled as one serving ([21 CFR 101.9(b)(6)](https://www.ecfr.gov/current/title-21/chapter-I/subchapter-B/part-101/subpart-A/section-101.9)).
- If it holds 200% to 300% of the reference amount, the label must add a second column for the entire package ([21 CFR 101.9(b)(12)(i)](https://www.ecfr.gov/current/title-21/chapter-I/subchapter-B/part-101/subpart-A/section-101.9)). FDA calls these "dual-column" labels ([FDA, Serving Size on the Nutrition Facts Label](https://www.fda.gov/food/nutrition-facts-label/serving-size-nutrition-facts-label)).

With a dual-column label, use the per-package column if you ate the whole thing. Use the per-serving column for anything less.

## Household measures or grams

The serving line gives both a household measure and grams. If you weigh your food, use the gram figure. It removes the question of how full your cup or spoon was.

Some labels give only a volume, such as fluid ounces or milliliters for drinks. A volume does not tell you the weight, so log those by servings unless the label also gives grams.

## How MACROS handles it

This section is about my app, MACROS.

- When you scan a label, MACROS shows one serving's size and grams, such as "1 cup (40g) each", and a running gram total.
- The Servings stepper moves in quarter servings. Calories, protein, carbs, and fat scale with it. Half a pack of a 2-serving package is 1 serving.
- MACROS does not read the "servings per container" line. To log a whole package, set Servings to that count, or switch to Grams and enter the net weight.
- Logging by grams needs grams per serving. If the label gives only a volume, the Grams option stays off until you add the gram weight yourself. MACROS does not guess grams from a volume.
- The math is the same as above: per-serving values × servings, or grams eaten ÷ grams per serving.

## How I checked

- [FDA, Serving Size on the Nutrition Facts Label](https://www.fda.gov/food/nutrition-facts-label/serving-size-nutrition-facts-label): where the serving line sits, what a serving means, and dual-column labels.
- [FDA, How to Understand and Use the Nutrition Facts Label](https://www.fda.gov/food/nutrition-facts-label/how-understand-and-use-nutrition-facts-label): the sample lasagna label and its 1, 2, and 4 serving figures.
- [21 CFR 101.9](https://www.ecfr.gov/current/title-21/chapter-I/subchapter-B/part-101/subpart-A/section-101.9), paragraphs (b)(1), (b)(6), (b)(8)(i), and (b)(12)(i): serving definition, single-serving packages, rounding of servings per container, and the per-package column.
- [21 CFR 101.12(b)](https://www.ecfr.gov/current/title-21/chapter-I/subchapter-B/part-101/subpart-A/section-101.12): reference amounts for cookies, grain-based bars, and yogurt.

I read the eCFR text as amended through November 5, 2026. I compared the MACROS section with the app's source code on November 7, 2026. I am the developer of MACROS, not a dietitian.

<!-- TODO (owner): optionally add 2 or 3 worked examples from real packages you own, with label photos and the product name, before publishing. -->

## Related

- [Why label calories don't add up to 4-4-9](/blog/label-calories-4-4-9/)
- [Why your label scan and the food database disagree](/blog/label-scan-vs-food-database/)
- [How to set protein, carb, and fat goals](/guides/how-to-set-macro-goals/)
