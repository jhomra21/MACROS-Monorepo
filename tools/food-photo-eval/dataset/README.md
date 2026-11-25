# Collecting a small food-photo dataset

Thanks for helping evaluate meal estimates. This is research data, not an app feature. Keep photos private and include only people who have agreed to participate.

## What to photograph

- About 50 home meals. For each meal, weigh and photograph small, medium, and large portions.
- 10 fast-food meals.
- 10 packaged snacks, such as a chip bag or protein bar. Include the package in view.
- 10 negatives with no food (for example, an empty plate, a pet, or a landscape).

For each plated meal, take one photo around 45° and one directly overhead. Use ordinary, clear lighting; avoid filters. Include a fork in about half of the photos. Keep the camera distance and plate style natural.

Before plating, tare a kitchen scale with the empty plate or container. Weigh every visible component separately, including sauces, dressings, cooking oil, and toppings when practical. Record those weights as eaten weights. For a packaged item, record the edible amount and use the package serving label only as a note, not as a substitute for the weighed amount. For liquids, record measured millilitres and do not invent grams.

## Filenames and truth

Use lowercase IDs with a suffix identifying the view, for example:

```text
home-001-small-45.jpg
home-001-small-top.jpg
home-001-medium-45.jpg
home-001-large-45.jpg
fastfood-001-45.jpg
snack-001-top.jpg
negative-001-45.jpg
```

Put images in `photos/`. For every image, create `truth/<same-id>.json`, following `truth.schema.json` and `example/home-001-small-45.json`. Repeat the meal's weighed components for both views of the same plate. Set `foodKey` to a `sourceIdentifier` from `cal-macro-tracker/CommonFoods/common_foods.json` when there is a reasonable match; otherwise use `null`. Record ambiguity and foods missing from that list in `notes`. A packaged item's visible name is not a nutrition database match unless that food actually exists there.
