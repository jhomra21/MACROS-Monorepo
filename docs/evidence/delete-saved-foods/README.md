# Delete saved foods

## What "saved food" means in code

A saved food is a `FoodItem` SwiftData row whose `source` is not `common`: `custom`, `barcodeLookup`, `labelScan`, or `searchLookup`. Common foods are the bundled seed database (`CommonFoodSeedLoader`), are reseeded on launch, and cannot be deleted (`FoodItemRepository.deleteReusableFood` already rejects them).

`LogEntry` stores a full copy of name, serving, per-serving and consumed nutrients, plus an optional plain `foodItemID: UUID`. Logged meals store `LoggedMealComponentSnapshot` rows, also with a plain UUID. There is no SwiftData relationship, so there is no delete rule that can cascade from `FoodItem` into history. Saved meals reference foods through `MealComponent.foodItemID`; the existing repository blocks deleting a food that a saved meal still uses. Widgets, sharing, and Health read only log entries, never `FoodItem`.

Before this change, the only delete path was the Delete Food button inside the Settings food editor.

## Failure modes (written before implementation)

1. Deleting a saved food removes, edits, or re-totals already-logged diary entries (food or meal logs).
2. Dashboard totals, History, widget data, Health samples, or shared-day data change after the delete.
3. A common (seed) food shows a delete action, or deleting it appears to succeed and it returns on next launch.
4. A food used by a saved meal is deleted, leaving the meal with a missing component and wrong totals.
5. Blocked delete (food used by a meal) fails silently, or only after the user already confirmed.
6. Add Food "On Device" list keeps showing the deleted row because results are held in `@State`, not a live query.
7. Searching for the deleted food's name still returns it on device.
8. Meal-builder food picker still shows it, or keeps its ID in the selection set and later adds a missing food.
9. Settings Saved Foods preview and Show All lists still show it.
10. Cancelling the confirmation deletes the food or leaves the row stuck in a swiped or removed state.
11. Swipe action breaks tap-to-select on the row (logging, picker toggling, editor navigation).
12. Editing or "log again" on an old entry whose food was deleted crashes or fails to save.
13. Recents/suggestion pills: a suggestion built from history still references the deleted food ID.
14. Barcode cache: rescanning a deleted barcode food reuses a stale cached row.

## Evidence and results (round 1)

Fixture: iPhone 17e `F976E800-DA1F-4F20-B755-DFD964E33975`, iOS 27.0, erased, then DEBUG Settings → Developer → Load Demo Data (20 custom foods, 432 log entries over 90 days). Debug build of this branch with Xcode 27.0 (`DEVELOPER_DIR=/Applications/Xcode-26.4.1.app/Contents/Developer`), the USDA proxy override only. The UI was driven through T3 device tools and `agent-device`. Store state was read with an earlier, partial version of [`db-snapshot.sh`](db-snapshot.sh) (read-only, `sqlite3 mode=ro`).

Before deleting anything, I created a saved meal "Almonds, Banana" through the meal builder and logged it once, so history contains a food-log and a meal-log snapshot. The round 1 screenshots named below were replaced in round 2 to stay within the image budget; they remain in commit `afdbf3b`.

