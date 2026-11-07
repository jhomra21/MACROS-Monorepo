# USDA v1 nutrition basis

FDC Branded `foodNutrients` are per 100 g (per 100 ml for volume servings; see round 3). The v1 contract returned them as `*PerServing` beside the label serving, so build 23 (which searches USDA through `/v1/packaged-foods/search`) showed values 2–5× too high. v2 (`/v2/foods/search`) already scaled them.

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

`makeProxyFoodResult` (v1 search, packaged search, and details) now feeds the shared `usdaSourceFood` record through v2's `normalizeUSDAFood`, the single scaling function. Per-100 g values are scaled by grams/100 when the serving is in known grams. Otherwise the serving is "100 g", `gramsPerServing` is 100, and values stay unscaled. v1 keeps its response shape and field names, so build 23 still decodes it. Because v1 now reuses the whole normalizer, v1 values are rounded like v2 (kcal to whole numbers, others to 0.1). v1 names and brands also become display-cased like build 33, for example "NUTELLA FERRERO WITH BREADSTICKS" becomes "Nutella Ferrero with Breadsticks" and "GAD BAKERIES, LLC" becomes "Gad Bakeries". v1 still filters search results on the raw FDC name and brand, as v2 does. `gramsPerServing` accepts `g`, `grm`, `gram`, and `grams` case-insensitively from one `GRAM_UNITS` set used by both contracts. Round 3 replaces the "100 g" fallback for Branded records with a volume or unknown basis.

## Red/green

Source base: `origin/main` `f7f83f0`. Bun 1.4.2, Node runtime QA, Miniflare. Raw logs stayed local in `/tmp/usda-v1-basis-evidence/` and are not tracked; this README keeps the summaries.

| Check | Before fix | After fix |
| --- | --- | --- |
| `worker/usda-proxy` `bun test` | 88 pass, 6 fail | 94 pass |
| Runtime QA (`make qa-network`) | FAIL: v1 search returned `qa foods, inc.`, no grams, 359 / 12.82 / 6.41 / 74.36 | PASS, 130 HTTP requests, 60 assertion groups |
| Convex integration (`make qa-network`) | not reached | 76 pass |
| `bun run check`, `make lint-js`, `git diff --check` | — | pass |

Fixtures are FDC Branded shaped (`GRM` unit, per-100 g `foodNutrients`). Results are the per-100 g values scaled to the serving size, not FDC `labelNutrients`; the fixtures are chosen so the scaled values equal the printed label values, and the tests compare against those. The runtime suite also checks that a USDA food from `/v2/foods/search` produces the same repair key as `/v1/usda/foods/:fdcId` (name, brand, serving, grams, and macros, compared the way the app compares them).

## Live before/after (local `wrangler dev`, `DEMO_KEY`)

`origin/main` and the fix each ran on loopback with separate cache state and a temporary `.dev.vars` (`DEMO_KEY` only), which was deleted after each run. Values are kcal / protein / fat / carbs / sodium mg.

| 2026852 Nutella with Breadsticks, 52 g ("1 CONTAINER") | Before | After | Label |
| --- | --- | --- | --- |
| `/v1/packaged-foods/search?provider=usda` | 519 / 7.69 / 26.9 / 65.4 / 250 | 270 / 4 / 14 / 34 / 130 | 270 / 4 / 14 / 34 / 130 |
| `/v1/usda/foods/2026852` | 519 / 7.69 / 26.92 / 65.38 / 250 | 270 / 4 / 14 / 34 / 130 | same |

In `/v2/foods/search?q=nutella breadsticks`, 2026852 is merged into the Open Food Facts record that has the same GTIN. The five Open Food Facts items and the cursor were identical before and after. The only USDA item, 2560070 ("1 Unit (52g)", unit `GRM` in search records), changed from "100 g" 500 / 7.7 / 25 / 65.4 to 52 g 260 / 4 / 13 / 34. After the fix, its v1 and v2 repair keys match. Before the fix they did not.

### v2 `GRM` effect

An offline replay compared `origin/main` and the fix through `usdaSourceFood` → `normalizeUSDAFood` over 40 synthetic unit and size combinations plus the three live records. 39 outputs were byte-identical. The 4 that changed were all `GRM` records:

