# Camera inline Details evidence

Media removed in the repo cleanup; retrieve with `git show 074b10994f1b68d9d7a8d6c54ed7effb90d5f1f5:docs/evidence/camera-inline-details/baseline/e12-common-copy.png`.

## Result and limits

Details, label Edit details, and failed-barcode Enter manually use the shared editor inside the camera glass card. Name/brand/serving, all nutrients, source notes, Required Review, reusable-food behavior, Servings/Grams and Log remain available. Log collapses to Logged; Scan again starts a new item. Non-camera callers still push LogFoodScreen.

Observed on the locked iPhone 17e B (`F976E800-DA1F-4F20-B755-DFD964E33975`), iOS 27, 390 × 844. Tests ran serially on the locked iPad runner (`E91B597B-CE57-4C0B-A8A4-51CBDC3386AB`). No subagents, new simulators, main checkout edits, project-file edits, merges, version changes, deployments or uploads.

**Not an all-green claim:**

- Native iOS 27 `dismissalConfirmationDialog` did not intercept a dirty **dashboard zoom-cover** downward swipe. `green/zoom-dirty-swipe.png` shows the lost editor before the fallback. `interactiveDismissDisabled(isDirty)` now blocks that gesture, verified in `green/zoom-dirty-blocked.*`. Explicit Close/Scan again/Retake offer both discard and keep. Clean zoom swipe still dismisses (`green/final-clean-swipe.*`). iOS 26 runtime was unavailable.
- E12 common-copy screenshot is not pixel-identical: native Log button glass-edge pixels differ although its tree/geometry/copy match. Four other editor pairs match exactly below the system clock. See `extraction/comparison.json`.
- The final post-focus E12 replay also has four pixel-identical pairs, but four raw trees use XCTest fallback instead of the baseline UIKit-role-rich AX schema. Their wrappers, class roles and placeholder representation differ. Those tree comparisons are unavailable, not passes; raw snapshots and schema status remain in `final-noncamera/`. The original extraction's five tree comparisons still pass.
- No SE-class device exists in the permitted inventory. AX3/AX5 passed on 390 pt; 375 pt device behavior is not claimed.
- VoiceOver enabled: focus ring landed on the nutrition summary; one right swipe moved to Servings. Full rotor/field traversal was not completed.
- Offscreen Next initially failed, including a reader-only attempt and direct scroll-then-focus (`red/reader-only-focus-protein.*`, `red/direct-scroll-next-protein.*`). The final implementation scrolls explicitly, then completes focus when the Form row appears. Calories → Protein and Previous → Calories pass in `rerun/{next-protein,previous-calories}.*`; no timer or async retry was added.
- No simulator validates DataScanner teardown, privacy indicator, cold restart, torch or live barcode recognition. The owner accepted the four TestFlight hardware checks below.

## Artifacts and scenario ledger

PNG and JSON pairs share a basename. JSON is the actual accessibility snapshot, not a reconstructed tree. Some XCTest captures include underlying dashboard nodes and hidden camera descendants; those are not visible controls. `capture-assertions.json` validates fourteen captured state expectations. `artifact-manifest.json` contains media hashes.

