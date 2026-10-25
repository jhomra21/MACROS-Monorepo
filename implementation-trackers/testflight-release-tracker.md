# TestFlight Release Tracker (WS10)

Mac, on `main` after all Phase 1 and Phase 2 branches are merged and an interim review has passed.

## Steps

1. Version: `MARKETING_VERSION` 1.0.0, bump `CURRENT_PROJECT_VERSION`. Confirm `ITSAppUsesNonExemptEncryption` stays false, icons have no alpha, privacy usage strings exist for camera, photos, Health.
2. Scheme: production StoreKit (do not ship the local `.storekit` selection in the archive; archives ignore it, but confirm the Release build has no DEBUG unlock controls).
3. Archive: `xcodebuild archive -project cal-macro-tracker.xcodeproj -scheme cal-macro-tracker -destination 'generic/platform=iOS' -archivePath build/MACROS.xcarchive`, then `xcodebuild -exportArchive -archivePath build/MACROS.xcarchive -exportOptionsPlist tools/release/ExportOptions.plist -exportPath build/export` with `method app-store-connect` and `destination upload` (or upload the `.ipa` with Transporter). Signing uses the Mac's installed certificates; if automatic signing fails, stop and report.
4. TestFlight: internal group; the owner tests on a physical device with a sandbox account: yearly trial purchase, monthly purchase, lifetime purchase, cancellation flow, restore on a second device, Family Sharing of lifetime, Apple Health write and read, reminders firing, backup round trip, sharing invite on two devices, widgets and Lock Screen widget, quick actions.
5. QA artifact `build/testflight-qa-<date>/QA.md` with build number, device, results, and any defects filed back into the relevant tracker.
6. Submission checklist: App Privacy labels (from WS8 mapping), screenshots (WS8 shot list), review notes, support and privacy URLs, subscription review screenshots, age rating.
