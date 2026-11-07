---
title: "Why label calories don't add up to 4-4-9"
description: "Label calories can differ from protein × 4 + carbs × 4 + fat × 9. Learn why FDA's calorie methods and rounding cause it, with worked examples."
published: 2026-11-07
updated: 2026-11-07
draft: true
related:
  - guides/how-to-set-macro-goals
  - blog/serving-size-vs-whole-package
image: ../../assets/app-images/app-scan-details.png
imageAlt: "MACROS scan details for a demo cereal label showing 190 kcal, P 5, C 36, F 3, a Servings and Grams switch, and editable food name and serving size"
---

Label calories often differ from protein × 4 + carbs × 4 + fat × 9 because FDA lets food makers choose among several calorie methods, and because every number on the label is rounded. Fiber and sugar alcohols can create larger differences because they count toward total carbohydrate but can contribute fewer than 4 calories per gram.

MACROS checked the regulation below on November 7, 2026, in the eCFR text amended through November 5, 2026.

## The methods FDA allows

FDA's labeling rule lists the ways a maker may calculate calories per serving ([21 CFR 101.9(c)(1)(i)](https://www.ecfr.gov/current/title-21/chapter-I/subchapter-B/part-101/subpart-A/section-101.9)):

| Method | How calories are counted |
| --- | --- |
| (A) Specific Atwater factors | Food-specific factors from USDA Handbook No. 74 |
| (B) General factors | 4 per gram of protein, 4 per gram of total carbohydrate, 9 per gram of fat |
| (C) General factors, adjusted carbs | 4, 4, and 9, but carbohydrate minus non-digestible carbohydrates and sugar alcohols. Soluble non-digestible carbohydrate counts 2 per gram. Sugar alcohols use their own factors. |
| (D) FDA-approved food factors | Specific factors for particular foods or ingredients |
| (E) Bomb calorimetry | Lab-measured energy, minus 1.25 calories per gram of protein |

Only method (B) is plain 4-4-9. The same rule says the factors apply to the actual amounts "before rounding."

Method (C) uses these sugar alcohol factors, in calories per gram ([21 CFR 101.9(c)(1)(i)(F)](https://www.ecfr.gov/current/title-21/chapter-I/subchapter-B/part-101/subpart-A/section-101.9)):

| Sugar alcohol | Calories per gram |
| --- | --- |
| Erythritol | 0 |
| Mannitol | 1.6 |
| Isomalt | 2.0 |
| Lactitol | 2.0 |
| Maltitol | 2.1 |
| Xylitol | 2.4 |
| Sorbitol | 2.6 |
| Hydrogenated starch hydrolysates | 3.0 |

## The rounding rules

Each line on the label is rounded on its own ([21 CFR 101.9(c)](https://www.ecfr.gov/current/title-21/chapter-I/subchapter-B/part-101/subpart-A/section-101.9)):

| Label line | Rounding |
| --- | --- |
| Calories | Nearest 5 up to and including 50. Nearest 10 above 50. Under 5 may be shown as 0. |
| Total fat | Nearest 0.5 g below 5 g. Nearest 1 g above 5 g. Under 0.5 g is shown as 0. |
| Total carbohydrate | Nearest 1 g. Under 1 g may say "less than 1 gram." Under 0.5 g may be shown as 0. |
| Protein | Nearest 1 g. Under 1 g may say "less than 1 gram." Under 0.5 g may be shown as 0. |

So when you multiply the printed grams by 4, 4, and 9, you are working from rounded numbers. The maker worked from unrounded ones.

## Three worked examples

### Example 1: FDA's sample label is consistent with rounding

FDA's sample lasagna label lists 280 calories, 15 g protein, 34 g total carbohydrate, and 9 g fat per serving ([FDA, How to Understand and Use the Nutrition Facts Label](https://www.fda.gov/food/nutrition-facts-label/how-understand-and-use-nutrition-facts-label)). It is a teaching example, not a product for sale.

- 4 × 15 + 4 × 34 + 9 × 9 = 60 + 136 + 81 = 277.
- 277 is above 50, so it rounds to the nearest 10: 280.

These printed values produce 280 after calorie rounding. They do not show which calculation method or unrounded amounts produced the label.

### Example 2: a small serving, rounding only

This is an illustrative, made-up label. Suppose the actual amounts per serving are 0.4 g protein, 4.4 g carbohydrate, and 2.24 g fat, and the maker uses method (B).

- Actual calories: 4 × 0.4 + 4 × 4.4 + 9 × 2.24 = 1.6 + 17.6 + 20.16 = 39.36.
- 39.36 is under 50, so it rounds to the nearest 5: the label says 40.
- The label shows 0 g protein (under 0.5 g), 4 g carbohydrate, and 2 g fat (2.24 rounds to the nearest 0.5).
- From the printed grams: 4 × 0 + 4 × 4 + 9 × 2 = 0 + 16 + 18 = 34.

The printed grams give 34. The label says 40. Both follow the rules.

### Example 3: a bar with fiber and erythritol, method (C)

This is also an illustrative, made-up label. Suppose a bar has 20 g protein, 7 g fat, and 24 g total carbohydrate. That carbohydrate includes 10 g of dietary fiber, all soluble, and 8 g of erythritol. Every amount is a whole number, so rounding the grams changes nothing.

- Digestible carbohydrate: 24 − 10 − 8 = 6 g, at 4 per gram = 24.
- Soluble fiber: 10 g at 2 per gram = 20.
- Erythritol: 8 g at 0 per gram = 0.
- Protein: 20 × 4 = 80. Fat: 7 × 9 = 63.
- Total: 80 + 63 + 24 + 20 + 0 = 187, which rounds to 190.
- Plain 4-4-9 on the printed grams: 4 × 20 + 4 × 24 + 9 × 7 = 80 + 96 + 63 = 239.

The label says 190. Plain 4-4-9 says 239. The gap of 49 calories comes from the method, not from an error.

## Which number to log

Log the calorie number printed on the label. The maker calculated it from unrounded amounts with an allowed method. Recalculating from rounded grams adds error.

Look closer if the label total is far from every method above, or if a scan shows numbers that do not match the package. That can point to a misprint or a misread digit. Check the label you are holding.

## How MACROS handles it

1. Scan the label and compare the calories on the card with the printed calories. MACROS logs the label's number as is, so your entry matches the package even when 4-4-9 gives a different total.
2. If a scanned number does not match the package, tap Edit details and correct it before you log.
3. Tap Log.

<!-- visual:scan-details -->

Your daily calorie total adds up the calories you logged, and each macro total adds up the grams you logged.

If you set goals with Recalculate Targets, MACROS uses 4-4-9 to turn your protein, carb, and fat goals into a calorie goal. Your food entries keep their label calories, so your calorie ring and your macro rings may not fill at exactly the same pace. That is expected.

## How this was checked

- [21 CFR 101.9(c)](https://www.ecfr.gov/current/title-21/chapter-I/subchapter-B/part-101/subpart-A/section-101.9): the calorie methods in (c)(1)(i)(A) to (F), the sugar alcohol factors, and the rounding rules for calories, fat, carbohydrate, and protein.
- [FDA, How to Understand and Use the Nutrition Facts Label](https://www.fda.gov/food/nutrition-facts-label/how-understand-and-use-nutrition-facts-label): the sample lasagna label in example 1.
- Examples 2 and 3 are made-up labels to show the arithmetic. They are not real products.

MACROS publishes this site. MACROS checked the app steps against the current app on November 7, 2026. No dietitian reviewed this post.
