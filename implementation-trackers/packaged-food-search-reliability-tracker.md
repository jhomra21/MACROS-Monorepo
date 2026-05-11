# Packaged Food Search Reliability Implementation Tracker

Working tracker for improving packaged food search reliability across the Cloudflare Worker and Swift search flow. Update this file as implementation progresses with task status, bugs, quirks, findings, validation notes, and new decisions.

## Shared Understanding

- Goal: Make normal online packaged food search return useful data reliably and quickly while preserving source accuracy as much as practical.
- User priority: Users should get a response with food data for normal search; strict Open Food Facts-only behavior is less important than reliable results.
- Provider semantics:
  - Normal online search should use the Worker default/best-available path.
  - Explicit `provider=openFoodFacts` remains OFF-only, but can use both Search-a-licious and legacy Open Food Facts search.
  - Explicit `provider=usda` remains USDA-only.
- Restaurant/menu-like default searches should route to legacy Open Food Facts first because it returns useful restaurant/menu rows that Search-a-licious often misses or ranks poorly.
- Data quality: Do not invent missing nutrition values. Return available source fields and let the app/user fill gaps when data is incomplete.
- Scope discipline: Keep the first pass focused on Worker routing, OFF filter simplification, the Swift caller change, tests, validation, deployment, and concise changelog documentation.

## Core Decisions

### Upstream Search Strategy

- Add Search-a-licious as the primary Open Food Facts-backed search path.
- Keep legacy `https://world.openfoodfacts.org/cgi/search.pl` for pinned OFF fallback and restaurant/menu-like default searches.
- Do not batch duplicate legacy requests.
- Do not retry legacy `search.pl` eight times; restaurant/menu-like default searches may retry the legacy endpoint briefly because OFF frequently returns transient `503`.
- Remove the long pinned retry policy that produced ~24s failed responses.
- Target roughly an 8-second ceiling for pinned OFF before returning stale OFF data if cleanly available, otherwise `503`.

### Default / Best-Available Search

- Default/unpinned Worker search flow:
  - For normal packaged-food queries, try Search-a-licious first.
  - For restaurant/menu-like queries, try legacy OFF first with bounded retry handling, then Search-a-licious if legacy produces no usable response.
  - If Search-a-licious returns hits, return OFF-backed results.
- Do not silently fallback to USDA from default OFF search; USDA remains explicit.
- Keep existing USDA behavior unchanged.

### Restaurant/Menu Query Classification

- Replaced the initial restaurant-chain allowlist with a deterministic query-shape classifier in `worker/usda-proxy/src/restaurantSearch.ts`.
- The classifier routes legacy OFF first when a query looks like a restaurant menu item, using menu terms such as `burger`, `sandwich`, `nuggets`, `fries`, `taco`, `latte`, `bowl`, `tenders`, `alfredo`, and restaurant-context terms such as `diner`, `restaurant`, `combo`, `meal`, and `pieces`.
- Packaged-food terms such as `protein bar`, `greek yogurt`, `kind bar`, `cheerios`, and `frozen pizza` keep the query on the normal Search-a-licious path.
- A small phrase list remains only for ambiguous restaurant-name patterns such as `in n out`, `shake shack`, `five guys`, and `raising canes`; it is not the primary routing mechanism.

### Pinned Open Food Facts Search

- Explicit `provider=openFoodFacts` flow:
  - Try Search-a-licious first.
  - If Search-a-licious fails or returns zero hits, try legacy OFF once.
  - If both OFF backends return zero hits, return an empty OFF response.
  - If both OFF backends fail, return stale cached OFF data only if it can be implemented cleanly without broad cache redesign; otherwise return `503`.
- Do not fallback to USDA for pinned OFF.

### OFF Nutrition Filtering

- Remove or relax the OFF nutrition completeness filter.
- OFF-backed search results should not be hidden just because complete macro fields are missing.
- Keep the same `OpenFoodFactsProxyProduct` response shape with optional `nutriments`.
- Do not add `nutritionCompleteness` or other new public metadata in this pass.
- Document the reasoning in `changes-log.md`: filtering was hiding potentially useful foods; users can fill gaps; the Worker must not fabricate missing nutrition.