| # | Failure mode | Check and evidence | Result |
| --- | --- | --- | --- |
| 1 | Logged entries removed or edited | Deleted Protein bar (30 entries, one today), Apple (3 entries), and Orange (0). Snapshots `db-2-meal-logged` → `db-3-after-deletes`: still 433 entries and identical totals (185,535 kcal / 11,315 P / 23,954 C / 4,979 F). The round 1 digest covered only these `LogEntry` columns: ID, food and meal links, date, name, serving description, calories per serving, consumed macros, `updatedAt`, and `healthSyncVersion`. It skipped quantities, other per-serving values, and secondary nutrients, so it did not prove every field unchanged. Round 2 hashes every column (failure mode 30). | Partial in round 1; complete in round 2 |
| 2 | Dashboard, History, widgets, Health, sharing change | `dashboard-after-delete.png`: today still 1,580 kcal with the Protein bar row. History lists both Protein bar entries. Widgets, Health, and sharing read only `LogEntry` (no `FoodItem` reference in `CalMacroWidget`, `Shared`, `Features/Health`, `Features/Sharing`). Round 2's full-row `LogEntry` digest covers every field they read. | Passed (Health/sharing by code path + round 2 store digest) |
| 3 | Common foods deletable | Swiping a common "Egg, Whole" row in Add Food shows no action; the drag falls through to a normal tap. Common foods stay at 3,283 across deletes and relaunches. | Passed |
| 4 | Meal component deleted | Almonds (used by the saved meal) shows no Delete in Add Food or Settings. The meal still lists both components in the store snapshot. | Passed |
| 5 | Blocked delete fails silently or after confirming | The swipe action is not offered for foods in a saved meal (live `@Query` of `MealComponent`). Opening the food shows the existing editor note: "Used by 1 meal… Delete is blocked while this food is in a meal." | Passed |
| 6 | Add Food list keeps the row | `addfood-swipe-protein-bar.png` → row removed immediately after Delete. | Passed |
| 7 | On-device search still finds it | `addfood-search-after-delete.png`: "protein bar" → "No on-device foods or meals match this search yet." Only network results appear. | Passed |
| 8 | Meal picker keeps the row or its selection | `picker-swipe.png`: Black beans selected, then deleted. The row vanished, and Add put only Almonds and Banana into the meal (2 foods, 270 kcal). | Passed |
| 9 | Settings lists keep it | `settings-swipe-apple.png`: Apple deleted from the Saved Custom Foods preview; Orange deleted from Show All. Both lists updated; store shows 16 custom foods. | Passed |
| 10 | Cancel or confirmation glitches | No confirmation dialog; round 2 adds Undo instead. Before tapping Delete, swiping back cancels. | Passed (design changed) |
| 11 | Swipe breaks tapping | Tapping rows still logs (Log Food opens), toggles picker selection, and opens the Settings editor. | Passed |
| 12 | Editing or re-logging an orphaned entry fails | Edited today's Protein bar entry to 1.25 servings and back, then used Log Again. No crash; 434 entries; no saved food re-created (custom stays 16). | Passed |
| 13 | Suggestions/recents reference the deleted food | Suggestion pills come from log history and open a draft built from the entry's own snapshot, so they keep working and still show the name. Kept intentionally: they represent history, not saved foods. Residual: if a pill or Log Food opens an external (barcode/search) food whose saved copy was deleted and the user edits its nutrients, the existing auto-update rule saves a new copy (its footer says so). Code analysis only. | Accepted, documented |
| 14 | Stale barcode cache | `fetchCachedBarcodeFood` reads `FoodItem` rows only, so a deleted barcode food is no longer a cache hit and the next scan uses the network lookup. Code analysis only; no barcode scanned. | Passed (code path) |

## Review round 2: Undo, failures, and evidence gaps

### Failure modes (written before implementation)

15. Undo restores an incomplete food: a new UUID, or a lost field (brand, `sourceIdentifier`, barcode, external product ID, source name or URL, serving description, grams per serving, any per-serving macro or secondary nutrient, secondary nutrient backfill state, `searchableText`, `createdAt`, `updatedAt`).
16. After Undo, Add Food's On Device list (held in `@State`) does not show the food again, or shows it in a different position.
17. After Undo, the meal picker does not show the row again, or drops the selection the user had made before deleting it.
18. After Undo, the Settings preview or Show All list does not show the food again.
19. Full swipe deletes with no Undo affordance.
20. The Undo banner never goes away, its timer keeps running after the screen is gone, or an old timer dismisses a newer banner early.
21. Deleting several foods in a row: banners stack, or Undo restores the wrong food. (Defined behavior: each delete replaces the previous banner; earlier deletes stay final.)
22. Deleting the last row in a list breaks the empty state or crashes; Undo does not bring it back.
23. Undo after the same external food was saved again (rescan or search) creates a duplicate.
24. A forced store save failure removes the row from the list while the store still has it (ghost row or `UICollectionView` crash), loses the picker selection, shows no error, or blocks a retry. Checked on Add Food, the picker, and Settings.
25. An Undo save failure is silent or loses the deleted food without telling the user.
26. VoiceOver: the Delete swipe is not exposed as an accessibility action, the Undo button is unreachable before the banner hides, or the deletion is not announced.
27. The meal guard goes stale: Delete stays hidden after a meal is edited to drop the food or deleted, or appears for a food that was just added to a meal.
28. Logged meal snapshots change after deleting the saved meal and then a food it used.
29. An external (barcode or search) food that was deleted cannot be re-added by rescanning or searching, or re-adding hits a stale cache row.
30. The evidence digest skips `LogEntry` or `LoggedMealComponentSnapshot` columns, or hides NULL versus empty, so "unchanged" is overclaimed.
31. The banner uses a tinted or custom-styled surface instead of native Liquid Glass, or hides list content with no way to reach it.

