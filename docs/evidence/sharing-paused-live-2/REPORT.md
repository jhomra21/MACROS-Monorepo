# Sharing paused-state live test, attempt 2

## Result

The dev Convex deployment `energized-pigeon-822` was tested with `sharingRequirePro` enabled briefly and then restored to the initially empty `settings` table. No code was deployed or changed.

- Flag ON command started: `2026-11-02T02:15:00Z`; Convex created the `sharingRequirePro: true` row at `2026-11-02T02:15:03.057Z`.
- Flag OFF was successfully invoked at `2026-11-02T02:16:29Z`; the follow-up query confirmed restoration at `2026-11-02T02:16:31Z`.
- Confirmed flag-on window: approximately 88 seconds (from row creation at `02:15:03Z` until the empty table was confirmed at `02:16:31Z`).
- Initial and final `CONVEX_DEPLOYMENT=dev:energized-pigeon-822 bunx convex data settings` outputs were both empty; byte-for-byte comparison passed.
- `CONVEX_URL=https://energized-pigeon-822.convex.cloud bun scripts/sharingSmoke.ts`: passed.
- `CONVEX_DEPLOYMENT=dev:energized-pigeon-822 bunx convex insights`: “No issues found. The deployment is healthy over the last 72 hours.”

## Setup and baseline

- Worktree: `/Users/juan/.t3/worktrees/cal-macro-tracker/sharing-ui`
- Branch/head: `fix/sharing-ui-ring-polish` / `309939a72e085e0593386545d9d0081fa1f4ef17` (fast-forward pull reported already up to date).
- Built the Debug app with Xcode 26.4.1 (`DEVELOPER_DIR=/Applications/Xcode-26.4.1.app/Contents/Developer`) and installed on:
  - A: iPhone 17, `918D29B9-97D3-42C0-9C47-00605E01E8DB`
  - B: iPhone 17e, `F976E800-DA1F-4F20-B755-DFD964E33975`
- A had a Test B relationship; B initially had no relationship. Created an invite on A and accepted it on B. A's local DEBUG Pro was used only to create the invite; it does not grant server-side Pro.
- On B, logged Banana (105 kcal) and Chicken Breast (128 kcal), enabled local sharing, and set Test A's scope to Macros + Foods. A showed Test B's 233 kcal, macro rings, and both foods before the flag was changed.
- Baseline screenshots: `baseline-person-A.png`, `baseline-sharing-list-A.png`.

## Flag commands

The settings table was empty before the test. The exact ON command was:

```sh
cd /Users/juan/.t3/worktrees/cal-macro-tracker/sharing-ui/convex-backend && CONVEX_DEPLOYMENT=dev:energized-pigeon-822 bunx convex import --append --table settings ../build/sharing-paused-live-2/settings-on.jsonl
```

`settings-on.jsonl` contained `{"sharingRequirePro":true}`.

The first OFF attempt prompted for confirmation and was rejected by the non-interactive terminal. No import was applied by that failed attempt. The immediate successful OFF command was:

```sh
cd /Users/juan/.t3/worktrees/cal-macro-tracker/sharing-ui/convex-backend && CONVEX_DEPLOYMENT=dev:energized-pigeon-822 bunx convex import --replace --table settings ../build/sharing-paused-live-2/settings-empty.jsonl --yes
```

The empty JSONL import reported deleting 1 of 1 settings rows and adding 0 documents. A subsequent settings query reported no documents.

## Paused-state observations

- `paused-person-A.png`: Test B's person page showed “Sharing is paused because neither person has MACROS Pro,” an Upgrade to MACROS Pro button, and the “Sharing is paused” card instead of rings or foods.
- `paused-list-A.png`: the Test B row showed “Paused, needs MACROS Pro” in orange.
- `paused-reopen-A.png`: reopening Test B showed the paused card, with no cached rings or foods visible.
- `paused-person-B.png`: Test A's person page also showed the pause message, Upgrade button, and paused card.
- The required screen recording is `paused-window.mov`.

## UI issue observed

On both paused person pages, the sharing-scope segmented control still appeared enabled. Accessibility snapshots also exposed its Nothing, Macros, and Macros + Foods buttons without a disabled state. This conflicts with the expected disabled scope control while paused. No app code was changed.

## Restoration

- `restored-person-A.png`: after the empty settings restore, Test B's rings and both foods returned.
- `restored-list-A.png`: A's list returned to the normal Test B summary row.
- The post-restore settings output matched the empty baseline. Each saved query output records “There are no documents in this table.”

## Captures

All included stills, the recording, and `convex-insights.txt` are below 5 MB each. The invite URL and unrelated first-launch/share-sheet images are intentionally excluded.
