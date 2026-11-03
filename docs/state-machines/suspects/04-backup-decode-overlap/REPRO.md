# 04. Backup decode overlap

**Verdict: BLOCKED (live).** No app change or temporary hook.

## Trigger order and expected user impact

1. Select backup file A; the importer starts decoding it in an untracked task.
2. Before A finishes, present the importer again and select backup file B, or start an export.
3. Let the tasks finish in the opposite order.
4. Each completion updates the same `presentation` state without checking operation identity; import decoding does not set/check `isWorking`.

If reachable, the user may see the wrong import summary or an export sheet replacing it, and may import a backup different from the last one selected.

## Evidence and live attempt

- `cal-macro-tracker/Features/Backup/BackupSettingsSection.swift:76–92` starts an untracked task and presents its result. Export is gated separately at `95–109`; import picker is gated only by `isWorking` at `32–37`.
- A clean Debug app launched, but the file importer cannot be opened or rapidly resubmitted without UI input. The capture shows onboarding, not a backup screen: `onboarding-state.png`.
- Reachability through picker dismissal/re-presentation remains unknown; this attempt did not establish that the system picker can be reopened during decode.
