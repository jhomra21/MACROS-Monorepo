# Common food database

This package builds the bundled common-food database from the latest USDA
FoodData Central FNDDS CSV release listed on
https://fdc.nal.usda.gov/download-datasets. Each build records the exact
release name, archive URL, archive SHA-256, and release date in the manifest.
Rebuild a release already recorded in the manifest with
`bun run build -- --release "FNDDS 2021–2023 (October 2024)"`. The pipeline
verifies the cached archive against the manifest hash before regenerating the
JSON resources.

## Pipeline failure cases

- Nutrients missing for a food, including rows with absent nutrient amounts.
- Portions missing gram weights, or portions with non-positive weights.
- Duplicate descriptions and duplicate normalized friendly names.
- Non-ASCII UTF-8 descriptions, including accented characters.
- Foods with zero calories, which must not be discarded.
- Household portions expressed in grams or ounces that need deterministic unit
  conversion.
- Malformed CSV rows, invalid numeric fields, and missing required food IDs.
- Infant foods, alcohol-only entries, and NFS/NS-as-to duplicate descriptions.
- Missing source files, invalid archive structure, and undersized/oversized
  selected datasets.
- Repeated generation must produce byte-identical JSON output.

## Commands

```sh
bun run build
bun run build -- --release "FNDDS 2021–2023 (October 2024)"
bun run check
bun test
```

`build` caches the upstream archive outside the source tree and writes the
two deterministic JSON resources in `cal-macro-tracker/CommonFoods/`.
`generatedAt` is the source release date, so repeated builds against the same
upstream release produce deterministic output.

The checked-in bundle was generated from **FNDDS 2021–2023 (October 2024)**,
archive URL
`https://fdc.nal.usda.gov/fdc-datasets/FoodData_Central_survey_food_csv_2024-10-31.zip`,
SHA-256
`5ccc25ec2777a8982fbb61378a42f415316173eb11e48c9a8ba4cb19f5a4f29c`.

USDA FoodData Central data is public domain under 17 U.S.C. § 105.
