# Build 27 collection-view crash investigation

Media removed in the repo cleanup; retrieve with `git show 074b10994f1b68d9d7a8d6c54ed7effb90d5f1f5:docs/evidence/collection-feedback-loop/build27-nonrepro.mp4`.

## iOS 26 follow-up

**Reproduced on iOS 26.5 in both build 27 and pinned main.** Repeated Today hero expansion/collapse triggers UIKit's feedback-loop debugger. Its collected records show the first row's preferred height alternating by one physical pixel. Populated live Sharing updates did not reproduce the crash.

The root-cause follow-up supersedes the animation-removal workaround. Identical layout inputs produced 88/100-point heights from the nested lazy grid. An eager Grid and matching measurement/placement proposals keep smooth expansion, while an explicit Reduce Motion transaction prevents List-inserted animation. See [the iOS 26 follow-up report](ios26/README.md) for measured controls, primary sources, final iOS 26/27 GREEN and motion artifacts, and validation.

## Earlier iOS 27-only result

**Not reproduced in the earlier iOS 27 pass.** The inventory and ranked hypotheses below describe the unmodified snapshots, not the final fix.

Investigated on 2026-11-03 in the isolated `fix/collection-feedback-loop` worktree.
Main was pinned to `7034202b594ea43c819ec7c8b796e4b84213a201` (build 29).
The historical build used an unmodified `git archive 67e85ad` source snapshot (build 27), compiled in Debug for the simulator. This is not the TestFlight binary.

The supplied incident is consistent with UIKit detecting nonconvergent collection-view layout. It does **not** identify a screen or prove that app geometry state caused the loop. There are no app layout frames, exception reason, or UIKit collected records in the supplied thread.

## Ranked suspects

These are investigation priorities, not confirmed defects. Paths below are relative to `cal-macro-tracker/`. `27` means source at `67e85ad`; `main` means `7034202`.

### 1. Live Sharing rows, strongest release-specific lead

- `Features/Sharing/SharingDashboardScreen.swift:29-37` (same on 27/main): native `List` animates the entire dashboard value for 0.45 seconds. `SharingPersonRow` has a fixed 68-point ring beside three unconstrained wrapping text lines (`:130-167`). At 402 points, insets, ring, spacing, and disclosure indicator leave a narrow text column. Numeric updates can change wrapping and preferred row height during an animated snapshot.
- `Features/Sharing/SharingPersonScreen.swift` 27 `:60-98,116-139`; main `:66-104,122-145`: a single self-sizing ring/legend row, conditional goals, loading/empty substitutions, and food rows whose name and quantity/nutrition strings wrap. Totals, numeric text, and the food `ForEach` animate for 0.45 seconds during subscriptions.
- Counterevidence: ring dimensions are explicit, legend columns are fixed at 92 points (`Shared/MacroSummaryColumnView.swift:174-203`), and there is no geometry-to-state-to-row-size cycle in either Sharing view. Roster identity is `relationshipId`, food identity is `localEntryId` (`Features/Sharing/SharingSyncModels.swift:28,96`), not regenerated UUIDs.
- Release evidence: `8baff7c` changed the Sharing dashboard from `ScrollView/LazyVStack` to `List` between builds 25 and 26. `78841b0` combined person rings and legend into one row, enlarged the ring from 156 to 180, and changed the legend style in the same interval. `309939a` added cached-day/dashboard fallback and loading substitutions. **`0cbfd1c` added the live-update animations between builds 26 and 27.**
- Main retains these sizing/animation paths. Its later person-availability fixes (`142472e`, `f2d5bd4`) do not remove them.
- Reproduction limitation: the paired person showed “No macros shared today.” Navigation, empty/loading replacement, large text, and swipes were exercised, but populated live macro/food updates were not. No sharing scope, profile, invite, or server data was changed.

### 2. Today hero self-sizing and animated reveal

- `Features/Dashboard/DashboardScreen.swift` 27 `:219-254,402-409,464-480`; main `:231-266,414-421,476-492`: a large `VStack` is one `List` row. Tapping changes the ring diameter and animates a custom `RevealLayout` around `SecondaryNutritionDetailsView`'s `LazyVGrid`.
- `RevealLayout.sizeThatFits` measures with the incoming proposal, returns the child's width and a scaled height, then `placeSubviews` proposes the bounds width with an unspecified height. This is a concrete custom-sizing seam worth testing under different proposals, not proof of an inconsistency.
- `Features/Dashboard/MacroRingView.swift:93-107` uses diameters 269/321 plus stroke padding. Its secondary grid (`:124-154`) has wrapping Dynamic Type labels.
- Release evidence: `c38b8d5` and `c2acc77` introduced this hero/reveal work **before build 25**. It is not a new build-27 change.

### 3. Today scroll state, weaker than its surface appearance