### Swift App Search Behavior

- Change normal “Search Online” to call the Worker with `provider: nil`.
- Keep “Search USDA” pinned to `.usda`.
- Keep pagination pinned to the resolved provider returned by page 1.
- Do not change UI copy unless implementation creates an obviously incorrect state.

### Observability and Metadata

- Preserve `openFoodFactsAttemptCount` as total OFF backend attempts across Search-a-licious and legacy OFF.
- Do not add backend-specific public response fields.
- Add backend-specific logs only later if production traces show they are needed.

## Current Code Context

- Worker route: `worker/usda-proxy/src/index.ts`
  - Owns `/v1/packaged-foods/search`, cache read/write, public response shaping, and structured search logs.
- Worker orchestration: `worker/usda-proxy/src/packagedFoods.ts`
  - Owns provider selection, OFF retry behavior, USDA fallback, and internal execution metadata.
- OFF adapter: `worker/usda-proxy/src/openFoodFacts.ts`
  - Currently uses legacy `cgi/search.pl`, normalizes raw OFF products, filters for usable nutrition, and handles OFF client errors.
- Cache planning: `worker/usda-proxy/src/packagedFoodSearchCache.ts`
  - Keeps separate default, shared OFF, pinned OFF, and USDA cache keys.
- Worker tests: `worker/usda-proxy/tests/packagedFoods.test.ts`
  - Covers OFF retry behavior, USDA fallback, cache planning, pagination budget, and response contracts.
- Swift caller: `cal-macro-tracker/Features/AddFood/AddFoodScreen+RemoteSearch.swift`
  - `searchOnline()` currently pins `.openFoodFacts`; this must change to `nil`.
- Swift client: `cal-macro-tracker/Features/AddFood/PackagedFoodSearchClient.swift`
  - Builds the Worker request and resolves provider from the response.

## Documentation Evidence

- Open Food Facts API docs require a custom `User-Agent`; the Worker already uses `OPEN_FOOD_FACTS_USER_AGENT`.
- OFF docs state search endpoints are rate-limited and should not be used as search-as-you-type.
- OFF docs state global rate limits may return `503`.
- Search-a-licious current OpenAPI is available at `https://search.openfoodfacts.org/openapi.json`.
- Search-a-licious supports `GET /search` with `q`, `page`, `page_size`, `fields`, `langs`, and returns successful responses with `hits`, `page`, `page_size`, `page_count`, `count`, and `timed_out`.
- The exact `hits` product shape must be verified with sample requests before mapping; the OpenAPI schema declares `hits` as generic objects.

## Proposed File Shape

Prefer focused edits to existing files:

- `worker/usda-proxy/src/openFoodFacts.ts`
  - Add Search-a-licious adapter.
  - Reuse normalization helpers.
  - Remove/relax OFF nutrition filtering.
- `worker/usda-proxy/src/packagedFoods.ts`
  - Update default and pinned provider orchestration.
  - Remove long pinned retry policy.
- `worker/usda-proxy/tests/packagedFoods.test.ts`
  - Update retry/routing tests and add Search-a-licious coverage.
- `cal-macro-tracker/Features/AddFood/AddFoodScreen+RemoteSearch.swift`
  - Use default provider for normal online search.
- `changes-log.md`
  - Add concise implementation rationale and validation/deployment notes.

Add new Worker files only if `openFoodFacts.ts` becomes too large after the adapter split.

## Milestones and Tasks

### Milestone 1 — Verify Search-a-licious Contract

- [x] Run sample Search-a-licious request for `Mcdonalds`.
- [x] Confirm `hits` shape and field names for product mapping.
- [x] Confirm behavior for zero-hit responses.
- [x] Confirm status/error behavior for failed requests where possible.
- [x] Decide whether `timed_out: true` with hits should return hits or fail.

### Milestone 2 — OFF Adapter Changes

- [x] Add Search-a-licious URL builder using `q`, `page`, `page_size`, `fields`, and `langs`.
- [x] Add Search-a-licious response decoder with narrow runtime checks.
- [x] Reuse existing OFF product normalization for Search-a-licious hits.
- [x] Remove/relax `hasUsableNutrition` filtering for OFF-backed results.
- [x] Preserve optional nutrition fields without filling missing values.
- [x] Keep legacy `search.pl` adapter available for pinned fallback.

