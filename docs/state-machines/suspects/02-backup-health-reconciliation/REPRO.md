# 02. Backup / Health reconciliation

**Verdict: CONFIRMED behavior; whether it is a defect requires an import-policy decision. Severity: medium if ongoing Health-history reconciliation is intended.**

## Repeatable event order

1. On the isolated iPad, open Apple's Health app, finish its onboarding, and add a synthetic **180 lb** Weight sample. Enable Debug Pro in MACROS, enable Health weight import, and grant read access to Weight including past history through the native permission UI.
2. Verify the sample appears in the app store and `healthWeightAnchor` exists.
3. Export the synthetic demo backup and make a valid replacement JSON with `weightEntries: []`. The live run used **Slow-A.json**, containing 11 log entries and no weights.
4. In Settings > Import Backup, select that file through the actual Files picker. Confirm **Replace** in the import summary.
5. Inspect weights and anchor state. Revoke and grant Debug Pro to stop/restart weight observation, then inspect the next anchored imports and the local weights again.

## Observed result and artifacts

- [Before](store-before.log): one `healthKit` weight and 20 manual demo weights.
- [Anchor before](anchor-before.log): anchor present, reading enabled.
- [After replacement](store-after.log): no weight rows.
- [Anchor after](anchor-after.log): anchor still present, reading still enabled.
- [Trace](live-repro.log): the original sample imported at `1793703709.9891682`; after replacement/restart, imports at `1793703999.844969` and `1793703999.8510041` contained zero samples. The historical weight remained absent.
- [Synthetic Health sample](health-sample.png); [its deletion during cleanup](health-sample-deleted.log).

These logs record anchor presence, not byte-for-byte equality of serialized anchors. The observed failure is missing historical re-import after a replacement with an already-advanced import cursor.

## Source, impact, and minimal proposed fix

Baseline `cal-macro-tracker/Features/Backup/BackupImporter.swift:210–223` replaces weights. `Features/Health/HealthKitService.swift:273–306` queries from the stored Health anchor and advances it; `Features/Backup/BackupSettingsSection.swift:129–137` refreshes widgets/sharing/reminders, not Health history.

If Health sync is supposed to remain authoritative after replacement, users silently lose previously imported history locally while reading stays enabled. Reset/reconcile the weight anchor on replacement and restart observation after commit, deduplicating by Health UUID through `WeightRepository`. If replacement intentionally establishes a history reset boundary, document that policy instead. No Health source sample was deleted by importing the backup.

## Temporary hooks and limits

There was **no replacement bypass**: the live run used the native picker and production import action. Health start/stop/import-count logging supplied timing evidence; the backup-decode delay from suspect 04 was also active for Slow-A. The archived `Replace Weight Backup Probe` button was added but never used. All hooks were removed. Only synthetic Health data was used and the added sample was deleted.
