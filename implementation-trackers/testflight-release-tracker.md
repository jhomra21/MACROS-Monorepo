# TestFlight Release Tracker (WS10)

Mac, on `main` after all Phase 1 and Phase 2 branches are merged and an interim review has passed.

## Steps

1. [x] Version: owner decision keeps `MARKETING_VERSION` at 1.0. Xcode assigned TestFlight build 7; `CURRENT_PROJECT_VERSION` is now 7. `ITSAppUsesNonExemptEncryption` is false, icons have no alpha, and camera, photo library, and Health usage strings are present.
2. [x] Scheme: Archive uses Release; Release excludes the `#if DEBUG` Pro unlock controls in `ProSettingsSection` and `PurchaseStore`. The archive used the production StoreKit configuration.
3. [x] Archived commit `44e9551b66c90418b30de76e70d24377900a3ebf` as version 1.0/build 1; Xcode managed the uploaded App Store Connect build number to 7. Upload succeeded and App Store Connect reported the package processing. Archive entitlements include HealthKit and `group.juan-test.cal-macro-tracker`. QA evidence: `build/testflight-qa-2026-10-26/QA.md`.
4. [ ] Owner: after App Store Connect finishes processing version 1.0/build 7, add it to the internal TestFlight group and complete the physical-device sandbox checks in `build/testflight-qa-2026-10-26/QA.md`.
5. [ ] Owner: fill in and retain device results and defects in `build/testflight-qa-2026-10-26/QA.md`.
6. [ ] Owner: complete the submission checklist: App Privacy labels (from WS8 mapping), screenshots (WS8 shot list), review notes, support and privacy URLs, subscription review screenshots, and age rating.

Pre-checked on Windows (2026-10-26): `Info-iOS.plist` has `ITSAppUsesNonExemptEncryption` false and usage strings for camera, photo library, Health share and update; app icons are 1024×1024 RGB without alpha; the project initially had `MARKETING_VERSION` 1.0 / `CURRENT_PROJECT_VERSION` 1 with automatic signing for team `NK3K87K955`; the Pro unlock debug controls (`ProSettingsSection`, `PurchaseStore`) sit behind `#if DEBUG`; `tools/release/ExportOptions.plist` uses `app-store-connect`, `upload`, automatic signing, uploaded symbols, and Xcode-managed build numbering.

## Carried-over verification items (must pass on the TestFlight device)

Items that simulator QA could not verify during Phase 1 and 2. Each one is a required row in the WS10 QA artifact; file defects back into the source tracker.

Device results are pending in `build/testflight-qa-2026-10-26/QA.md`.

- WS2 (`pro-subscription-storekit-tracker.md`): every purchase path is unverified locally because the simulator `storekitd` rejects catalog activation (Apple FB22237318 / FB22500243). Verify on a device with a sandbox account: yearly with the 7-day trial, monthly, lifetime, restore on a second device, Family Sharing of lifetime, cancellation and grace/renewal copy, and that the legacy `fullunlock001` purchase still unlocks Pro. Products must exist in App Store Connect first (`docs/app-store/asc-products-checklist.md`).
- WS4 (`bundled-food-database-tracker.md`): search a saved food by its barcode digits, search a saved brand by prefix, and confirm mixed meal/food ordering in Add Food. Covered by persisted-store tests only.
- WS5 (`weight-health-reminders-tracker.md`): tap a delivered reminder in the background and from a cold launch and confirm it opens Add Food. Re-run the Apple Health authorization prompts on the device (write nutrition, read weight as Pro) because the HealthKit capability must be enabled on the App ID first. Verify the Pro multiple and smart reminder variants fire at their times.
- WS7 (`retention-polish-tracker.md`): barcode lookup 429 handling (non-retryable, `Retry-After` wording) needs a camera; simulator QA could not exercise it.
- WS6 (`backup-export-import-tracker.md`): export to Files through the share sheet and import the same file on the device; confirm Merge and Replace behave as in the simulator E2E.
- Platform: widgets and the Lock Screen widget after an import, quick actions, and the sharing invite flow between two devices.
