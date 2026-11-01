# Sharing v2 backend validation

Date: 2026-11-01. Branch: `feat/sharing-v2`, based on `e3aa3df`.
Scope: Convex backend only, plus the supplied plan and changes log.

## Implemented

- Additive schema, optional food scope, 100-food/day cap, bounded text and numeric
  inputs, owner/day food diffing, first-sync cleanup, and bounded weekly sweeping.
  `by_day` is an additional index so sweeping never scans newer food rows.
- `syncMyDay`, `setOutgoingScope`, and `personDay`, with build 23 wrappers and
  unchanged legacy response types. `setOutgoingScope` accepts optional `ownerDay`
  for owner-local interval boundaries; when omitted it uses server UTC today.
  Live person/day queries require both matching day arguments and the same
  server-current day window used by the existing dashboard.
- Pure Pro/connection policies, an absent-settings-row default of false, and
  internal atomic entitlement writes with a five-profile purchase cap.
- Two offline Apple verifiers, only three Pro product IDs, signed renewal/grace
  handling, authenticated purchase submission, and V2 notifications. Notification
  updates use Apple's `signedDate`, never arrival time; stale/equal updates do not
  overwrite newer state. New profile attachments inherit newer purchase state.
  A newer renewal JWS cannot clear a refund using an older transaction.
- Immediate profile tombstoning followed by indexed jobs deleting at most 100
  rows per transaction across all seven requested data categories.
- Return validators on every public query, mutation, and action. Strict bootstrap
  input parsing returns 400 without coercion.

## Checks

From `convex-backend/`, using Bun:

```sh
bun install
bun run check
bun run test
bun run test:integration
```

- `check`: TypeScript passed, then **19/19 unit tests** passed.
- `test`: **19/19 unit tests**, zero failures (11 verifier, 8 sharing-model).
- `test:integration`: **41/41 tests**, zero failures (36 sharing, 5 quota).
- From repository root, `make lint-js`: **0 errors, 0 warnings**.
- `git diff --check`: passed.
- Offline type generation: `bunx convex codegen --system-udfs --typecheck disable`.
  The installed CLI source confirms this path only generates local types; no
  deployment credentials or remote push are involved.
- Local esbuild runtime check: **15 isolate entrypoints / 26 bundle files** and
  **2 Node entrypoints / 3 bundle files**, with no package externals needed.
  This checks bundling, not execution inside a deployed Convex Node runtime.

The integration suite exercises registered Convex functions, authentication,
validators, the HTTP router, quotas, scheduling, database writes and privacy rules.
Only `AppleVerifier` methods are replaced for deterministic purchase fixtures.
Unit tests exercise real Apple verifier rejection paths, environment routing,
wrong bundle rejection, and an in-memory ES256-signed synthetic fixture that must
fail without an Apple certificate chain. The static Apple-published test fixture
was replaced with owner authorization after Droid-Shield flagged its JWS.
These tests do not prove a successful real-device purchase or verify a complete
Apple-style test certificate chain.

## Deployment: skipped by owner instruction

- No deployment or smoke test against **any** deployment is allowed in Phase 1.
  `energized-pigeon-822` is the live build 23/App Review backend and must not be
  touched, even if its label starts with `dev:`.
- **Nothing deployed. No smoke test run.** Deployment-based verification with a
  real Sandbox transaction is also skipped in this phase.
- No production deployment, production insights query, App Store Connect change,
  Swift change, Worker change, or web change was made. Step 0 MCP/AI-files setup
  remains outside Phase 1 as specified by the adopted plan.

### Files a future deployment would push

Convex deploys bundled function modules and configuration, not a Git diff.
The following Phase 1 sources would affect that payload:

```text
convex-backend/convex/schema.ts
convex-backend/convex/sharing.ts
convex-backend/convex/sharingValidators.ts
convex-backend/convex/foodSharing.ts
convex-backend/convex/foodCleanup.ts
convex-backend/convex/profileDeletion.ts
convex-backend/convex/proModel.ts
convex-backend/convex/entitlements.ts
convex-backend/convex/entitlementRecords.ts
convex-backend/convex/appleVerification.ts
convex-backend/convex/_lib/appleVerifier.node.ts
convex-backend/convex/_lib/purchasePolicy.ts
convex-backend/convex/appleRoots/root.ts
convex-backend/convex/crons.ts
convex-backend/convex/http.ts
```

The Node bundles include `@apple/app-store-server-library` and its dependencies
from `package.json`/`bun.lock`. Unchanged backend modules and `auth.config.ts`
also participate in a complete deployment. Generated server/API modules support
bundling. Tests, Markdown reports, and the DER asset are not deployed as standalone
files; the root's bytes are embedded through `appleRoots/root.ts`.

## Certificate

Apple Root CA G3 DER, downloaded directly from Apple:

`63343abfb89a6a03ebb57e9b3f5fa7be7c4f5c756f3017b3a8c488c3653e9179`

## Owner follow-up

1. Leave all deployments untouched during Phase 1. Any later deployment or
   device-based verification requires separate owner authorization.
2. Configure notification URLs separately for Sandbox and Production at release.
3. Keep `settings.sharingRequirePro` false until updated clients have submitted
   entitlements. Maintain at most one settings row (queries use `.unique()`).
2026-11-01 review fixes (`fix/sharing-v2-backend-review`): retained per-transaction anti-replay state, independent renewal ordering, five-profile links, scheduled reactive Pro expiry, REFUND_REVERSED, active-only 100-person dashboard, and dead quota job removal; 22 regression tests (15 initially failing, then 3 additional edge cases reproduced), 19/19 unit and 63/63 integration tests, TypeScript/offline codegen and root Oxlint clean (make unavailable; used `bun tools/oxlint/node_modules/oxlint/bin/oxlint --config .oxlintrc.json`); grace requires an unrevoked latest subscription period; rejected sixth-profile submissions still commit verified purchase updates; no deployment, real Sandbox purchase, or live subscription transport verified. Owner-requested follow-up: sharedFoodDays stores one capped, whitelisted array per owner/day, with canonical no-write retries, unique person-day reads and bounded pre-today cleanup/deletion; public API unchanged; 19/19 unit and 66/66 integration tests, TypeScript/offline codegen and root Oxlint passed; nothing deployed.
