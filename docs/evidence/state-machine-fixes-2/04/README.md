# 04. Overlapping backup decode

Media removed in the repo cleanup; retrieve with `git show 074b10994f1b68d9d7a8d6c54ed7effb90d5f1f5:docs/evidence/state-machine-fixes-2/04/red-newer-summary.png`.

## Exact live sequence

1. Grant Debug Pro and export synthetic demo data. Create `Slow-A.json` (first 11 log entries, no weights, exported Nov 1) and `Fast-B.json` (first 22 log entries, no weights, exported Nov 2).
2. Put both in the owned simulator's local Files provider `File Provider Storage` directory. Enable `search` for Files/Recents; never edit the committed simslim profile.
3. Apply only the archived backup-decode hook and helper. Arm `backup-delay` to `45`.
4. Through **Import Backup** and the actual Files picker, select Slow-A. While its decode completion is paused, tap **Import Backup** again and attempt to select Fast-B.
5. RED accepts B during A, publishes B, then overwrites it with A. GREEN intentionally prevents the second picker: all three backup actions are disabled until A completes. A coordinate tap on the disabled Import row leaves the UI unchanged.
6. After A completes, choose B normally (dismiss A if presented). Expand the summary to inspect the log-entry count. Do not apply the backup for this test.

Exact hook after detached decoding, before unmatched-meal lookup:

```swift
#if DEBUG
SuspectProbe.trace("backup decoded slow=\(url.lastPathComponent.contains("Slow"))")
if url.lastPathComponent.contains("Slow") { await SuspectProbe.pause("backup-delay") }
#endif
```

After assigning `presentation`, it logs `backup summary slow=<bool>`.

## Result

- RED: [trace](red-trace.log), newer presentation, stale final summary. B publishes at `1793722178.1863542`, then A publishes at `1793722198.156598`; the final visible count is **11**.
- GREEN: disabled actions, [accessibility capture](green-disabled-actions.log), [trace](green-trace.log). A pauses at `1793722940.699815`. Import and both exports are visibly disabled; tapping Import at the same position does not open Files. A finishes at `1793722988.754404`. Only afterward is B selected.
- Final newer summary screenshot and [accessibility capture](green-newer-summary.log) show **22** log entries.

Fix: `BackupSettingsSection.swift:77–82` acquires the existing `isWorking` flag synchronously before launching decode and releases it with `defer` on success, errors, empty selections, and picker failures. Export already owns the same flag. This serializes all three presentation-producing actions without another task handle, revision counter, or duplicated state.

The implementation intentionally chooses serialization rather than accepting overlapping latest-wins selections. No export/decode completion can race a newly accepted selection through this UI.