| fdcId | Before (v2) | After (v2) | FDC `labelNutrients` (comparison only) |
| --- | --- | --- | --- |
| 2655431 Oreo cheesecake, 136 GRM | 100 g: 368 kcal, 23.5 fat, 33.1 carbs | 1/5 cake (136 g): 500, 7 protein, 32 fat, 45 carbs, 399.8 mg Na | 500, 7, 32, 45, 400 mg |
| 2517161 Cheerios, 20 GRM | 100 g: 359 kcal | 3/4 cup (20 g): 72, 2.6, 1.3, 14.9, 97.4 mg Na | 71.8, 2.56, 1.28, 14.9, 97.4 mg |
| 2026852 Nutella, 52 g | unchanged (details record uses `g`) | — | 270, 4, 14, 34 |

## Repair effect

The app's `SecondaryNutrientRepairKey` compares source, trimmed lowercase name, brand, and serving, plus exact `gramsPerServing` and the four macros. Repair builds the refreshed draft from `/v1/usda/foods/:fdcId` (`USDAFoodDraftMapper`).

- **USDA foods saved from v2.** Before this fix, fresh v1 details matched only when they happened to agree with v2: a "100 g" serving with `gramsPerServing` 100, macros that v2's rounding left unchanged (for example integral values), and a brand that display casing did not alter. Other v2 foods did not match. v1 details now use the same basis, rounding, and display text as v2, so a v2-saved food matches when FDC data has not changed since it was saved.
- **Missing household text.** When a record has no `householdServingFullText`, the serving text comes from the size and unit. Round 1 kept the upstream spelling, so a v2 search record with `GRM` ("52 GRM") and v1 details with `g` ("52 g") disagreed. Round 2 renders every gram spelling as "<size> g". v2 foods saved before round 2 with "… GRM" text can still mismatch.
- **Warm caches.** Until round 2, the v1 and v2 USDA caches could keep serving pre-fix values for up to 24 h after a deploy, so a fresh v1 detail could disagree with a v2 page. The versioned keys below stop this.
- **Foods saved by older builds through v1.** These hold per-100 g values with the raw serving text. They still match when the new v1 details produce the same fields, for example a 100 g gram serving whose values already survive the new rounding and whose name and brand are unchanged by display casing. Otherwise repair marks them not repairable and does not change them. The owner accepted this.

## Edge cache

v1 responses are stored in the colo-local Cache API for 24 h (`CACHE_TTL_SECONDS` in `index.ts`), and v2 stores normalized USDA source pages for 24 h. A deploy clears neither. Round 2 versions only the USDA keys:

| Cache | Before | After |
| --- | --- | --- |
| Packaged search `usda` (pinned and default fallback) | `/v1/packaged-foods/search/usda?q=protein+bar&page=1&pageSize=10` | `…&pageSize=10&usdaBasis=2` |
| `/v1/usda/search` | `/v1/usda/search?q=protein+bar&page=1&pageSize=10` | `…&pageSize=10&usdaBasis=2` |
| `/v1/usda/foods/:fdcId` | `/v1/usda/foods/2026852` | `/v1/usda/foods/2026852?usdaBasis=2` |
| v2 USDA source page | `[3,"usda","chicken breast","1"]` | `[4,"usda","chicken breast","1"]` |
| Packaged search `openFoodFacts`, `openFoodFacts/pinned`, `default`, restaurant retry | unchanged | unchanged (asserted byte for byte) |
| v2 Open Food Facts source page | `[3,"openFoodFacts",…]` | unchanged |
| Barcode | `/v1/packaged-foods/barcodes/<code>` | unchanged |

The packaged-search `default` key stores only Open Food Facts responses (USDA fallbacks go to the `usda` key), so it keeps its warm entries.
## Round 2 failure modes (written before the round 2 fix)

