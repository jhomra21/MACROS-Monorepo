# Bundled Food Database Implementation Tracker (WS4)

Branch `launch/ws4-food-database`. Mac (pipeline is Bun; app side needs Xcode). Read `AGENTS.md`, `Data/Services/CommonFoodSeedLoader.swift`, `Data/Services/AppBootstrap.swift`, `Data/Models/FoodItem.swift` (`FoodItemLocalSearch`), `Features/AddFood/AddFoodSearchResults.swift`, `Features/AddFood/AddFoodScreen.swift`, `changes-log.md` sections "Food Search" and "Local Food Search Token-Match Follow-up", and `implementation-trackers/launch-program-tracker.md`.

## Shared Understanding

- `cal-macro-tracker/CommonFoods/common_foods.json` currently contains 3,199 foods. `CommonFoodSeedLoader.reconcile` upserts by normalized name on bootstrap and never deletes. Local search ranks in memory with `FoodItemLocalSearch.rankedFoods`.
- Online search requires an explicit "Search Online" tap or keyboard submit; it goes through the Worker to Open Food Facts and USDA.
- Goal: a user with no network can find common generic foods instantly, and the first search results look sane for everyday queries.

## Current Status

- Bundled source is USDA FNDDS 2021–2023, October 2024 archive. The manifest records the archive URL and SHA-256; a named, recorded release can be rebuilt with `bun run build -- --release "<sourceRelease>"`.
- Current bundle has 3,199 foods, including nutrition-relevant preparation variants. 428 foods use the explicit `100 g` fallback because no eligible gram-backed household portion is available. The 12 original generic entries retain their exact shipped serving descriptions, gram sizes, and per-serving nutrients; future releases must preserve those fields because saved meal components store serving counts. The October 2024 named release now includes 112 curated query mappings (97 unique target foods), with exact targets validated during generation and priorities emitted in the manifest.
- Current iPhone 17 Pro / iOS 26.4 measurements on this 3,199-food bundle: five clean-install bootstrap-ready launches had 0.5896 s median; five second launches had 0.1140 s median. These measure `AppLaunchState.start()` through bootstrap readiness, not process-to-first-pixel.
- Local search-update completion medians across five runs were 0.0296 s for `chicken`, 0.0264 s for `rice`, and 0.0169 s for `apple`. They measure update-function completion through result assignment, not full keypress-to-render latency. Temporary instrumentation was removed after collection.
- The final in-app 50-query sweep and result capture are under ignored `build/ws4-qa-2026-10-25/final-build/`. All 50 first results passed the qualitative first-result sanity audit; the seven previous misses now rank the curated plain/common entries first. Top-three names and kcal per serving are recorded. Aliases cover household synonyms and the curated staple queries. See the QA report for the rubric and full results.
- Local search uses consistent case/diacritic folding and punctuation tokenization, plural-insensitive phrase matching, deterministic match tiers, and stable alphabetical/UUID tie-breaking. Regression coverage includes required everyday plain-food queries, alias ranking, apostrophe, hyphen, and diacritic queries.

## Core Decisions

### Source and pipeline

