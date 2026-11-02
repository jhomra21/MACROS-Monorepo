# Reusable sharing invite evidence

## Outcome

Implemented and pushed `feat/reusable-invite-link` from `origin/main` at `1cbea61`.
Dev backend only: `https://energized-pigeon-822.convex.cloud`.
No production deployment, website deployment, merge, version bump, or upload.
The owner's checkout and all `IGNOREDbuild/` directories were not accessed.
No subagents, simulator erases, or XcodeBuildMCP session/profile/config writes.

### Focused commits

- Backend + integration/HTTP smoke + single changes-log entry:
  `5a77b64ec9628b59b545e1a17e2ff2da8ae0bf4a`
- App identity-bound local reuse + regression coverage:
  `f71a46db2579e8590dd71d5b063bfe1dcf756f90`
- App/website copy:
  `82edd2f6f20cd1ef47b68378c66ff51350bd8011`
- Aggregate: **12 files, 216 insertions, 37 deletions**.

## Behavior and security

- `acceptInvite` leaves the invite pending and no longer writes `acceptedAt` or
  `acceptedByProfileId`. Schema fields are retained. Old accepted documents and
  accepted-hash history still block reuse.
- All prior owner/deletion/self/hash/live checks remain. Repeat acceptance keeps
  the relationship and open grant; removed pairs can reconnect.
- Server creation is unchanged, including revoking old pending links for a truly
  new hash, same-hash retry, seven-day TTL, and the 20/day creation quota.
- App reuse requires the saved profile key to match the current Keychain identity
  and more than one hour to remain. It returns before authentication/server calls.
  Unbound old links are discarded because they might already be consumed.
- Settings already has Revoke Invite, then Create Invite Link, so no button was added.
- Anyone holding a link can connect/reconnect until expiry or revocation.
  Removing a person is not link revocation. Existing connections survive revocation.
- Per-invite acceptance rate limiting is recommended, not added. Existing quotas
  are per-profile and do not provide a trivial per-invite counter.
- Cleanup reviewed: the only cron sweeps shared foods. Deletion removes all owned
  invites and historical accepted-by references. Not recording new accepted-by
  fields prevents acceptor deletion from deleting the owner's reusable link.

## Failure-first coverage

`FAILURE-MODES.md` was written before implementation. Integration and HTTP smoke
coverage and native regression tests were added before changing product code.
`integration-before.log` records **5 expected failures** on the old server.
`integration-after.log` records the green run.

| Check | Result | Evidence |
| --- | --- | --- |
| Backend `bun run check` | Typecheck + 20 unit tests passed | `backend-check.log` |
| Backend `bun run test:integration` | 75 passed | `integration-after.log` |
| `make lint-js` | Passed | `lint.log` |
| `make quality-format-check` | Passed | `format.log` |
| `make quality-build` | Passed | `build.log` |
| Full serial iPad suite, StoreKit class excluded | 228 passed, 0 failures | `app-tests.log`, `test-summary.json` |
| Website `bun run check` | 31 Astro files, 0 errors/warnings/hints; TypeScript passed | `web-check.log` |
| Dev HTTP smoke | Passed, including two acceptors and repeated acceptance | `smoke.log` |
| Dev insights before | No issues, healthy over prior 72 hours | `insights-before.log` |
| Dev insights after deployment, smoke and UI evidence | No issues, healthy over prior 72 hours | `insights-after.log` |

The iPad was shutdown and had no active test process before the serial run:
`E91B597B-CE57-4C0B-A8A4-51CBDC3386AB`.
Options: `-parallel-testing-enabled NO -test-timeouts-enabled YES`
`-default-test-execution-time-allowance 30`
`-maximum-test-execution-time-allowance 45`
`-skip-testing:cal-macro-trackerTests/PurchaseStoreStoreKitTests`.
The full local `.xcresult` remains under `build/reusable-invite/Tests.xcresult`;
the published folder includes its exported summary, not DerivedData or bundle internals.
Raw command logs and the exact patch retain tool-emitted whitespace. They produce
`git diff --check` whitespace notices when added as evidence; source diffs pass.

## Deployment confirmation

After backend tests/lint passed, ran:

```sh
cd /Users/juan/.t3/worktrees/cal-macro-tracker/reusable-invite/convex-backend && CONVEX_DEPLOYMENT=dev:energized-pigeon-822 bunx convex dev --once --typecheck enable --tail-logs disable
```

