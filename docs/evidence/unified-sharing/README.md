# Unified sharing: Share screen and person row (phases 2 and 3)

Plan: [unified-sharing](../../plans/active/unified-sharing.md). Branch `app/share-screen`. Raw output: ignored `build/evidence/2026-11-10-unified-sharing/`.

## Failure modes (written before any code)

### Image path (phase 2)

1. `ImageRenderer` returns nil at the larger canvas sizes. Keep the three-attempt retry and the existing "Something went wrong sharing." alert with Retry.
2. Exported pixel size is wrong (scale follows the device display scale instead of the target). Render at a fixed scale so Story is 1080x1920, Post 1080x1350, Square 1080x1080 on every device.
3. Text clips or overlaps: Story/Post/Square have very different heights, and Full detail adds six secondary values. Large numbers (5-digit calories, 3-digit grams) and Over-goal deltas must still fit. Dark mode must not change layout.
4. Dark mode exports a transparent or wrong background. The exported image must be opaque with a solid background that matches the chosen appearance.
5. Food names leak onto the image. The card must be built only from totals, goals and secondary totals; a check on the exported PNG must find no fixture food name.
6. The caption is lost: some targets ignore text items. The caption is copied to the clipboard on every Share tap, with a visible and spoken "Caption copied. Paste it in your post." note. The caption item must not ride along into Save Image, AirDrop or Copy.
7. Caption edits are ignored or the field is empty: the copied and shared text must be the field's current value; an empty caption copies nothing and says nothing.
8. Share tapped twice quickly presents two sheets or renders twice. Disable Share while rendering.
9. Sheet state is stale: switching size/detail or the selected day while open must update the preview; the exported image must match the preview.
10. Review prompt fires while the Share sheet is open. The idle check must treat the whole Share flow as share UI.
11. Share warm-up still builds the old card/exporter signature, or warm-up crashes after the exporter changes.
12. Dashboard tutorial step that opens Sharing breaks because the share button or toolbar changed. The button stays disabled while the tutorial runs and the swipe past today still opens Sharing.
13. "Save Image" from the share sheet fails because `NSPhotoLibraryAddUsageDescription` is missing. Checked on the simulator; result in the Findings section.
14. Reduce Motion, Dynamic Type and VoiceOver: pickers labelled, preview reads the numbers, targets at least 44 pt, sheet content scrolls at large type.

### Person row (phase 3)

15. Free user or sharing off lands on a dead end. The row must go to the existing setup screen, where the Pro paywall rows already live.
16. Stale count: the row shows people when sharing is off or the user is not Pro. Count is shown only when sharing is on and Pro.
17. Remote failure or offline blocks the image path: the dashboard subscription failing must not disable, delay or error the Share button or the preview.
18. The row opens a different destination than the swipe past today. Both must open the same Sharing dashboard.
19. Opening the row while the sheet is dismissing leaves the sheet up or pushes twice.

### Test fixture safety

20. Fixtures must never touch real data. Fixture mode is DEBUG only, selected by a launch environment variable, uses an in-memory store with the demo dataset, a scripted sharing remote, and a scripted entitlement. It never talks to Convex or StoreKit, and runs only on a locked disposable simulator.
21. Test reads the pasteboard from another process and triggers the iOS paste prompt: verify, and if it fires, use the in-app hook instead.

## Test plan

XCUITest target `cal-macro-trackerUITests` drives the app with fixtures:

- Home -> Share opens the sheet titled Share; switch each size and detail and assert the preview's accessibility value changes.
- Tap Share: assert the caption is on the pasteboard, the "Caption copied" note is shown and the system share sheet appears.
- Export the nine size x detail combinations as PNG; assert pixel dimensions, opaque pixels in the corners, and (Vision OCR) that no fixture food name appears and that OCR does read the macro labels.
- Person row: free fixture, Pro fixture with sharing on and off, and Pro with the remote offline.

## Red then green

Environment: Xcode 27.0 (`DEVELOPER_DIR=/Applications/Xcode-26.4.1.app/Contents/Developer`), iOS 27.0 simulators iPhone 17e `F976E800` (UI runs) and the iPad runner `E91B597B` (serial suite), both locked under `/tmp/macros-sim-locks/` and released afterwards. Fixture: DEBUG-only launch environment (`MACROS_UI_FIXTURE=1`) with an in-memory store, the demo dataset, a scripted entitlement and a scripted sharing remote; nothing real is touched.

