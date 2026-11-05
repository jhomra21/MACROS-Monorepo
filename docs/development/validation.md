# Validation

Run commands from the active repository root unless a package directory is shown. Install dependencies with `bun install --frozen-lockfile` in each package first. Keep logs under ignored build/evidence.

## Native checks

```sh
make quality-storekit
make quality-format-check
make quality-build
xcodebuild -list -project cal-macro-tracker.xcodeproj
git diff --check
```

`quality-format-check` runs official `swift-format lint --strict --parallel --recursive --configuration .swift-format cal-macro-tracker`. The wrapper warns and skips if the tool is absent; a skip is not a formatting pass. `make format` applies it. `make quality-build` compiles but does not execute XCTest.

Other existing targets: `quality-dead` (Periphery), `quality-dup`, `quality-debt`, `quality-deps`, `quality-n1`, and `quality-secrets`. `make quality` combines these with build, formatting, and StoreKit checks. Heuristics do not prove runtime correctness.

Read the [runbook](simulator-runbook.md), acquire an available device's lock, and replace the placeholder with a safe existing UDID. Never use the owner fixture. Run serially with bounded allowances:

```sh
xcodebuild \
  -project cal-macro-tracker.xcodeproj \
  -scheme cal-macro-tracker \
  -destination 'platform=iOS Simulator,id=<IOS_SIMULATOR_UDID>' \
  -parallel-testing-enabled NO \
  -test-timeouts-enabled YES \
  -default-test-execution-time-allowance 30 \
  -maximum-test-execution-time-allowance 45 \
  test
```

For one class, add `-only-testing:cal-macro-trackerTests/InsightsAnalyticsTests` before `test`. StoreKit tests require the explicitly selected compatible toolchain described in the runbook. Test resources, including migration stores, remain in the test bundle. [Goal calculator failure cases](../../cal-macro-trackerTests/GoalCalculatorTests.md) are part of the test specification.

After instruction/resource changes, inspect the built .app and embedded .appex for Markdown. New AGENTS or docs files must not enter either bundle.

## JavaScript and TypeScript

```sh
make lint-js
# In each affected package: web, worker/auth, worker/usda-proxy, convex-backend
bun run check
# From the root, with tools/runtime-qa and convex-backend dependencies installed:
make qa-network
```

Oxlint uses root `.oxlintrc.json`, vendored anti-slop rules, and complexity maximum 20. Keep coverage and severities unchanged. See [tooling instructions](../../tools/oxlint/README.md). Astro script lint does not validate markup; web check runs Wrangler types, Astro check, and TypeScript.

Worker auth check includes Bun tests. The proxy's runtime tests run through [runtime QA](../../tools/runtime-qa/README.md), which mocks upstreams and uses loopback Miniflare HTTP. Convex `bun run test:integration` uses convex-test in memory, not a production deployment. Neither requires credentials.

On macOS, also run:

```sh
cd web && bun run check && bun run build
# From the root:
bun docs/evidence/web-og/verify-og.mjs
```

The OG verifier rebuilds disposable copies and writes raw output under build/evidence. Linux CI must not run web build because the generator needs macOS Helvetica. Never substitute `deploy` for check/build; it can migrate remote D1 and publish.
