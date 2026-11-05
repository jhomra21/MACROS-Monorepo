# F2 / F3 state-machine fixes

Base: `da00befaae3d9954c7046f80570bda4936f918d7`. Scope: F2 and F3 only.
F1/F4 await the widget branch; Q1 requires no purge change. The 11 suspects
remain a separate live-reproduction workstream.

## F2 failure inventory (written before tests or implementation)

- Interruption after the base copy: destination exists but committed WAL rows are absent.
- Interruption after the shared-memory copy: WAL still absent; SHM is not durable data.
- Interruption after WAL copy: separate copies are not a consistent live snapshot.
- A partially written base, WAL, or staging file must never become the published store.
- Any copy/read/backup/validation/publish error must propagate without publishing.
- Crash before publish: discard staging on relaunch and retry from untouched legacy data.
- Widget opening during migration: only the final base path is readable, never staging.
- Committed, uncheckpointed WAL rows must survive migration.
- Disk-full during preparation, backup, validation, or publication: fail closed; retry after space is freed.
- Relaunch after each step: missing destination retries; staging is disposable; published destination is a no-op.
- Already-migrated device: preserve its destination, including newer writes; do not overwrite from legacy.
- Corrupt legacy store, unavailable directory, SQLite busy/locked, protection/permission failure:
  report failure and leave source intact.
- Source equals destination or source absent: no migration.
- A pre-existing destination made by the old unsafe copier is indistinguishable from a
  legitimate shared store with newer data. Do not automatically replace it.

Implemented protocol: absent → staging → consistent SQLite backup → validated,
self-contained base → atomic publication. Errors leave destination absent.
Only the app migrates; the widget checks only the published destination.
Use SQLite backup rather than VACUUM to preserve implicit row IDs.

## F3 E2E scenario (before implementation)

1. Install Debug base on a claimed allowed iPhone and enable a fresh sharing identity.
2. A Bun script creates a second fresh identity through the dev auth worker, uploads
   recognizable totals, and connects through an invite.
3. Open the second person's detail screen and verify the totals.
4. Remove the relationship from the script; verify the authoritative dashboard no
   longer includes either person. Leave detail open.
5. Red: original totals remain. Green: no totals or foods; clear removed state.
6. Reconnect/repeat with the fixed binary; delete every test profile through
   `sharing.deleteMySharingProfile`. Do not record tokens or credentials.

## Progress

- [x] Read complete findings, store/person models, local guidance, and widget diff.
- [x] F2 failing isolated tests and red evidence.
- [x] F2 atomic migration and green evidence.
- [x] F3 live red E2E.
- [x] F3 availability fix and live green E2E; clean up identities.
- [x] Required checks and full serial iPad suite except StoreKit; 234 tests passed, 0 failures. Evidence review and push remain.

F2: six tests; red has eight failed assertions across five cases, including
`["base"]` versus `["base", "committed WAL"]`; green has zero failures.
Evidence: `docs/evidence/state-machine-fixes/f2-{red,green}.txt`.
The test fixture keeps a legacy WAL writer open and checks that legacy base/WAL
bytes remain unchanged. The app reads legacy SQLite read-only, finishes backup,
switches staging to DELETE journal mode, quick-checks, protects and synchronizes
the base, then renames within its destination directory. Staging is removed on
error/relaunch. Widget read-only opening is unchanged and cannot select staging.
No new enum was needed: existence of the published base is the durable state.

F3: real iPhone B / iOS 27 Debug base `da00bef`, fresh app viewer and
scripted partner against dev only. Red retained 1234 kcal / P87 C146 F33 after
remote removal and the app roster becoming empty. Green replaced detail with
“Person removed” and no totals or scope/removal controls. Current roster person
is optional; the captured value supplies only identity/name. The detail task
identity includes membership and ignores cancellation/removal errors. Existing
paused/notShared checks remain. Loading and dashboard failure have separate
presentation, without another enum or changes to the shared sync service.
Both profiles deleted through the app API; private script state removed.
Phone B slim profile verified, phone shut down, lock released.
Evidence: `f3-red-stale.{png,txt}`, `f3-red-server.txt`, `f3-red-roster.txt`,
`f3-green-{before,after}.png`, `f3-green-after.txt`, `f3-green-server.txt`,
and `f3-{partner,viewer}-cleanup.txt` in the evidence directory.

Full serial iPad suite: 234 tests passed, 0 failures; StoreKit tests skipped.
The simulator was shut down and its lock released. Raw output is in ignored
`build/state-machine-fixes/full-suite.log`.

Widget overlap: only the required short `changes-log.md` entry; neither Swift
implementation file overlaps `origin/feat/shared-person-widget`.

## References

- https://www.sqlite.org/backup.html
- https://www.sqlite.org/c3ref/backup_finish.html
- https://www.sqlite.org/lang_vacuum.html (VACUUM may change implicit ROWIDs)
