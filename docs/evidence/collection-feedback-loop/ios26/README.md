# iOS 26 collection feedback-loop investigation

## Finding

Reproduced in unmodified build 27 (`67e85ad`) and pinned main/build 29 (`7034202b594ea43c819ec7c8b796e4b84213a201`), on the same iPhone 17 simulator, iOS 26.5 (23F77), 402 × 874 points, 3× display.

The trigger is **repeated expansion/collapse of the Today hero**, not a demonstrated Sharing defect. At 2026-11-03 23:24:05 UTC, UIKit logged:

```text
[com.apple.UIKit:UICollectionViewFeedbackLoopDebugger]
Collection view <UpdateCoalescingCollectionView ...> is stuck in its update loop.
Reason: "PreferredAttributes"; invalidatedItems: ["(0-0)"].
preferredSize: (402.0, 407.6666666666667) -> (402.0, 407.3333333333333)
preferredSize: (402.0, 407.3333333333333) -> (402.0, 407.6666666666667)
```

The records repeat for 100 layout passes. The collection frame is `(0 0; 402 874)`, content offset `{0, -116}`, adjusted insets `{116, 0, 102, 0}`. The same first hero row alternates by one physical pixel. This is direct sizing evidence, not an inference from a stack alone.

Pinned main also traps at **23:25:59 UTC**, alternating `403.0` and `403.3333333333333` points. Both `.ips` reports contain `EXC_BREAKPOINT`, `_assertionFailure`, `_setNeedsVisibleCellsUpdate`, compositional invalidation, many recursive `_updateVisibleCellsNow` frames, and SwiftUI `UpdateCoalescingCollectionView.layoutSubviews`. Two private UIKit frames are unsymbolicated in these simulator reports. UIKit's collected records explicitly identify its feedback-loop debugger. This reproduces the reported failure class, but does not prove the original tester was on Today.

## Root-cause follow-up, 2026-11-04 UTC

The animation removal in `53e2932` is superseded. The reproducible app-level cause is **non-idempotent measurement of the nested lazy grid during the animated reveal**, not fractional multiplication alone.

Temporary instrumentation (`layout-probe.patch.gz`, applied to pinned main `7034202`) logged every reveal measurement and placement, animation progress, `displayScale`, and the hero VStack's measured size. It did not write geometry back to state. The retained logs are isolated by app PID, because stopping a shell wrapper did not immediately stop its simulator log children.

### Logged causal controls

| Control | Actual toggle callbacks | Fit calls | Identical proposal/progress groups with different child sizes | Result |
| --- | ---: | ---: | ---: | --- |
| Original animated `LazyVGrid`, PID 42933 | 5 | 1212 | 97 | feedback-loop trap |
| Same lazy grid, always measure with unspecified height, PID 43774 | 5 | 1357 | 101 | same trap |
| Eager `Grid`, original animation and unrounded multiplication, PID 44316 | 124 | 18660 | 0 of 7254 groups | no feedback loop |

These are callback/measurement counts, unlike the later uninstrumented UI tap-request counts. Full numeric summaries are in `layout-measurements.json`; the three compressed logs preserve the actual inputs and outputs.

At **00:17:02.977–00:17:03.025 UTC**, the original layout repeatedly logs:

```text
width = 362, displayScale = 3, progress = 0.020545798082464
proposal height = nil: child height = 88, result height = 1.8080302312568453
proposal height = nil: child height = 100, result height = 2.054579808246415
proposal height = 45.79248351906196: child height = 88 AND 100
```

`progress` is unchanged throughout the terminal remeasurement loop. The child differs by **12 points** for the same proposal, not floating-point epsilon. After multiplication the difference is **0.2465495769895697 points**, or **0.739648730968709 physical pixels** at 3×. At **00:17:03.050 UTC**, UIKit reports the first row alternating between **407.6666666666667 and 407.3333333333333 points**. Its layout-generated value is always the previous value. The cell origin alternates between `y = 0.333333` and `y = -0`. The records continue through 100 passes.

