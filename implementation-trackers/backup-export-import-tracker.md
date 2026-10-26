# Backup Export and Import Tracker (WS6)

Branch `launch/ws6-backup`. Mac only. Phase 2: starts after WS2, WS3, and WS5 are merged (so the backup covers `BodyProfile` and `WeightEntry`). Read `AGENTS.md`, `swift-dev.mdc`, all `Data/Models/*.swift`, `Data/Services/*Repository*.swift`, `App/AppStorageKeys.swift`, `Shared/MacroRingPalette.swift`, and `implementation-trackers/launch-program-tracker.md`.

## Status

Implementation is complete. Formatting, build, `BackupRoundTripTests` (9/9), and `MealSchemaMigrationTests` (1/1) pass. Simulator QA verified custom food logging, Pro-gated backup controls, JSON export/share, Files save, and backup parsing/summary. End-to-end Replace/Merge completion and seeded two-day/meal/weight/settings parity remain unverified; see `build/ws6-qa-2026-10-26/QA.md`.

## Shared Understanding

- Nothing today lets a user move their data to a new phone. The program keeps data local (no iCloud at launch), so a file-based backup is the migration path. Export and import are Pro (`PaidFeature.backup`).

## Core Decisions

- Format `MACROSBackup` JSON, `version: 1`, `exportedAt`, `appVersion`, then arrays of Codable DTOs (not SwiftData models): `goals`, `bodyProfile`, `foods` (custom and external sources only; `common` foods are reseeded), `meals` with components, `logEntries`, `weightEntries`, and `settings` (ring colors, suggestions toggle, reminder configuration). Stable ordering by `createdAt` then `id` so two exports of the same data are byte-identical.
- Also export a CSV of log entries (one row per entry, consumed values and per-serving values) for spreadsheets.
- Export: Settings > Backup > "Export backup" writes `MACROS-backup-<yyyy-MM-dd>.json` to a temporary directory and presents the share sheet (reuse the pattern in `DailyShareImageExporter` / `DashboardShareSupport`). "Export logs as CSV" likewise.
- Import: `fileImporter` for JSON; parse and show a summary sheet (counts, date range, app version) with two choices: Merge (skip rows whose `id` already exists) or Replace (delete all non-common data first, then insert). Run in one `PersistenceReporter.persist` transaction per table group; show progress; on failure roll back and show the error banner. Reload widgets and trigger sharing sync after import.
- Validation rules: reject unknown versions, malformed JSON, negative nutrition values, entries referencing missing foods (import them as snapshot-only entries, which `LogEntry` already supports since it carries its own nutrition).

## Proposed File Shape

- `Features/Backup/{BackupDocument,BackupExporter,BackupImporter,BackupSettingsSection,BackupImportSummarySheet}.swift`.
- `Features/Settings/SettingsScreen.swift`: one section insertion.
- Tests: `BackupRoundTripTests` (failure list first: round-trip equality, unknown version, corrupt JSON, duplicate ids on merge, replace clears custom data but keeps common foods, CSV escaping of commas and quotes in food names).

## Milestones and Tasks

### Failure list (written before tests and implementation)

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
5. [ ] Validation and simulator E2E. Unit/build/format checks pass; full app erase/reinstall with seeded two-day data, Replace/Merge completion, and Dashboard/History/Insights/Settings parity are not verified. Partial evidence and exact steps are in `build/ws6-qa-2026-10-26/QA.md`.