`deploy.log` confirms the exact dev URL and **Convex functions ready**.
`deployed-function-spec.json` confirms the deployed function signatures.
Convex did not print a deployed function hash. The deployed `sharing.ts` source
SHA-256 is `7d5f9f1853ddea2844a5b747c3aba39836554fcc291e1776821a348187dfb729`;
this is a **source hash**, not a claimed Convex deployment hash.
`backend.diff` is the exact production-function diff (one comment change and
removal of the acceptance-status patch); creation and schema are unchanged.
CLI-generated template-only changes were discarded, leaving no generated API churn.

```sh
cd /Users/juan/.t3/worktrees/cal-macro-tracker/reusable-invite/convex-backend && CONVEX_DEPLOYMENT=dev:energized-pigeon-822 bunx convex insights
cd /Users/juan/.t3/worktrees/cal-macro-tracker/reusable-invite/convex-backend && CONVEX_URL=https://energized-pigeon-822.convex.cloud bun scripts/sharingSmoke.ts
```

The smoke creates disposable A/B/C profiles. B and C accept A's same link, B
repeats acceptance, dashboards and snapshots are checked, revocation is rejected,
and a deleted owner's link is rejected. A and B are deleted during the scenario;
the `finally` cleanup deletes remaining C. Therefore the final line saying
“Cleaned up 1 disposable profiles” means **one remaining profile**, not two leaked
profiles. Every run tombstones all three through the public deletion API, whose
scheduled cleanup removes related data.

## Live A/B proof

- A: iPhone 17 `918D29B9-97D3-42C0-9C47-00605E01E8DB`, existing Test A identity/data.
- B: iPhone 17e `F976E800-DA1F-4F20-B755-DFD964E33975`, existing Test B identity/data.
- Waited while A had an active `add-food-zoom` claim. The owner explicitly said
  the job was finished and released A before it was used.
- Installed the validated Debug app without erasing either device. Debug Pro was
  granted through the existing Developer control (it was off after installation).
  No demo data was loaded. Existing pairing was retained.
- A's two Create Invite Link taps returned the identical URL and expiry:
  `a-first-create.png`, `a-second-create.png`, and their matching
  `a-first-settings.json.txt` / `a-second-settings.json.txt`.
- B independently showed identical URL/expiry across two taps:
  `b-first-create.png`, `b-second-create.png` and corresponding hierarchies.
- B opened A's link and accepted twice. `b-people.png` / `b-people.json.txt` show
  exactly one **Test A** connection afterward, against dev (no mocked backend).
- No third simulator was used. The **second distinct acceptor** is proved by
  the disposable HTTP smoke plus row-level registered integration tests.
- Both captured links were revoked before publishing, confirmed by
  `a-revoked.json.txt` / `b-revoked.json.txt` with no invite/share controls or errors.
  The screenshots therefore contain revoked, non-authorizing test tokens.
- A and B were both **shut down** immediately afterward at the owner's request
  so the sharing-animation job could proceed. The owner's Air was not used.

Run the standalone evidence verifier from either evidence folder:

```sh
cd /Users/juan/.t3/worktrees/cal-macro-tracker/reusable-invite/build/reusable-invite && python3 verify-evidence.py
```

## Copy changes (complete list)

1. `SharingScreen.swift`: footer explains anyone with the link can connect,
   seven-day expiry, revocation, same-link reuse, and revoke-then-create replacement.
2. `SharingPersonScreen.swift`: Remove Person confirmation no longer says a new
   invite is required; warns a live link allows reconnection until expiry/revocation.
3. `web/src/data/site.ts`: Pro FAQ explains reusable link access and expiry/revocation.
4. `web/src/pages/privacy.astro`: new paragraph explains bearer-link access,
   reuse/replacement, and revocation versus removing existing connections;
   policy effective date updated to November 1, 2026.

The app, `web/src`, and `docs` were searched for once / one person / single / invite
language. No other user-facing single-use claim was found. No website was deployed.
**A website deploy is needed to publish the FAQ/privacy copy.**

## Limits

- StoreKit tests deliberately excluded, as requested.
- Did not wait seven real days. Exact expiry, missing owner, corrupt/duplicate
  hashes and legacy consumed rows are covered by registered integration tests.
- No per-invite rate limit, website deploy, production deploy, version bump,
  upload, merge, or PR was requested/performed.
- Settings screenshots, not system share-sheet screenshots, prove repeated app
  creation. The dashboard + menu uses the same tested `createInvite()` service.
- This is current dev verification, not proof of behavior in an installed old
  TestFlight binary; registered wire-shape compatibility tests pass.
- Convex MCP status initially required `CONVEX_DEPLOYMENT`; explicit dev-only
  CLI selection was used. UI CLI calls used explicit simulator IDs and
  `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`; no defaults were set.

Final review found no redundant product logic, duplicate grant creation, schema
changes, or unrelated edits. The only cleanup was removing a smoke helper wrapper.
