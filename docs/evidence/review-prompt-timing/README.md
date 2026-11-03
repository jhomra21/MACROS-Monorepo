# Review prompt timing, 2026-11-03

Baseline: `8e145eb` (`origin/main` when the worktree was created).
Device: iPhone 17e B, `F976E800-DA1F-4F20-B755-DFD964E33975`, iOS 27.0.
App: `juan-test.cal-macro-tracker`, Debug, version 1.0 (28).
Recordings are real device captures, downscaled to 390 points and H.264 compressed; every evidence file is below 5 MB. No review was submitted.

## Results and timestamps

Wall-clock log timestamps below are device local time (UTC−06:00); add six hours for UTC.

| Check | Time on 2026-11-03 | Evidence |
| --- | --- | --- |
| RED Add Food | Request at 11:19:57.489, immediately after Log Food | `red-add-food.mp4`, `red-add-food.png` |
| RED camera photo import | Request at 11:22:07.693, over the camera's logged result/photo | `red-camera.mp4`, `red-camera.png` |
| GREEN Add Food, fresh reinstall | Idle wait starts 11:24:49.788; request at 11:24:51.865 (2.077 s) | `green-add-food.mp4`, `green-add-food.png` |
| Second qualifying log, same version | About 11:25; Today shows six items, no further request | `green-same-version.png`, `review-log.txt` |
| Open Add Food during wait | Wait starts 11:29:37.323; cancelled at 11:29:38.784 (1.461 s) | `green-cancel-resume.mp4`, `green-cancelled-sheet.png` |
| Pending request resumes, date 15 days ago | Next wait 11:29:57.938; request 11:30:00.015 (2.077 s) | `green-cancel-resume.mp4`, `green-15-days.png` |
| Persisted date 13 days ago, version reset | Log at 11:31:53; no wait/request, Today has ten items | `gap-13-setup.json`, `green-13-days.png`, `review-log.txt` |
| GREEN camera photo import, date 15 days ago | Wait 11:34:23.198; request 11:34:25.264 (2.066 s) | `gap-15-setup.json`, `green-camera.mp4`, `green-camera.png` (idle Today), `green-camera-after.png` (prompt) |
| Settings link | Tapped at 11:32:21 and repeated about 11:35 | `settings-rate-row.png`, `settings-app-store.png`, `settings-exact-url.png`, `settings-url-tree.txt` |

The videos show no prompt while the logging sheet is open or dismissing on GREEN. RED camera shows the prompt covering the still-present camera result. GREEN camera uses **Edit details** to confirm the OCR-missing name, then **Log Food**; all camera source is unchanged.

The Settings tap opens Safari on this slim simulator (App Store is unavailable). Safari reports that it cannot open the page. Its focused address field contains exactly:
`https://apps.apple.com/app/id6767565938?action=write-review`.
The accessibility tree and screenshot capture that actual destination, not a manually typed URL.

## Repeatable E2E steps

1. Acquire the device lock before use. All shell commands run from this worktree:

   ```sh
   cd /Users/juan/.t3/worktrees/cal-macro-tracker/review-prompt && mkdir -p /tmp/macros-sim-locks && while ! mkdir /tmp/macros-sim-locks/F976E800-DA1F-4F20-B755-DFD964E33975; do sleep 120; done
   ```

2. Build Debug at the baseline before changing source:

   ```sh
   cd /Users/juan/.t3/worktrees/cal-macro-tracker/review-prompt && xcodebuild -project cal-macro-tracker.xcodeproj -scheme cal-macro-tracker -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/macros-review-build build
   ```

3. Back up existing app data, uninstall/reinstall the Debug `.app`, and launch. Finish onboarding: **Get Started → I already know my numbers → Continue → disable Daily reminder → Continue → Skip** dashboard tips. Open **Settings**, scroll to **Developer → Load Demo Data → Replace Data**, then return to Today.
   The seeder creates **432 entries on 90 distinct days**, exceeding ≥5 entries/≥3 days within 90 days. The dashboard shows a 90-day streak; the final synthetic shared store has 439 entries on 90 days (`engagement.json`). The seeder emits no successful-log notification.

4. Start a device video before tapping the logging button. **Add Food → Apple → Log Food** reproduces RED. Dismiss with **Not Now**. Reset `reviewPromptedAppVersion` for the independent camera trial (baseline used launch arguments `-reviewPromptedAppVersion ""`; the captured prompt confirms eligibility).

5. Import the repository fixture into Photos:

   ```sh
   cd /Users/juan/.t3/worktrees/cal-macro-tracker/review-prompt && xcrun simctl addmedia F976E800-DA1F-4F20-B755-DFD964E33975 docs/app-store/fixtures/oat-crunch-nutrition-label.png
   ```

   **Camera → More camera options → Choose a Photo → imported label → Edit details**. Enter **Oat Crunch** in the missing food-name field, dismiss the keyboard with **Done**, then log. Record RED camera.

6. Build the implementation, fresh uninstall/reinstall, and repeat onboarding/demo seeding and Add Food. Record until the prompt appears after idle Today, then dismiss it. Log Apple again without resetting preferences: no prompt.

