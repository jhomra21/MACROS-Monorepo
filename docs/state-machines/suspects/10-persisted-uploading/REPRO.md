# 10. Persisted uploading

**Verdict: NOT REPRODUCIBLE as an indefinite user-visible upload/spinner defect. Restoration of the internal `uploading` value was confirmed.**

## Repeatable event order

1. Attach the fresh Owner dev identity to the isolated Debug app, enable Sharing, and allow an initial upload to finish.
2. Set `suspect-upload-delay` to `60`. Edit a daily goal in real Settings and tap **Save Goals**, producing a changed snapshot.
3. The service persists `.uploading`, then pauses immediately before its existing real remote mutation. Verify the persisted value and inspect the UI.
4. Before the delay ends, disable that delay file and relaunch the app with `--relaunch`, terminating the old process and its task.
5. Inspect the initialized status, subsequent upload, final persisted value, and visible app UI.

The edited goal was synthetic test data. No production profile or owner device was used.

## Observed result and artifacts

[Trace](live-repro.log):

```text
1793704335.2222838 upload before mutation
1793704335.2229729 pause upload-delay begin
1793704375.124868  upload init status=uploading
1793704378.0776892 upload before mutation
1793704378.526956  upload after mutation
1793704383.085588  upload init status=succeeded
```

[Initial post-relaunch status](status-after.log) was `uploading`; [final status](status-final.log) was `succeeded`. A new upload finished about 3.4 seconds after initialization. [Pending UI](upload-pending-ui.png) shows the saved-goals screen. [The relaunch capture](relaunched-ui.png) was taken too early and shows a blank startup view; it is not evidence of normal post-launch UI or recovery. The terminal trace and absence of a status consumer support the verdict, not that screenshot.

## Source and verdict boundary

Baseline `cal-macro-tracker/Features/Sharing/SharingSyncService.swift:73–76` restores upload metadata without restoring a task. `197–208` persists uploading before the await and success after it. `183–186` normalizes a hash-equal **failed** status, not a hash-equal uploading status.

A whole-app reference search found no view consuming `lastUploadStatus` outside the service/local store. Current UI uses other busy/error state. The live next-event path also repaired this changed-snapshot case. Therefore the conditional user-visible failure in the original suspect was not reproduced.

This is not proof that every hash-equal/offline startup normalizes the internal enum. Such residue can remain a bookkeeping concern, but it is not evidence of an infinite spinner. If a future UI exposes this status, normalize process-bound uploading to an idle/retry state on initialization. No current app fix is proposed or implemented here.

## Exact temporary hook and cleanup

After existing `setLastUploadStatus(.uploading)` and before `remoteClient.upsertDailySnapshot(payload)`, DEBUG code logged the boundary and awaited `SuspectProbe.pause("upload-delay")`. Initialization and successful mutation return were also logged. [Exact patch](../temporary-hooks.patch.txt).

[Both fresh backend profiles were deleted](../backend-cleanup.log). The fixture invite token and upload metadata were cleared locally, Sharing and Health reading were disabled, and the identity override/delay files were removed. Hooks were discarded and the original app restored.