- Source: USDA FoodData Central FNDDS (public domain). Download the latest FNDDS CSV release from `https://fdc.nal.usda.gov/download-datasets` (verify the exact URL at run time and record it with the release date). Fall back to SR Legacy only if FNDDS is unavailable.
- Pipeline in `tools/food-db/` (Bun + TypeScript, isolated `package.json`, no root package): `bun run build` downloads to a cache dir ignored by git, parses `food.csv`, `food_nutrient.csv`, `food_portion.csv`, `nutrient.csv`, and the WWEIA category file, and writes `cal-macro-tracker/CommonFoods/common_foods.json` plus `common_foods_manifest.json` (`version`, `source`, `sourceRelease`, `count`, `generatedAt`).
- Nutrient mapping by FDC nutrient id: 1008 energy kcal, 1003 protein, 1004 total fat, 1005 carbohydrate, 1258 saturated fat, 1079 fiber, 2000 total sugars, 1235 added sugars (null when absent), 1093 sodium (mg), 1253 cholesterol (mg). Missing values stay `null`; never fabricate.
- Serving: prefer a household portion with a gram weight (`1 cup`, `1 medium`, `1 slice`, `1 piece`, `1 oz`), else `100 g`. Store `servingDescription` and `gramsPerServing`; nutrients are per that serving.
- Once a bundled food is shipped, its serving size and per-serving nutrients are immutable; subsequent dataset releases must preserve them for legacy foods because saved meals store serving counts and recompute from the current food record.
- Selection: exclude infant formulas and baby foods, alcohol mixers with no nutrition, and entries whose names contain `NFS`/`NS as to` duplicates of a more specific entry. Prefer one representative per base food (for example one "Chicken breast, grilled" rather than ten cooking variants). Target 2,500 to 3,500 foods; JSON under 2 MB.
- Names: friendly, Title Case, source descriptors trimmed; keep the original FNDDS description in `aliases` so token search still matches it. Keep the 12 existing names unchanged so reconcile updates them in place.
- Determinism: stable ordering, stable ids by FDC id in aliases if needed; running the pipeline twice yields an identical file.

### App side

- Add `AppStorageKeys.commonFoodSeedVersion`; `AppBootstrap` runs `reconcile` only when the manifest version differs from the stored one (first launch or an updated bundle), then stores it. The repair path (`repairIfNeeded`) is unchanged.
- First-launch insert of ~3k `FoodItem` rows must not block the launch screen longer than necessary: perform decode off main (already `Task.detached`) and insert in one `PersistenceReporter.persist` transaction; measure and record cold-launch time before and after.
- Search UX in `AddFoodSearchResults.swift`: when the trimmed query has 3+ characters and local matches are fewer than 5, show a prominent "Search online for “<query>”" row at the top of the results that calls the existing `onSearchOnline`. Keep the existing bottom "Search Online" button behavior for the empty state.
- Verify local search stays responsive with 3k foods (the `@Query`/fetch path that feeds `rankedFoods`); if a full fetch per keystroke is too slow, add a `searchableText` `contains` predicate pre-filter before ranking.

## Proposed File Shape

- `tools/food-db/package.json`, `tsconfig.json`, `src/build.ts`, `src/fndds.ts`, `src/select.ts`, `src/names.ts`, `src/schema.ts`, `tests/*.test.ts`, `README.md`.
- `cal-macro-tracker/CommonFoods/common_foods.json` (regenerated), `common_foods_manifest.json` (new, added to the app target resources in `project.pbxproj`).
- `Data/Services/CommonFoodSeedLoader.swift` (manifest decode), `Data/Services/AppBootstrap.swift` (version gate), `App/AppStorageKeys.swift`, `Features/AddFood/AddFoodSearchResults.swift`.
- `.oxlintrc.json` only if the new package must be included in `make lint-js` coverage (follow the existing include pattern).

## Milestones and Tasks

1. Failure list and pipeline tests first: missing nutrient rows, portions without gram weight, duplicate names, non-UTF8 descriptions, zero-calorie foods, unit conversions.
2. Pipeline, generation, manual review of the top 300 names.
3. App seed versioning and launch-time measurement.
4. Search row and responsiveness check.
5. Validation: `bun run check`/`bun test` in `tools/food-db`, `make lint-js`, `make quality-format-check`, `make quality-build`, `make quality-n1`, targeted tests (`LocalConfidenceTests`, `LogEntryQueryTests`); E2E QA in `build/ws4-qa-<date>/QA.md`: cold launch timing, then 50 everyday queries (chicken, rice, egg, oatmeal, banana, pizza, burger, salad, coffee, milk, bread, pasta, beef, salmon, yogurt, cheese, potato, beans, tortilla, peanut butter, and 30 more) with the top three results and a sanity check of calories per serving. Changes-log entry with the dataset version and license note.

## Edge Cases

- Users who renamed or edited a common food: reconcile matches by name, so an edited name becomes a custom-looking orphan; leave it alone (existing behavior).
- Widgets read the shared store; nothing changes for them.
- Do not touch Worker search contracts.
