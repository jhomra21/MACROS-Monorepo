# 10. Persisted uploading

**Verdict: BLOCKED (live).** No app change or temporary hook.

## Trigger order and expected user impact

1. Enable sharing with valid credentials and start a daily snapshot upload.
2. Let the service persist `.uploading` immediately before awaiting the remote mutation.
3. Terminate the process while the mutation is outstanding.
4. Relaunch. The service restores the persisted upload status, but has no matching task from the old process.

If the UI exposes that restored status without normalization, the user may see “uploading” indefinitely until another upload changes it.

## Evidence and live attempt

- `cal-macro-tracker/Features/Sharing/SharingSyncService.swift:64–74` initializes `lastUploadStatus` from local storage; `197–206` persists `.uploading` before awaiting the remote write and later persists success.
- A clean Debug app was launched and captured at first-run (`onboarding-state.png`). No share identity/backend config was available to create a real upload, and no UI driver could navigate to sharing.
- The exact user-visible status after relaunch was not observed; inspect `SharingScreen` presentation during a dev-backed repro before calling the persistence state a user-facing defect.
