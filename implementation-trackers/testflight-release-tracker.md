# TestFlight Release Tracker (WS10)

Mac, on `main` after all Phase 1 and Phase 2 branches are merged and an interim review has passed.

## Steps

1. Version: `MARKETING_VERSION` 1.0.0, bump `CURRENT_PROJECT_VERSION`. Confirm `ITSAppUsesNonExemptEncryption` stays false, icons have no alpha, privacy usage strings exist for camera, photos, Health.
2. Scheme: production StoreKit (do not ship the local `.storekit` selection in the archive; archives ignore it, but confirm the Release build has no DEBUG unlock controls).
3. Archive: `xcodebuild archive -project cal-macro-tracker.xcodeproj -scheme cal-macro-tracker -destination 'generic/platform=iOS' -archivePath build/MACROS.xcarchive`, then `xcodebuild -exportArchive -archivePath build/MACROS.xcarchive -exportOptionsPlist tools/release/ExportOptions.plist -exportPath build/export` with `method app-store-connect` and `destination upload` (or upload the `.ipa` with Transporter). Signing uses the Mac's installed certificates; if automatic signing fails, stop and report.
4. TestFlight: internal group; the owner tests on a physical device with a sandbox account: yearly trial purchase, monthly purchase, lifetime purchase, cancellation flow, restore on a second device, Family Sharing of lifetime, Apple Health write and read, reminders firing, backup round trip, sharing invite on two devices, widgets and Lock Screen widget, quick actions.
5. QA artifact `build/testflight-qa-<date>/QA.md` with build number, device, results, and any defects filed back into the relevant tracker.
6. Submission checklist: App Privacy labels (from WS8 mapping), screenshots (WS8 shot list), review notes, support and privacy URLs, subscription review screenshots, age rating.

## Carried-over verification items (must pass on the TestFlight device)

Items that simulator QA could not verify during Phase 1 and 2. Each one is a required row in the WS10 QA artifact; file defects back into the source tracker.

- WS2 (`pro-subscription-storekit-tracker.md`): every purchase path is unverified locally because the simulator `storekitd` rejects catalog activation (Apple FB22237318 / FB22500243). Verify on a device with a sandbox account: yearly with the 7-day trial, monthly, lifetime, restore on a second device, Family Sharing of lifetime, cancellation and grace/renewal copy, and that the legacy `fullunlock001` purchase still unlocks Pro. Products must exist in App Store Connect first (`docs/app-store/asc-products-checklist.md`).
- WS4 (`bundled-food-database-tracker.md`): search a saved food by its barcode digits, search a saved brand by prefix, and confirm mixed meal/food ordering in Add Food. Covered by persisted-store tests only.
- WS5 (`weight-health-reminders-tracker.md`): tap a delivered reminder in the background and from a cold launch and confirm it opens Add Food. Re-run the Apple Health authorization prompts on the device (write nutrition, read weight as Pro) because the HealthKit capability must be enabled on the App ID first. Verify the Pro multiple and smart reminder variants fire at their times.
- WS7 (`retention-polish-tracker.md`): barcode lookup 429 handling (non-retryable, `Retry-After` wording) needs a camera; simulator QA could not exercise it.
- WS6 (`backup-export-import-tracker.md`): export to Files through the share sheet and import the same file on the device; confirm Merge and Replace behave as in the simulator E2E.
- Platform: widgets and the Lock Screen widget after an import, quick actions, and the sharing invite flow between two devices.