7. For date isolation, close the app **and shut down the claimed simulator** before editing its preferences. Resolve the app data container while booted using `xcrun simctl get_app_container <UDID> juan-test.cal-macro-tracker data`. Use Python `plistlib` on `<container>/Library/Preferences/juan-test.cal-macro-tracker.plist`, preserving all other keys:

   ```python
   values["reviewPromptedAppVersion"] = "qa-other-version"
   values["reviewLastRequestedAt"] = time.time() - days * 86400
   ```

   Boot and reopen the app. Use `days = 15`, log Apple, and immediately tap **Add Food** on Today before two seconds elapse. The test used two consecutive device CLI presses, with no settle between Log Food and the Today Add Food tap. Leave the new sheet open for longer than two seconds, then cancel. The pending request appears after the next uninterrupted two seconds.
   Repeat the stopped-simulator plist procedure with `days = 13`: log Apple and verify no request. Then use `days = 15` again for GREEN camera.
   **No source-code bypass was added.** Earlier host `defaults write`/launch-argument attempts did not invalidate simulator preference caches; those attempts are not the date-gate evidence. The accepted 13/15-day runs use stopped-simulator plist edits and subsequent boots. The setup JSON files record the actual persisted values for the final runs.

8. Open **Settings → About → Rate MACROS on the App Store**. Switch the automation target to Safari, focus its address field, and capture the exact URL and error. Do not type or navigate to a replacement URL.

9. Collect timestamped request logs:

   ```sh
   cd /Users/juan/.t3/worktrees/cal-macro-tracker/review-prompt && xcrun simctl spawn F976E800-DA1F-4F20-B755-DFD964E33975 log show --last 25m --style compact --predicate 'category == "AppReview"'
   ```

10. Close automation, restore the pre-QA app data and shared store, verify the original simslim profile, shut down, then release the lock with `rmdir`. No reserved simulator was touched. The Debug app remains installed; the synthetic label remains in Photos. `simulator-restore.txt` records restoration.

## Validation

- `make quality-format-check`: passed.
- `make quality-build`: passed (not counted as tests).
- Full serial iPad suite: **229 passed, 0 failures**, `PurchaseStoreStoreKitTests` excluded. See `ipad-suite-summary.json` and `validation.txt`.

Exact suite command (iPad lock acquired separately and released immediately after the run):

```sh
cd /Users/juan/.t3/worktrees/cal-macro-tracker/review-prompt && DEVELOPER_DIR=/Applications/Xcode-26.4.1.app/Contents/Developer xcodebuild -project cal-macro-tracker.xcodeproj -scheme cal-macro-tracker -destination 'platform=iOS Simulator,id=E91B597B-CE57-4C0B-A8A4-51CBDC3386AB' -derivedDataPath /tmp/macros-review-ipad -parallel-testing-enabled NO -test-timeouts-enabled YES -default-test-execution-time-allowance 30 -maximum-test-execution-time-allowance 45 -skip-testing:cal-macro-trackerTests/PurchaseStoreStoreKitTests -resultBundlePath /tmp/macros-review-ipad.xcresult test
```

No new unit tests were written. Final implementation review found no duplicated state, dead helpers, or polling. The existing paywall UserDefaults key is observed through AppStorage so opening a paywall also cancels the wait. Inactive scenes cannot accumulate idle time.

## Concurrent branch overlap

`shared-person-overlap.txt` contains the requested
`git diff --name-only origin/main...origin/feat/shared-person-widget` output.
Overlapping source files are **AppRootView.swift** (one modifier call) and **SettingsScreen.swift** (four-line About link). `changes-log.md` overlaps as history only. No project-file or camera changes.

## Share sheet follow-up

Device-local time is UTC−06:00. On 2026-11-03, RED began waiting at 13:34:10.476 and requested review at 13:34:12.547 while the system share sheet was open. `red-share-sheet.png` and `red-share-sheet-followup.mp4` show the prompt over the sheet.

On the fixed build, the wait began at 13:39:52.959 and was cancelled at 13:39:55.044 while sharing. After the share sheet closed, the wait restarted at 13:40:38.631 and requested review at 13:40:40.724, 2.093 seconds later. `green-share-sheet-open.png` shows the unobstructed sheet; `green-share-sheet-after.png` and `green-share-sheet-followup.mp4` show the prompt after returning to Today. The AppReview log is in `review-log-share-sheet.txt`. No review was submitted.

To repeat: install the Debug build, complete onboarding, load Developer → Load Demo Data, then stop the simulator and set `reviewPromptedAppVersion` to `qa-other-version` and `reviewLastRequestedAt` to 15 days ago in the app’s preferences plist. Reboot, open Add Food → Apple, and tap **Log Food** followed immediately by the dashboard Share toolbar button with no settle between presses. RED shows the prompt over sharing. With the fixed build, keep the share sheet open beyond two seconds, verify it remains unobstructed, close it, and observe the prompt about two seconds after returning to Today.
