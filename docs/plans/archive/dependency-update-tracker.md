# JavaScript and TypeScript Dependency Update

Updated 2026-10-26 with Bun 1.4.4. Latest stable versions were checked with `bun outdated` and the npm registry's `latest` tags. Each dependency's official release notes, changelog, or current API documentation was reviewed before upgrading.

## Dependency changes

| Package | Dependency | From → to | Current docs / release notes consulted | Breaking changes and response |
| --- | --- | --- | --- | --- |
| `worker/usda-proxy` | `hono` | 4.10.1 → 4.13.14 | [Hono v4.13.14](https://github.com/honojs/hono/releases/tag/v4.13.14) | No breaking change noted in the release; the worker check and runtime E2E passed. |
| `worker/usda-proxy` | `zod` (exact) | 4.1.12 → 4.6.7 | [Zod v4.6.7](https://github.com/colinhacks/zod/releases/tag/v4.6.7) | Stayed on major v4; typecheck passed. |
| `worker/usda-proxy` | `@types/bun` | 1.3.12 → 1.4.4 | [DefinitelyTyped Bun types](https://github.com/DefinitelyTyped/DefinitelyTyped/tree/master/types/bun) | Type-only update; typecheck passed. |
| `worker/usda-proxy` | `@types/node` | 24.5.2 → 26.6.5 | [DefinitelyTyped Node types](https://github.com/DefinitelyTyped/DefinitelyTyped/tree/master/types/node) | Node 26 declarations typecheck on the existing runtime toolchain. |
| `worker/usda-proxy` | `typescript` | 5.9.3 → 7.0.2 | [TypeScript 7.0.2](https://github.com/microsoft/TypeScript/releases/tag/v7.0.2) | TypeScript 7 compiler passed `tsc --noEmit`. |
| `worker/usda-proxy` | `wrangler` | 4.80.0 → 4.116.0 | [Wrangler 4.116.0](https://github.com/cloudflare/workers-sdk/releases/tag/wrangler%404.116.0) | Held at newest Wrangler with stable Miniflare 4 / workerd 1.20260730.1. Newer Wrangler 4.117+ requires Miniflare 5 prereleases; matching the Worker test runtime takes priority over adopting that prerelease. |
| `worker/auth` | `hono` | 4.12.18 → 4.13.14 | [Hono v4.13.14](https://github.com/honojs/hono/releases/tag/v4.13.14) | No breaking change noted in the release; tests passed. |
| `worker/auth` | `jose` | 6.2.3 → 6.2.13 | [jose v6.2.13](https://github.com/panva/jose/releases/tag/v6.2.13) | Terminology refactor and preserved error causes; no call-site change required. |
| `worker/auth` | `zod` (exact) | 4.1.12 → 4.6.7 | [Zod v4.6.7](https://github.com/colinhacks/zod/releases/tag/v4.6.7) | Stayed on major v4; tests passed. |
| `worker/auth` | `@types/bun` | 1.3.12 → 1.4.4 | [DefinitelyTyped Bun types](https://github.com/DefinitelyTyped/DefinitelyTyped/tree/master/types/bun) | Type-only update; check passed. |
| `worker/auth` | `@types/node` | 25.0.0 → 26.6.5 | [DefinitelyTyped Node types](https://github.com/DefinitelyTyped/DefinitelyTyped/tree/master/types/node) | Type-only update; check passed. |
| `worker/auth` | `typescript` | 5.9.3 → 7.0.2 | [TypeScript 7.0.2](https://github.com/microsoft/TypeScript/releases/tag/v7.0.2) | TypeScript 7 compiler passed; 3 unit tests passed. |
| `worker/auth` | `wrangler` | 4.88.0 → 4.116.0 | [Wrangler 4.116.0](https://github.com/cloudflare/workers-sdk/releases/tag/wrangler%404.116.0) | Held at newest Wrangler with stable Miniflare 4 / workerd 1.20260730.1; newer 4.117+ uses Miniflare 5 prereleases. |
| `web` | `astro` | 6.1.6 → 7.4.2 | [Astro v7 upgrade guide](https://docs.astro.build/en/guides/upgrade-to/v7/), [Astro changelog](https://github.com/withastro/astro/blob/main/packages/astro/CHANGELOG.md) | V7 switches to Vite 8/Rust compiler, makes JSX whitespace compression default, and requires Node ≥22.23.4. Raised the `engines.node` floor to 22.23.4; `astro check` and production build passed. |
| `web` | `zod` | 4.1.12 → 4.6.7 | [Zod v4.6.7](https://github.com/colinhacks/zod/releases/tag/v4.6.7) | Stayed on major v4; check/build passed. |
| `web` | `@astrojs/check` | 0.9.8 → 0.9.12 | [Astro v7 upgrade guide](https://docs.astro.build/en/guides/upgrade-to/v7/) | Updated with Astro; check and build passed. |
| `web` | `@types/bun` | 1.4.4 → 1.4.4 | [DefinitelyTyped Bun types](https://github.com/DefinitelyTyped/DefinitelyTyped/tree/master/types/bun) | Already at latest stable; unchanged. |
| `web` | `@types/node` | 25.6.0 → 26.6.5 | [DefinitelyTyped Node types](https://github.com/DefinitelyTyped/DefinitelyTyped/tree/master/types/node) | Type-only update; Astro check/build passed. |
| `web` | `typescript` | 5.9.3 → 6.0.3 | [TypeScript 6.0 notes](https://www.typescriptlang.org/docs/handbook/release-notes/typescript-6-0.html), [TypeScript 7.0.2](https://github.com/microsoft/TypeScript/releases/tag/v7.0.2) | Held at 6.0.3, the newest compatible release: `astro check` currently rejects TypeScript 7.0 with an explicit unsupported-version error. This was confirmed by a failed 7.0 check, then the 6.0 check/build passed. |
| `web` | `wrangler` | 4.82.2 → 4.116.0 | [Wrangler 4.116.0](https://github.com/cloudflare/workers-sdk/releases/tag/wrangler%404.116.0) | Held at newest stable Miniflare 4-matched Wrangler (workerd 1.20260730.1); 4.117+ uses Miniflare 5 prereleases. |
| `convex-backend` | `convex` | 1.37.0 → 1.48.0 | [Convex JavaScript docs](https://docs.convex.dev/client/javascript), [Convex releases](https://github.com/get-convex/convex-backend/releases) | No API edits; code check and 23 registered integration tests passed. Codegen could not run without a configured Convex deployment; no deployment was created or contacted with a valid deployment identifier. |
| `convex-backend` | `zod` (exact) | 4.1.12 → 4.6.7 | [Zod v4.6.7](https://github.com/colinhacks/zod/releases/tag/v4.6.7) | Stayed on major v4; check and integration tests passed. |
| `convex-backend` | `@edge-runtime/vm` | 5.0.0 → 5.0.0 | [Convex test guidance](https://docs.convex.dev/testing/convex-test) | Already at latest stable; unchanged. |
| `convex-backend` | `@types/bun` | 1.3.12 → 1.4.4 | [DefinitelyTyped Bun types](https://github.com/DefinitelyTyped/DefinitelyTyped/tree/master/types/bun) | Type-only update; check passed. |
| `convex-backend` | `@types/node` | transitive → 26.6.5 | [DefinitelyTyped Node types](https://github.com/DefinitelyTyped/DefinitelyTyped/tree/master/types/node) | Added as a direct devDependency because TypeScript 7 no longer auto-includes `@types/*`; `convex/tsconfig.json` sets `"types": ["node"]`. Convex typecheck passed. |
| `convex-backend` | `convex-test` (exact) | 0.0.54 → 0.0.65 | [Convex test docs](https://docs.convex.dev/testing/convex-test) | Upgraded the exact pin; integration suite passed (23/23). |
| `convex-backend` | `typescript` | 5.9.3 → 7.0.2 | [TypeScript 7.0.2](https://github.com/microsoft/TypeScript/releases/tag/v7.0.2) | TypeScript 7 compiler passed check and integration suite. |
| `convex-backend` | `vitest` | 5.0.4 → 5.0.5 | [Vitest v5.0.5](https://github.com/vitest-dev/vitest/releases/tag/v5.0.5) | Patch release contains test cleanup and runner fixes; integration tests passed. |
| `tools/runtime-qa` | `zod` (exact) | 4.1.12 → 4.6.7 | [Zod v4.6.7](https://github.com/colinhacks/zod/releases/tag/v4.6.7) | Stayed on major v4; check and runtime E2E passed. |
| `tools/runtime-qa` | `@types/node` | 25.0.0 → 26.6.5 | [DefinitelyTyped Node types](https://github.com/DefinitelyTyped/DefinitelyTyped/tree/master/types/node) | Type-only update; check passed. |
| `tools/runtime-qa` | `esbuild` | 0.27.4 → 0.28.2 | [esbuild v0.28.2](https://github.com/evanw/esbuild/releases/tag/v0.28.2) | Release fixes TypeScript alias tree-shaking, CSS minification, output overwrite safeguards, and top-level-await output; runtime E2E passed. |
| `tools/runtime-qa` | `jose` | 6.2.3 → 6.2.13 | [jose v6.2.13](https://github.com/panva/jose/releases/tag/v6.2.13) | Error causes retained; runtime E2E passed. |
| `tools/runtime-qa` | `miniflare` | 4.20260501.0 → 4.20260730.0 | [Wrangler/Miniflare release 4.116.0](https://github.com/cloudflare/workers-sdk/releases/tag/wrangler%404.116.0) | Kept stable Miniflare 4 paired with Wrangler 4.116.0/workerd 1.20260730.1; full Worker loopback E2E passed. |
| `tools/runtime-qa` | `typescript` | 5.9.3 → 7.0.2 | [TypeScript 7.0.2](https://github.com/microsoft/TypeScript/releases/tag/v7.0.2) | TypeScript 7 compiler passed check and E2E. |
| `tools/food-db` | `csv-parse` | 6.1.0 → 7.0.3 | [csv-parse changelog](https://csv.js.org/parse/changelog/) | The v7 API used by this package remains supported; check and 13 tests / 114 assertions passed. |
| `tools/food-db` | `yauzl` | 3.2.0 → 3.4.0 | [yauzl 3.4.0 API and change history](https://github.com/thejoshwolfe/yauzl) | 3.4 adds Promise wrappers and async iteration; existing consumers remain supported. |
| `tools/food-db` | `zod` | 4.6.7 → 4.6.7 | [Zod v4.6.7](https://github.com/colinhacks/zod/releases/tag/v4.6.7) | Already at latest stable; the caret range was replaced with an exact `4.6.7` pin. |
| `tools/food-db` | `@types/bun` | 1.2.0 → 1.4.4 | [DefinitelyTyped Bun types](https://github.com/DefinitelyTyped/DefinitelyTyped/tree/master/types/bun) | Type-only update; check and tests passed. |
| `tools/food-db` | `@types/yauzl` | 2.10.3 → 3.4.0 | [DefinitelyTyped yauzl types](https://github.com/DefinitelyTyped/DefinitelyTyped/tree/master/types/yauzl) | Types now cover yauzl 3.4 Promise APIs; existing code compiled and tests passed. |
| `tools/food-db` | `typescript` | 5.7.3 → 7.0.2 | [TypeScript 7.0.2](https://github.com/microsoft/TypeScript/releases/tag/v7.0.2) | TypeScript 7 compiler passed check and test validation. |
| `tools/oxlint` | `oxlint` and `@oxlint/plugins` (exact) | 1.88.0 → 1.89.0 | [Oxlint v1.89.0](https://github.com/oxc-project/oxc/releases/tag/oxlint_v1.89.0) | Kept both exact pins paired. The release promotes many built-in rules into recommended presets; the repo uses explicit rules and the current lint gate reported no warnings/errors. |
| `tools/oxlint` | `typescript` | 5.9.3 → 7.0.2 | [TypeScript 7.0.2](https://github.com/microsoft/TypeScript/releases/tag/v7.0.2) | TypeScript 7 compiler passed via package toolchain; smoke test passed. |

## Validation

All seven packages passed `bun install --frozen-lockfile`.

| Package | Validation result |
| --- | --- |
| `worker/usda-proxy` | `bun run check` passed. `wrangler deploy --dry-run --config wrangler.jsonc` passed; durable object, rate limits, and environment bindings matched the existing config. |
| `worker/auth` | `bun run check` passed; 3 tests / 9 expectations. Dry-run passed; token rate-limit and environment bindings matched the existing config. |
| `web` | `bun run check` passed (18 Astro files, 0 errors/warnings/hints); `bun run build` passed (5 pages); dry-run passed with the configured D1, rate limit, and assets bindings. |
| `convex-backend` | `bun run check` passed (8 tests / 16 expectations); `bun run test:integration` passed (23/23). `bunx convex codegen` was attempted but blocked because there is no configured `CONVEX_DEPLOYMENT`; the synthetic name probe was rejected by the Convex API and did not create a deployment. |
| `tools/runtime-qa` | `bun run check` passed; loopback HTTP/Miniflare test passed with 129 requests, 59 assertion groups, and no findings. |
| `tools/food-db` | `bun run check` passed; `bun test` passed (13 tests / 114 expectations). |
| `tools/oxlint` | Root lint gate passed: 65 files, 116 rules, 0 warnings, 0 errors. `node`-based smoke test passed, covering anti-slop, accumulating-spread, plugin-loading, and complexity boundaries. |

Worker type declarations were regenerated by each package's check script. No application-code changes were needed for dependency API migrations. The Oxlint smoke runner was made Windows-compatible and its temp-path comparison made separator-independent.

TypeScript 7 no longer includes `@types/*` packages automatically, so `convex-backend/convex/tsconfig.json` names `"types": ["node"]` and `@types/node` is a direct devDependency there.

The Swift package `convex-swift` was checked on the same day and is already at its latest release, 0.8.1 (February 2026), so no Xcode package update was needed.

Validation logs are in `build/deps-qa-2026-10-26/` (local/generated, not committed).

## 2026-10-29 Web Refresh

Changed only `web/`. Astro moved to its latest patch, and `@types/node` moved to its latest patch. The other holds were re-checked against the registry.

| Package | Dependency | From → to | Current docs / release notes consulted | Breaking changes and response |
| --- | --- | --- | --- | --- |
| `web` | `astro` | 7.4.2 → 7.4.4 | [Astro 7.4.3](https://github.com/withastro/astro/releases/tag/astro%407.4.3), [Astro 7.4.4](https://github.com/withastro/astro/releases/tag/astro%407.4.4) | Patch releases only. 7.4.3 fixes duplicate `<Image />` srcset candidates; 7.4.4 changes `astro add` only. No code change needed. |
| `web` | `@types/node` | 26.6.5 → 26.6.6 | [DefinitelyTyped Node types](https://github.com/DefinitelyTyped/DefinitelyTyped/tree/master/types/node) | Type-only patch; check passed. |
| `web` | `zod` | 4.6.7 → 4.6.7 | [Zod v4.6.7](https://github.com/colinhacks/zod/releases/tag/v4.6.7) | Already at latest stable; unchanged. |
| `web` | `@astrojs/check` | 0.9.12 → 0.9.12 | npm `latest` tag | Already at latest stable; unchanged. |
| `web` | `@types/bun` | 1.4.4 → 1.4.4 | npm `latest` tag | Already at latest stable; unchanged. |
| `web` | `typescript` | held at 6.0.3 | [TypeScript 7.0.2](https://github.com/microsoft/TypeScript/releases/tag/v7.0.2), `@astrojs/check@0.9.12` peer range | Latest stable is 7.0.2, but `@astrojs/check` peers on `typescript` `^5.0.0 \|\| ^6.0.0`. 6.0.3 is the newest 6.x release. Hold until `@astrojs/check` widens its range. |
| `web` | `wrangler` | 4.116.0 → 4.156.0 | [Wrangler 4.156.0](https://github.com/cloudflare/workers-sdk/releases/tag/wrangler%404.156.0), [Wrangler changelog](https://github.com/cloudflare/workers-sdk/blob/main/packages/wrangler/CHANGELOG.md) | Adopted the latest release by owner decision, despite the Miniflare 5 beta dependency (`miniflare@5.20261023.3-beta`, `workerd@1.20261023.1`). Items checked against this project: deploys now upload source maps by default (4.150; no `upload_source_maps` set here); `nodejs_compat` is enabled by default from compatibility date 2026-08-04 (this project uses 2026-04-15 and sets the flag explicitly); the dev registry path (4.154) and `/cdn-cgi` local paths (4.117) moved, and neither is set or used here. `wrangler types` changed `worker-configuration.d.ts` in content, so the file is committed. |

Validation: `bun install`, `bun run check` (18 Astro files, 0 diagnostics), `bun run build` (5 pages), `bun test src/worker.test.ts` (5 pass), `bun run deploy:dry-run` (no deploy), and the `lint-js` oxlint command (65 files, 0 errors). `wrangler types` rewrote `worker-configuration.d.ts` with whitespace only, so that file was restored.

Logs are in `build/web-deps-2026-10-29/` (local/generated, not committed).

Wrangler 4.156.0 (owner decision, same day): `bun run check`, `bun run build`, `bun test src/worker.test.ts` (5 pass), and `bun run deploy:dry-run` (bindings unchanged: SUPPORT_DB, two rate limiters, ASSETS) passed. A local `wrangler dev --config wrangler.api.jsonc` smoke answered `/api/waitlist` and `/api/support` under Miniflare 5 beta, then was stopped. Runtime QA `check` and `test` passed, but those scripts import `miniflare` directly on the stable Miniflare 4 pin, so they do not exercise wrangler or Miniflare 5. The Convex `test:integration` suite (convex-test, in-memory) and the oxlint command passed.

Caveat: Miniflare 5 is still a beta. It runs in `wrangler dev` and the tests. The deploy path runs wrangler itself, which is a release with a beta Miniflare dependency. Revert the pin to 4.116.0 if a dev or deploy regression appears.

Follow-up 2026-10-29: `cf migrate` for `web/` was tried and reverted. `cf build` delegates to `astro build` for Astro projects and never writes Worker Build Output, and the Cloudflare docs say Astro 6+ does not build with `cf` during the beta. Wrangler stays the build and deploy tool for `web/`. Workers Issues and full observability sampling were enabled in `web/wrangler.jsonc`.