11. **Unit spelling in fallback serving text.** With no `householdServingFullText`, the serving text keeps the upstream unit: v2 search records (`GRM`) give "52 GRM" while v1 details (`g`) give "52 g". The repair key compares serving text exactly (lowercased), so repair fails or marks the food not repairable. Every gram spelling must render as "<size> g" in the shared path. Volume and other units keep their spelling (they become "100 g" anyway).
12. **Household text still wins.** The gram rendering must only apply when household text is missing; "1 bar" stays "1 bar".
13. **Copied fixtures hide drift.** A parity test that reuses one record for search and details cannot catch a difference between the endpoints. The search and details fixtures must differ in unit spelling and be built independently.
14. **Warm v1 caches serve pre-fix numbers.** `/v1/packaged-foods/search` with the `usda` key (pinned or default fallback), `/v1/usda/search`, and `/v1/usda/foods/:fdcId` serve the colo cache for 24 h, so old per-100 g values outlive the deploy. Each USDA key needs a basis version item.
15. **Warm v2 USDA source pages.** `/v2/foods/search` caches normalized USDA pages for 24 h. An old `GRM` page can return a "100 g" food while fresh v1 details return the label serving, so repair keys disagree. The USDA source-page key needs a version.
16. **Collateral cache flush.** Open Food Facts search (`openFoodFacts`, `openFoodFactsPinned`), the packaged-search `default` key (it stores only Open Food Facts responses), barcode keys, and the v2 Open Food Facts source-page key must stay byte-identical, or a deploy needlessly flushes them and spends upstream budget.
17. **Version collision.** The new USDA keys must differ from the old ones, or the old entries are still read.

## Round 2 fix

- `makeServingDescription` in `usda.ts` (shared by v1 and v2) renders any `GRAM_UNITS` spelling as "<size> g" when household text is missing. Household text and non-gram units keep their spelling.
- `packagedFoodSearchCache.ts` adds `usdaBasis=2` to the packaged-search `usda` key and builds both `/v1/usda` keys (`usdaSearchCacheKey`, `usdaFoodCacheKey`), which `index.ts` now uses. `unifiedFoods.ts` writes USDA source pages under version 4 and every other source under version 3.

## Round 2 red/green

Base: rebased onto `origin/main` `c84b848`. Raw logs are local in `/tmp/usda-v1-basis-evidence/round2/`, not tracked.

| Check | Before fix | After fix |
| --- | --- | --- |
| `worker/usda-proxy` `bun test` | 95 pass, 3 fail: search gave "52 GRM" vs details "52 g"; packaged `usda` key lacked `usdaBasis=2` (the Open Food Facts and `default` assertions before it passed); v2 wrote `[3,"usda",…]` | 98 pass |
| Runtime QA (`make qa-network`) | — | PASS, 130 HTTP requests, 60 assertion groups |
| Convex integration (`make qa-network`) | — | 76 pass |
| `bun run check`, `make lint-js`, `git diff --check` | — | pass |

The parity test builds the search record (`GRM`, `nutrientId`/`value`) and the details record (`g`, 52.0, `amount`/`nutrient.id`) separately, both without household text, and requires v1 search, v1 details, and v2 to give the same repair key fields, "52 g", and the label values 270 / 4 / 14 / 34.

## Round 2 live check (local `wrangler dev`, `DEMO_KEY`)

`DEMO_KEY` allows 10 requests per rolling hour per IP. Each probe ran once, with no retries. A temporary `.dev.vars` (`DEMO_KEY` only) was written for each run and deleted afterward. "Before" is round 1 (`d817c9f`); "after" is round 2. Values are serving / grams / kcal / protein / fat / carbs / sodium mg.

| Probe | Before (live) | After (live) |
| --- | --- | --- |
| `/v1/packaged-foods/search?q=nutella breadsticks&provider=usda`, 2026852 | "1 CONTAINER" / 52 / 270 / 4 / 14 / 34 / 130 | 503, quota spent |
| `/v1/usda/foods/2026852` | same as above | 503, quota spent |
| `/v2/foods/search?q=nutella breadsticks`, USDA 2560070 | "1 Unit (52g)" / 52 / 260 / 4 / 13 / 34 / 130 | 200, USDA skipped (quota) |
| `/v1/packaged-foods/search?q=kind chewy granola bars&provider=usda`, 2577959 (`GRM`, empty household text) | "23 GRM" / 23 / 100 / 1 / 3.5 / 16 / 65.1 | 503, quota spent |
| `/v1/usda/foods/2577959` | 503, quota spent | 503, quota spent |
| `/v2/foods/search?q=kind chewy granola bars` | 200, USDA skipped (quota) | 200, USDA skipped (quota) |

