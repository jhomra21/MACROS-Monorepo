# Build-28 in-place upgrade

Media removed in the repo cleanup; retrieve with `git show 074b10994f1b68d9d7a8d6c54ed7effb90d5f1f5:docs/evidence/shared-person-widget-e2e/01-small-shared.png`.

Device A: iPhone 17, `918D29B9-97D3-42C0-9C47-00605E01E8DB`.
No erase, uninstall, identity reset, or re-pairing was performed.

1. Built base `8ebd989` (build 28) under `build/shared-widget/build28`.
2. Installed it over A's existing app and opened its existing Test A ↔ Test B
   relationship. `32-migration-before.png`, 16:35 local, shows Test B.
3. Installed the feature app in place. `33-migration-after.png`, 16:37 local,
   shows the same connected Test B without accepting a new invite.
4. Logged synthetic Widget E2E Oats on B, through its UI, at 16:40:
   650 calories, P40/C80/F20. Goals are 2200/160/220/70.
5. Added actual shared widgets on A. The slimmed simulator initially prevented
   App Intents execution. After temporarily enabling the two owner-authorized
   dependencies described in REPORT, the extension independently authenticated
   and fetched Test B. `01-small-shared.png` through `05-rectangular-shared.png`
   show actual shared totals/goals. They are not gallery previews.
6. Cold and warm person links still resolve the current relationship
   (`27-cold-link.png`, `28-warm-link.png`).

This proves the relationship survived an in-place build-28 upgrade and the
extension can use the migrated device identity. Credential bytes were never
printed. Exact byte equality, migration idempotence, scoped verified deletion,
fresh shared insertion, private invite insertion, and legacy unscoped
read/update/delete are covered by the prewritten isolated Keychain checks.

Build 25 and newer downgrade compatibility is based on their unscoped Keychain
operations finding/updating the group item, not a claimed separate TestFlight
downgrade run. Hardware data-protection and distribution signing remain gates.