### Milestone 3 — Worker Orchestration

- [x] Update default search to use Search-a-licious first and USDA fallback on zero hits/outage.
- [x] Update pinned OFF to use Search-a-licious first and legacy OFF once on zero hits/outage.
- [x] Remove long pinned retry policy.
- [x] Keep `provider=openFoodFacts` from falling back to USDA.
- [x] Keep `openFoodFactsAttemptCount` as total OFF backend attempts.
- [x] Preserve public response shape.
- [x] Route restaurant/menu-like default searches to legacy OFF first with bounded retry handling.
- [x] Keep normal packaged-food default searches on Search-a-licious first.
- [x] Remove the Nutritionix trial provider path after validating legacy OFF restaurant coverage.

### Milestone 4 — Cache Behavior

- [x] Keep existing cache key kinds unchanged.
- [x] Ensure Search-a-licious OFF responses write through existing OFF cache plans.
- [x] Evaluate stale OFF fallback only if it fits existing cache behavior cleanly.
- [x] Defer KV/R2/D1 stale cache redesign if required.

### Milestone 5 — Swift Caller

- [x] Change `searchOnline()` to call `startRemoteSearch(..., provider: nil)`.
- [x] Keep `searchUSDA()` pinned to `.usda`.
- [x] Preserve load-more behavior using `remoteSearch.provider`.
- [x] Leave UI copy unchanged unless a wrong state appears during validation.

### Milestone 6 — Tests

- [x] Add Search-a-licious success test for default search.
- [x] Add default Search-a-licious zero-hit fallback-to-USDA test.
- [x] Add default Search-a-licious outage fallback-to-USDA test.
- [x] Add pinned Search-a-licious failure then legacy OFF success test.
- [x] Add pinned Search-a-licious zero-hit then legacy OFF zero-hit empty response test.
- [x] Update old pinned 8-attempt retry tests to match the new bounded behavior.
- [x] Add test proving incomplete OFF nutrition products are no longer hidden.
- [x] Add restaurant/menu classifier tests covering hard restaurant-shaped queries and packaged-food blockers.
- [x] Add routing tests proving restaurant/menu-like default searches hit legacy OFF first and retry transient legacy failures.
- [x] Keep cache read/write plan tests passing.

### Milestone 7 — Documentation and Validation

- [x] Update `changes-log.md` with concise reasoning for Search-a-licious routing and OFF filter removal.
- [x] Update `changes-log.md` with legacy OFF restaurant routing, Nutritionix removal, and query-shape classifier validation.
- [x] Run Worker tests with `bun test`.
- [x] Run Worker check with `bun run --cwd worker/usda-proxy check`.
- [x] Run Swift formatting/build validation required by the touched Swift file.
- [x] Run `git diff --check`.
- [x] Run simplify review after implementation.
- [x] Run defensive-code-review after validators pass.
- [x] Run simulator search-and-log flow against the local Worker.

### Milestone 8 — Deploy and Production Verification

- [x] Deploy Worker from `worker/usda-proxy` with `bunx --bun wrangler deploy`.
- [x] Test the normal unpinned search request.
- [x] Test the explicit pinned OFF request.
- [x] Capture status, timing, resolved provider, and trace logs.
- [x] Record deployment version and validation summary in `changes-log.md`.

## Edge Cases

- Search-a-licious returns hits with missing nutrition: return products with optional missing fields; do not invent values.
- Search-a-licious returns zero hits for default search: fallback to USDA.
- Search-a-licious returns zero hits for pinned OFF: try legacy OFF once.
- Both pinned OFF backends return zero hits: return empty OFF result.
- Both pinned OFF backends fail: return stale OFF data only if cleanly available, otherwise `503`.
- Page > 1 remains provider-pinned per existing Worker validation.
- Cached OFF results remain provider `openFoodFacts` regardless of whether they came from Search-a-licious or legacy OFF.

## Validation Notes