Because the quota ran out, the FDC JSON captured live (`/fdc/v1/food/2026852`, `/fdc/v1/food/2577959`, and a Branded search page containing 2577959) was replayed through each build's real `searchUSDAFoods`, `fetchUSDAFood`, and `usdaSourceFood` → `normalizeUSDAFood`:

| Replay of live FDC JSON | Round 1 | Round 2 | Label |
| --- | --- | --- | --- |
| 2026852 v1 details | "1 CONTAINER" / 52 / 270 / 4 / 14 / 34 / 130 | same | 270 / 4 / 14 / 34 / 130 |
| 2577959 v1 search | "23 GRM" / 23 / 100 / 1 / 3.5 / 16 / 65.1 | "23 g", values unchanged | 100 / 1 / 3.5 / 16 / 65.1 |
| 2577959 v1 details | "23 GRM", values as above | "23 g", values unchanged | same |
| 2577959 v2 search | "23 GRM", values as above | "23 g", values unchanged | same |

In 2577959, both endpoints report `GRM`, so round 1 already matched across endpoints. Round 2 changes only the text, which future records with different spellings need (the parity test covers that). Saved v2 foods with "23 GRM" text will not match the new "23 g" details.

## Round 3 failure modes (written before the round 3 fix)

FDC Branded `foodNutrients` are per 100 g or per 100 ml, depending on `servingSizeUnit`. Foundation, SR Legacy, and Survey (FNDDS) values are per 100 g. Rounds 1 and 2 treated every record as per 100 g.

18. **Volume servings get invented grams.** A Branded `MLT` or `ml` record falls back to "100 g" with `gramsPerServing` 100 and unscaled per-100 ml values. Build 23 allows gram logging whenever `gramsPerServing` > 0, so beverages and oils become loggable by grams at an assumed density of 1. Volume units (`ml`, `mlt`, `milliliter`, `milliliters`, any case) with a positive, finite size must scale the per-100 ml values by size/100, as grams do. They keep household text, or "<size> ml" when it is missing, and must not set `gramsPerServing`.
19. **Unknown basis claims grams.** A Branded record with a missing or unrecognized unit, or a missing, zero, negative, or non-finite size, may be per 100 g or per 100 ml. It must keep the unscaled per-100 values, use the serving "100 g or ml", and leave `gramsPerServing` unset. Household text must not be used, because the values are not per that serving.
20. **Non-branded records lose their gram basis.** Foundation, SR Legacy, and Survey (FNDDS) records, which `/v1/usda/foods/:fdcId` can return, must keep "100 g" with `gramsPerServing` 100. A record without `dataType` counts as Branded: search only requests Branded foods, and that choice never claims grams.
21. **Endpoint drift for volume.** v1 search, v1 details, and v2 must give the same serving, grams, and values for a volume record. The parity test builds the search record (`MLT`) and the details record (`ml`) separately and expects values computed by hand from the per-100 ml inputs.
22. **Gram regression.** Gram records (every `GRAM_UNITS` spelling) must keep their round 2 serving, grams, and values exactly.
23. **App decoding.** Leaving `gramsPerServing` out must still decode in build 23 (`USDAProxyFood.gramsPerServing: Double?`) and in v2 (`RemoteSearchResult.gramsPerServing: Double?`). The app treats serving text as free text and only requires it to be non-empty, so "100 g or ml" and "240 ml" decode and log by servings.
24. **Docs overstate label values.** Docs and the changes log say v1 now shows label values. The values are per-100 values scaled to the serving size, so they can differ from FDC `labelNutrients` by rounding (2655431: 399.8 mg sodium against a printed 400 mg).
25. **Stale caches.** Volume and unknown-basis records change in v1 and v2. `origin/main` writes v2 USDA pages under version 3 and has no `usdaBasis` item, so this branch's version 4 and `usdaBasis=2` keys have never been written by a deployed build. No further bump is needed as long as the branch stays undeployed until this fix lands.

