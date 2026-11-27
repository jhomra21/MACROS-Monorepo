# Restaurant menu source: wiring fix, coverage, and local verification

Date: 2026-11-27. Local `wrangler dev` on the default port 8787; nothing deployed.

## Wiring bug: root cause

The source was registered and returned the bundled item when called directly. With the unchanged code,
a clean `wrangler dev` returned the bundled Chick-fil-A item first. The earlier "only Open Food Facts"
output came from two causes in the environment and in the source cache, not from the registry, the
merge, or the cursor:

1. Stale `wrangler dev` processes from the first attempt (wrangler -> workerd) still held port 8787 for this
   worktree and kept answering with an older bundle. Curl to that port hung. This is the best-supported
   explanation, not fully proven: I did not capture the old bundle's output. Those processes were stopped by PID (never `pkill -f`).
2. `loadSource` cached every source page in the colo cache (empty pages for 300 s, others for 3600 s) under a
   key that has no data version. Any page cached before a data or matcher change is served unchanged. The bundled
   source is an in-memory lookup, so a cache can only hide edits. A query run after a matcher fix kept returning
   an empty cached page until it expired (observed: "mcdonald nuggets" returned 0 through the Worker while
   the source returned 5 when called directly).

Fix: `FoodSource.cacheable === false` makes `loadSource` skip the page cache for that source, and the
bundled source sets it. Other sources keep their cache keys (USDA v4, others v3).

Also fixed: `mergeFoodResults` re-sorted bundled items by id, which undid the source's closeness order
(for example "Bacon & Cheese Whopper" ahead of "Whopper"). It now keeps the source order when the other keys tie.
A query that names a chain puts that chain's bundled items first. A chain-less match ("big mac") wins ties
against Open Food Facts but never beats an exact-name packaged result ("greek yogurt").

## Matching

Queries are folded to compact keys, so these all find Chick-fil-A: "chick-fil-a", "chick fil a", "chickfila",
"chikfila". These find McDonald's: "mcdonalds", "mcdonald's", "mc donalds", "mcdonald". Singular/plural
fold on both sides ("sandwiches"/"sandwich", "fries"/"fry", "nuggets"/"nugget", "McNuggets"/"nugget").
Word order does not matter (all item words must match). A chain-less query needs at least two item words,
so "banana", "cheerios" and other single generic words never match menu rows. Chipotle and Five Guys rows are
components; "chipotle chicken burrito bowl" returns the chicken match first, then every Chipotle component,
and never a made-up bowl total.

## Coverage (items per chain, official US data, retrievedAt 2026-11-27)

| Chain | Items | Official source |
|---|---:|---|
| Chick-fil-A | 250 | chick-fil-a.com/nutrition-allergens (the page's own embedded nutrition table): entrees, nuggets, sandwiches, sides, salads, breakfast, kids, treats, drinks, coffee, sauces, dressings |
| McDonald's | 82 | mcdonalds.com product pages (each item's own nutrition panel) |
| Chipotle | 86 | chipotle.com nutrition PDF: per-ingredient rows plus kids portions and drinks; no bowl totals |
| Starbucks | 30 | starbucks.com product nutrition pages: 17 drinks (grande where the page offers it; Flat White is listed at tall) and 13 food items |
| Taco Bell | 148 | tacobell.com/nutrition/info |
| Panda Express | 130 | pandaexpress.com/nutritioninformation |
| Raising Cane's | 58 | raisingcanes.com/allergens (August 2026 PDF embedded in the page) |
| Popeyes | 69 | popeyes.com nutrition guide PDF (plk-use1-prod.sites.rbictg.com) |
| Burger King | 78 | bk-use1-prod.sites.rbictg.com nutrition PDF; **the PDF is dated November 2022**, the newest one reachable |
| Five Guys | 79 | fiveguys.com US Nutrition & Allergen Guide (September 2026); ingredient rows, no built-burger totals |
| Domino's | 75 | cache.dominos.com Nutrition Guide (March 2025): specialty pizzas (hand tossed, 4 sizes), breads, chicken, sandwiches, desserts |
| Dunkin' | 932 | dunkindonuts.com nutrition guide PDF (updated 10-28-2026) |
| Panera Bread | 363 | panerabread.com nutrition guide PDF (effective 11/4/2026) |
| **Total** | **2,382** | |