- `DashboardScreen.swift` 27 `:189-194,384-399`; main `:201-206,396-411`: raw scroll offset drives compact-summary visibility (220/180 hysteresis) and bottom-button compaction (12/2 hysteresis), with animations on the surrounding subtree.
- Crucial counterevidence: the compact summary is a `ZStack` overlay, **not a top safe-area inset** (27 `:62-75`; main `:71-84`). It does not intentionally reserve space in the list.
- The bottom safe-area inset (27 `:111-114`; main `:123-126`) uses `compactActionsAreHorizontal: true` (27 `:347`; main `:359`). `App/BottomPinnedDualActionBar.swift:113-119` reserves the same 60-point button height in both horizontal modes. `BottomPinnedActionContainer` fixes its reported height (`App/BottomPinnedActionBar.swift:254-265`). Scroll compaction changes width, not the intended bottom-inset height.
- Tutorial geometry writes `frames` with equality guards (`Features/Dashboard/Tutorial/DashboardTutorial.swift:17-23,120-124`), used to position an overlay. Outside the tutorial, it does not feed measured row height back into row sizing.
- Build 27 adds the Add Food matched zoom source (`ca56d91`), not these thresholds or sizing rules. The ring `.id` is a constant string (27 `:251`; main `:263`).

### 4. Add Food search list and generic food forms

- `Features/AddFood/AddFoodSearchResults.swift:98-218`: a `List` with a horizontally scrolling suggestion header, zero minimum row height, explicit row insets, and asynchronously replaced search results. Offset updates reach `AddFoodScreen.swift:141-179`, which writes scroll tracking and animates camera-button compaction.
- `Shared/FoodNutritionRow.swift:33-75` has competing text columns with unrestricted wrapping. It is shared by search, Today food rows, meal forms, and quantity screens. Dynamic Type, long names, and numeric widths can legitimately change preferred heights; no measured-height state is used.
- Counterevidence: the search bottom action bar also has a constant reported height across compact/expanded modes (`App/BottomPinnedActionBar.swift:109-115`). These paths did not change between builds 25 and 27.
- Generic `App/FoodDraftEditorForm.swift` is a Form at 27 `:68`, main `:95`, used by manual food, log/review food, remote meal-component selection, edit-log, and reusable-food editing. Optional nutrition rows depend on editing/focus state, not geometry. Main adds focus scrolling and stable field IDs; those additions cannot explain build 27.

## Complete List/Form inventory

17 reachable declarations in both snapshots, plus one preview-only List. Risk is relative to this crash, not a general code-quality judgment.

| Declaration / route | 27 line | Main line | Relative risk / sizing evidence |
| --- | ---: | ---: | --- |
| `Features/Sharing/SharingDashboardScreen.swift`, populated Sharing roster | 29 | 29 | Higher: whole-list live animation and narrow wrapping text |
| `Features/Sharing/SharingPersonScreen.swift`, tap shared person | 44 | 50 | Higher: live animated self-sizing hero and food rows |
| `Features/Dashboard/DashboardScreen.swift`, Today / selected day | 176 | 188 | Higher: custom animated hero; scroll state with important fixed-inset counterevidence |
| `Features/AddFood/AddFoodSearchResults.swift`, Add Food Search | 98 | 98 | Medium: result replacement, nested horizontal header, wrapping nutrition rows |
| `App/FoodDraftEditorForm.swift`, manual/log/review/edit/reusable food | 68 | 95 | Medium: optional rows and keyboard; no geometry-sized rows |
| `Features/AddFood/MealEditorScreen.swift`, Manual > Create Meal / Edit Meal | 61 | 61 | Medium-low: changing component rows and suggested name; fixed action inset at 128 |
| `Features/AddFood/LogMealScreen.swift`, select saved meal | 43 | 43 | Medium-low: loading replacement and quantity-dependent text; fixed inset at 97 |
| `Features/AddFood/MealComponentQuantityScreen.swift`, edit meal component | 48 | 48 | Medium-low: shared wrapping row and keyboard/quantity changes; fixed inset at 70 |
| `Features/AddFood/MealComponentFoodPickerScreen.swift`, Create/Edit Meal > Add Food | 23 | 23 | Medium-low: async search replacement and selection checkmark changes row width (39-49), no geometry feedback |
| `Features/Settings/SettingsScreen.swift`, Settings | 25 | 25 | Low: conditional paid/settings rows, expandable sections, keyboard and paywall sheets |
| `Features/Settings/SettingsScreen.swift`, Saved Custom/External Foods > Show All | 327 | 331 | Low: wrapping saved-food name/description (main 362-369), stable model IDs |
| `Features/Sharing/SharingScreen.swift`, Sharing settings / invite entry | 26 | 26 | Low: long text/links and conditional invite rows, keyboard, no geometry observation |
| `Features/Onboarding/BodyProfileFormScreen.swift`, guided profile setup | 205 | 205 | Low: Dynamic Type selects VStack/HStack at 184-188; fixed numeric widths and conditional pace row, no measured-state loop |
| `Features/AddFood/LoggedMealDetailScreen.swift`, logged meal detail | 14 | 14 | Low: one-time snapshot load, shared nutrition rows, no geometry/size animation |
| `Features/Weight/WeightScreen.swift`, Settings > Weight | 15 | 15 | Low: week-grouped stable IDs, wrapping date text, fixed action inset at 40 |
| `Features/Weight/WeightEntrySheet.swift`, Weight > Log Weight | 27 | 27 | Low: numeric field, date picker, medium/large sheet detents at 49 |
| `Features/Backup/BackupImportSummarySheet.swift`, Settings > Import Backup preview | 15 | 15 | Low: counts/date range, medium/large sheet detents, action bar switches for accessibility size but not scroll |
| `Features/Sharing/SharingDashboardScreen.swift`, `#Preview("Sharing People")` only | 173 | 173 | Not reachable in the shipped app |

