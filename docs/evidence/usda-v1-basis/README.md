# USDA v1 nutrition basis

FDC Branded `foodNutrients` are per 100 g. The v1 contract returned them as `*PerServing` beside the label serving, so build 23 (which searches USDA through `/v1/packaged-foods/search`) showed values 2–5× too high. v2 (`/v2/foods/search`) already scaled them.

## Failure modes (written before the fix)

1. **v1 per-100 g passthrough.** `/v1/packaged-foods/search?provider=usda`, the default search's USDA fallback, `/v1/usda/search`, and `/v1/usda/foods/:fdcId` label per-100 g values as per serving next to a household serving. Example: 2026852 serving 52 g reports 519 kcal instead of 270.
2. **Secondary nutrients left unscaled.** Saturated fat, fiber, sugars, added sugars, sodium, and cholesterol must use the same basis as the main macros.
3. **`GRM` unit ignored.** Branded records mostly use `GRM`. Only `g`/`gram`/`grams` counted as grams, so most foods lost their label serving (v2 fell back to 100 g). Units must be matched case-insensitively.
4. **Invented grams.** Volume (`MLT`, `ml`) or other non-gram units, a missing unit, or a missing, zero, negative, or non-finite serving size must not scale. They fall back to a "100 g" serving with `gramsPerServing` 100 and the unscaled per-100 g values.
5. **Two code paths drift.** v1 and v2 must share one basis and scaling function. Rounding, serving text, and grams must agree, or the secondary-nutrient repair key (exact `Double` and normalized-text equality) will not match.
6. **v2 regression.** For non-`GRM` records, v2 output must stay byte-identical. The only intended v2 change is that `GRM` foods now get their label serving and scaled values.
7. **v1 completeness contract.** v1 still omits foods that lack any of calories, protein, fat, or carbs. v2 keeps them with review flags.
8. **Search filter drift.** v1 must still filter on the raw FDC name and brand, like v2, not on display-cased text.
9. **Stale edge cache.** v1 responses are cached in the colo-local Cache API for 24 h (`CACHE_TTL_SECONDS`), so old numbers can outlive a deploy.
10. **Older saved foods.** Foods saved from v1 by older builds hold per-100 g values. After the fix they no longer match fresh v1 details, so repair marks them not repairable instead of silently changing them. The owner accepted this.

## Fix

`makeProxyFoodResult` (v1 search, packaged search, and details) now feeds the shared `usdaSourceFood` record through v2's `normalizeUSDAFood`, the single scaling function. Per-100 g values are scaled by grams/100 when the serving is in known grams. Otherwise the serving is "100 g", `gramsPerServing` is 100, and values stay unscaled. v1 keeps its response shape and field names, so build 23 still decodes it. Because v1 now reuses the whole normalizer, v1 values are rounded like v2 (kcal to whole numbers, others to 0.1). v1 names and brands also become display-cased like build 33, for example "NUTELLA FERRERO WITH BREADSTICKS" becomes "Nutella Ferrero with Breadsticks" and "GAD BAKERIES, LLC" becomes "Gad Bakeries". v1 still filters search results on the raw FDC name and brand, as v2 does. `gramsPerServing` accepts `g`, `grm`, `gram`, and `grams` case-insensitively from one `GRAM_UNITS` set used by both contracts.

## Red/green

Source base: `origin/main` `f7f83f0`. Bun 1.4.2, Node runtime QA, Miniflare. Raw logs are in ignored `build/evidence/2026-11-07-usda-v1-basis/`.

| Check | Before fix | After fix |
| --- | --- | --- |
| `worker/usda-proxy` `bun test` | 88 pass, 6 fail | 94 pass |
| Runtime QA (`make qa-network`) | FAIL: v1 search returned `qa foods, inc.`, no grams, 359 / 12.82 / 6.41 / 74.36 | PASS, 130 HTTP requests, 60 assertion groups |
| Convex integration (`make qa-network`) | not reached | 76 pass |
| `bun run check`, `make lint-js`, `git diff --check` | — | pass |

