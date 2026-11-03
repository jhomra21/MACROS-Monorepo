# 02. Health history after backup replacement

## Exact live sequence

1. In Apple's Health app on the isolated simulator, complete onboarding and add a synthetic 180 lb Weight. Grant Debug Pro in MACROS, enable Health weight reading, and grant Weight read access including all recorded history in the native authorization sheet.
2. Load synthetic demo data before capturing the baseline. Export it through **Export Backup**. If demo setup replaced an imported row, add another synthetic Health sample so the normal observer imports a current row. Capture store and anchor presence.
3. Make `Slow-A.json` from that real export: first 11 log entries, `weightEntries: []`, exported date `2026-11-01T00:00:00.000Z`. Put it in the simulator's local Files provider storage and enable the `search` service category with `simslim enable <UDID> search`, leaving the profile unedited.
4. Apply only the archived Health observer/import-count logs and backup-decode hook, plus the helper. Arm `backup-delay` to `45`.
5. Open **Import Backup**, select Slow-A through Files > Browse > On My iPhone, wait for its summary, and confirm **Replace All Data** twice.
6. RED: revoke/grant Debug Pro to restart observation; inspect the store and anchor again. GREEN: repeat the same replacement with a previously advanced anchor and verify replay immediately, without adding a new Health sample after replacement.
7. Export the restored one-weight state as `Health-Merge.json`, select it through Files, and **Merge** twice. Inspect counts after each merge.

Hooks log only `health start observation`, `health stop observation`, and `health applied samples=<n> deleted=<n>` at the existing production calls. The backup hook is reproduced in [04](../04/README.md). No replacement shortcut was used.

## Result

- RED: [before store](red-store-before.log), [before anchor](red-anchor-before.log), [after store](red-store-after.log), [after anchor](red-anchor-after.log), [trace](red-trace.log). One Health row plus 20 manual demo rows became zero rows. At `1793722304.894783` and `1793722304.897713`, restarted anchored queries returned zero samples; the anchor remained present.
- GREEN, final implementation: [before store](green-store-before.log), [before anchor](green-anchor-before.log), [after store](green-store-after.log), [after anchor](green-anchor-after.log), [trace](green-trace.log), [weight screen](green-history.png). At `1793723515.041984`, observation stops; at `1793723515.407521–1793723515.407649`, restart invalidates old queries; at `1793723515.6251922`, all **three historical synthetic samples** replay and collapse to one same-day Health row. A following import returns zero. No source Health sample was added after replacement.
- [First merge](green-merge-once.log) and [second merge](green-merge-twice.log) each retain exactly one Health row.
- [Synthetic sample screenshot](health-sample.png); [final empty native Health list](health-cleanup.log).

Fix: `BackupImporter.swift:126–130` resets the anchor only after a successful replace commit. Merge leaves it untouched. `BackupSettingsSection.swift:137–143` stops old queries before replacement and restarts with current Pro/read access afterward, including the failure path. Restart also invalidates any query started by an intervening service refresh.

Existing dedupe, unchanged: `WeightRepository.swift:67–76` indexes stored Health UUIDs; `98–108` looks up `entriesByUUID[sample.uuid]` before day fallback and updates rather than inserts. `88–96` selects the latest sample per day. Backup merges also preserve existing row IDs via `BackupImporter.importRows`. No new dedupe mechanism was introduced.

Health history still uses the existing 365-day predicate. This fix does not expand the product's import window or delete anything from Health. Apple documents that a nil anchor removes the incremental restriction: https://developer.apple.com/documentation/healthkit/hkanchoredobjectquery.
