# Unconfirmed state-machine suspects

Live attempts used the Debug app built from `origin/main` at `da00befaae3d9954c7046f80570bda4936f918d7` on the clean iPhone 17e (`F976E800-DA1F-4F20-B755-DFD964E33975`). The app launched and first-run screenshots were captured. No suspect was confirmed. No app code or temporary hooks were added.

| # | Suspect | Verdict | Artifact | Evidence |
|---|---|---|---|---|
| 01 | Repair stale writeback | BLOCKED-live | [REPRO](01-repair-stale-writeback/REPRO.md) | Requires editing the same entry while an external repair lookup is suspended; no UI driver or delayed lookup fixture. |
| 02 | Backup/Health reconciliation | BLOCKED-live | [REPRO](02-backup-health-reconciliation/REPRO.md) | Requires imported replacement weights plus Health history/anchor; neither could be seeded through this simulator session. |
| 03 | Health authorization completion | BLOCKED-live | [REPRO](03-health-authorization-completion/REPRO.md) | Requires entitlement transition during Health authorization; HealthKit controls/sample injection unavailable. |
| 04 | Backup decode overlap | BLOCKED-live | [REPRO](04-backup-decode-overlap/REPRO.md) | Requires overlapping file imports/exports; picker could not be driven and reachability is unconfirmed. |
| 05 | Two invite creators | BLOCKED-live | [REPRO](05-two-invite-creators/REPRO.md) | Dev backend configuration did not pass the required dev-identity check; no profiles or mutations were created. |
| 06 | Scope response vs subscription echo | BLOCKED-live | [REPRO](06-scope-subscription-echo/REPRO.md) | Requires delayed scope response and second client; safe dev config and UI interaction unavailable. |
| 07 | Root deferred deep link | BLOCKED-live | [REPRO](07-root-deferred-deep-link/REPRO.md) | Three rapid `simctl openurl` requests were sent, but onboarding blocked navigation observation. |
| 08 | Onboarding permission cancellation | BLOCKED-live | [REPRO](08-onboarding-permission-cancellation/REPRO.md) | First-run screen captured; cannot navigate to reminder permission prompt and cancel it with available tooling. |
| 09 | Camera busy cancellation | BLOCKED-live | [REPRO](09-camera-busy-cancellation/REPRO.md) | Barcode route attempted behind onboarding; no capture/lookup or navigation-away interaction was possible. |
| 10 | Persisted uploading | BLOCKED-live | [REPRO](10-persisted-uploading/REPRO.md) | Requires authenticated upload and termination mid-request; no safe dev identity/backend config. |
| 11 | Widget exchange handle | BLOCKED-live; static only | [REPRO](11-widget-exchange-handle/REPRO.md) | Static interleaving remains plausible at the in-flux branch head; live widget reproduction intentionally not attempted. |

Each artifact directory contains the repeatable event order, code references, live attempt notes, and a sub-5 MB simulator screenshot. The launch screenshot is evidence of the test setup only, not a reproduction.

## Validation and limitations

- `origin/main` app sources in this worktree match current `origin/main`; Debug build succeeded.
- The iPhone 17e was erased for a clean install, launched, and shut down after capture. The simulator lock was released.
- `agent-device`, `idb`, `maestro`, and `applesimutils` were not installed. XcodeBuildMCP UI inspection required `simulatorId` defaults, which the task forbids configuring. `simctl` can launch/open URLs but does not synthesize touch events.
- HealthKit sample injection was unavailable: `simctl privacy` does not list HealthKit, and `simctl push` is for APNs.
- Dev sharing smoke was not run because the environment check did not establish the required `energized-pigeon-822` target. No backend identities were created.
- No temporary hooks were used. No app code was changed.
