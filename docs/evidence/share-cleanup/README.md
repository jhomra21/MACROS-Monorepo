# Share cleanup (Phase 1, no visible change)

## Failure modes (written before the code changes)

1. Merged share-sheet wrapper changes what the system sheet receives (image source vs URL), so the dashboard image loses its Save Photo JPEG path or the invite/backup sheet shares the wrong item.
2. Snapshot-to-totals property drops or swaps a field (fat/carbs order), so ring or legend values change on the Sharing dashboard row or person screen.
3. Shared summary formatter changes a separator (`·` vs `•`), the gram suffix (`g` vs none), or spacing, altering visible text at one of the four call sites.
4. Removing `SharingScope` breaks decoding: `SharingPerson` decodes the Convex `scope` object as a required key, and tests and previews construct it.
5. Share card render drifts (scale, background, color scheme) after the exporter file edit.
6. New file leaves a synchronized group (app, widget, tests) with wrong membership and breaks a target build.

## Proof of no change

A temporary XCTest (not committed) renders fixture data only:
the dashboard share card through `DailyShareImageExporter.exportImage`, the Sharing dashboard,
and two person screens (with goals and foods, and without goals) through a hosting controller.
It ran before and after the edits on the same simulator. Raw PNGs and the byte comparison live in the ignored
`build/evidence/2026-11-10-share-cleanup/`.

Results are recorded at the end of this file.

## Results

- Simulator: iPhone 17e F976E800 (locked, released after). Xcode 27.0 via `DEVELOPER_DIR`.
- Before vs after, `cmp` on PNG bytes: `share-card`, `sharing-dashboard`, `person-with-goals`, `person-no-goals` all byte-identical.
- Full serial suite excluding `PurchaseStoreStoreKitTests`: 262 tests, 0 failures. `make quality-build` succeeded; the widget builds from the same `Shared` and `Data/Models` synchronized groups.
- `swift-format lint --strict` on changed files and `git diff --check` clean.
- The Insights selected-value label and `FoodNutritionRow` text are not on a captured screen. Their strings were checked against the old literals by reading (`•` separator; no `g` suffix in the row).