History (`Features/History/HistoryScreen.swift:16`) and Insights (`Features/Insights/InsightsScreen.swift:32,187`) use ScrollView, not List/Form. Their navigation can reach listed forms.
Camera's result-card `.id(content.kind)` and measured ScrollView height are not a List/Form in build 27. Camera details/review can navigate to the generic food Form. Main's inline camera editor also reuses it, but that addition postdates build 27. No camera source was edited.

## Release comparison

| Build | Commit | Commit time |
| --- | --- | --- |
| 25 | `9761515` | 2026-11-01 17:31:30 -0600 |
| 26 | `c09b97c` | 2026-11-01 19:53:14 -0600 |
| 27 | `67e85ad` | 2026-11-02 09:37:08 -0600 |
| 29 / investigated main | `7034202` | Pinned checkout |

`git diff 9761515 c09b97c` establishes the Sharing List conversion/hero changes.
`git diff c09b97c 67e85ad` isolates the new Sharing animations and Add Food zoom source.
No random `.id(UUID())` churn was found in either snapshot. Build 27's three explicit `.id` modifiers are a constant ring ID, a tutorial-step overlay ID, and camera result kind.

## Apple primary sources

1. [UIKit: preferredLayoutAttributesFitting](https://developer.apple.com/documentation/uikit/uicollectionreusableview/preferredlayoutattributesfitting(_:).md): default implementation adjusts attributes for self-sizing cells.
2. [UIKit: shouldInvalidateLayout for preferred attributes](https://developer.apple.com/documentation/uikit/uicollectionviewlayout/shouldinvalidatelayout(forpreferredlayoutattributes:withoriginalattributes:).md): a cell's changed attributes may require a larger layout refresh.
3. [SwiftUI: onScrollGeometryChange](https://developer.apple.com/documentation/swiftui/view/onscrollgeometrychange(for:of:action:).md): geometry changes frequently; Apple recommends transforming to a small value and avoiding broad app updates on every scroll change.
4. [Apple Developer Forums thread 694141](https://developer.apple.com/forums/thread/694141): developer reports quote UIKit's exception: “stuck in its update/layout loop,” including inconsistent self-sizing preferred attributes as one possible cause. UIKit asks for Console logs in the `UICollectionViewRecursion` category. Reports include width-rounding and estimated-size issues, but these are developer observations, not Apple-prescribed fixes.
5. [Apple Developer Forums thread 53843](https://developer.apple.com/forums/thread/53843): example of repeatedly dirtying layout while laying out a self-sizing label.

No public Apple API contract or exact numeric recursion threshold was found for the private `_UICollectionViewFeedbackLoopDebugger.printCollectedRecords(for:raiseException:)` symbol. The supplied stack plus documented sizing/invalidation behavior support the *class* of failure, not a particular app-level cause. A collection-backed system menu is also not excluded by an app-frame-free stack; List/Form is the main app-source search surface, not a certainty.

## Earlier iOS 27 reproduction attempts

- Allowed iPhone 17 A, `918D29B9-97D3-42C0-9C47-00605E01E8DB`, 402 x 874 points, iOS **27.0** only. Actual crash was iOS **26.6.2**.
- Acquired the filesystem lock. Automation initially refused because another session held A. Waited 120 seconds, then explicitly obtained the user's permission to close that stale automation session without shutdown/erase. B's filesystem lock remained owned elsewhere after the required 120-second retry; it was not taken or removed.
- Installed historical build 27 over the existing app with `xcrun simctl install`. Later installed current main the same way. Never erased, uninstalled, seeded demo data, changed sharing settings, or saved the synthetic long name.
- Captured UIKit at debug level with `xcrun simctl spawn <A> log stream --style compact --level debug --predicate 'subsystem == "com.apple.UIKit"'`. Captures were stopped explicitly.
- Build 27: expanded/collapsed hero, 20 alternating initial flings, search list 12 alternating flings, keyboard/query replacement, unsaved 127-character name, Show More nutrition rows, Dynamic Type large <-> largest accessibility size, landscape-left/right and portrait requests, sheets over Today, Sharing roster/person navigation, and 12 alternating Sharing-detail flings.
- Found populated October 30 data (3 items) without modifying it. At maximum Dynamic Type a pan revealed the pinned compact summary; then performed 30 alternating dashboard flings. Initial empty-day/hero-centered gestures did **not** reliably scroll because the hero has a high-priority gesture; those are not counted as verified threshold crossings.
- Main: repeated populated October 30/max-Dynamic-Type pan and verified the compact summary in the accessibility tree, 30 alternating flings, rotation requests, Add Food search scroll with observed row replacement, keyboard open/close, sheet dismissal, and 12 alternating Sharing-detail flings.
- Some synthesized scroll calls returned no progress or no visible change. These are harness/gesture limitations, not app crash reproductions. A semantic “Manual” target disappears while search is active; closing search restored it. No workaround modified app code.
- Final app was responsive on main's Today, original `large` text size and portrait restored, hero collapsed, no unsaved draft remaining. Closed this investigation's automation session/panel, left A booted, and removed only the lock acquired by this investigation.

### Limits

Neither a populated live Sharing update nor a synthetic long **saved row** was tested: the connected person had no macros today, and A's paired fixture was preserved. The 127-character name test covered an unsaved form field, not a wrapped persisted list row. Actual landscape relayout depends on the app's supported orientations; command success alone is not proof of it. No device with iOS 26.6.2 was available. Absence on 27 does not rule out the reported 26.6.2 crash.

## Earlier iOS 27 validation and artifacts

- Both Debug simulator builds succeeded. Historical log: `/tmp/macros-loop-build27.log`; main log: `/tmp/macros-loop-build-main.log`.
- Existing build warnings include SharingRemoteClient Decodable actor-isolation warnings and a tutorial overlay actor-isolation warning. No compiler errors.
- **Tests executed: 0.** No source fix was made, so format/fix validation and the conditional full serial iPad suite were not run. No xcresult or RED/GREEN claim.
- `build27-nonrepro.mp4` and `main-nonrepro.mp4`: compressed, no-crash investigation recordings, not RED/GREEN proof. Original recordings remain under `.investigation/`; the build-27 touch-overlay export timed out, but the underlying video exists.
- `uikit-build27.log.gz` and `uikit-main.log.gz`: compressed UIKit output filtered to the corresponding app process (PID 92396 for build 27, PID 8912 for main). The raw historical stream overlapped the main run because stopping its shell wrapper did not stop its simctl/log children; those children were subsequently stopped explicitly. Per-process filtering keeps the evidence separate. `capture-summary.json` records capture sizes, timestamps, and feedback-loop match counts.
- Captured app records: build 27, 15:53:09.731–15:59:03.226, 10,985 lines; main, 16:00:32.906–16:04:01.974, 6,232 lines. Both had zero feedback-loop matches.
- Video durations: build 27, 338 seconds; main, 129 seconds. They are compressed to 3 fps for storage, so they are not suitable for frame-timing measurements.
- `main-compact-summary.png`: decoded from the main recording at 18 seconds; confirms the compact-summary overlay was actually shown at the largest accessibility text size.
- `final-main-today.png`: responsive final Today screen, 402 x 874.
- All files were kept under 5 MB. That earlier non-reproduction pass made no commit or push.

## Original follow-up requests

Retained as investigation history. The iOS 26 follow-up supplies a local trigger and collected preferred-size records; the original tester's full report and last-screen context still matter.

1. Tester’s last screen and exact actions: Today vs Sharing, whether scrolling/expanding the ring, editing food, dismissing a sheet/menu, or receiving a live update; font size and any unusually long food/person names.
2. Full original `.ips`, including exception reason, application-specific information and unelided frames 10-103, not just the stack excerpt.
3. A device Console capture on iOS 26.6.2 that includes `UICollectionViewRecursion` / feedback-loop collected records immediately before the trap. Preferred/original attributes, repeatedly invalidated index path, collection frame, content offset, and insets can distinguish alternating row sizes from scroll/inset feedback.
4. With tester consent, a sanitized local backup or minimal synthetic reproduction fixture. Do not share invitation tokens or sharing identity secrets.
5. A permitted two-device test with populated same-day Sharing data and real incoming updates, ideally on 26.6.2. The new build-27 animation commit is the first bounded comparison to test once that path is implicated.