Per-record fields: name, serving, grams only when the chain prints them, calories, protein, carbs, fat, plus
saturated fat, fiber, sugars, sodium and cholesterol when printed. A value the chain prints as "<1" or leaves blank is
stored as missing and listed in `requiredReviewNutrients`; it is never estimated. Every record carries `sourceURL`
(item page when the chain has one) and `retrievedAt`.

## Chains skipped

- **Wendy's**: the only Wendy's nutrition documents reachable are UK PDFs (kcal, salt). The US nutrition lives in the
  order.wendys.com app, whose pages give calories but no macros without a browser session.
- **Subway**: the official US nutrition PDF link works in a browser, but media.subway.com never completes a download from this
  machine (TLS connects, then every read times out across curl, HTTP/1.1 and Python), and the web page has no table.

## Local run

`bun run dev` on 8787 with a git-ignored `.dev.vars` (placeholder USDA key, test Open Food Facts agent). USDA is
rate limited with the placeholder key (`X-MACROS-Skipped-Sources: usda`), and Open Food Facts calls were spaced
about 2 s apart to stay inside its local budget. Raw output is in this directory (ignored by git).

Headline proof, `GET /v2/foods/search?q=chick-fil-a grilled chicken sandwich`, first result:

```json
{"source":"restaurantMenus","name":"Grilled Chicken Sandwich","brand":"Chick-fil-A","servingDescription":"1 serving (206 g)",
 "nutrition":{"calories":390,"protein":28,"carbs":45,"fat":11,"saturatedFat":2.5,"fiber":3,"sugars":11,"sodium":765,"cholesterol":75},
 "sourceURL":"https://www.chick-fil-a.com/menu/entrees/grilled-chicken-sandwich","retrievedAt":"2026-11-27"}
```

Paging: `chick fil a nuggets` page 1 returns 31 items with a cursor; page 2 returns 2 further Open Food Facts items
with no repeats from page 1.

## Query transcript (top 3 per query, all HTTP 200)

