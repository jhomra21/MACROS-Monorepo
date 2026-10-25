# Common food database

This package builds the bundled common-food database from the latest USDA
FoodData Central FNDDS CSV release listed on
https://fdc.nal.usda.gov/download-datasets. Each build discovers the current
release, then records its exact URL and release date in the manifest.

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
bun run check
bun test
```

`build` caches the upstream archive outside the source tree and writes the
two deterministic JSON resources in `cal-macro-tracker/CommonFoods/`.
`generatedAt` is the source release date, so repeated builds against the same
upstream release produce deterministic output.

USDA FoodData Central data is public domain under 17 U.S.C. § 105.
