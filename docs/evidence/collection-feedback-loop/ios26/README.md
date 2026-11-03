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

## Runtime and isolation

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

## Fix

Only `DashboardScreen.swift` changes:

- Explicit nil animation transactions for hero expansion and tutorial-driven collapse prevent animated preferred-height renegotiation of the self-sizing List row.
- Conditional secondary-nutrition content replaces `RevealLayout`. Its animated progress, opacity/accessibility masking, clipping, and the now-unused layout implementation are removed.
- No timers, delayed state, view model, layout rounding heuristic, OS-version guess, or fixed height.
- Ring/numeric update animation, compact-summary behavior, food rows, and all Sharing code remain unchanged.

## GREEN and validation

The fixed build was installed over the same reproduction data at approximately **23:28:02 UTC**. The GREEN capture starts before installation/launch and continues through repeated hero toggles, maximum accessibility sizes, verified compact-summary scrolling, rotation requests, and another live Sharing insertion/long-name/deletion pass.

The original GREEN recording is **755.233 seconds**, longer than the complete original RED attempt by **27.017 seconds**. The committed 3-fps copy is 755.333 seconds. This is elapsed coverage, not a claim of continuous rapid tapping or a frame-timing benchmark.

- Requested hero tap batches: **24 + 100** at standard size, **60** at maximum accessibility size, then **120** more at standard size, plus individual expansion/collapse checks. No crash. Secondary metrics remained accessible: Sat Fat 3.7 g, Fiber 3.7 g, Sugars 14.6 g, Added Sugar 0 g, Sodium 1887.6 mg, Cholesterol 73.4 mg.
- Verified the compact-summary overlay after actual vertical panning and return to the expanded hero. Some generic `scroll top` attempts did not move the list; they are not counted as coverage.
- Replayed six live A logs, one long-name yogurt, one Apple, then deleted that newly added Apple. Observed incoming detail change **2345 -> 2560 -> 2465 kcal**, with wrapping food rows and alternating scrolling at maximum accessibility size.
- Repeated `chicken` search and result replacement. Completed **30/30** additional down/up search scrolls at largest accessibility size. The timestamped scroll transcript is committed.
- Captured **47,102** live UIKit lines. **Zero actual feedback-loop records** in either the live stream or a separate persisted category query from 17:28 local onward. The sole persisted keyword hit is the log command's own echoed predicate, not an app event; it remains visible in the query artifact rather than being hidden.
- Diagnostic inventory after GREEN contains only the two unsigned-entitlement startup reports and the two RED crashes. **No new app crash report.** Finished on responsive, collapsed Today with the same four-food reproduction fixture.
- `make quality-format-check`: passed. `make quality-build`: passed. Existing concurrency warnings remain in unchanged tutorial/Sharing files; no warning suppression or unrelated fix. Logs are committed. `git diff --check`: clean.
- Full serial iPad suite: **247 passed, 0 failed, 0 skipped, 0 expected failures**, independently extracted with `xcresulttool`. `PurchaseStoreStoreKitTests` was explicitly excluded at selection time, so its tests are not included in the 247 or the skipped count. iPad Air 11-inch, iOS 27.0 (24A434), serial execution, 30/45-second per-test allowances. Result bundle: `/tmp/macros-loop.xcresult`. Run start **23:45:51.090 UTC**, finish **23:46:14.706 UTC**.

```sh
xcodebuild -project cal-macro-tracker.xcodeproj -scheme cal-macro-tracker \
  -destination 'platform=iOS Simulator,id=E91B597B-CE57-4C0B-A8A4-51CBDC3386AB' \
  -parallel-testing-enabled NO -test-timeouts-enabled YES \
  -default-test-execution-time-allowance 30 \
  -maximum-test-execution-time-allowance 45 \
  -skip-testing:cal-macro-trackerTests/PurchaseStoreStoreKitTests \
  -resultBundlePath /tmp/macros-loop.xcresult test
xcrun xcresulttool get test-results summary --path /tmp/macros-loop.xcresult --compact
```

Final defensive-code review ran personally after the normal validators. Scope: the hero conditional, both expansion-state writes, and their ring/tutorial callers. No new guards, duplicate validation, timers, or impossible-state fallback were added. Explicit nil animation is intentional, not a redundant wrapper: it overrides animated caller transactions. Removed layout/animation helpers have no remaining references. No additional source change was justified.

### Cleanup already verified

Both UI device sessions are closed. The newly created iOS 26 simulator is shut down but retained; A stays booted and usable at normal text size/portrait, Debug Pro enabled. A has 18 rows / 2465 kcal after investigation logs and deletion; its existing Test B connection was not removed. The `iOS26 Loop Probe` relationship and Macros + Foods scope remain for repeatability.

The clean detached historical worktree was removed. Released our new-device/A/17e locks. Waited for the other worker's iPad lock without removing it, acquired it at **23:45:31 UTC**, then released our acquired lock after tests. The iPad was already booted and remains booted. The previously unclaimed 17e remains off. No camera or prohibited simulator was touched. At **23:46:41 UTC**, installed runtime storage is **7.9 GiB**, new simulator data **2.3 GiB**, and `df -h /` shows **52 GiB available**. The exported runtime copy remains in `/tmp/macros-ios26-runtime` (7.9 GiB), separate from the installed runtime.

## Artifacts

- `red-build27-full.mp4`: entire post-pairing RED attempt, compressed to 3 fps, 402 × 874. Not a frame-timing measurement.
- `red-build27-today-focused.mp4`: 36.250-second focused clip at 12 fps.
- `red-main-today.mp4`: minimal main repeat.
- `red-build27.ips`, `red-main.ips`: actual simulator crash reports, with only `crashReporterKey` replaced by `REDACTED`, as authorized after Droid Shield flagged the diagnostic identifier. Stack, exception, timing, and layout evidence are unchanged.
- `red-build27-feedback.log`, `red-main-feedback.log`: collected invalidation records.
- `build27-live-roster-ax.png`, `build27-shared-long-row-ax.png`: populated live Sharing at maximum accessibility size.
- `green-compact-summary-ax.png`, `green-expanded-hero-ax.png`: fixed UI; the expanded secondary metrics are also verified in the accessibility tree after scrolling.
- `green-full.mp4`: complete longer GREEN pass, compressed to 3 fps.
- `green-uikit.log.gz`, `green-persisted-feedback-query.log`, `capture-summary.json`: log capture, explicit category query, and machine-readable results.
- `green-final-today.png`, `A-final-today.png`, `green-search-scrolls.json`: usable final states and timestamped search coverage.
- `format.log`, `quality-build.log.gz`, `serial-ipad-tests.log.gz`, `serial-ipad-summary.json`: normal validators, losslessly compressed full build/test output, and independently extracted counts.

Every committed evidence file is under 5 MB. Raw recordings/logs remain in `/tmp`; the private invite-setup video is not a public evidence artifact.

## Limits

- Runtime is **26.5**, not the tester's **26.6.2**. These are Debug simulator rebuilds with Xcode 27, not the uploaded TestFlight binary.
- Same failure mechanism and row are reproduced locally; the original tester's last screen is still unknown.
- Orientation commands succeeded, but the iPhone app's portrait-only support means command success is not proof of landscape UI coverage.
- UI-driven successive logs were roughly 10–21 seconds apart, not subsecond network bursts. The largest text sizes and list scrolling did overlap incoming updates.
- No unit tests were added after implementation. The required existing full serial iPad suite is separate from the on-device GREEN reproduction.