The geometry observer's last delivered inner-VStack size before the tight loop was `(362, 387.1362794367891)` at **00:17:01.655 UTC**. This excludes the outer top/bottom row padding. Geometry-change callbacks stop during the tight loop, while the synchronous fit/placement logs continue. This observer is therefore not being mistaken for UIKit's final cell-height measurement.

**Mechanism:** placement and the next sizing pass of the lazy subtree keep producing different answers. The reveal scales those different answers at a fixed in-flight progress; pixel alignment turns their subpixel difference into the observed one-pixel preferred-size difference. UIKit accepts a new preferred size, invalidates the layout, and remeasures, receiving the other answer again. There is no fixed point, and the synchronous invalidation cycle prevents the animation from advancing to another frame. Interrupting the animation exposes the problematic intermediate value; it is not evidence that SwiftUI incorrectly completed an animation at that value.

The 12-point difference matches configured grid spacing, but these logs do **not** identify a private lazy-grid cache entry or prove exactly which internal spacing estimate changed. Nor do they establish UIKit's private rounding formula. The proven defect is the unstable measurement boundary; the fix does not depend on either private implementation guess.

### Hypotheses resolved

- **Unrounded `height * progress` alone:** not the cause. The eager-grid control retains exactly that unrounded calculation and passes 124 reversals; every unspecified-height child measurement is `99.33333333333333` points (2165 measurements).
- **Different incoming heights / text wrapping alone:** insufficient. The unspecified-height control still returns `88` and `100` for the same width and fixed progress and crashes at **00:18:28.006 UTC**. Original measurements at zero, infinity, finite, and unspecified heights show the same discrepancy.
- **Inner content measurement instability during List remeasurement:** demonstrated by identical-input discrepancies, then removed by the eager-grid control without removing animation, clipping, or List.
- **An interrupted progress value must be reset:** unsupported. The fixed layout handles the same repeated interruption pattern; no progress reset, lockout, or delayed completion is needed.
- **Measurement versus placement mismatch:** also real. Eager Grid legitimately compresses under finite-height proposals. The first eager control's fit heights ranged from `90.66666666666666` to `99.33333333333333`; placing with unspecified height clipped the bottom labels. Final measurement now uses the same width/unspecified-height proposal as placement. The final expanded screenshot verifies all six complete labels.

## Historical RED runtime and isolation

