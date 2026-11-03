# 04. Backup decode overlap

**Verdict: CONFIRMED through the real Files picker, with a temporary timing hook. Severity: medium.**

## Repeatable event order

1. Grant Debug Pro and export a synthetic demo backup. Create two valid JSON copies: **Slow-A.json** with 11 `logEntries`, and **Fast-B.json** with 22. Both have empty `weightEntries`.
2. Put the files in the isolated simulator's Files storage. Enable the simulator's `search` service category so Files/Recents works; do not edit the committed service profile.
3. Set `suspect-backup-delay` to `45`. Open Settings > Import Backup and select Slow-A using the native picker.
4. While A is paused after decode, tap **Import Backup** again. The picker is reachable because import decoding has not set `isWorking`. Select Fast-B.
5. Let B complete first, then A. Inspect the final import summary before applying anything.

## Observed result and artifacts

[Trace](live-repro.log):

```text
1793703819.785033 backup decoded slow=true
1793703819.7860131 pause backup-delay begin
1793703830.29951  backup decoded slow=false
1793703830.433837 backup summary slow=false
1793703866.6480808 pause backup-delay end cancelled=false
1793703866.976873 backup summary slow=true
```

The older completion replaced the newer presentation. [The final visible summary](stale-summary.png) shows **11 entries**, although B, with 22 entries, was selected last. The trace establishes B's earlier summary assignment; no screenshot is claimed to show B's summary.

A was subsequently imported deliberately to exercise suspect 02. Replacement did not happen automatically.

## Source, impact, and minimal proposed fix

Baseline `cal-macro-tracker/Features/Backup/BackupSettingsSection.swift:32–37` gates the picker only on `isWorking`; `76–92` starts independent tasks and unconditionally assigns `presentation`. Export sets its own busy flag at `95–109`.

Users can be offered an older backup than the one they selected last, risking replacement with the wrong dataset if they confirm it. Set an import busy gate before starting decode and clear it on every exit, or use an operation generation to reject stale completions. Serialize competing import/export presentations as well. No fix was implemented.

## Exact temporary hook

After the existing detached decode returned, the DEBUG hook checked `url.lastPathComponent.contains("Slow")` and called:

```swift
await SuspectProbe.pause("backup-delay")
```

It logged decode and summary assignments for both files. It did not change picker availability, summary contents, or import behavior. [Exact patch](../temporary-hooks.patch.txt). Hooks and picker fixtures were removed; the `search` service change was restored and verified.