Fixtures are FDC Branded shaped (`GRM` unit, per-100 g `foodNutrients`), and the tests compare results against the printed label values. The runtime suite also checks that a USDA food from `/v2/foods/search` produces the same repair key as `/v1/usda/foods/:fdcId` (name, brand, serving, grams, and macros, compared the way the app compares them).

## Live before/after (local `wrangler dev`, `DEMO_KEY`)

`origin/main` and the fix each ran on loopback with separate cache state and a temporary `.dev.vars` (`DEMO_KEY` only), which was deleted after each run. Values are kcal / protein / fat / carbs / sodium mg.

| 2026852 Nutella with Breadsticks, 52 g ("1 CONTAINER") | Before | After | Label |
| --- | --- | --- | --- |
| `/v1/packaged-foods/search?provider=usda` | 519 / 7.69 / 26.9 / 65.4 / 250 | 270 / 4 / 14 / 34 / 130 | 270 / 4 / 14 / 34 / 130 |
| `/v1/usda/foods/2026852` | 519 / 7.69 / 26.92 / 65.38 / 250 | 270 / 4 / 14 / 34 / 130 | same |

In `/v2/foods/search?q=nutella breadsticks`, 2026852 is merged into the Open Food Facts record that has the same GTIN. The five Open Food Facts items and the cursor were identical before and after. The only USDA item, 2560070 ("1 Unit (52g)", unit `GRM` in search records), changed from "100 g" 500 / 7.7 / 25 / 65.4 to 52 g 260 / 4 / 13 / 34. After the fix, its v1 and v2 repair keys match. Before the fix they did not.

### v2 `GRM` effect

An offline replay compared `origin/main` and the fix through `usdaSourceFood` → `normalizeUSDAFood` over 40 synthetic unit and size combinations plus the three live records. 39 outputs were byte-identical. The 4 that changed were all `GRM` records:

| fdcId | Before (v2) | After (v2) | labelNutrients |
| --- | --- | --- | --- |
| 2655431 Oreo cheesecake, 136 GRM | 100 g: 368 kcal, 23.5 fat, 33.1 carbs | 1/5 cake (136 g): 500, 7 protein, 32 fat, 45 carbs, 399.8 mg Na | 500, 7, 32, 45, 400 mg |
| 2517161 Cheerios, 20 GRM | 100 g: 359 kcal | 3/4 cup (20 g): 72, 2.6, 1.3, 14.9, 97.4 mg Na | 71.8, 2.56, 1.28, 14.9, 97.4 mg |
| 2026852 Nutella, 52 g | unchanged (details record uses `g`) | — | 270, 4, 14, 34 |

## Repair effect

The app's `SecondaryNutrientRepairKey` compares source, trimmed lowercase name, brand, and serving, plus exact `gramsPerServing` and the four macros. Repair builds the refreshed draft from `/v1/usda/foods/:fdcId` (`USDAFoodDraftMapper`). Before this fix, USDA foods saved from v2 never matched. Now v1 details carry the same basis, rounding, and display text, so they match. Foods saved by older builds through v1 hold per-100 g values and raw text, so they no longer match. Repair marks them not repairable and does not change them. The owner accepted this.

## Edge cache

v1 responses are stored in the colo-local Cache API for 24 h (`CACHE_TTL_SECONDS` in `index.ts`), and a deploy does not clear them. Clients get only `s-maxage`, which private caches ignore. Bumping one shared line in `buildCacheKey` would also flush the unrelated Open Food Facts search and barcode caches. A targeted bump needs three edits (the `usda`/`default` packaged-search keys and the two `/v1/usda` routes), so it was not implemented. Build 23 is not released yet. Deploying this at least 24 h before release lets old entries expire. If that is too slow, add a `basis` item to those three USDA cache keys.
