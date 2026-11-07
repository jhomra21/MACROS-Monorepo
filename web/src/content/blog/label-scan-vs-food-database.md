---
title: "Why your label scan and the food database disagree"
description: "A label scan reads the package in your hand. A database entry copies a label from another time or place. Why they differ and how to check."
published: 2026-11-07
updated: 2026-11-07
draft: true
image: ../../assets/app-images/app-add-food.png
imageAlt: "MACROS food search for greek yogurt: two on-device matches, then search results for several Greek yogurt products with calories from 67 to 230 kcal"
imageCaption: "A MACROS search for \"greek yogurt\". Different products share a name but not their numbers, so check the brand and serving before you pick one."
---

A label scan reads the package in your hand. A database entry is a copy of a label from some other time, place, or person, so the two can disagree.

The usual causes are a changed recipe, a different regional version, a different serving basis, rounding, a typing error, or a scan misread. When they disagree, check the scan against the label you are holding, then fix the entry before you log it.

I checked the sources below on November 7, 2026.

## Where each number comes from

| Source | Who supplies the data | What it is based on | How often it changes |
| --- | --- | --- | --- |
| Your label scan | You, from the package you bought | The printed Nutrition Facts label | Every time you scan |
| USDA FoodData Central, Branded Foods | Manufacturers | "Food label information," collected by a public-private partnership | Monthly |
| Open Food Facts | Volunteers | Barcode scans and photos of product labels | Whenever someone edits a product |

The USDA row comes from the [FoodData Central data type documentation](https://fdc.nal.usda.gov/data-documentation). The Open Food Facts row comes from its [Discover page](https://world.openfoodfacts.org/discover), which describes a "collaborative" database built by "a non-profit association of volunteers."

None of these sources is wrong by design. They are copies made at different times by different people.

## Why the numbers differ

- **The recipe changed.** A maker can change a product and its label. An older database entry keeps the old numbers until someone updates it.
- **It is a different version.** The same brand and name can be sold with different recipes in different countries. Open Food Facts lists products from many countries.
- **The serving basis differs.** One entry may store values per serving and another per 100 g. If an entry has no serving weight, an app may show it per 100 g, which looks nothing like the label.
- **The label is rounded.** Labels round calories to the nearest 5 or 10 and grams to set steps ([21 CFR 101.9(c)](https://www.ecfr.gov/current/title-21/chapter-I/subchapter-B/part-101/subpart-A/section-101.9)). A database that stores unrounded or per-100 g values can be off by a few units after scaling.
- **Someone typed it wrong.** A misplaced decimal or a value in the wrong field happens in any hand-entered data.
- **The scan misread the label.** Glare, curves, and small print can make text recognition miss or misread a digit.

The printed label is not exact either. FDA treats a food as misbranded if lab testing finds calories more than 20% above the label value ([21 CFR 101.9(g)(5)](https://www.ecfr.gov/current/title-21/chapter-I/subchapter-B/part-101/subpart-A/section-101.9)). That rule is about enforcement. It does not tell you how far any single package is off.

## Our check

<!-- TODO (owner): run the check below on your own products, fill in the table, and write a one-sentence headline result here. Do not publish with empty rows. -->

TODO (owner): headline result goes here after the product checks. Example shape: "In N products I bought in [month], X of the USDA entries and Y of the Open Food Facts entries matched the label calories exactly."

### Method

1. Buy or pick products from your kitchen. Write down the store and date.
2. Photograph each Nutrition Facts label.
3. Look up the barcode in [FoodData Central](https://fdc.nal.usda.gov/) and in [Open Food Facts](https://world.openfoodfacts.org/).
4. Record calories, protein, carbs, and fat per serving from each source. If a source gives only per 100 g, convert with the label's serving weight and note that you did.
5. Record the difference from the label and the most likely cause.

### Results

| Product (brand, size) | Label photographed | Label kcal per serving | USDA kcal per serving (FDC ID) | Open Food Facts kcal per serving (barcode) | Difference (kcal) | Likely cause |
| --- | --- | --- | --- | --- | --- | --- |
| TODO | TODO | TODO | TODO | TODO | TODO | TODO |
| TODO | TODO | TODO | TODO | TODO | TODO | TODO |
| TODO | TODO | TODO | TODO | TODO | TODO | TODO |
| TODO | TODO | TODO | TODO | TODO | TODO | TODO |
| TODO | TODO | TODO | TODO | TODO | TODO | TODO |

### Limits

This is a small sample of products I chose, not a random sample. It shows how often these copies drift from the label for these products on these dates. It does not measure how accurate either database is overall.

## How MACROS handles it

This section is about my app, MACROS.

- Label scans run on your iPhone with Apple's Vision text recognition. The photo is not sent to a server for reading.
- Barcode lookups and text searches go to the MACROS food-search service, which queries Open Food Facts and USDA FoodData Central ([privacy policy](/privacy/)). Search results appear below your on-device matches.
- In Edit details, a barcode result names Open Food Facts as its source, with a link to the product page.
- If a label scan could not read calories, protein, carbs, or fat, MACROS asks you to enter them or confirm they are 0 before you log.
- Every value is editable before you log. If you edit a saved food from a database, MACROS updates your local copy, so your corrected values are used the next time you log it.

## How I checked

- [FoodData Central data type documentation](https://fdc.nal.usda.gov/data-documentation): Branded Foods come from manufacturers' label information and update monthly.
- [Open Food Facts, Discover](https://world.openfoodfacts.org/discover): volunteer, collaborative database built from barcode scans and label photos.
- [21 CFR 101.9](https://www.ecfr.gov/current/title-21/chapter-I/subchapter-B/part-101/subpart-A/section-101.9), paragraphs (c) and (g)(5): label rounding and the 20% calorie compliance limit. I read the eCFR text as amended through November 5, 2026.

I compared the MACROS section with the app's source code on November 7, 2026. I am the developer of MACROS, not a dietitian.

## Related

- [Serving size vs. the whole package](/blog/serving-size-vs-whole-package/)
- [Why label calories don't add up to 4-4-9](/blog/label-calories-4-4-9/)
- [How MACROS handles your food diary data](/privacy/)