### Undo design

- After a delete, the screen that owns the list shows a bottom banner, "Deleted ‹name›", with an Undo button. It is inset into the safe area, so it does not cover rows. It uses the app's untinted Liquid Glass surface (`appGlassRoundedRect`), and VoiceOver announces "Deleted ‹name›".
- Before deleting, the app captures the food as the existing `BackupFood` value (every stored field, same UUID, timestamps) plus its `searchableText`. Undo inserts that exact row again through `FoodItemRepository.restoreReusableFood`, which refuses with a message if the same food (by ID, external ID, or barcode) was saved again meanwhile.
- Lists refresh after Undo: Add Food and the picker re-run their on-device query through a revision counter, Settings lists are live `@Query`s, and the picker re-selects the food if it was selected when deleted.
- The banner hides after 5 seconds. The timer is a `.task(id:)` keyed to the deleted food, paused while an error alert is up. SwiftUI cancels it on a newer delete, Undo, an alert, or leaving the screen, and a cancelled sleep returns before clearing. So a stale timer cannot hide a newer banner, and dismissing an alert restarts the countdown. With VoiceOver on, the banner has no timer and stays until the user acts or leaves the screen.
- Deleting several foods in a row: each delete replaces the banner, and only the latest can be undone. Earlier deletes are final.
- Full swipe stays enabled because Undo covers it.
- The swipe button is now a red-tinted non-destructive button. `role: .destructive` deletes the list item in UIKit before the data changes, so any outcome other than "this row disappears" crashes (see the crash notes).
- DEBUG-only E2E hook (`#if DEBUG` in `FoodItemRepositoryPersistence.swift`): launching with `-debugFailSavedFoodDeletes <n>` or `-debugFailSavedFoodRestores <n>` makes the next n deletes or restores throw after their change is staged, so the real `PersistenceReporter` rollback runs.

### Evidence and results (round 2)

