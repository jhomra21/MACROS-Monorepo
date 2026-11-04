# Search row polish, 2026-11-04

Base: `7585a8c` (build 32). Device: iPhone 17e B, `F976E800-DA1F-4F20-B755-DFD964E33975`, iOS 27.0. All UI actions and screenshots used the device-bound CLI returned by T3 `device_open`. No reserved simulators were touched. Both simulator locks were acquired with `mkdir` before use and released afterward.

## RED → GREEN

- `worker-red.txt`: tests written and run before implementation, **84 passed, 8 failed**, 92 total. The original 83 tests passed; the mixed-case preservation test also passed already. Captured test logs have trailing whitespace removed only.
- `worker-green.txt`: **92 passed, 0 failed**, including unchanged v1, dedupe, cursor, and normalization parity tests.
- `red-main-greek-yogurt.png` / `red-main-tree.txt`: unchanged main app against the pre-deploy live Worker. Repeated `GREEK YOGURT`, no brand, `140.1 kcal`, `C 16.0`.
- `green-add-food-greek-yogurt.png` / `green-add-food-tree.txt`: live results now show secondary brands, display-case names, whole kcal and clean macro values. The two On Device rows are unchanged.
- `green-add-food-ax5.png` / `green-add-food-ax5-tree.txt`: AX5, brand wraps naturally above stacked nutrition.
- `green-meal-picker.png` / `green-meal-picker-tree.txt` and `green-meal-picker-ax5.png` / `green-meal-picker-ax5-tree.txt`: same shared remote row in Choose Foods, normal and AX5.

Screenshots are native 1× simulator captures, not mocks. Synthetic demo food data was already on the assigned simulator. Text size was restored to Large afterward.

## Repeat the UI check

1. Prefix shell commands with `cd /Users/juan/.t3/worktrees/cal-macro-tracker/search-row-polish &&`. Acquire the iPhone lock with `mkdir -p /tmp/macros-sim-locks && mkdir /tmp/macros-sim-locks/F976E800-DA1F-4F20-B755-DFD964E33975`. If occupied, sleep 120 seconds and retry, at most 90 times; do not take over an existing lock.
2. Build Debug with Xcode at `/Applications/Xcode-26.4.1.app/Contents/Developer`, generic iOS Simulator destination, and derived data outside the repository. Pass **both** overrides, with the unconditional assignment **last**:
   ```sh
   cd /Users/juan/.t3/worktrees/cal-macro-tracker/search-row-polish && DEVELOPER_DIR=/Applications/Xcode-26.4.1.app/Contents/Developer xcodebuild -project cal-macro-tracker.xcodeproj -scheme cal-macro-tracker -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/macros-search-polish-green 'PACKAGED_FOOD_SEARCH_BASE_URL[sdk=iphonesimulator*]=https://cal-macro-tracker-usda-proxy.jhonra121.workers.dev' PACKAGED_FOOD_SEARCH_BASE_URL=https://cal-macro-tracker-usda-proxy.jhonra121.workers.dev build
   ```
   Xcode's CLI parser mishandles the conditional assignment if it is last, yielding `iphonesimulator*]=https://…`. Verify the actual built `USDA_PROXY_BASE_URL` with `plutil -extract USDA_PROXY_BASE_URL raw <app>/Info.plist`. `red-endpoint.txt` and `green-endpoint.txt` record the verified values.
3. Install the app on B. Call T3 `device_list`, then `device_open` for B. Use its returned CLI for `open juan-test.cal-macro-tracker --relaunch`, `snapshot -i`, and all subsequent UI actions.
4. Tap Add Food. Fill Search foods with `greek yogurt`, submit with `keyboard enter`, then inspect Search Results. Assert brand lines, `Greek Yogurt`, and `140 kcal`; confirm the On Device section has no added brand lines. Save a screenshot and accessibility snapshot.
5. Set `settings text-size accessibility-extra-extra-extra-large`. Scroll down with fractional amounts such as `scroll down 0.6 --settle` until a remote row is fully visible. Assert name, wrapped brand, kcal, and macros are stacked without clipping.
6. Restore `settings text-size large`. Close search, choose Manual → Create Meal → Add Food. Search `greek yogurt`, submit, and repeat normal/AX5 screenshots in Choose Foods. Restore Large.
7. Close the automation session/device panel without shutting down the simulator, then `rmdir` the lock. Do not leave an existing automation session claimed.

The RED app artifact remains at `/tmp/macros-search-polish-red/Build/Products/Debug-iphonesimulator/cal-macro-tracker.app`. It was built before source implementation and photographed before deployment. Replaying it now cannot reproduce the old Worker output.

## Worker / compatibility

Deployed with `bunx wrangler whoami` followed by `bunx --bun wrangler deploy` after all Worker tests and type checks passed.

- Worker: `https://cal-macro-tracker-usda-proxy.jhonra121.workers.dev`
- Version: `9b5da072-c74c-43c8-9b80-75575eea1dca`
- `live-greek-yogurt.json`, `live-chicken-breast.json`: trimmed live `/v2/foods/search` responses, 24 results each.
- `v1-compatibility.json`: default and `provider=usda` `/v1/packaged-foods/search?q=greek%20yogurt` responses were **byte-identical before and after deployment**, with the same response/item shape. No v1 implementation or tests changed.
- Source-page cache schema advanced from 2 to 3 so old, already-normalized cache entries cannot bypass the new boundary. Dedupe still uses normalized name/brand identity and GTIN, with no key changes.
- Brand acronym policy is deliberately narrow: preserve `USA` and ampersand-separated initials such as `M&S`, not every 2–3-letter uppercase word (`THE`, `BIG`, `COW`). Digit-bearing tokens remain verbatim. Existing lowercase casing is preserved, apart from whitespace cleanup and trailing legal brand suffix removal.

## Validation

All commands ran in the feature worktree and in the foreground:

- Worker `bun test`: **92 passed**, zero failed; `bun run check`: passed.
- `make lint-js`: 108 files, zero warnings/errors. Initial spacing findings were fixed.
- `make quality-format-check`: passed.
- `make quality-build`: passed (not counted as tests).
- Full serial non-StoreKit iPad suite: **256 passed, 0 failed, 0 skipped**, no runtime warnings. `PurchaseStoreStoreKitTests` was explicitly excluded as requested. `ipad-test-summary.json` is exported from `/tmp/macros-search-polish.xcresult`.

Suite command (after acquiring the iPad lock; old result bundle removed first):

```sh
cd /Users/juan/.t3/worktrees/cal-macro-tracker/search-row-polish && DEVELOPER_DIR=/Applications/Xcode-26.4.1.app/Contents/Developer xcodebuild -project cal-macro-tracker.xcodeproj -scheme cal-macro-tracker -destination 'platform=iOS Simulator,id=E91B597B-CE57-4C0B-A8A4-51CBDC3386AB' -parallel-testing-enabled NO -test-timeouts-enabled YES -default-test-execution-time-allowance 30 -maximum-test-execution-time-allowance 45 -skip-testing:cal-macro-trackerTests/PurchaseStoreStoreKitTests -resultBundlePath /tmp/macros-search-polish.xcresult test
```

Logs remain in `/tmp/macros-search-polish-{worker-check,quality-build,tests,deploy}.log`. Evidence in this directory is under 5 MB.