- **Red** (commit `ac91f73`, tests and fixture only): 7 of 7 `ShareScreenUITests` failed. Home loaded from the fixture, then every test failed at "Share sheet did not open" because the toolbar button still rendered and presented the image directly. Raw: `build/evidence/2026-11-10-unified-sharing/red.log`.
- **Green** (next commits): the same tests, split per size so each stays under the 45 s allowance, 11 of 11 pass. Raw: `green.log`, `full.log`.
- **Counted separately.** UI scheme `cal-macro-trackerUITests` (iPhone 17e): 11 tests, 0 failures. Unit scheme `cal-macro-tracker`, serial, excluding `PurchaseStoreStoreKitTests`: 262 tests, 0 failures, and it no longer launches UI tests. Run commands are in [validation](../../development/validation.md).
- **Exports**: the nine size x detail PNGs are in ignored `build/evidence/2026-11-10-unified-sharing/share-exports/`. Each is exactly 1080x1920, 1080x1350 or 1080x1080, has opaque corners, and Vision OCR finds the weekday header, finds Protein for Macros/Full and Fiber for Full only, and finds none of the 16 demo food names. A temporary render at 12,345 kcal, 1,234 g protein and 18,200 mg sodium (light and dark, all nine combinations) showed no clipping.

Findings that shaped the tests:

- Reading `UIPasteboard` from the UI test runner blocks on the iOS paste prompt and hangs the test. The app reads its own pasteboard back after copying and the DEBUG fixture writes it to the export folder; the test reads that file.
- The medium detent builds only visible rows, so tests drag the sheet to full height first. The Share button is pinned, so it stays reachable at both detents.

## Save Image from the share sheet

Checked on the iPhone 17e simulator with the fixture. Before the change, with only `NSPhotoLibraryUsageDescription`, tapping Save Image wrote no file into the simulator library (DCIM stayed at 7 files; I did not capture what the screen showed). So Save Image did not work on the simulator without the add key. With `NSPhotoLibraryAddUsageDescription` set to "MACROS saves share images you choose to your photo library.", Save Image shows the add-only prompt "Allow MACROS to add photos and videos to your photo library?" and, once allowed, writes `IMG_0008.JPG`. A real-device check of Save Image remains an owner step.

## Not verified

- A real post to Instagram, Snapchat, TikTok or X: only the system share sheet was presented. Whether each target keeps the caption text item is app-specific.
- Offline is simulated by the scripted remote failing authentication; airplane mode on a device was not tried.
- VoiceOver speech for the "Caption copied" announcement was not heard; the announcement and the visible note are in place.

## Round 2: menu and full height

Owner feedback on TestFlight build 34: the sheet opened half height, and the "Share with a person" row looked like part of the image. The Home Share button now opens a menu first.

### Failure modes (written before any code)

1. The sheet still opens at the medium detent, so the caption field and Copy caption sit below the fold until the user drags. Test: the caption field is hittable right after opening, with no drag.
2. The person row or its footer stays in the sheet. Test: `share-person-row` does not exist in the sheet.
3. The Share button still opens the sheet directly, so the menu never shows. Test: tapping Share shows both "Post an image" and "Live sharing", and the sheet is not up yet.
4. "Post an image" opens nothing, or opens the sheet twice.
5. "Live sharing" goes to the wrong place: free users or Pro with sharing off must reach setup (the Sharing switch), Pro with sharing on must reach the Sharing dashboard (Alex listed). Each of the three fixtures is tested.
6. The menu subtitle does not render as a subtitle, or shows a stale count (people shown when sharing is off or the user is not Pro). The count appears only for Pro with sharing on, and only after the dashboard has loaded.
7. The menu button loses its accessibility label, shrinks below 44 pt, or stays tappable while the dashboard tutorial runs.
8. The review prompt fires while the menu or sheet is up, or the swipe past today stops opening Sharing, or warm-up breaks. These paths are untouched in code; the sheet flag that `isShareUIUp` reads is still the one set by "Post an image".
9. Live sharing fires while the menu is still dismissing and the push is lost. The menu item runs its action after the menu closes, so it calls the existing open callbacks directly.
10. Offline remote blocks the image path. "Post an image" must open the sheet and Share must work with the remote failing.
11. Copy uses em dashes or jargon. Plain words only.

Red and green results for this round are in the section below once recorded.

## Screenshots (tracked)

- [share-sheet-light.png](share-sheet-light.png), [share-sheet-dark.png](share-sheet-dark.png): the sheet at full height, Pro fixture with sharing on.
- [export-story-macros-1080x1920.png](export-story-macros-1080x1920.png): a 9:16 export of the demo day, default detail.