| ID | Scenario | Red / baseline observation | Green observation and artifact |
|---|---|---|---|
| E1 | Barcode and real Photos OCR label expand inline | Both pushed Log Food: `red/barcode-details-push.*`, `red/label-details-push.*` | No push, 572 pt card and 193 pt drawn strip on 390 × 844: `green/final-zoom-expanded.*`, `green/label-expanded.*`, `heights.json` |
| E2 | Dashboard zoom and expansion morph | Regression guard, not expected red | `green/final-flow.mp4`, `zoom-contact.png`, `morph-contact.png`, `zoom-frames.json`: frame sampling shows no wide/left viewport sweep. One glass container follows expansion; no separate matched geometry layer |
| E3 | Edit Calories 160 → 200 | Old pushed editor worked, no separate failing edit assertion | Live header and saved 200 kcal: `green/barcode-edited*`, `green/final-flow-keyboard.*`, dashboard entry in `green/final-clean-swipe.*` |
| E4 | Missing required Calories/Protein | No baseline run of missing fixture | Log disabled initially and after one confirmation; enabled after both intentional-zero switches; logs: `green/required-review-{initial,one-confirmed,enabled,logged}.*`. Positive Calories removed its own unresolved review while Protein still blocked Log (`required-review-protein.*`) |
| E5 | Log stays camera | Old Details Log returned to dashboard: `red/log-leaves-camera.*` | `green/barcode-logged.*`, `final-flow-logged.*`; edited draft and multiplier used. Common reusable-copy creation verified in E12 |
| E6 | Dirty Scan again / Retake / Close | Isolated dirty behavior observed red; explicit dialog not run on base | Scan/Close dialogs + Keep preserve text: `dirty-scan-dialog.*`, `dirty-close-dialog.*`, `dirty-kept.*`; discard returns scanning: `dirty-discarded.*`. Label Retake keep/discard: `dirty-retake-{dialog,kept,discarded}.*` |
| E7 | Clean exits and swipe | No base red expected | Clean Close exercised repeatedly. Collapsed rename → Edit details → Retake is immediate: `renamed-clean-{open,retake}.*`. Clean zoom swipe returns Today: `final-clean-swipe.*` |
| E8 | Software keyboard / strip / toolbar | S3 exposed dashboard behind accessory gap; offscreen Next later failed | Strip visually zero, Form remains, Log/Done reachable: `final-flow-keyboard.*`, `final-keyboard.*`. Done restores 75% card. Name → Brand passed S2; final offscreen Next/Previous pass: `rerun/{next-protein,previous-calories}.*` |
| E9 | AX3, AX5, narrow device | No SE device available, no baseline failure claimed | Only Log pinned, summary/quantity scroll: `ax3-{expanded,scrolled}.*`, `ax5-final-{expanded,scrolled}.*`. Pre-fix AX5 Scan again overlapped Close (`ax5-scrolled.png`); label font capped at AX1 and final targets are separate |
| E10 | VoiceOver / Reduce Motion | Regression guard, no base failure claimed | VO focus ring on summary then Servings: `voiceover-{expanded,next}.png`; Reduce Motion resize recorded in `reduce-motion.mp4`. Settings before/on/restored captures included |
| E11 | Failed barcode Enter manually | Recovery reducer tests observed red before implementation; no base UI capture | Blank inline draft cannot Log until name; `recovery-{error,inline-disabled,ready,logged}.*` |
| E12 | Other callers unchanged | Real d53a313 editor captures in `baseline/e12-*` | Manual Continue → Log, saved food, grams Log, search, common-food edit/message/copy pass at extraction and final. Extraction: five trees identical. Both phases: four pixel-identical pairs, common-copy native edge difference. Final: four raw tree comparisons unavailable after backend fallback. `extraction/README.md`, `final-noncamera/comparison.json` |
| E13 | Landscape | No baseline failure expected | 65% editor / 35% strip, summary scrolls and Log pinned: `green/landscape.*` |
| R9 | Background editing | No base capture | Protected Draft survives Home → open; Scan again + discard works: `green/background-{return,scan-again}.*` |
| D7 | Second item | No base second-item run | Barcode 200 kcal → Log → Scan again → actual Photos OCR label renamed Second Inline Item → inline Log: `after-log-scan-again.*`, `label-renamed-expanded.*`, `second-item-logged.*` |
| Quantity | Grams and serving conversion | E12 grams baseline | 37 g → 42 g updates header to 181.6 kcal and dashboard persists 42 g: `inline-grams-{edited,logged,dashboard}.*` |

Intermediate captures remain for traceability. Prefer the `final-*`, `ax5-final-*` and named ledger captures over earlier debug states. `green/zoom-clean-swipe-dismissed.json` was captured during transition and is stale; `final-clean-swipe.*` is the settled result. One early required-switch tap hit its label rather than UISwitch; final confirmation captures were overwritten only after verified actual switch activation.

