# 02. Backup / Health reconciliation

**Verdict: BLOCKED (live).** No app change or temporary hook.

## Trigger order and expected user impact

1. Health weight observation is active and `healthWeightAnchor` has advanced beyond older Health samples.
2. Import a replacement backup that omits one or more of those previously imported Health weights.
3. Backup replacement commits its weight rows, but leaves the Health anchor unchanged.
4. The Health observer runs; its anchored query returns only changes after the saved anchor.

If backup replacement is intended to reconcile Health history, the missing older weights remain absent in the app. Whether this is wrong depends on whether import is meant to reset or preserve Health synchronization history.

## Evidence and live attempt

- `cal-macro-tracker/Features/Backup/BackupImporter.swift:210–223` replaces weight rows. `cal-macro-tracker/Features/Health/HealthKitService.swift:273–306` queries from `healthWeightAnchor`. `cal-macro-tracker/Features/Backup/BackupSettingsSection.swift:129–137` refreshes integrations but does not directly reconcile Health history.
- A clean Debug install was launched; no UI driver was available to import a backup or create Health sample history. The simulator UI was at onboarding (`onboarding-state.png`); no HealthKit sample injection was available through `simctl`.
- `live-attempt.log` records the build and device constraints. Test on a device with seeded Health history and an explicit backup policy before deciding this is a defect.