Same simulator and Xcode, erased again and loaded with demo data (20 custom foods, 432 entries). The search proxy override was set with `simctl spawn … launchctl setenv`. UI was driven only through T3 device tools and `agent-device`. [`db-snapshot.sh`](db-snapshot.sh) now dumps every column of every `ZLOGENTRY` and `ZLOGGEDMEALCOMPONENTSNAPSHOT` row (43 and 22 columns) and of every non-common `ZFOODITEM` row (25 columns, without SwiftData's `Z_PK`/`Z_ENT`/`Z_OPT`, which change on re-insert). Values are dumped as SQL literals with `quote()`, so NULL stays distinct from `''` and REALs round-trip, then hashed. Snapshots `db-0` … `db-38` (summary plus full row dumps) are in ignored `build/evidence/2026-11-07-delete-saved-foods/`.

| # | Failure mode | Check and evidence | Result |
| --- | --- | --- | --- |
| 15 | Undo restores an incomplete food | For every Undo, the full saved-food row dump before the delete and after Undo is byte-identical (`diff` empty): Banana in the picker (`db-5`/`db-6`); the external Fage yogurt with barcode, brand, `usda:` external ID, source name and URL, grams, saturated fat, sodium, sugars, and backfill state (`db-8`/`db-10`); Protein bar (`db-11`/`db-13`); Cottage cheese through the accessibility action (`db-36`/`db-38`). Same UUID, `createdAt`, `updatedAt`, and `searchableText`. | Passed |
| 16 | Add Food list not refreshed after Undo | Protein bar, the only on-device match for "protein bar", reappears after Undo (`agent-device` snapshot). With the default list, Almonds returns at the top in its original order. | Passed |
| 17 | Picker loses row or selection after Undo | Selected Banana → Delete → Undo: the row is back as "Banana…, Selected" (`picker-undo-banner.png` shows the banner from the first delete). | Passed |
| 18 | Settings lists not refreshed after Undo | Saved External Foods' only row comes back after Undo (`settings-last-row-undo-banner.png`, now only in commit `a74e9c5`, shows the empty state and banner first). Saved Custom Foods preview: Banana comes back (`db-30`/`db-31`). | Passed |
| 19 | Full swipe has no Undo | A full fling across the Fage row in Settings deletes it and shows the banner. | Passed |
| 20 | Banner timer stuck or stale | Without Undo, the banner is gone after about 5 seconds (Black beans in the picker, Banana in Add Food after 6.5 seconds). With the countdown paused during a "Can't Undo" alert held for 7 seconds, the banner was still there 2 seconds after OK and Undo worked. The task is tied to the view and its id; code review confirms no timer outlives the screen. | Passed |
| 21 | Repeated deletes | Deleted Fage then Almonds in Add Food. One banner, "Deleted Almonds". Undo restored only Almonds: the dump differs from before only by the missing Fage row (`db-14`/`db-16`). | Passed (defined behavior) |
| 22 | Last row breaks the list | Settings → Saved External Foods' last row, and Add Food's only "protein bar" match, both turn into the empty-state text with the banner, and Undo brings them back. With the old destructive role, the same Settings swipe crashed (see crash notes). | Passed after fix |
| 23 | Undo duplicates a re-saved food | `restoreReusableFood` checks by ID, external product ID, and barcode before inserting. Code path only; not reproduced in E2E. Round 3 found a cross-provider gap in this check and fixed it (failure mode 32). | Superseded by round 3 |
| 24 | Forced delete failure | `-debugFailSavedFoodDeletes 1`, one launch per surface. Add Food (Apple), the picker (Banana, selected), and Settings preview (Apple): "Can't Delete Food — Forced save failure (DEBUG)." (`addfood-forced-failure.png`), the store dump is unchanged (`db-17`/`18`, `21`/`22`, `25`/`26`), the row stays, and the picker row stays "Selected". The retry deletes (`db-19`, `23`, `27`), and Undo restores identical rows (`db-20`, `db-24`). No crash. | Passed |
| 25 | Undo failure | `-debugFailSavedFoodRestores 1`: Undo shows "Can't Undo" (`undo-failure-alert.png`), the store still lacks the food (`db-28`), and the banner stays. The first run showed the countdown expiring behind the alert, so the food could not be retried. The fix pauses the countdown during the alert. Re-run: alert held 7 seconds, banner still present, second Undo restored the row (`db-30`/`db-31`). (The first run left Apple deleted in the fixture.) | Passed after fix |
| 26 | VoiceOver | Simulator has no VoiceOver, so I read the iOS accessibility tree through the macOS Accessibility API (`ax-actions.swift` in the raw folder). Saved food rows expose the custom action "Delete"; common rows ("Egg, Whole") do not. Performing that action on Cottage cheese deleted it and showed the banner, and Undo restored it identically (`db-36`–`38`). The Undo button is a normal button in the tree. The announcement and the no-timer-with-VoiceOver branch are code only. | Passed (announcement by code) |
| 27 | Stale meal guard | Saved meal Almonds + Banana: Almonds has no swipe action (the drag falls through to a tap, as in round 1). Edit the meal to remove Almonds and save: Almonds now offers Delete. Delete the saved meal: Banana becomes deletable and was deleted. The guard is a live `@Query` of `MealComponent`. | Passed |
| 28 | Logged meal snapshots change | Logged the meal (`db-32`: 435 entries, 2 meal snapshots `4d40cca7…`). Edited the meal, deleted the saved meal, then deleted Banana: entry digest `fcacaa1f…` and meal snapshot digest `4d40cca7…` unchanged through `db-38`. `dashboard-meal-history.png` (now only in commit `a74e9c5`): "Almonds, Banana" still logs 270 kcal. | Passed |
| 29 | External food cannot be re-added | The external Fage yogurt deleted by the crash run was found again by USDA search and logged. The store has one `searchLookup` row, new UUID, same `usda:2756461` ID, no duplicate. Barcode rescanning was not run (no camera in Simulator); it uses the same `FoodItem` lookup as round 1 item 14. | Passed (search); barcode by code path |
| 30 | Digest overclaims | Full-column, NULL-preserving dumps as above. Across all 39 snapshots, the `LogEntry` digest changes only when something was logged (432 → 433 → 434 → 435), never on a delete, failure, or Undo. | Passed |
| 31 | Banner styling or occlusion | Untinted `appGlassRoundedRect` (Liquid Glass on iOS 26+), safe-area inset above the search field, Camera button, and keyboard (screenshots). | Passed |

### Crash notes

- Round 1: a destructive swipe followed by a confirmation dialog crashed with `UICollectionView … Invalid number of items in section`. The destructive role removes the row before the dialog, but the data still held it.
- Round 2, root cause: the round 1 build crashed on a full swipe of the last Saved External Foods row with `NSInternalInconsistencyException: attempt to delete item 0 from section 12 which only contains 0 items before the update` (raw `crash-1-settings-fullswipe.ips`). The food was deleted in the store. `role: .destructive` deletes the item in UIKit first; SwiftUI's diff (row replaced by the empty-state row) then deletes it again. Any change other than "this row disappears", such as a failed save or an empty-state row, hits the same mismatch. The fix is a non-destructive button tinted red, so every outcome goes through SwiftUI's normal diff. This round confirmed the empty-state and failed-save paths.
- The round 1 picker crash blamed on the red tint (`SharingPickerHostModifier` release) did not reproduce on iOS 27. The picker opened 4 of 4 times with the tinted button, and every picker scenario above ran without a crash. The round 1 logs are gone, so the root cause is not established; that build also had the confirmation dialog.

### Limitations

- Only the iOS 27.0 Simulator runtime is installed (26.5 was removed), and runtimes were not installed for this work. iOS 26 behavior (deployment target) was not run.
- Barcode rescanning and the "saved again before Undo" refusal were checked by code path only. (Round 3 ran both through the fixture proxy.)

### Validation (round 2)

- Failure modes 15–31 written before implementation; no unit tests added.
- `make quality-format-check`: passed. Debug simulator build: passed.
- Full serial iPad suite (`E91B597B…`, Xcode 27.0, 30/45-second allowances, `-collect-test-diagnostics never`, `PurchaseStoreStoreKitTests` skipped): **262 passed, 0 failed, 0 skipped**. Bundle `/tmp/macros-delete-saved-foods-r2.xcresult`.

### Repeat

1. Acquire the iPhone 17e lock, erase it, install this branch's Debug build, onboard with "I already know my numbers", load demo data, and set the search proxy with `xcrun simctl spawn <UDID> launchctl setenv PACKAGED_FOOD_SEARCH_BASE_URL_OVERRIDE <proxy URL>`.
2. Before each delete, run `sh docs/evidence/delete-saved-foods/db-snapshot.sh <UDID> <label>`. Run it again after the delete and after Undo.
3. Swipe a saved food left (or fling fully) in Add Food, the meal picker, and Settings, then tap Undo within 5 seconds. The `db-<label>-ZFOODITEM.txt` dump after Undo must `diff` empty against the one before the delete. `ZLOGENTRY` and `ZLOGGEDMEALCOMPONENTSNAPSHOT` digests must not change.
4. Relaunch with `agent-device open juan-test.cal-macro-tracker --relaunch --launch-args=-debugFailSavedFoodDeletes --launch-args=1` (or `-debugFailSavedFoodRestores`) to force one failure. The store must be unchanged, the row must stay, and the retry must work.

## Review round 3: cross-provider Undo and VoiceOver countdown

### Failure modes (written before implementation)

32. Undo of a deleted USDA `searchLookup` food that has a barcode inserts a duplicate after the same product was saved again through Open Food Facts (`barcodeLookup`, new UUID, different external ID). The reverse direction (deleted Open Food Facts food, re-saved through USDA search) duplicates too.
33. The restore check compares raw barcode strings, so the 12-digit UPC-A and 13-digit EAN-13 forms of one product (`012345678905` vs `0012345678905`) are treated as different foods.
34. The restore check goes too far: Undo is refused for a food nothing re-saved (a custom or label food that happens to share a barcode, or an unrelated external food), or the refusal deletes or changes the re-saved row.
35. The refusal is silent, uses a new message, or the banner disappears without the user learning why. It must be the existing "‹name› was saved again, so there is nothing to undo." alert.
36. VoiceOver turned on while the 5-second countdown runs: the old timer still fires and hides Undo.
37. VoiceOver turned off while the banner is up: no timer starts, so the banner stays forever.
38. A VoiceOver change restarts the countdown in a way that hides a newer banner, or keeps running behind a "Can't Undo" alert.
39. At AX5 Dynamic Type with a long food name, the banner clips or truncates the Undo button, grows so tall that it hides most rows, or overlaps the search field or Camera button.
40. An Undo save failure on Add Food or in the meal picker (not only Settings) is silent, loses the food, drops the banner, or blocks a retry.

### Fixes

- Undo now checks for a duplicate with a restore-specific query (`savedFoodDuplicating` in `FoodItemRepositoryPersistence.swift`). It matches the same row ID, or, for an external food, any `barcodeLookup` or `searchLookup` row with the same external product ID or barcode. Barcodes go through the existing `OpenFoodFactsIdentity.barcodeAliases` via `fetchBarcodeFood`, so `012345678905` and `0012345678905` match. A match refuses with the existing "‹name› was saved again, so there is nothing to undo." alert and leaves the store unchanged. Saving is unchanged: it still does not merge a USDA food with an Open Food Facts scan.
- VoiceOver is now part of the countdown task identity: `undoCountdownID` is nil while VoiceOver is on (as it already was during an error alert). Turning VoiceOver on cancels a running countdown. Turning it off gives a new id, so a fresh 5-second countdown starts.

### Evidence and results (round 3)

Same iPhone 17e, erased, Debug builds of `a74e9c5` (red) and this change (green), DEBUG Settings → Load Demo Data. UI driven only through the T3-bound `agent-device`; store state from [`db-snapshot.sh`](db-snapshot.sh). Raw snapshots, logs, and screenshots are in ignored `build/evidence/2026-11-07-delete-saved-foods-r3/`.

What was real and what was a fixture:

- Lookups: the app's existing DEBUG seam `PACKAGED_FOOD_SEARCH_BASE_URL_OVERRIDE` (set with `simctl spawn … launchctl setenv`) pointed at [`fixture-proxy.py`](fixture-proxy.py) on `127.0.0.1:8787`, not the live USDA or Open Food Facts services. It serves one product under both providers: USDA search `usda:999001` with barcode `0012345678905`, and the Open Food Facts barcode response `openfoodfacts:012345678905`. Its request log shows the real app calls: `GET /v2/foods/search?q=fixture%20skyr` and `GET /v1/packaged-foods/barcodes/0012345678905`.
- Barcode: the simulator has no camera. The fixture writes an EAN-13 PNG, added with `simctl addmedia`. In the real Camera screen, "Choose a Photo" picked it, and the app's Vision barcode scanner decoded `0012345678905`. Everything after that (Open Food Facts lookup, result card, Log, save) is the app's normal code path.
- VoiceOver: the simulator cannot run VoiceOver. The app reads `accessibilityVoiceOverEnabled`, which follows the system accessibility flag. I flipped it with `simctl spawn <UDID> defaults write com.apple.Accessibility VoiceOverTouchEnabled -bool true|false` followed by `notifyutil -p com.apple.accessibility.cache.vot.enabled`. No DEBUG override was added. The app responded live: with the flag on, the banner had no timer (verified 8 s and 13 s); with it off, the normal 5-second timer ran. No speech, focus, or announcement is produced this way.

| # | Failure mode | Check and evidence | Result |
| --- | --- | --- | --- |
| 32 | Cross-provider re-save duplicates on Undo | Logged the USDA fixture from search (one `searchLookup` row, barcode `0012345678905`). With the VoiceOver flag on so the banner outlives the trip, swiped Delete in Add Food, opened Camera, chose the barcode photo, logged the Open Food Facts result (new UUID, barcode `012345678905`), closed Camera, tapped Undo. **Red (`a74e9c5`):** Undo succeeded and the store held both rows; Add Food showed "2 on-device matches" (`db-r3-red-13-after-undo`). **Green:** "Can't Undo — Fixture Skyr Yogurt was saved again, so there is nothing to undo." ([`cross-provider-undo-refused.png`](cross-provider-undo-refused.png)); only the `barcodeLookup` row remains (`db-r3-green-04-after-undo`). The reverse direction (deleted Open Food Facts food re-saved by USDA search) uses the same query, but was not run in E2E: logging a search result closes Add Food, and with it the banner. | Passed after fix (reverse by code path) |
| 33 | Raw barcode comparison | The red and green runs above use 13-digit USDA vs 12-digit Open Food Facts barcodes; only the alias lookup matches them. | Passed |
| 34 | Over-refusal or row change | Refusal: the `ZFOODITEM` dump and all three digests are byte-identical before and after the refused Undo (`db-r3-green-03`/`04`). An unrelated external food (USDA `usda:999002`, no barcode) deleted while the Open Food Facts row existed was restored by Undo. Custom foods restored normally (Black beans, Brown rice, Apple, Cottage cheese). | Passed |
| 35 | Silent or new refusal message | Existing "Can't Undo" alert and message, banner still shown behind it (screenshot above). | Passed |
| 36 | VoiceOver on mid-countdown | Delete Almonds, flag on 0.7 s later. **Red:** banner gone at 8.7 s. **Green** (Apple): banner still present at 7.7 s and 13.5 s; Undo then restored Apple. | Passed after fix |
| 37 | VoiceOver off leaves banner forever | **Red:** banner still present 12 s after turning the flag off. **Green** (Banana, banner held 13 s with the flag on): after turning it off, present at 1.3, 2.5, 3.8, and 5.1 s, gone at 6.3 s. | Passed after fix |
| 38 | Restart hides a newer banner or runs behind an alert | The id is nil whenever an alert is up or VoiceOver is on, and SwiftUI cancels the old task on any id change. With the flag on, the banner stayed for 9 s after dismissing a "Can't Undo" alert, and for 7.7 s after closing Camera and after cancelling the photo picker. | Passed |
| 39 | AX5 layout with a long name | AX5 text size, 109-character fixture name ([`ax5-long-name-banner.png`](ax5-long-name-banner.png)). Undo is fully visible and hittable (129×63 pt). The name truncates to two lines ("Deleted Fixtur…"); the full name stays in the text's accessibility label. The banner is about 185 pt tall above the Camera button and inset into the safe area, so the list scrolls clear of it. The row itself wraps one word per line at AX5; that is the existing row layout, not part of this change. | Passed |
| 40 | Undo failure on Add Food and the meal picker | `-debugFailSavedFoodRestores 1`, one launch each. Add Food (Black beans) and the picker (Brown rice, selected): "Can't Undo — Forced save failure (DEBUG).", the store lacks the food while failed (19 rows), the banner is still there after holding the alert 10.6 s / 10.5 s and 1.5 s after OK, and the retry restores a byte-identical row (`db-r3-af-01`/`03`, `db-r3-pk-01`/`03`). The picker row comes back "Selected". | Passed |

Round 2's `settings-last-row-undo-banner.png` and `dashboard-meal-history.png` were replaced by the two round 3 images to stay within the five-image budget; they remain in commit `a74e9c5`.

### Owner device checks (not run here)

- VoiceOver on a real device: "Deleted ‹name›" is announced, Undo is reachable by swipe navigation, and the banner stays until acted on; turning VoiceOver off with the banner up hides it about 5 seconds later.
- iOS 26 (deployment target): banner, swipe action, and countdown on the iOS 26 runtime (only iOS 27.0 is installed here).
- Live services: the cross-provider Undo refusal with a real USDA branded food and its Open Food Facts barcode.

### Validation (round 3)

- Failure modes 32–40 written before implementation; E2E red on `a74e9c5`, green after the fix; no unit tests added.
- `make quality-format-check`: passed. Debug simulator build: passed.
- Full serial iPad suite (`E91B597B…`, Xcode 27.0, 30/45-second allowances, `-collect-test-diagnostics never`, `PurchaseStoreStoreKitTests` skipped): **262 passed, 0 failed, 0 skipped**. Bundle `/tmp/macros-dsf-r3-suite.xcresult`.

### Repeat (round 3)

1. Acquire the iPhone 17e lock, erase it, install the Debug build, onboard, and run DEBUG Settings → Load Demo Data.
2. `python3 docs/evidence/delete-saved-foods/fixture-proxy.py serve 8787`, then `xcrun simctl spawn <UDID> launchctl setenv PACKAGED_FOOD_SEARCH_BASE_URL_OVERRIDE http://127.0.0.1:8787`. Write the barcode with `fixture-proxy.py barcode <png>` and `xcrun simctl addmedia <UDID> <png>`.
3. Set the VoiceOver flag as above. Search "fixture skyr" and log it. Swipe Delete it in Add Food, open Camera → More camera options → Choose a Photo → the barcode → Log, close Camera, and tap Undo. Expect "Can't Undo" and one `barcodeLookup` row.
4. For the countdown, delete a food and flip the flag while the banner is up. Flag on: no timer. Flag off: the banner hides about 5 seconds later.
5. Reset with `agent-device settings text-size large` and the flag set to false.
