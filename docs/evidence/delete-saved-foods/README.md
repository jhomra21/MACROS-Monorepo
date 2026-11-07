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
| 18 | Settings lists not refreshed after Undo | Saved External Foods' only row comes back after Undo (`settings-last-row-undo-banner.png` shows the empty state and banner first). Saved Custom Foods preview: Banana comes back (`db-30`/`db-31`). | Passed |
| 19 | Full swipe has no Undo | A full fling across the Fage row in Settings deletes it and shows the banner. | Passed |
| 20 | Banner timer stuck or stale | Without Undo, the banner is gone after about 5 seconds (Black beans in the picker, Banana in Add Food after 6.5 seconds). With the countdown paused during a "Can't Undo" alert held for 7 seconds, the banner was still there 2 seconds after OK and Undo worked. The task is tied to the view and its id; code review confirms no timer outlives the screen. | Passed |
| 21 | Repeated deletes | Deleted Fage then Almonds in Add Food. One banner, "Deleted Almonds". Undo restored only Almonds: the dump differs from before only by the missing Fage row (`db-14`/`db-16`). | Passed (defined behavior) |
| 22 | Last row breaks the list | Settings → Saved External Foods' last row, and Add Food's only "protein bar" match, both turn into the empty-state text with the banner, and Undo brings them back. With the old destructive role, the same Settings swipe crashed (see crash notes). | Passed after fix |
| 23 | Undo duplicates a re-saved food | `restoreReusableFood` checks by ID, external product ID, and barcode before inserting. Code path only; not reproduced in E2E. | Passed (code path) |
| 24 | Forced delete failure | `-debugFailSavedFoodDeletes 1`, one launch per surface. Add Food (Apple), the picker (Banana, selected), and Settings preview (Apple): "Can't Delete Food — Forced save failure (DEBUG)." (`addfood-forced-failure.png`), the store dump is unchanged (`db-17`/`18`, `21`/`22`, `25`/`26`), the row stays, and the picker row stays "Selected". The retry deletes (`db-19`, `23`, `27`), and Undo restores identical rows (`db-20`, `db-24`). No crash. | Passed |
| 25 | Undo failure | `-debugFailSavedFoodRestores 1`: Undo shows "Can't Undo" (`undo-failure-alert.png`), the store still lacks the food (`db-28`), and the banner stays. The first run showed the countdown expiring behind the alert, so the food could not be retried. The fix pauses the countdown during the alert. Re-run: alert held 7 seconds, banner still present, second Undo restored the row (`db-30`/`db-31`). (The first run left Apple deleted in the fixture.) | Passed after fix |
| 26 | VoiceOver | Simulator has no VoiceOver, so I read the iOS accessibility tree through the macOS Accessibility API (`ax-actions.swift` in the raw folder). Saved food rows expose the custom action "Delete"; common rows ("Egg, Whole") do not. Performing that action on Cottage cheese deleted it and showed the banner, and Undo restored it identically (`db-36`–`38`). The Undo button is a normal button in the tree. The announcement and the no-timer-with-VoiceOver branch are code only. | Passed (announcement by code) |
| 27 | Stale meal guard | Saved meal Almonds + Banana: Almonds has no swipe action (the drag falls through to a tap, as in round 1). Edit the meal to remove Almonds and save: Almonds now offers Delete. Delete the saved meal: Banana becomes deletable and was deleted. The guard is a live `@Query` of `MealComponent`. | Passed |
| 28 | Logged meal snapshots change | Logged the meal (`db-32`: 435 entries, 2 meal snapshots `4d40cca7…`). Edited the meal, deleted the saved meal, then deleted Banana: entry digest `fcacaa1f…` and meal snapshot digest `4d40cca7…` unchanged through `db-38`. `dashboard-meal-history.png`: "Almonds, Banana" still logs 270 kcal. | Passed |
| 29 | External food cannot be re-added | The external Fage yogurt deleted by the crash run was found again by USDA search and logged. The store has one `searchLookup` row, new UUID, same `usda:2756461` ID, no duplicate. Barcode rescanning was not run (no camera in Simulator); it uses the same `FoodItem` lookup as round 1 item 14. | Passed (search); barcode by code path |
| 30 | Digest overclaims | Full-column, NULL-preserving dumps as above. Across all 39 snapshots, the `LogEntry` digest changes only when something was logged (432 → 433 → 434 → 435), never on a delete, failure, or Undo. | Passed |
| 31 | Banner styling or occlusion | Untinted `appGlassRoundedRect` (Liquid Glass on iOS 26+), safe-area inset above the search field, Camera button, and keyboard (screenshots). | Passed |

### Crash notes

- Round 1: a destructive swipe followed by a confirmation dialog crashed with `UICollectionView … Invalid number of items in section`. The destructive role removes the row before the dialog, but the data still held it.
- Round 2, root cause: the round 1 build crashed on a full swipe of the last Saved External Foods row with `NSInternalInconsistencyException: attempt to delete item 0 from section 12 which only contains 0 items before the update` (raw `crash-1-settings-fullswipe.ips`). The food was deleted in the store. `role: .destructive` deletes the item in UIKit first; SwiftUI's diff (row replaced by the empty-state row) then deletes it again. Any change other than "this row disappears", such as a failed save or an empty-state row, hits the same mismatch. The fix is a non-destructive button tinted red, so every outcome goes through SwiftUI's normal diff. This round confirmed the empty-state and failed-save paths.
- The round 1 picker crash blamed on the red tint (`SharingPickerHostModifier` release) did not reproduce on iOS 27. The picker opened 4 of 4 times with the tinted button, and every picker scenario above ran without a crash. The round 1 logs are gone, so the root cause is not established; that build also had the confirmation dialog.

### Limitations

- Only the iOS 27.0 Simulator runtime is installed (26.5 was removed), and runtimes were not installed for this work. iOS 26 behavior (deployment target) was not run.
- Barcode rescanning and the "saved again before Undo" refusal were checked by code path only.

### Validation (round 2)

- Failure modes 15–31 written before implementation; no unit tests added.
- `make quality-format-check`: passed. Debug simulator build: passed.
- Full serial iPad suite (`E91B597B…`, Xcode 27.0, 30/45-second allowances, `-collect-test-diagnostics never`, `PurchaseStoreStoreKitTests` skipped): **262 passed, 0 failed, 0 skipped**. Bundle `/tmp/macros-delete-saved-foods-r2.xcresult`.

### Repeat

1. Acquire the iPhone 17e lock, erase it, install this branch's Debug build, onboard with "I already know my numbers", load demo data, and set the search proxy with `xcrun simctl spawn <UDID> launchctl setenv PACKAGED_FOOD_SEARCH_BASE_URL_OVERRIDE <proxy URL>`.
2. Before each delete, run `sh docs/evidence/delete-saved-foods/db-snapshot.sh <UDID> <label>`. Run it again after the delete and after Undo.
3. Swipe a saved food left (or fling fully) in Add Food, the meal picker, and Settings, then tap Undo within 5 seconds. The `db-<label>-ZFOODITEM.txt` dump after Undo must `diff` empty against the one before the delete. `ZLOGENTRY` and `ZLOGGEDMEALCOMPONENTSNAPSHOT` digests must not change.
4. Relaunch with `agent-device open juan-test.cal-macro-tracker --relaunch --launch-args=-debugFailSavedFoodDeletes --launch-args=1` (or `-debugFailSavedFoodRestores`) to force one failure. The store must be unchanged, the row must stay, and the retry must work.