| Query | Top 3 | HTTP |
|---|---|---:|
| chick-fil-a grilled chicken sandwich | Grilled Chicken Sandwich [restaurantMenus] 390 cal<br>Chick-fil-A Grilled Chicken Club Sandwich [restaurantMenus] 520 cal<br>Chick-Fil-A, Grilled Chicken Sandwich [openFoodFacts] 314 cal | 200 |
| chikfila grilled sandwich | Grilled Chicken Sandwich [restaurantMenus] 390 cal<br>Chick-fil-A Grilled Chicken Club Sandwich [restaurantMenus] 520 cal | 200 |
| chick fil a nuggets | Chick-fil-A Nuggets [restaurantMenus] 250 cal<br>8 ct Chick-fil-A Nuggets [restaurantMenus] 250 cal<br>12 ct Chick-fil-A Nuggets [restaurantMenus] 380 cal | 200 |
| chickfila spicy chicken sandwich | Spicy Chicken Sandwich [restaurantMenus] 450 cal | 200 |
| big mac | Big Mac [restaurantMenus] 580 cal<br>Big Mac [openFoodFacts] 242 cal<br>Big mac [openFoodFacts]  cal | 200 |
| mcdonalds big mac | Big Mac [restaurantMenus] 580 cal<br>Big Mac™ Bacon [openFoodFacts] 240 cal<br>Le Big Mac™ [openFoodFacts] 231 cal | 200 |
| mcdonald's quarter pounder | Quarter Pounder with Cheese [restaurantMenus] 520 cal<br>Double Quarter Pounder with Cheese [restaurantMenus] 740 cal<br>Bacon Quarter Pounder with Cheese [restaurantMenus] 630 cal | 200 |
| mc donalds fries | Small World Famous Fries [restaurantMenus] 230 cal<br>Large World Famous Fries [restaurantMenus] 480 cal<br>Medium World Famous Fries [restaurantMenus] 320 cal | 200 |
| chipotle chicken burrito bowl | Chicken [restaurantMenus] 180 cal<br>Kid's Menu Chicken [restaurantMenus] 90 cal<br>Flour Tortilla (burrito) [restaurantMenus] 320 cal | 200 |
| chipotle white rice | Cilantro-Lime White Rice [restaurantMenus] 210 cal<br>Kid's Menu Cilantro-Lime White Rice [restaurantMenus] 100 cal<br>Chipotle White Rice [openFoodFacts] 430 cal | 200 |
| starbucks egg bites | Bacon & Gruyère Egg Bites [restaurantMenus] 300 cal<br>Egg White & Roasted Red Pepper Egg Bites [restaurantMenus] 170 cal<br>STARBUCKS Egg Bites with Three Cheese & Ham Free-r [openFoodFacts] 177 cal | 200 |
| starbucks grande latte | Caffè Latte [restaurantMenus] 190 cal<br>Chai Latte [restaurantMenus] 200 cal<br>Matcha Latte [restaurantMenus] 220 cal | 200 |
| taco bell crunchwrap | Crunchwrap Supreme [restaurantMenus] 530 cal<br>Crunchwrap Dipper [restaurantMenus] 270 cal<br>Breakfast Crunchwrap - Bacon [restaurantMenus] 660 cal | 200 |
| panda express orange chicken | The Original Orange Chicken (4 oz) [restaurantMenus] 360 cal<br>The Original Orange Chicken (6.2 oz) [restaurantMenus] 560 cal<br>Original Orange Chicken [openFoodFacts] 490 cal | 200 |
| wendys baconator | Baconator [openFoodFacts] 931 cal<br>Pringles baconator wendy's [openFoodFacts] 536 cal | 200 |
| burger king whopper | Whopper Sandwich [restaurantMenus] 670 cal<br>Whopper Sandwich With Cheese [restaurantMenus] 760 cal<br>Double Whopper Sandwich [restaurantMenus] 920 cal | 200 |
| subway turkey sub | (no results) | 200 |
| popeyes chicken sandwich | Chicken Sandwich-Classic [restaurantMenus] 700 cal<br>Chicken Sandwich-Spicy [restaurantMenus] 700 cal | 200 |
| raising canes chicken fingers | Chicken Finger [restaurantMenus] 130 cal | 200 |
| five guys cheeseburger | Bacon (2 pieces) (Supplier S) [restaurantMenus] 70 cal<br>Bacon (2 pieces) (Supplier D) [restaurantMenus] 73 cal<br>Bacon (1 piece) (Supplier D) [restaurantMenus] 36 cal | 200 |
| five guys fries | Little Cajun Style Fries [restaurantMenus] 540 cal<br>Regular Cajun Style Fries [restaurantMenus] 967 cal<br>Large Cajun Style Fries [restaurantMenus] 1328 cal | 200 |
| dunkin glazed donut | Glazed Donut [restaurantMenus] 240 cal<br>Glazed Blueberry Donut [restaurantMenus] 350 cal<br>Glazed Chocolate Donut [restaurantMenus] 370 cal | 200 |
| dominos pepperoni pizza | Ultimate Pepperoni Pizza (Hand Tossed, Small) [restaurantMenus] 380 cal<br>Ultimate Pepperoni Pizza (Hand Tossed, Medium) [restaurantMenus] 420 cal<br>Ultimate Pepperoni Pizza (Hand Tossed, Large) [restaurantMenus] 360 cal | 200 |
| panera bagel | Blueberry Bagel [restaurantMenus] 290 cal<br>Everything Bagel [restaurantMenus] 300 cal<br>Plain Bagel [restaurantMenus] 280 cal | 200 |
| greek yogurt | Greek Yogurt [openFoodFacts]  cal<br>Greek Yogurt with Berries [restaurantMenus] 250 cal<br>Greek Yogurt Coconut Blended [openFoodFacts]  cal | 200 |
| banana | Banana [openFoodFacts]  cal<br>Bananas [openFoodFacts] 200 cal<br>Banana Chiquita classe extra [openFoodFacts]  cal | 200 |
| cheerios | Cheerios [openFoodFacts] 359 cal<br>Cheerios [openFoodFacts]  cal<br>Cheerios [openFoodFacts]  cal | 200 |