## Spikes

Order S1 → S3 → S2 → S4. All four passed on simulator. `spikes/README.md`, PNG/tree pairs, `spikes.mp4` and removed prototype source preserve the experiment. S1 uses clear row backgrounds, not a second filled surface. S3 collapses viewport minimum height and padding as well as its frame; production fixes the accessory safe-area background. S2 verifies the keyboard toolbar host. S4 verifies the single native glass shape; no tint or custom blur was added.

## Failure-first tests and final validators

`failure-modes.md` preceded the isolated test code; commit `bd50b52` precedes the feature implementation.

| Run | Result | Durable evidence |
|---|---|---|
| Initial red compile | Missing isDirty/recoveryDraftOpened | `validation/isolated-red-compile.txt` |
| Inert-stub red assertions | 38 tests, 13 assertion failures across 9 test cases: flow 28/4 assertions, editor 10/9 assertions | `validation/isolated-red-assertions.txt` |
| Isolated green | 39 tests, zero failures: flow 28, editor 10, layout 1 | `validation/isolated-green.txt` |
| Final reviewed full suite | 242 tests, zero failures, TEST SUCCEEDED | `validation/final-suite.txt` |
| Formatting / generic simulator build / JS lint | All pass; JS 93 files, zero warnings/errors | `validation/{format,build,lint-js}.txt` |
| Actual layout CSVs | All 960 measurements byte-identical at base, extraction and final | `height-comparison.json`, `{baseline,extraction,green}/heights.csv` |

The red assertion run completed its assertions, then hung during runner teardown; the owned xcodebuild process was terminated. It is red assertion evidence, not a normally completed test invocation. Green runs completed normally. Full suite intentionally excludes PurchaseStoreStoreKitTests, as authorized; no macOS, live-network or hardware test is claimed.

The retained baseline layout build log has trailing whitespace stripped; diagnostic text and outcomes are unchanged.

Final defensive pass: `defensive-review.md`. Only four newly unused stored wrapper inputs were removed; then the full 242-test suite and normal validators passed again. Test selectors and counts were not reduced.

The final focus follow-up retained both immediate focus for already-visible rows and appearance-triggered focus for virtualized rows. The final 242-test run includes that follow-up. `repeat.py` passed its focused-field assertions and the barcode edit/log, dirty gesture/confirmation, required-zero review and recovery paths.

## Repeat

Use this worktree, never the main checkout or an IGNOREDbuild directory. Acquire the device's `/tmp/macros-sim-locks/<UDID>` directory first; if owned, wait 120 s and retry, never remove another owner's lock. Stay below the four-booted-device budget. Use T3 device_open to obtain a bound driver and set `MACROS_DEVICE_DRIVER` to its absolute executable path. Every UI command goes through that bound driver.

```sh
cd /Users/juan/.t3/worktrees/cal-macro-tracker/camera-inline
git apply --check docs/evidence/camera-inline-details/fixture.patch
git apply docs/evidence/camera-inline-details/fixture.patch
DEVELOPER_DIR=/Applications/Xcode-26.4.1.app/Contents/Developer \
  xcodebuild -project cal-macro-tracker.xcodeproj -scheme cal-macro-tracker \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/macros-camera-inline-repro build
git apply -R docs/evidence/camera-inline-details/fixture.patch
xcrun simctl install F976E800-DA1F-4F20-B755-DFD964E33975 \
  /tmp/macros-camera-inline-repro/Build/Products/Debug-iphonesimulator/cal-macro-tracker.app
python3 docs/evidence/camera-inline-details/repeat.py
```

