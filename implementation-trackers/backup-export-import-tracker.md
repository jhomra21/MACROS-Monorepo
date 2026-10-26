# Backup Export and Import Tracker (WS6)

Branch `launch/ws6-backup`. Mac only. Phase 2: starts after WS2, WS3, and WS5 are merged (so the backup covers `BodyProfile` and `WeightEntry`). Read `AGENTS.md`, `swift-dev.mdc`, all `Data/Models/*.swift`, `Data/Services/*Repository*.swift`, `App/AppStorageKeys.swift`, `Shared/MacroRingPalette.swift`, and `implementation-trackers/launch-program-tracker.md`.

## Status

Implementation is complete. Formatting, build, `BackupRoundTripTests` (15/15), and `MealSchemaMigrationTests` (1/1) pass. Prior simulator QA verified export to Files, uninstall/reinstall, Replace and Merge automatic dismissal, and two-day meal/weight/settings parity across Dashboard, History, Insights, and Settings. Review follow-up validates profile/settings/date bounds before mutation and independently verifies destination settings restoration. Evidence and limits: `build/ws6-qa-2026-10-26/QA.md`.

## Shared Understanding

- Nothing today lets a user move their data to a new phone. The program keeps data local (no iCloud at launch), so a file-based backup is the migration path. Export and import are Pro (`PaidFeature.backup`).

## Core Decisions

- Format `MACROSBackup` JSON, `version: 1`, `exportedAt`, `appVersion`, then arrays of Codable DTOs (not SwiftData models): `goals`, `bodyProfile`, `foods` (custom and external sources only; `common` foods are reseeded), `meals` with components, `logEntries`, `weightEntries`, and `settings` (ring colors, suggestions toggle, reminder configuration). Stable ordering by `createdAt` then `id` so two exports of the same data are byte-identical.
- Also export a CSV of log entries (one row per entry, consumed values and per-serving values) for spreadsheets.
- Export: Settings > Backup > "Export backup" writes `MACROS-backup-<yyyy-MM-dd>.json` to a temporary directory and presents the share sheet (reuse the pattern in `DailyShareImageExporter` / `DashboardShareSupport`). "Export logs as CSV" likewise.
- Import: background JSON decoding and a counts Form with pinned Merge/Replace actions. Validate the whole document, then stage every group in a background `@ModelActor` context with autosave disabled and exactly one save; roll back on failure. Restore settings and refresh widgets, sharing, and reminders on the main actor after saving.
- Bundled references carry optional source identifiers in version 1 and reconnect to local UUIDs. Unmatched log references retain nutrition snapshots; unmatched meal components have no snapshot and are counted in a summary warning.
- Presentation fix: stable Settings rows alone did not prevent duplicate presenters on iOS 27. The summary/share/paywall sheet and error banner use the single Backup header host, rather than the outer Section modifier originally requested. The file importer stays on its button. First file selection and successful automatic dismissal are verified without transition delays or UIKit workarounds.
- Validation rules: reject unknown versions, malformed JSON, negative nutrition values, entries referencing missing foods (import them as snapshot-only entries, which `LogEntry` already supports since it carries its own nutrition).

## Proposed File Shape

- `Features/Backup/{BackupDocument,BackupExporter,BackupImporter,BackupSettingsSection,BackupImportSummarySheet}.swift`.
- `Features/Settings/SettingsScreen.swift`: one section insertion.
- Tests: `BackupRoundTripTests` (failure list first: round-trip equality, unknown version, corrupt JSON, duplicate ids on merge, replace clears custom data but keeps common foods, CSV escaping of commas and quotes in food names).

## Milestones and Tasks

### Failure list (written before tests and implementation)

- An extreme birth year, invalid profile measurement, reminder time, ring hex, or nonfinite date may survive validation and crash downstream after Replace deletes local data.
- Shared source/destination defaults may hide a missing settings restore; failed Replace must retain different local settings.
- A logged meal's nested snapshots or non-default ring/reminder settings may be lost on round trip.
- Replace may leave components, logged snapshots, weights, or profiles from the previous store.
- Bundled foods may have different UUIDs on another device; references must reconnect by source identifier.
- A negative weight in the final validation group must leave every existing row and setting untouched.
- Merge with changed duplicate values must retain local values across all model groups.
- An unresolved bundled meal item must be counted in the summary, not silently discarded.
- Recreating Settings rows during import may orphan the live summary sheet.
- A successful backup may lose fields or change decoded content when exported and imported.
- Unsupported backup versions or malformed JSON may be accepted or crash import.
- Negative nutrition values may enter the local store from a crafted backup.
- Merge may overwrite an existing row instead of retaining local values for duplicate IDs.
- Replace may leave stale non-common data behind or delete seeded `.common` foods.
- Missing food references may block import even though log entries contain nutrition snapshots.
- CSV cells containing commas, quotes, or newlines may become malformed.
- Export order or JSON key order may vary between runs for identical data.

1. [x] Failure list and tests.
2. [x] DTOs and exporter.
3. [x] Importer and summary UI.
4. [x] Settings section with Pro gate (`ProPaywallSheet(context: .backup)` when locked).
5. [x] Validation and simulator E2E. Full fixture export, uninstall/reinstall, Replace/Merge completion, document parity, and Dashboard/History/Insights/Settings comparisons pass. Reproduction steps, screenshots, and unverified external effects are in `build/ws6-qa-2026-10-26/QA.md`.