## Round 3 fix

- `servingBasis` in `usda.ts` now owns the FDC basis for v1 search, v1 details, and v2. `usdaSourceFood` scales the per-100 values by size/100 for a gram or volume serving with a positive, finite size. Only gram servings set `gramsPerServing`. Volume servings keep household text, or "<size> ml" (every `VOLUME_UNITS` spelling renders as `ml`).
- With a Branded record whose unit is missing or unrecognized, or whose size is missing or not positive, the values stay unscaled on a "100 g or ml" serving with no `gramsPerServing`. A missing `dataType` counts as Branded.
- Non-branded records keep round 2 behavior: "100 g" with `gramsPerServing` 100, or a scaled gram serving if one were present (FDC gives these records none). A volume unit on them is ignored, since their values are per 100 g.
- `normalizeUSDAFood` no longer rescales or replaces the serving. It only rounds and display-cases, so the "100 g" fallback that invented grams is gone. Both `dataType` fields are now decoded.
- "100 g or ml" was chosen because both app decoders (`USDAProxyFood` for v1, `RemoteSearchResult` for v2) take any non-empty serving text and an optional `gramsPerServing`. The user logs such a food by servings of 100 g or ml. The text does not pick a unit the record does not state.
- Cache keys: `origin/main` `f0636fc` still writes v2 USDA pages under version 3 and has no `usdaBasis` item, so this branch's version 4 and `usdaBasis=2` keys are new to any deploy. No further bump.

## Round 3 behavior

The same shared path serves v1 search, v1 details, and v2, so the three agree in every row. Tests assert this for gram, volume, and unknown-basis records. Non-branded records reach only v1 details, because both searches request Branded foods.

| Record | Before (round 2) | After (round 3) |
| --- | --- | --- |
| Branded `g` / `GRM`, size 52 | household or "52 g", grams 52, values × 0.52 | unchanged |
| Branded `ml` / `MLT`, size 240 | "100 g", grams 100, unscaled | household or "240 ml", no grams, values × 2.4 |
| Branded, unit missing or unknown (`IU`), or size missing, 0, or negative | "100 g", grams 100, unscaled | "100 g or ml", no grams, unscaled |
| Foundation, SR Legacy, Survey (FNDDS), no serving | "100 g", grams 100, unscaled | unchanged |

An offline replay of round 2 and round 3 compared v1 details, v1 search, and v2 output over 540 combinations of `dataType` (Branded, missing, Foundation), 15 unit spellings, 6 sizes, and household text present or missing. 252 were byte-identical: every gram record with a positive size, and every Foundation record. All 288 that changed were Branded or missing-type records with a volume unit, an unknown or missing unit, or a gram unit without a positive size.

## Round 3 red/green

Base: rebased onto `origin/main` `f0636fc`; the only conflict was the changes-log heading order. Raw logs and the replay script are local in `/tmp/usda-v1-basis-evidence/round3/`, not tracked.

| Check | Before fix | After fix |
| --- | --- | --- |
| `worker/usda-proxy` `bun test` | 96 pass, 5 fail: `MLT` details gave "100 g" / 100 / 42 kcal instead of "240 ml" / none / 101; search, details, and v2 gave the same wrong key; the unknown basis claimed 100 g; "240 MLT" text; the direct normalizer test | 101 pass |
| Runtime QA (`make qa-network`) | — | PASS, 130 HTTP requests, 60 assertion groups |
| Convex integration (`make qa-network`) | — | 76 pass |
| `bun run check`, `make lint-js`, `git diff --check` | — | pass |

The volume parity test builds the search record (`MLT`, `nutrientId`/`value`) and the details record (`ml`, 240.0, `amount`/`nutrient.id`) separately. It expects values worked out by hand from the per-100 ml inputs: 42 kcal × 2.4 = 100.8 → 101, 10.6 g carbs × 2.4 = 25.44 → 25.4, 4 mg sodium × 2.4 = 9.6. After the red run, the non-branded test gained a 240 `MLT` variant as a regression guard; it passes on both versions. No live `DEMO_KEY` probe was run in round 3.
