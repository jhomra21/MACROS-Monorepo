---
title: "Why your label scan and the food database disagree"
description: "A label scan reads the package in your hand. A database entry copies a label from another time or place. Why they differ and how to check."
published: 2026-11-07
updated: 2026-11-07
draft: true
image: ../../assets/app-images/app-add-food.png
imageAlt: "MACROS search for greek yogurt, with two on-device matches followed by remote results showing different brands and calorie values."
related:
  - blog/serving-size-vs-whole-package
  - blog/label-calories-4-4-9
---

A label scan reads your package. USDA Branded Foods and Open Food Facts entries can reflect a different package version, serving basis, or transcription.

The usual causes are a changed recipe, a different regional version, a different serving basis, rounding, a typing error, or a scan misread. When they disagree, check the scan against the label you are holding, then fix the entry before you log it.

MACROS checked the sources below on November 7, 2026.

## Where each number comes from

| Source | Who supplies the data | What it is based on | How often it changes |
| --- | --- | --- | --- |
| Your label scan | You, from the package you bought | The printed Nutrition Facts label | Every time you scan |
| USDA FoodData Central, Branded Foods | Manufacturers | "Food label information," collected by a public-private partnership | Monthly |
| Open Food Facts | Volunteers | Barcode scans and photos of product labels | Whenever someone edits a product |

The USDA row comes from the [FoodData Central data type documentation](https://fdc.nal.usda.gov/data-documentation). The Open Food Facts row comes from its [Discover page](https://world.openfoodfacts.org/discover), which describes a "collaborative" database built by "a non-profit association of volunteers."

## Why the numbers differ

- **The recipe changed.** A maker can change a product and its label. An older database entry keeps the old numbers until someone updates it.
- **It is a different version.** The same brand and name can be sold with different recipes in different countries. Open Food Facts lists products from many countries.
- **The serving basis differs.** One entry may store values per serving and another per 100 g. If an entry has no serving weight, an app may show it per 100 g, which looks nothing like the label.
- **The label is rounded.** Labels round calories to the nearest 5 or 10 and grams to set steps ([21 CFR 101.9(c)](https://www.ecfr.gov/current/title-21/chapter-I/subchapter-B/part-101/subpart-A/section-101.9)). A database that stores unrounded or per-100 g values can be off by a few units after scaling.
- **Someone typed it wrong.** A misplaced decimal or a value in the wrong field happens in any hand-entered data.
- **The scan misread the label.** Glare, curves, and small print can make text recognition miss or misread a digit.

The printed label is not exact either. FDA's compliance rule generally treats a food as misbranded when calories measured in a composite sample exceed the declared value by more than 20%, subject to the rule's analytical-variability qualification. The sampling procedure combines 12 consumer-unit subsamples ([21 CFR 101.9(g)(2) and (g)(5)](https://www.ecfr.gov/current/title-21/chapter-I/subchapter-B/part-101/subpart-A/section-101.9)). This is an enforcement rule, not an estimate of the error in your individual package.

## A label-versus-database check

<!-- TODO (owner): run the check below on your own products, fill in the tables, and write a one-sentence headline result here. Do not publish with empty rows. -->

TODO (owner): headline result goes here after the product checks. Example shape: "In N products bought in [month], X of the USDA entries and Y of the Open Food Facts entries matched the label calories exactly."

### Method

1. Buy or pick products from your kitchen. Write down the store and date.
2. Photograph each Nutrition Facts label and note the photo date.
3. Look up the barcode in [FoodData Central](https://fdc.nal.usda.gov/) and in [Open Food Facts](https://world.openfoodfacts.org/).
4. Record each source's lookup date, record ID or barcode, original nutrition basis, serving weight, calories, protein, carbs, and fat. Normalize all values to the same labeled serving, keeping the original values and the conversion.
5. Calculate USDA minus label and Open Food Facts minus label separately. Record an explanation only when verified. Otherwise write "cause not established."

### Source records

One row per source per product.

| Product (brand, size) | Source | Date (photo or lookup) | Record ID or barcode | Original basis | Serving weight (g) | Conversion to labeled serving |
| --- | --- | --- | --- | --- | --- | --- |
| TODO | Label | TODO | TODO | Per serving | TODO | None |
| TODO | USDA | TODO | TODO (FDC ID) | TODO | TODO | TODO |
| TODO | Open Food Facts | TODO | TODO (barcode) | TODO | TODO | TODO |

### Calories per labeled serving

| Product (brand, size) | Label (kcal) | USDA (kcal) | OFF (kcal) | USDA − label (kcal) | OFF − label (kcal) | Verified explanation or unknown |
| --- | --- | --- | --- | --- | --- | --- |
| TODO | TODO | TODO | TODO | TODO | TODO | TODO |
| TODO | TODO | TODO | TODO | TODO | TODO | TODO |
| TODO | TODO | TODO | TODO | TODO | TODO | TODO |
| TODO | TODO | TODO | TODO | TODO | TODO | TODO |
| TODO | TODO | TODO | TODO | TODO | TODO | TODO |

OFF is Open Food Facts.

### Macros per labeled serving

| Product (brand, size) | Source | Protein (g) | Carbs (g) | Fat (g) |
| --- | --- | --- | --- | --- |
| TODO | Label | TODO | TODO | TODO |
| TODO | USDA | TODO | TODO | TODO |
| TODO | Open Food Facts | TODO | TODO | TODO |

### Limits

This is a small, hand-picked sample of products, not a random sample. It shows how often these copies drift from the label for these products on these dates. It does not measure how accurate either database is overall.

## How MACROS handles it

- Label scans run on your iPhone with Apple's Vision text recognition. The photo is not sent to a server for reading.
- Barcode lookups use Open Food Facts through the MACROS food-search service. Text search can return Open Food Facts and USDA Branded Foods results below your on-device matches ([privacy policy](/privacy/)).

<!-- visual:add-food -->

In Edit details, a barcode result names Open Food Facts as its source, with a link to the product page.

<!-- visual:barcode-source -->

If a label scan could not read calories, protein, carbs, or fat, MACROS asks you to enter them or confirm they are 0 before you log.

<!-- visual:scan-required-review -->

- Every value is editable before you log. When you edit a saved database food before logging and then log it, MACROS updates its reusable local copy. Selecting that saved copy again uses your corrections.

## How this was checked

- [FoodData Central data type documentation](https://fdc.nal.usda.gov/data-documentation): Branded Foods come from manufacturers' label information and update monthly.
- [Open Food Facts, Discover](https://world.openfoodfacts.org/discover): volunteer, collaborative database built from barcode scans and label photos.
- [21 CFR 101.9](https://www.ecfr.gov/current/title-21/chapter-I/subchapter-B/part-101/subpart-A/section-101.9), paragraphs (c), (g)(2), and (g)(5): label rounding, the 12-subsample composite, and the 20% calorie compliance limit with its analytical-variability qualification, in the eCFR text as amended through November 5, 2026.

MACROS publishes this site. MACROS compared the section about the app with its source code on November 7, 2026. No dietitian reviewed this post.
