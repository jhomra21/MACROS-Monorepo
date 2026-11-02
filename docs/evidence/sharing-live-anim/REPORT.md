# Live Sharing Animation QA

## Setup

- Baseline: `a462fd6` (`feat/add-food-zoom`), Debug build.
- Updated build: this worktree, Debug configuration.
- Test A: iPhone 17, `918D29B9-97D3-42C0-9C47-00605E01E8DB`, display name Test A, Debug Pro.
- Test B: iPhone 17e, `F976E800-DA1F-4F20-B755-DFD964E33975`, display name Test B, sharing Macros + Foods with A.
- Both builds used the same app bundle and preserved simulator app data. Test A continued to list Test B after installing the updated build.
- Probe entry: “Live Animation Probe”, 600 kcal, P 35 g, C 60 g, F 15 g. It was deleted from Test B at the end.
- The temporary custom food definition was also deleted from Test B’s saved foods after the final log entry was removed.

## Findings

- Push/first frame: `before/person-first-frame.png` shows the baseline zero/empty state. `after/person-first-frame.png` shows the current 600 kcal, macro totals, and food row already present on the first captured updated screen, with no zero-value loading flash.
- Baseline update: `before/person-add-correct.mp4` captured the person screen while B logged the probe. It contains the pre-update and post-update states without intermediate ring or number motion. `before/frames/person-add-*.png` are 30 fps contact sheets derived from that clip.
- Updated Sharing-list insertion: `after/dashboard-add.mp4` captured B logging the probe while A remained on the Sharing list. `after/frames/dashboard-add-*.png` show the row totals and small rings advancing from zero to 600 kcal.
- Updated person screen: `after/person-remove.mp4` captured B deleting the probe while A remained on Test B’s person screen. The 30 fps sheets in `after/frames/person-remove-*.png` show the calorie value changing from 600 to 0, the rings shrinking, and the food row leaving.
- Updated Sharing list: `after/dashboard-delete.mp4` captured the same deletion with A on the Sharing list. Its sheets in `after/frames/dashboard-delete-*.png` show the small rings and totals line changing from 600 kcal to 0.
- The added and removed food used the same local entry when editing; `SharedFood.id` is `localEntryId`, not its array index (`cal-macro-tracker/Features/Sharing/SharingSyncModels.swift:96`).
- Animation timing follows `MacroDashboardRingPanel`’s `.animation(reduceMotion ? nil : .smooth(duration: 0.45), value: totals)` at `cal-macro-tracker/Features/Dashboard/MacroRingView.swift:104`. `MacroSummaryColumnView.currentValueText` now has `.contentTransition(.numericText())` so legend values roll inside that transaction.

## Validation

- `make quality-format-check`: passed.
- `make quality-build`: passed.
- Serial iPad Air 11-inch simulator suite, excluding `PurchaseStoreStoreKitTests`: 225 passed, 0 failed, 0 skipped.
- `git diff --check`: passed.

## Artifacts

- `before/person-first-frame.png`
- `before/person-add-correct.mp4`, `before/frames/`
- `after/person-first-frame.png`
- `after/dashboard-add.mp4`, `after/frames/dashboard-add-*.png`
- `after/person-remove.mp4`, `after/frames/person-remove-*.png`
- `after/dashboard-delete.mp4`, `after/frames/dashboard-delete-*.png`

Each retained clip and contact sheet is under 5 MB. The abandoned initial recorder output (`before/person-add.mp4`) was invalid and is not evidence.
