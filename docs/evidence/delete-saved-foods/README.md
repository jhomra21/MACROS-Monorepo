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

## Evidence and results

Fixture: iPhone 17e `F976E800-DA1F-4F20-B755-DFD964E33975`, iOS 27.0, erased, then DEBUG Settings → Developer → Load Demo Data (20 custom foods, 432 log entries over 90 days). Debug build of this branch with Xcode 27.0 (`DEVELOPER_DIR=/Applications/Xcode-26.4.1.app/Contents/Developer`), the USDA proxy override only. The UI was driven through T3 device tools and `agent-device`. Store state was read with [`db-snapshot.sh`](db-snapshot.sh), which is read-only (`sqlite3 mode=ro`). Raw output, including `db-*.txt` snapshots and logs, is in ignored `build/evidence/2026-11-07-delete-saved-foods/`.

Before deleting anything, I created a saved meal "Almonds, Banana" through the meal builder and logged it once, so history contains a food-log and a meal-log snapshot.

| # | Failure mode | Check and evidence | Result |
| --- | --- | --- | --- |
| 1 | Logged entries removed or edited | Deleted Protein bar (30 entries, one today), Apple (3 entries), and Orange (0). Snapshots `db-2-meal-logged` → `db-3-after-deletes`: still 433 entries, identical totals (185,535 kcal / 11,315 P / 23,954 C / 4,979 F), and identical SHA-256 over every entry's ID, food link, date, name, serving, per-serving and consumed values, `updatedAt`, and `healthSyncVersion` (`c01b7aed…`). The logged-meal snapshot digest is also unchanged (`55499fcd…`). | Passed |
| 2 | Dashboard, History, widgets, Health, sharing change | `dashboard-after-delete.png`: today still 1,580 kcal with the Protein bar row. History lists both Protein bar entries. Widgets, Health, and sharing read only `LogEntry` (no `FoodItem` reference in `CalMacroWidget`, `Shared`, `Features/Health`, `Features/Sharing`), and the entry digest above covers every field they read, including the Health sync version. | Passed (Health/sharing by code path + store digest) |
| 3 | Common foods deletable | Swiping a common "Egg, Whole" row in Add Food shows no action; the drag falls through to a normal tap. Common foods stay at 3,283 across deletes and relaunches. | Passed |
| 4 | Meal component deleted | Almonds (used by the saved meal) shows no Delete in Add Food or Settings. The meal still lists both components in the store snapshot. | Passed |
| 5 | Blocked delete fails silently or after confirming | The swipe action is not offered for foods in a saved meal (live `@Query` of `MealComponent`). Opening the food shows the existing editor note: "Used by 1 meal… Delete is blocked while this food is in a meal." | Passed |
| 6 | Add Food list keeps the row | `addfood-swipe-protein-bar.png` → row removed immediately after Delete. | Passed |
| 7 | On-device search still finds it | `addfood-search-after-delete.png`: "protein bar" → "No on-device foods or meals match this search yet." Only network results appear. | Passed |
| 8 | Meal picker keeps the row or its selection | `picker-swipe.png`: Black beans selected, then deleted. The row vanished, and Add put only Almonds and Banana into the meal (2 foods, 270 kcal). | Passed |
| 9 | Settings lists keep it | `settings-swipe-apple.png`: Apple deleted from the Saved Custom Foods preview; Orange deleted from Show All. Both lists updated; store shows 16 custom foods. | Passed |
| 10 | Cancel or confirmation glitches | No confirmation: the trailing destructive swipe deletes like the app's existing diary-entry swipe and iOS lists generally. Before tapping Delete, swiping back cancels. See the crash note below. | Passed (design changed) |
| 11 | Swipe breaks tapping | Tapping rows still logs (Log Food opens), toggles picker selection, and opens the Settings editor. | Passed |
| 12 | Editing or re-logging an orphaned entry fails | Edited today's Protein bar entry to 1.25 servings and back, then used Log Again. No crash; 434 entries; no saved food re-created (custom stays 16). | Passed |
| 13 | Suggestions/recents reference the deleted food | Suggestion pills come from log history and open a draft built from the entry's own snapshot, so they keep working and still show the name. Kept intentionally: they represent history, not saved foods. Residual: if a pill or Log Food opens an external (barcode/search) food whose saved copy was deleted and the user edits its nutrients, the existing auto-update rule saves a new copy (its footer says so). Code analysis only. | Accepted, documented |
| 14 | Stale barcode cache | `fetchCachedBarcodeFood` reads `FoodItem` rows only, so a deleted barcode food is no longer a cache hit and the next scan uses the network lookup. Code analysis only; no barcode scanned. | Passed (code path) |

### Crash found and fixed during E2E

The first implementation used a destructive swipe followed by a confirmation dialog. Tapping Delete crashed with `UICollectionView … Invalid number of items in section`: the destructive role removes the row before the dialog, but the data still held it. A red-tinted non-destructive button avoided that, but opening the meal picker then crashed every time in SwiftUI's `ForEach` update (`SharingPickerHostModifier` release), reproduced 3/3 and gone once the tint was removed. The shipped version keeps the native destructive role and only offers it when the delete cannot be refused, so the row and the data stay consistent. Remaining risk: if the store save itself fails, the row could disappear while the data still holds it. The app then shows a "Can't Delete Food" alert; that path was not reproduced.

### Validation

- Failure modes written before implementation; no unit tests added.
- `make quality-format-check` and `make quality-build`: passed.
- Full serial iPad suite (`E91B597B…`, Xcode 27.0, 30/45-second allowances, `-collect-test-diagnostics never`, `PurchaseStoreStoreKitTests` skipped): **262 passed, 0 failed**. Bundle: `/tmp/macros-delete-saved-foods.xcresult`.

### Repeat

1. Acquire the iPhone 17e lock, erase it, install this branch's Debug build, onboard with "I already know my numbers", and load demo data.
2. `sh docs/evidence/delete-saved-foods/db-snapshot.sh F976E800-DA1F-4F20-B755-DFD964E33975 before`
3. Swipe left on Protein bar in Add Food → Delete; on Apple in Settings → Saved Custom Foods → Delete.
4. Run the script again with label `after` and compare: entry count, totals, and both digests must match; only the food list shrinks.
