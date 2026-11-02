# Sharing paused-state live test

## Result

Aborted before changing the dev deployment. The required baseline could not be confirmed after installing and launching the Debug build:

- Device A showed the Today dashboard with zero logged foods, not Test B's sharing row.
- Device B showed the first-run “See your sharing circle” tutorial.
- Therefore the requested existing connection, cached rings, and foods were not available to verify before the server-wide flag change.

`sharingRequirePro` was never enabled. No deployment data was modified.

## Worktree and build

- Worktree: `/Users/juan/.t3/worktrees/cal-macro-tracker/sharing-ui`
- Branch/head: `fix/sharing-ui-ring-polish` / `309939a72e085e0593386545d9d0081fa1f4ef17`
- Pulled with `git pull --ff-only`; already up to date.
- Built Debug with Xcode 26.4.1 and installed/launched `juan-test.cal-macro-tracker` on:
  - A: iPhone 17, `918D29B9-97D3-42C0-9C47-00605E01E8DB`
  - B: iPhone 17e, `F976E800-DA1F-4F20-B755-DFD964E33975`

## Dev settings

Baseline command:

```sh
cd /Users/juan/.t3/worktrees/cal-macro-tracker/sharing-ui/convex-backend && CONVEX_DEPLOYMENT=dev:energized-pigeon-822 bunx convex data settings
```

Output: `There are no documents in this table.`

The same command was rerun at `2026-11-02T01:35:27Z`; `cmp` confirmed its captured output matches `settings-before.txt` exactly. The captured outputs are in `settings-before.txt` and `settings-after.txt`.

For reference, Convex's documented, deployment-scoped import commands were prepared but **not run**:

```sh
cd /Users/juan/.t3/worktrees/cal-macro-tracker/sharing-ui/convex-backend && CONVEX_DEPLOYMENT=dev:energized-pigeon-822 bunx convex import --append --table settings ../build/sharing-paused-live/settings-on.jsonl
cd /Users/juan/.t3/worktrees/cal-macro-tracker/sharing-ui/convex-backend && CONVEX_DEPLOYMENT=dev:energized-pigeon-822 bunx convex import --replace --table settings ../build/sharing-paused-live/settings-empty.jsonl
```

The second command restores the exact empty-table baseline using Convex's documented empty-import table-clearing flow.

## Captures and validation

- `baseline-home.png` and `current-A.png`: A's Today dashboard, no visible sharing connection.
- `current-B.png`: B's first-run sharing tutorial.
- `route-launch.png`: transitional screen during a route launch; not evidence of sharing data.
- No screen recording was started and no paused-state captures were possible.
- Flag on/off UTC times and active duration: not applicable; flag was never enabled.
- Smoke test and Convex insights were skipped because preconditions were not met.
- No app code was changed.
