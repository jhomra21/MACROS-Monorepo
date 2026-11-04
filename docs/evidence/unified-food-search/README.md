# Unified food search evidence

Design: [`../../design/unified-food-search.md`](../../design/unified-food-search.md).
Base: `origin/main` at `21921b1`; branch: `feat/unified-food-search`.

## What changed

- `/v2/foods/search` concurrently requests registered OFF and USDA sources under one 8-second deadline. Normalization, source ranking/deduplication, per-source caches and cursor positions live in the Worker. Swift accepts arbitrary source strings.
- Add Food and the meal picker share a 700 ms idle-debounced, cancellable session with a three-character minimum. Keyboard Search submits immediately. On-device results stay independent; online errors show only a working **Try again** button.
- OFF v2 cache misses use an isolated, persistent rolling 8/min gate and upstream `Retry-After` cooldown, failing closed. USDA retains the global 14/min budget. Client requests share the existing 30/min limiter. Failed/skipped source pages keep their positions; merged responses are never cached.
- Legacy `/v1` routes, cache keys, response shapes and test files are unchanged. Raw USDA extraction is shared, but v1 keeps its original filtering/mapping. Existing barcode mapping and persisted provenance remain.

## Test-first record and final checks

`red-worker-tests.txt` records **58 existing tests passing**, followed by the new suite failing to import the not-yet-created implementation. Failure/parity cases and shared fixtures were written before feature implementation.

The unchanged-main RED binary was built before implementation. Its screenshots were captured later, after the authorized simulator lock became available. Only its built Info.plist search URL was overridden to the deployed Worker and ad-hoc re-signed; no baseline source was edited. `red-search-online.png`, `red-usda-fallback.png`, and `red-ui.txt` show the previous explicit online/provider-fallback flow.

Final validation:

- `bun test --cwd worker/usda-proxy`: **83 pass, 0 fail, 278 assertions, 6 files**, including the unchanged 58 legacy tests. Output: `green-worker-tests.txt`.
- `bun run --cwd worker/usda-proxy check`: generated binding types and TypeScript pass.
- `make lint-js`: **106 files, 0 warnings, 0 errors**.
- `make quality-format-check` and `make quality-build`: pass.
- Serial non-StoreKit iPad suite: **252 pass, 0 fail, 0 skipped**, no runtime warnings. `ipad-test-summary.json` is the xcresult summary, not build output. StoreKit tests were explicitly excluded, not counted as passed or skipped. macOS and hardware camera testing were not run.
- Code-simplifier and final defensive-code review completed locally, without subagents. Removed the obsolete throwing signature from normalized draft construction. Kept cancellation/generation guards, source-boundary validation, review gates and fail-closed coordination because those protect reachable failure paths.

Final xcresult: `/tmp/macros-unified-reviewed.xcresult`. Repeat from this worktree with a fresh result path:

```sh
DEVELOPER_DIR=/Applications/Xcode-26.4.1.app/Contents/Developer \
xcodebuild -project cal-macro-tracker.xcodeproj -scheme cal-macro-tracker \
  -destination 'platform=iOS Simulator,id=E91B597B-CE57-4C0B-A8A4-51CBDC3386AB' \
  -parallel-testing-enabled NO -test-timeouts-enabled YES \
  -default-test-execution-time-allowance 30 \
  -maximum-test-execution-time-allowance 45 \
  -skip-testing:cal-macro-trackerTests/PurchaseStoreStoreKitTests \
  -resultBundlePath /tmp/macros-unified-repeat.xcresult test
```

## Deployed Worker and live probes

URL: `https://cal-macro-tracker-usda-proxy.jhonra121.workers.dev`

Version **`a0dcff22-8f62-4645-829c-cf58c5c9fba8`**, deployed at `2026-11-04T02:58:11Z`, confirmed as the latest 100% deployment after final source review. No Wrangler configuration or binding migration changed.

`live-probes.json` summarizes the saved bodies and headers:

- `chicken breast`: 200, 24 merged results (12/source), 0.403 s warm. Initial cold observation was 1.327 s.
- `mcdonalds big mac`: 200, 8 OFF results, 1.056 s; USDA completed with no matching rows.
- `737628064502`: 200, one OFF product, 0.803 s.
- `zz`: 400, `{"error":"Try again"}`, no upstream calls.
- v1 default: 200, OFF result, 0.253 s. Explicit v1 `provider=usda`: 200, 12 rows, 0.169 s. Both retain `query/page/pageSize/resolvedProvider/results/hasMore`.