- Search-a-licious live sample returned `200` with `hits` containing direct product fields; `brands` can be an array and some hits omit `nutriments`.
- Search-a-licious live zero-hit sample returned `200`, `hits: []`, `page_count: 0`, and `count: 0`.
- Implemented `timed_out: true` handling to return available hits, but treat a timeout with no hits as retryable/unavailable.
- Worker Bun tests passed after updating routing expectations.
- Worker type check passed; Wrangler still emits the existing experimental `secrets` warning.
- Swift format check and iOS simulator debug build passed.
- `git diff --check` passed.
- Simplify review removed orphaned retry/backoff plumbing, shared OFF HTTP status handling, and replaced repeated test URL substring checks with request helper predicates.
- Post-implementation simplify review tightened the OFF outcome type into a discriminated union, removed the now-obsolete legacy request-budget plumbing, and changed legacy OFF fallback to fetch only the requested page now that nutrition filtering no longer requires backfilling skipped products.
- Defensive-code review found no additional high-confidence redundant guards or impossible-state branches after simplify cleanup.
- Post-implementation defensive-code review found no additional high-confidence redundant guards, duplicated validation, or impossible-state branches to remove.
- Deployed Worker version `05d567cd-082e-4d4a-8dbd-ee2b6771d5bf`.
- Production unpinned `Mcdonalds` request returned `200` in about `1.43s`, resolved to `openFoodFacts`, and returned 12 results.
- Production pinned OFF `Mcdonalds` request returned `200` in about `0.15s`, resolved to `openFoodFacts`, and returned 12 results.
- Simulator end-to-end flow passed after starting local `wrangler dev` for the simulator base URL. Visual checks confirmed the Add Food sheet, online search results, Log Food form prefill, and final Today summary all rendered correctly; logging `Wrap - Mcdonalds Grilled - Mcdonalds` updated Today to `198.3 kcal`, `13.6g` protein, `15.3g` carbs, `9.1g` fat, and one logged item.
- Restaurant routing validation against local `wrangler dev` confirmed legacy OFF can return relevant rows for `Burger King whopper`, `Starbucks latte`, `McDonald nuggets`, and `olive garden chicken alfredo`.
- Hard-query validation showed some restaurant-shaped queries correctly route legacy-first but still have no usable OFF rows, including `in n out double double`, `shake shack fries`, `five guys cheeseburger`, and `raising canes tenders`.
- Packaged-food validation confirmed `protein bar`, `greek yogurt`, `frozen pizza`, `kind bar`, and `cheerios` stay on the normal Search-a-licious path.
- Simulator validation confirmed `olive garden chicken alfredo` renders `Olive Garden, Chicken Alfredo, Dinner`, while `protein bar` renders normal packaged-food results.
- Post-implementation review simplified zero-nutrition draft construction, avoided unread restaurant default cache writes, stopped retrying OFF responses with `Retry-After`, and removed stale USDA fallback parameters; defensive-code review found no additional Swift cleanup.
- Follow-up review fixed the Swift Load More button to trust the Worker `hasMore` contract even when a filtered page has no visible results; the final defensive pass removed one unused Worker telemetry metadata field.
- Follow-up review fixed missing-nutrition Open Food Facts search selections to pass required review nutrients into `LogFoodScreen`, preventing immediate logging of all-zero manual-review drafts.
- The final cleanup review extracted shared Open Food Facts draft import mapping and shared token matching for OFF/USDA filters; broader OFF orchestration and retry timing changes were left unchanged to preserve the validated routing behavior.
- A follow-up cleanup pass shared the Swift missing-nutrition review predicate and clarified OFF name-token matching terminology; stale fallback metadata plumbing was left unchanged to avoid broad cache/telemetry contract churn.
- The final defensive-code review removed an unreachable Swift branch from the missing-nutrition review predicate and found no additional high-confidence redundant guards, duplicated validation, or impossible-state branches to remove.
- The final repeat cleanup pass found LGTM from simplify reuse/quality/efficiency reviewers and LGTM from Swift/Worker defensive-code reviewers; validators and final diff review passed.

## Findings and Follow-Ups

- Search-a-licious response mapping was verified against live sample output before coding.
- A durable stale-cache strategy likely requires KV/R2/D1 and was deferred instead of forced into this first pass.
- A future UI pass may add explicit missing-nutrition review affordances if relaxed OFF results expose many incomplete products.
