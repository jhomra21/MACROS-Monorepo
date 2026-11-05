---
title: How to set protein, carb, and fat goals
description: "Set daily macro goals with calorie-to-gram math, adult reference ranges, and a worked example. Learn how the MACROS goal calculator estimates your targets."
published: 2026-11-04
updated: 2026-11-04
draft: false
image: ../../assets/app-images/app-settings.png
imageAlt: "MACROS Settings showing editable Daily Goals for calories, protein, carbs, and fat, plus Recalculate Targets"
imageCaption: "Settings > Daily Goals in MACROS. These demo values illustrate the controls, not a recommended diet."
---

Start with a calorie estimate and convert your chosen macro percentages to grams. This guide explains the math and shows how MACROS calculates and saves targets.

This guide is for generally healthy adults. It is not medical advice. Talk to a qualified health professional about medical conditions, pregnancy, or an eating disorder before setting diet targets. These adult ranges and the app's calculator are not a plan for children.

## Start with adult reference ranges

The National Academies' Acceptable Macronutrient Distribution Ranges, or AMDRs, describe shares of total daily calories. For adults, they are:

| Nutrient | Share of daily calories |
| --- | --- |
| Protein | 10–35% |
| Carbohydrate | 45–65% |
| Fat | 20–35% |

These are population reference ranges, not a personalized prescription. The [National Academies' AMDR report, Table 3-1](https://www.nationalacademies.org/read/27957/chapter/5) lists these adult values and explains their use in dietary planning. Choose percentages that add to 100%. A 20% protein, 50% carbohydrate, and 30% fat split is one example within all three ranges.

The adult protein Recommended Dietary Allowance, or RDA, is 0.8 grams per kilogram of body weight per day. The [National Academies' DRI summary tables, protein footnote b](https://www.nationalacademies.org/read/25353/chapter/28) state this figure. It is a reference intended to meet the needs of nearly all healthy adults, not an upper limit or a sports-performance target. Individual needs can differ.

At 70 kg, the calculation is 70 × 0.8 = 56 g of protein per day. In pounds, 154.3 lb ÷ 2.20462 ≈ 70 kg, so the same calculation gives about 56 g. Do not confuse grams per kilogram with grams per pound.

## Turn calories into grams

For planning, protein and carbohydrate each provide 4 calories per gram. Fat provides 9. These are the general factors in [FDA nutrition-labeling rules, 21 CFR 101.9(c)(1)(i)(B)](https://www.ecfr.gov/current/title-21/chapter-I/subchapter-B/part-101/subpart-A/section-101.9).

- Protein grams = daily calories × protein percentage ÷ 100 ÷ 4.
- Carb grams = daily calories × carb percentage ÷ 100 ÷ 4.
- Fat grams = daily calories × fat percentage ÷ 100 ÷ 9.

For an illustrative 2,000-calorie day with a 20/50/30 split, that gives 100 g protein, 250 g carbs, and about 66.7 g fat. This is a math example, not a calorie recommendation. Food-label calories may not match 4/4/9 exactly because of rounding, fiber, sugar alcohols, and permitted calculation methods.

<!-- visual:calorie-flow -->

## How the MACROS calorie estimate works

MACROS uses the Mifflin–St Jeor equation to estimate resting energy needs:

Resting calories = 10 × weight in kg + 6.25 × height in cm − 5 × age in years + a sex constant.

The constant is +5 for Male and −161 for Female. For Unspecified, MACROS uses their midpoint, −78. That midpoint is an app convention, not a separately validated equation. The [original Mifflin–St Jeor study](https://pubmed.ncbi.nlm.nih.gov/2305711/) studied healthy adults. An estimate cannot measure your individual metabolism.

The app multiplies resting calories by the activity factor you select:

| Activity | App description | Multiplier |
| --- | --- | --- |
| Sedentary | Mostly sitting, little planned exercise | 1.2 |
| Light | Light exercise 1–3 days per week | 1.375 |
| Moderate | Moderate exercise 3–5 days per week | 1.55 |
| Active | Hard exercise 6–7 days per week | 1.725 |
| Very active | Very hard training or a physical job | 1.9 |

These factors are the app's estimation settings. They are not part of the original resting-energy equation. Maintain uses that total unchanged. Lose subtracts 250, 500, or 750 calories per day for the selected 0.25, 0.5, or 0.75 kg weekly pace. Gain adds 250 or 500 calories for 0.25 or 0.5 kg per week. The pound equivalents are about 0.55, 1.10, and 1.65 lb. These settings do not guarantee a particular weight change.

The calculator clamps its result to at least 1,500 calories for Male or 1,200 for Female and Unspecified. It flags a requested target below that floor. These are software limits, not proof that a calorie target is safe or adequate for you.

The age field starts at 30. If you clear it, the app uses 30 and shows a notice. Weight converts between kg and lb; height converts between centimeters and feet/inches. Changing units retains the underlying metric measurements.

## What the app's macro presets mean

MACROS offers these starting splits before rounding:

| Preset | Protein | Carbs | Fat |
| --- | --- | --- | --- |
| Balanced | 30% | 40% | 30% |
| High protein | 40% | 30% | 30% |
| Low carb | 35% | 20% | 45% |

The preset names are product labels, not dietary guidelines. None of these presets falls within all three adult AMDRs. Balanced puts carbs below 45%. High protein also puts protein above 35%. Low carb puts carbs below 45% and fat above 35%. Choose manual goals if you want a split within the reference ranges or targets agreed with a professional.

<!-- visual:amdr -->

The calculator rounds protein and fat to the nearest 5 g. It first rounds carbs to 5 g too. It accepts a calorie total between the requested total and 2% above it. Outside that range, the app replaces carbs with the smallest 5 g step that reaches the target. That adjustment can raise or lower carbs. It then calculates the displayed calorie goal from the final grams with 4/4/9. The saved goal can therefore differ from the initial calorie estimate.

## A worked calculator example in kg and lb

Take a hypothetical 30-year-old adult using Male, 70 kg, 175 cm, Moderate activity, Maintain, and Balanced. This is an explanation of the software, not advice to use these settings.

1. The resting estimate is 10 × 70 + 6.25 × 175 − 5 × 30 + 5 = 1,648.75 calories.
2. The activity estimate is 1,648.75 × 1.55 = 2,555.56 calories.
3. Maintain adds zero. The result is above the app's calorie floor.
4. The 30/40/30 split gives about 191.67 g protein, 255.56 g carbs, and 85.19 g fat before rounding.
5. The app rounds to 190 g protein, 255 g carbs, and 85 g fat. That totals 2,545 calories, below the estimate.
6. It raises carbs to 260 g. The final goal is 2,565 calories, 190 g protein, 260 g carbs, and 85 g fat.

<!-- visual:calculator -->

In imperial units, 70 kg is about 154.3 lb and 175 cm is about 5 ft 8.9 in. Entering those rounded imperial values gives nearly the same estimate and the same rounded macro goals. The app displays height conversions to a whole inch, so switching units may show 5 ft 9 in while retaining the original centimeters internally.

## Sources and scope

I am the developer of MACROS, not a medical reviewer. I checked the sources below on November 4, 2026, and compared the calculator explanation with this version of the app.

- [National Academies, 2024 AMDR report, chapter 3 and Table 3-1](https://www.nationalacademies.org/read/27957/chapter/5): adult percentage ranges and their limits.
- [National Academies, 2019 DRI summary tables, protein footnote b](https://www.nationalacademies.org/read/25353/chapter/28): adult protein RDA of 0.8 g/kg.
- [FDA, 21 CFR 101.9(c)(1)](https://www.ecfr.gov/current/title-21/chapter-I/subchapter-B/part-101/subpart-A/section-101.9): general 4/4/9 calorie factors and other labeling methods.
- [Mifflin et al., 1990, original resting-energy equation](https://pubmed.ncbi.nlm.nih.gov/2305711/): the adult equation used by the app.

## Set your daily goals in MACROS

Open Settings and find Daily Goals. Enter your calorie, protein, carb, and fat targets, then tap Save Goals.

<!-- visual:settings -->

For a calculated starting point, tap Recalculate Targets. Enter your body profile.

<!-- visual:profile -->

Choose your activity and goal direction, then tap Review targets.

<!-- visual:activity -->

Check the macro balance and targets before applying them. These calculator screenshots use the worked example above, not a recommended diet.

<!-- visual:review -->

Revisit your targets with a professional if they do not fit your needs. A macro total alone does not tell you whether your diet provides enough fiber, vitamins, or minerals.

Read [how MACROS handles your food diary data](/privacy/) or [contact the developer for app help](/support/). The [MACROS calorie counter and food diary homepage](/) lists the app's features.