Probe header names are parsed case-insensitively. Saved log/header text normalizes trailing whitespace and line endings; JSON bodies are retained unchanged. V1 does not emit v2 upstream diagnostics; an empty diagnostic object there is not a measurement of v1 upstream traffic.

## Repeatable simulator E2E and measured load

Used only the authorized iPhone 17e B, `F976E800-DA1F-4F20-B755-DFD964E33975`, after acquiring its `/tmp/macros-sim-locks/` directory lock. All UI input/capture used the T3-pinned `agent-device` CLI. No other iPhone was modified or simulator created/shut down.

GREEN Debug builds use `PACKAGED_FOOD_SEARCH_BASE_URL=http://127.0.0.1:8799`. The included `gateway.ts` forwards real responses from the deployed Worker, without fixtures or fabricated successes. It logs Worker requests and the Worker's `X-MACROS-Upstream-Calls` header to a local JSONL file. Release configuration was not changed.

1. Run `SEARCH_EVIDENCE_LOG=/tmp/macros-unified-repeat.jsonl bun docs/evidence/unified-food-search/gateway.ts`.
2. Install a Debug build configured for that loopback URL on the authorized locked device. Open Add Food, focus an empty search field.
3. With the returned pinned CLI, run `type chicken --delay-ms 200`, pause exactly one second, then `type ' breast' --delay-ms 200`. Wait for the final results; do not submit or navigate until the measurement log is saved.
4. `typing-200ms-with-pause.jsonl` contains exactly that measured interval: **2 Worker requests** (`chicken`, `chicken breast`), **2 upstream calls total** (one OFF and one USDA for `chicken`; final query was cached). This is an observed mixed-cache run, not a cold-cache promise. A cold two-query run can spend up to four upstream calls. Cancellation cannot undo calls already sent.
5. `green-typing.mp4` records this 200 ms/character run and one-second pause (28.13 s, 390×844, 15 fps). Saved local foods occupy the viewport while typing. `green-merged-results.png` and `green-merged-ui.txt` separately show the On Device/Search Results boundary and merged rows. The saved response proves both contributions.
6. Keyboard Search was exercised separately and triggered an immediate request. Load more appended another page. Selecting a row opens a neutral editable review (`green-review.png`). Returning from review retains results without an extra request (`green-return-ui.txt`).
7. Stop the gateway's actual listener process, confirm loopback connection refusal, and change the query. `green-try-again.png`/`green-error-ui.txt` show the genuine unreachable-base failure. Restart the gateway, tap **Try again**, and obtain `green-retry-recovered.png`. Killing only a shell wrapper does not stop Bun; the first wrapper-only attempt was not used as error evidence.
8. Deny camera permission through the device CLI, open Camera, and inspect `green-camera-search.png`/`green-camera-ui.txt`. **Search** opens Add Food. Permission was reset afterward.
9. Apply `settings text-size accessibility-extra-extra-extra-large`. The initial `green-ax5.png` exposed a cramped horizontal row; remote rows now use the existing stacked row layout. `green-ax5-stacked.png` and its UI snapshot show the fix. Scroll the result list to view full rows; native Search remains a single-line field. Text size was restored to `large`.
10. Add Food → Manual → Create Meal → Add Food opens the shared picker. Search `mcdonalds big mac` without a submit action: `green-meal-picker.png`/`green-meal-picker-ui.txt` show the same neutral automatic results, and `green-meal-review.png` shows the editable review. No meal was saved during this check.

All checked-in evidence is below 5 MB. Only demo/test data appears in screenshots and the local observation log. The gateway is not part of production. The final installed Debug app was rebuilt against the deployed URL, not the stopped local gateway; the device was left booted at standard text size and its lock released.

## Limits / open issues

- OFF explicitly discourages search-as-you-type. The owner approved the 700 ms settled-query compromise and global v2 gate. Those bounds do **not** establish provider permission or compliance. Existing v1 OFF traffic is outside the new gate.
- Source caches are colo-local. Global quotas can silently omit one source on cache misses; retained cursor positions allow a later retry. They do not guarantee both providers for every query.
- The simulator has no real barcode/camera capture proof; live nutrition data can be incomplete or inaccurate and remains editable. A hardware pass remains appropriate before release.
- AX5 evidence covers the changed remote results. Existing on-device rows and the native search-field layout were not redesigned.
- StoreKit and macOS tests were not run for this feature.
- Main advanced after the requested base `21921b1` (27 commits at final review). This feature branch was not rebased or merged with that later work; integration must account for it.
