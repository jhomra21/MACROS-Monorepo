# Backup Export and Import Tracker (WS6)

Branch `launch/ws6-backup`. Mac only. Phase 2: starts after WS2, WS3, and WS5 are merged (so the backup covers `BodyProfile` and `WeightEntry`). Read `AGENTS.md`, `swift-dev.mdc`, all `Data/Models/*.swift`, `Data/Services/*Repository*.swift`, `App/AppStorageKeys.swift`, `Shared/MacroRingPalette.swift`, and `implementation-trackers/launch-program-tracker.md`.

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

1. Failure list and tests.
2. DTOs and exporter.
3. Importer and summary UI.
4. Settings section with Pro gate (`ProPaywallSheet(context: .backup)` when locked).
5. Validation: format, build, targeted tests, `git diff --check`; E2E: export on simulator A, erase app, reinstall, import with Replace, confirm Dashboard, History, Insights, Settings match; Merge path with overlapping data; screenshots in `build/ws6-qa-<date>/QA.md`. Changes-log entry.