- Initial `df -h /`: 68 GiB available, above the required 20 GiB.
- Both `/Applications/Xcode.app` and `/Applications/Xcode-26.4.1.app` report Xcode 27.0 (27A266a); the directory name is not the toolchain version. Installed SDK: iOS Simulator 27.0.
- Apple rejects `xcodebuild -downloadPlatform iOS -buildVersion 26.6.2 -architectureVariant arm64`: not available for download.
- Apple's downloadable catalog lists 26.0, 26.0.1, 26.1, 26.2, 26.3.1, 26.4, 26.4.1, and **26.5**, plus beta/RC variants. The newest offered stable 26.x runtime is **26.5 (23F77)**. The arm64 catalog size is **8,522,901,969 bytes**; installed storage reports **7.9 GiB**.
- Installed with `xcodebuild -downloadPlatform iOS -buildVersion 26.5 -architectureVariant arm64 -exportPath /tmp/macros-ios26-runtime`. The command downloaded and installed it and exported a runtime bundle. Runtime image ID: `1B4E45A9-D521-4894-BFB5-243420B8CCF9`.
- Created exactly one simulator, `MACROS-iPhone-17-iOS26-crash`, UDID `4EFBA68F-F1C7-41C5-AEB9-E800FCBA40AC`. No runtime/device was deleted.
- Four devices were initially booted. Acquired the unclaimed iPhone 17e lock, shut it down to free a slot, and retained that lock through cleanup. Never exceeded four booted devices. The prohibited Air/owner/media devices were untouched.
- A (`918D29B9-97D3-42C0-9C47-00605E01E8DB`) and the new simulator were locked before use. All shell commands started in the isolated `collection-loop` worktree. No subagents, camera edits, version bump, upload, merge, or owner-checkout use.
- Apple primary sources: [documented download/import commands](https://developer.apple.com/documentation/xcode/downloading-and-installing-additional-xcode-components.md), [runtime catalog](https://devimages-cdn.apple.com/downloads/xcode/simulators/index2.dvtdownloadableindex). Earlier sizing/invalidation references remain in the parent README.

## Builds and setup

Historical source was a detached temporary worktree at `/tmp/macros-loop-build27-worktree`, created from `67e85ad`. Both revisions were built in Debug with:

```sh
xcodebuild -project <absolute-project> -scheme cal-macro-tracker \
  -configuration Debug \
  -destination 'platform=iOS Simulator,id=4EFBA68F-F1C7-41C5-AEB9-E800FCBA40AC' \
  -derivedDataPath <separate-/tmp-derived-data> build
```

Bundle versions were verified as 27 and 29. Normal simulator signing is necessary: initial builds with `CODE_SIGNING_ALLOWED=NO` compiled but failed on launch because SwiftData could not find the App Group entitlement. The two 17:08 local crash reports are that unrelated setup error, not RED evidence. Rebuilding with normal simulator signing fixed startup without a source edit.

All UI actions used the UDID-pinned CLI returned by T3 `device_open`. UIKit capture and simulator video ran during attempts:

```sh
xcrun simctl spawn <UDID> log stream --style compact --level debug \
  --predicate 'subsystem == "com.apple.UIKit" OR eventMessage CONTAINS "feedback loop" OR eventMessage CONTAINS "UICollectionViewRecursion"'
xcrun simctl io <UDID> recordVideo --codec=h264 <absolute-mp4>
```

The persisted post-crash log supplied the collected records; the live stream alone did not retain them. Search the **`UICollectionViewFeedbackLoopDebugger` category**, not only the older `UICollectionViewRecursion` name.

## RED steps and timestamps (UTC, 2026-11-03)

1. Fresh build-27 simulator: complete manual-goal onboarding with 2200 kcal / P160 / C220 / F70; disable reminders and skip tutorial.
2. A was already sharing on the development Convex backend. Its Debug Pro flag was actually off at inspection; enabled it through Developer settings, without loading demo data. Created an invite in Settings > Sharing, enabled sharing on the receiver as `iOS26 Loop Probe`, pasted the token, and accepted. No invitation tokens are included in committed evidence.
3. On receiver Sharing roster, observe A change **0 -> 215 kcal** after logging Brown rice on A at approximately 23:12:28.
4. At maximum accessibility size, send successive A logs: yogurt 23:13:34, Apple 23:13:55, Almonds 23:14:09, then Banana. The receiver reached 700 kcal. Perform 18 + 30 alternating flings and orientation requests. Single-row roster flings sometimes had no measurable movement.
5. Open A's detail. Enable **Macros + Foods** in both directions through the per-person pickers. Send Black beans 23:16:31, Brown rice 23:16:43, yogurt 23:16:56, Apple 23:17:11, Almonds 23:17:27. Scroll incoming food rows at accessibility size (40 + 40 alternating flings), change font size and request both landscape directions/portrait.
6. Log a 116-character yogurt description at 23:18:13, then Apple at 23:18:26. Verify a persisted wrapping food row on the receiver (the sharing protocol truncates the transmitted name). Scroll another 40 flings. Delete only the newly logged Apple through Edit Entry > Delete Entry, while receiver scrolls 24 + 18 flings. Receiver totals change **1625 -> 1530 kcal**. No Sharing crash.
7. Receiver Add Food: search `chicken`, submit keyboard, verify actual result replacement and down/up scrolling at normal and largest accessibility size. Raw alternating flings sometimes dismissed the sheet instead of scrolling; those are not counted as verified search scrolling.
8. Populate receiver Today using normal UI logging: Chicken Breast, a long-named toast, Yuca Fries, Zucchini Pickled. Verify **4 entries**, **585.4 kcal**, **P29.9 / C65 / F23.2**, and secondary nutrition values.
9. On Today at standard `large` text size, issue `press <Expand nutrition details ref> --count 12`. **Crash at 23:24:05 UTC**, within the repeated tap sequence. The following Dynamic Type/scroll commands in that shell chain never ran. The runner reported `XCTEST_RECORDED_FAILURE` because the app had trapped; the `.ips` and UIKit records establish the actual failure.
10. Install unmodified pinned main over the same app data, relaunch, and repeat 12 hero taps. **Crash at 23:25:59 UTC**, without needing more live updates, search, rotation, or a fresh fixture.

The original build-27 post-pairing RED video is **728.217 seconds** (committed 3-fps copy: 728.333 seconds). The focused clip is **36.250 seconds**; the main RED recording is a minimal **22.333-second** repeat. The preceding sharing/search activity is a broad negative test, not proof that those paths cannot fail under other conditions.


## Final fix

Only two Dashboard source files change, with no camera source changes:

- `SecondaryNutritionDetailsView`: replace the six-item `LazyVGrid` with two eager `GridRow`s in `Grid`, retaining three columns, 12-point spacing, nutrient order, and existing text styling. All six cells are known during sizing.
- Restore `RevealLayout`, clipping, opacity, and the original `.smooth(duration: 0.35)` expand/collapse animation, including tutorial-driven collapse.
- Measure the full child with `ProposedViewSize(width: proposal.width, height: nil)`, matching placement instead of compressing it to the current reveal height.
- Use a shared expansion `Transaction`. With Reduce Motion off, it contains the original smooth animation and does not disable animations. With Reduce Motion on, it has nil animation **and** `disablesAnimations = true`, preventing List from inserting an animation.

There is no pixel-rounding heuristic, fixed height, timer, delayed state, OS check, extra model, geometry-state feedback, or blocked input. The layout continues reporting `childHeight * progress` without rounding. All diagnostic source changes were removed; only their replay patch/logs remain as evidence.

### Reduce Motion, measured rather than assumed

A real Settings > Accessibility > Motion toggle was verified visually and through the inner switch's checked value. Tapping the outer accessibility label did not change the switch; that unsuccessful setup was not counted as a passing check.

A temporary readback at **00:36:34–00:36:58 UTC** confirmed `SwiftUI reduceMotion = 1` and `UIAccessibility.isReduceMotionEnabled = 1`. Despite that, the original nil-animation transaction still produced many intermediate ring sizes inside List. `reduce-motion-readback.log` preserves those values. An explicit disabled-animation transaction corrected this, without changing normal-motion behavior.

Final **uninstrumented** captures:

- Normal: **161 captured frames**, **83 intermediate-size frames**. The saturated blue arc's right edge traverses `335 → 361` points and back, with a maximum adjacent captured change of **3 points**, rather than the 26-point endpoint jump. Dense original-frame strips show both directions. This is visual/captured-frame evidence, not a device ProMotion frame-time benchmark.
- Reduce Motion: **74 captured frames**, only right-edge values **335 and 361**, **zero intermediate-size frames**, four direct state changes. The system setting was on. Returned it to its original off state afterward.

The reproducible pixel probe scans the source frames scaled to 402 × 874, over `x = 200..<390`, `y = 120..<480`, for the blue arc (`b > 150`, `b-r > 70`, `b-g > 30`), then records its rightmost x coordinate. `motion-measurements.json` includes every source frame index, presentation time, and result. JPEG strips use consecutive captured frames, not generated interpolation. Raw full-resolution source clips remain in `/tmp/macros-loop2-release-{normal,reduced}-motion.mp4`.

## Guidance and primary sources

Read the installed `apple-design` and `animate` skills before designing. Their relevant guidance is continuous, interruptible state transitions, reversing from presentation state, avoiding unnecessary layout work, and providing a real reduced-motion path. `swiftui-performance-audit` was absent from the global skills directory but available through the installed skill loader; its layout-thrash, stable identity, targeted instrumentation, and same-reproduction verification guidance was used. No subagent was started.

Apple sources consulted, and what each establishes:

1. [Layout](https://developer.apple.com/documentation/swiftui/layout.md) and [sizeThatFits](https://developer.apple.com/documentation/swiftui/layout/sizethatfits(proposal:subviews:cache:).md): the parent may probe repeatedly with different proposals; `sizeThatFits` reports the composite size and placement receives the chosen bounds. An unspecified dimension requests ideal size. This supports width-only natural-height measurement, not arbitrary cached or fixed heights.
2. [Animatable](https://developer.apple.com/documentation/swiftui/animatable.md) and [animatableData](https://developer.apple.com/documentation/swiftui/animatable/animatabledata-6nydg.md): SwiftUI writes interpolated values on successive frames. A fixed progress during synchronous remeasurement is not a new animation frame or proof of an incorrect final state.
3. [LazyVGrid](https://developer.apple.com/documentation/swiftui/lazyvgrid.md): creates children only when needed; Apple explicitly says to use a lazy grid only when profiling shows regular Grid performs poorly. Six labels do not need lazy creation.
4. [Grid](https://developer.apple.com/documentation/swiftui/grid.md): eagerly renders children so it can size rows and columns correctly; tallest row cells and widest column cells determine layout. This directly fits the bounded six-metric panel.
5. [preferredLayoutAttributesFitting](https://developer.apple.com/documentation/uikit/uicollectionreusableview/preferredlayoutattributesfitting(_:).md), [shouldInvalidateLayout](https://developer.apple.com/documentation/uikit/uicollectionviewlayout/shouldinvalidatelayout(forpreferredlayoutattributes:withoriginalattributes:).md), and [selfSizingInvalidation](https://developer.apple.com/documentation/uikit/uicollectionview/selfsizinginvalidation-swift.property.md): self-sizing cells can change preferred size, which may trigger a larger layout refresh. These explain the measured preferred-size/invalidation cycle.
6. [Use SwiftUI with UIKit, WWDC22](https://developer.apple.com/videos/play/wwdc2022/10072/), around 21:51–22:24: hosted SwiftUI content changes automatically resize self-sizing collection/table cells. Do not add app-owned row invalidation or frame-change loops.
7. [displayScale](https://developer.apple.com/documentation/swiftui/environmentvalues/displayscale.md) and [Building Custom Views with SwiftUI, WWDC19](https://developer.apple.com/videos/play/wwdc2019/237/), 4:23–4:49: scale is an environment value; SwiftUI rounds view corners to pixels. Our measured scale is 3. This explains quantization, not a mandate to round every custom layout's return value.
8. [Apple DTS: List row expansion](https://developer.apple.com/forums/thread/761656): custom disclosure content can animate differently in List versus Stack; the answer suggests a nil transaction for that bounce report. The follow-up explicitly says that loses smoothness. It is **not** a general prescription proving that List height animation is unsupported, nor proof that disabling our animation fixes the cause. No Apple primary source found prescribes a universal safe custom List-row animation recipe; this implementation is validated by the measured reproduction, not attributed to an undocumented guarantee.
9. `UICollectionViewFeedbackLoopDebugger`: no public Apple API contract or exact recursion threshold was found. The **UIKit framework's own runtime records** are the primary source here: reason `PreferredAttributes`, row `(0-0)`, alternating preferred/layout-generated sizes and origins, 100 logged passes. The older [Apple-hosted recursion discussion](https://developer.apple.com/forums/thread/694141) is developer-reported context, not an Apple-prescribed fix.
10. [accessibilityReduceMotion](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducemotion.md), [UIAccessibility.isReduceMotionEnabled](https://developer.apple.com/documentation/uikit/uiaccessibility/isreducemotionenabled.md), and [Transaction.disablesAnimations](https://developer.apple.com/documentation/swiftui/transaction/disablesanimations.md): avoid large animation when the preference is true; `disablesAnimations` prevents views from inserting animations into the transaction. The final reduced-motion capture verifies the result.

Documentation URLs were fetched with `.md`. Video/forum `.md` variants returned 404/403, so their ordinary Apple URLs/transcripts were read instead. An initial animatableData URL and preferred-layout-attributes class URL returned 404; the canonical URLs above were then fetched successfully. Failed lookups were not treated as evidence.

## Final GREEN, 2026-11-04 UTC

The same existing fixtures were reused, with installation over the app, not erase/uninstall/demo seeding:

- iOS 26.5, iPhone 17 `4EFBA68F-F1C7-41C5-AEB9-E800FCBA40AC`: four Today entries, **585.4 kcal**, **P29.9 / C65 / F23.2**.
- iOS 27.0, iPhone 17 A `918D29B9-97D3-42C0-9C47-00605E01E8DB`: preserved **18 entries / 2465 kcal**. Only `simctl install` was used for installation; sharing/account/data settings were unchanged.

Both final builds completed the requested tap batches: **24 + 100 standard, 60 maximum accessibility size, 120 standard**, plus individual expansion/collapse checks. The JSON transcripts include each requested batch, exit status, UTC range, and pre/post accessibility snapshots. These are dispatched UI tap-request counts, not a claim that the uninstrumented app counted every tap.

| Final pass | Start UTC | Finish UTC | Result |
| --- | --- | --- | --- |
| iOS 26 batches | 00:42:13.826 | 00:44:06.760 | all batches exit 0, responsive |
| iOS 27 batches | 00:39:34.439 | 00:41:31.625 | all batches exit 0, responsive |
| Normal-motion recording | 00:44:09 | duration 6.121667 s | smooth intermediate frames both ways |
| Reduce Motion recording | 00:39:35 | duration 6.290000 s | endpoints only |

`green-full.mp4` is the **113.461667-second** final iOS 26 stress recording, compressed to 3 fps for size; it is not the smoothness proof. `green-normal-motion.mp4` and `green-motion-frames.jpg` preserve that proof separately. Superseded no-animation GREEN artifacts were replaced/removed, not presented as final evidence. The retained RED clips/reports are unchanged.

- **37,454 iOS 26 UIKit stream lines, zero actual feedback-loop category records.**
- **26,695 iOS 27 UIKit stream lines, zero actual feedback-loop category records.**
- Separate persisted `UICollectionViewFeedbackLoopDebugger` queries from 00:39 UTC return **zero records** on both devices. Stream coverage begins earlier than the final passes and includes exploratory controls; no failure is excluded by that broader window.
- Host app-crash inventory is unchanged: **17 before / 17 after, no new report**, checked at **00:47:15.580 UTC**. Baseline was after the two intentional diagnostic RED crashes.
- Expanded normal-size screenshot shows all six complete nutrient labels and values, without bottom clipping: Sat Fat 3.7 g, Fiber 3.7 g, Sugars 14.6 g, Added Sugar 0 g, Sodium 1887.6 mg, Cholesterol 73.4 mg.
- Final states are responsive, collapsed Today at `large` text size. Reduce Motion returned to off.

## Final validation

- `make quality-format-check`: passed.
- `make quality-build`: passed. The final incremental build reports no warnings; earlier probe builds warned in unchanged tutorial code. No warning suppression or unrelated change.
- Full serial iPad suite: **247 passed, 0 failed, 0 skipped, 0 expected failures**, independently re-read with `xcresulttool`. `PurchaseStoreStoreKitTests` was explicitly excluded at selection time, not counted as skipped.
- iPad lock waited from **00:39:04.204 UTC**, acquired **00:40:39.947**, released **00:41:11.395**. Acquisition used atomic `mkdir` and directory-change events, not polling or removing another worker's lock.
- Actual test timestamps from xcresult: **00:40:41.486–00:41:10.717 UTC**. Bundle: `/tmp/macros-loop2.xcresult`. Build/test/lock logs and raw summary are retained.

```sh
xcodebuild -project cal-macro-tracker.xcodeproj -scheme cal-macro-tracker \
  -destination 'platform=iOS Simulator,id=E91B597B-CE57-4C0B-A8A4-51CBDC3386AB' \
  -parallel-testing-enabled NO -test-timeouts-enabled YES \
  -default-test-execution-time-allowance 30 \
  -maximum-test-execution-time-allowance 45 \
  -skip-testing:cal-macro-trackerTests/PurchaseStoreStoreKitTests \
  -resultBundlePath /tmp/macros-loop2.xcresult test
xcrun xcresulttool get test-results summary --path /tmp/macros-loop2.xcresult --compact
```

Review after validators: no redundant guards, duplicate validation, unused helpers, timers, or geometry-state writes remain. `expansionTransaction` is shared by the two expansion-state writes; its accessibility-only disabled-animation flag is supported by measured nil-transaction failure. The grid remains bounded to six existing metrics. No unit tests were added after implementation.

## Artifacts

- Original RED: `red-build27{,-today-focused,-full}` clips/log/report names and `red-main*`; original setup/negative Sharing screenshots remain.
- Causal measurements: `layout-probe.patch.gz`, `layout-measurements.json`, `red-probe.log.gz`, `nil-height.log.gz`, `grid-probe.log.gz`.
- Final UI: `green-full.mp4`, `green26-actions.json`, `green27-actions.json`, `green-expanded-hero.png`, `green-final-today.png`, `green27-final-today.png`.
- Motion: `green-normal-motion.mp4`, `green-motion-frames.jpg`, `green-reduced-motion.mp4`, `green-reduced-frames.jpg`, `green-reduce-motion-on.png`, `motion-measurements.json`, both gesture telemetry files, `reduce-motion-readback.log`.
- UIKit/crash inventory: `green-uikit.log.gz`, `green27-uikit.log.gz`, both persisted-query logs, `crash-inventory.json`, `capture-summary.json`.
- Validators: `format.log`, `quality-build.log.gz`, `serial-ipad-tests.log.gz`, `serial-ipad-summary.json`, `serial-ipad-run.json`, `serial-ipad-lock.log`.

Every committed evidence file is under **5,000,000 bytes**. Large raw recordings/logs remain in `/tmp`, outside Git.

## Isolation and limits

`git pull --ff-only` ran first and was already up to date. All shell commands started with `cd /Users/juan/.t3/worktrees/cal-macro-tracker/collection-loop &&`. No subagents, camera source changes, prohibited simulator operations, build/version bump, upload, merge, or XcodeBuildMCP defaults/profile changes.

Each used simulator was locked before interaction. No existing lock was taken. The iPad's other worker was allowed to finish. At most four devices were booted; no reserved device was stopped to create space. Both UI sessions are closed; iOS 26 is shut down and retained, A is left booted and usable, and only our acquired locks were released.

The reproduced runtime is 26.5, not the original tester's 26.6.2. Builds are Debug simulator binaries, not the uploaded TestFlight artifact. This proves the measured local mechanism and requested reproduction passes, not that every UIKit sizing defect or the original tester's last screen is known. The original broad Sharing/search negative exercise remains historical context, not a newly repeated final sharing E2E claim.
