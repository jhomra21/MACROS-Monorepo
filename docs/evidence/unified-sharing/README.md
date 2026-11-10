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

Recorded below as the work proceeds.