The patch is evidence only, never application source. Do not run the formatter while it is applied; formatting changes its reverse-apply context. Fixture modes: barcode, label, label-missing, recovery; `-CameraLayoutServings <amount>` sets starting servings. Repeat writes new captures into `rerun/`, leaving the original ledger intact. For real OCR, add `docs/app-store/fixtures/oat-crunch-nutrition-label.png` with explicit-device simctl addmedia, then Camera → More camera options → Choose a Photo → select the image → enter its name → Edit details.

E12: run `e12.py baseline` on the preserved base build and `e12.py extraction` on extraction commit 577405d, using the same simulator/inputs. It uses only synthetic foods. The clear-app-state command did not reliably clear this simulator's stored food rows, so unrelated dashboard log counts are not compared; editor inputs, normalized trees and exact pixel comparisons are the regression evidence.

Final replay: `e12.py final-noncamera`. An inherited demo store triggered the unrelated native rating prompt; an initial replay stopped there, and another stopped on duplicate identical saved fixtures. The repeat-safe helper now records/dismisses “Not Now” and selects the equivalent saved fixture by its current reference. The complete replay passed. `compare-e12.py <phase>` requires Pillow; it checks exact pixels and reports strict tree equality separately from backend-schema comparability. It does not remove mismatching wrappers or rewrite raw snapshots to claim equality.

Final suite:

```sh
cd /Users/juan/.t3/worktrees/cal-macro-tracker/camera-inline
DEVELOPER_DIR=/Applications/Xcode-26.4.1.app/Contents/Developer \
  xcodebuild -project cal-macro-tracker.xcodeproj -scheme cal-macro-tracker \
  -destination 'platform=iOS Simulator,id=E91B597B-CE57-4C0B-A8A4-51CBDC3386AB' \
  -derivedDataPath /tmp/macros-camera-inline-build -parallel-testing-enabled NO \
  -test-timeouts-enabled YES -default-test-execution-time-allowance 30 \
  -maximum-test-execution-time-allowance 45 \
  -skip-testing:cal-macro-trackerTests/PurchaseStoreStoreKitTests test
make quality-format-check
make quality-build
make lint-js
python3 docs/evidence/camera-inline-details/summarize.py
```

Copy the actual CAMERA_CARD_EVIDENCE CSV from each run before reinstalling/erasing that app. `summarize.py` checks the retained CSV hashes, captures and media manifest; historical local /tmp logs are optional once their excerpts are committed. `heights.json` explicitly distinguishes screenshot edges from AX descendant frames.

## Integration and cleanup

Widget comparison used `origin/feat/shared-person-widget` at `31fbc5a980114d39f55a5ec7560ed081cee81c03`, divergent since `da00bef`. Its 132 divergent paths include project/AppRootView/widget/sharing files; **only changes-log.md overlaps this feature**. The raw two-point diff also includes camera layout changes already in our d53a313 base, not new widget edits. No project, widget, sharing, dashboard or AppRootView file was edited here.

Text size restored to Large, Reduce Motion off, VoiceOver off, orientation portrait. The latest B session is closed and both acquired locks are released; reused devices were left booted rather than shutting down another worker's boot. The phone has the clean, uninstrumented final app, verified in `green/final-clean-normal-app.*` to open the normal camera hint. The owner's iPhone Air and all reserved devices were left untouched.

Coordination correction: an earlier B release/reacquisition conflicted with the migration worker. After notification, the automatic waiter was cancelled and the existing lock was left alone. The owner later identified a separate stale B lock left by a finished worker and explicitly authorized its atomic replacement. Subsequent runs acquired normally, yielded B to the waiting share-sheet worker, and released only locks acquired by this work.

## Owner TestFlight checks

Still required on hardware:

1. Expand Details, wait 10 seconds, confirm camera privacy indicator turns off.
2. Scan again, confirm live feed resumes and recognizes a barcode; no black gap before it starts.
3. Background while expanded, return with edits intact, Scan again successfully.
4. After inline Log, confirm indicator remains off until Scan again.

These checks validate teardown/restart, including retaining the frozen still until startScanning succeeds. They are deferred by owner decision, not simulator passes.
