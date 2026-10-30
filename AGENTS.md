# AGENTS.md

## Philosophy

This codebase will outlive you. Every shortcut becomes someone else's burden. Every hack compounds into technical debt that slows the whole team down. 
You are not just writing code, you are shaping the future of this project. The patterns you establish will be copied. The corners you cut will be cut again.
Fight entropy. Leave the codebase better than you found it.
Do not write plausible code, write accurate code backed by the reality of this codebase

## Code Thinking

Review your implementation before stopping. Check whether there is a better or simpler approach whether any redundant code remains, whether duplicate logic was introduced, and whether any dead or unused code was left behind. If you find issues, fix them now; if not, briefly confirm the implementation is clean.
                
Think carefully and only action the specific task I have given you with the most concise and elegant solution that takes into consideration existing code across codebase.
Prefer the most concise and elegant solutions that changes or adds as little code as possible.

Read `swift-dev.mdc` for specific swift coding guidance.

When behavior is unclear or tooling is non-obvious, verify it against primary docs or public repo examples instead of guessing. Use web research and GitHub/API lookups to confirm build-system, Xcode project, and framework details before changing project structure.

If you append `.md` to any of Apple's developer documentation it will render as markdown.
Example: https://developer.apple.com/documentation/

## Engineering Rules (Non-Negotiable)

- Functional style first: prefer pure functions, immutable updates, explicit inputs/outputs.
- Single responsibility: each function/module should have one reason to change.
- Complexity budget:
  - Target `O(1)` or `O(log n)` where practical.
  - Avoid accidental `O(n^2+)` (nested scans in hot paths).
  - Use `Map`/`Set` for membership and indexing instead of repeated linear lookups.
- Performance footgun policy:
  - Do not introduce `setTimeout`, `setInterval`, `requestAnimationFrame`, or self-rescheduling loops unless explicitly justified in code comments and cleaned up deterministically.
  - No polling loops when event-driven/reactive alternatives exist.
- Avoid hidden side effects: no mutation of shared module state unless clearly documented.

## Code Maintainability

- Two things that make code actually maintainable:
  1. reduce the layers a reader has to trace
  2. reduce the state a reader has to hold in their head

## Code Organization

- Keep app-specific logic organized.
- Prefer composition over inheritance; avoid god-modules.
- Keep adapters thin and deterministic; isolate I/O at boundaries.

## Change Quality Bar

- Keep diffs focused; do not mix refactors with feature behavior changes unless requested.
- Preserve public contracts unless change is intentional and documented.
- Validate before finishing
- Do not append routine validation command lists to `changes-log.md` unless explicitly requested; if validation needs to be recorded, use one short summary line instead.
- When a GPT-5.4/GPT-5.5-style model completes a multi-step implementation plan, run the project skill `/defensive-code-review` only after the planned work and normal validators are complete. This is a final cleanup pass for proven redundant guards, duplicated validation, and impossible-state branching; do not run it after every edit or for trivial one-off changes.

## Commands

- Simulator budget: keep at most two simulators booted on the Mac. Keep protected fixtures local and separate from disposable QA fixtures. Never shut down reserved, unknown, or actively claimed devices merely to meet this budget.
- Local StoreKit testing (`PurchaseStoreStoreKitTests`, real paywall prices in the simulator) needs an iOS 27.0 simulator runtime: the iOS 26.4 runtime rejects catalog activation with `SKInternalErrorDomain Code=3`. Use the default Xcode 26.4 at `/Applications/Xcode.app`; Xcode 27.0 (installed as `/Applications/Xcode-26.4.1.app`) hung the same probe, so do not point `DEVELOPER_DIR` at it for StoreKit runs.
- Inspect project targets and schemes:
  - `xcodebuild -list -project "/Users/juan/Documents/xcode/cal-macro-tracker/cal-macro-tracker.xcodeproj"`
- Build the app from the CLI (a build is not a test run):
  - `make quality-build`
- Run the full iOS Simulator test suite serially with a bounded per-test allowance. Replace the placeholder with an available simulator UUID; never use simulator `39FE5E39-17CE-4395-B141-9E70EBA594BC`:
  ```sh
  xcodebuild \
    -project "cal-macro-tracker.xcodeproj" \
    -scheme "cal-macro-tracker" \
    -destination 'platform=iOS Simulator,id=<IOS_SIMULATOR_UDID>' \
    -parallel-testing-enabled NO \
    -test-timeouts-enabled YES \
    -default-test-execution-time-allowance 30 \
    -maximum-test-execution-time-allowance 45 \
    test
  ```
- Run one supported test class using the same options and a real class selector, for example:
  ```sh
  xcodebuild \
    -project "cal-macro-tracker.xcodeproj" \
    -scheme "cal-macro-tracker" \
    -destination 'platform=iOS Simulator,id=<IOS_SIMULATOR_UDID>' \
    -parallel-testing-enabled NO \
    -test-timeouts-enabled YES \
    -default-test-execution-time-allowance 30 \
    -maximum-test-execution-time-allowance 45 \
    -only-testing:cal-macro-trackerTests/InsightsAnalyticsTests \
    test
  ```
  The shared `cal-macro-tracker` scheme includes the `cal-macro-trackerTests` target. Test resources, including migration fixtures, belong to the test bundle, not the app bundle.
- macOS builds are intentionally deferred; do not use `-destination 'platform=macOS'` unless explicitly requested.
- When interacting with Cloudflare, use the `cf` CLI for account and resource tasks (D1, DNS, deployments, cache). `web/` and `worker/*` stay on `wrangler.jsonc` for `dev`/`deploy`; do not run `cf init`, `cf dev`, `cf build`, or `cf deploy` in them: Astro 6+ does not build with `cf` during the beta. Re-evaluate `cf migrate` when the cf docs drop that limitation.
- Lint / formatting:
  - The repository formatter is the official `swift-format` tool, wired through `make quality-format-check` and `make format` with the root `.swift-format` configuration.
  - `make lint-js` runs the isolated Bun/Oxlint package against owned JavaScript and TypeScript sources. It enables vendored anti-slop rules and classic `eslint/complexity` at error with a maximum of 20. Keep the rules, severities, and source coverage intact; fix findings in owned source rather than adding suppressions.
  - Astro documents may be selected as Oxlint inputs, but this does not validate Astro template or markup semantics. Swift formatting remains separate and unchanged.
  - Do not document or assume an additional linter unless it is added to the repository workflow.

## Current Codebase Shape

- `cal-macro-tracker.xcodeproj` contains the `cal-macro-tracker` app, `CalMacroWidget` extension, and `cal-macro-trackerTests` test target. The shared `cal-macro-tracker` scheme runs the app's XCTest target.
- Native code is organized under app, data, shared, widget, and feature directories. The iPhone-first SwiftUI app uses SwiftData for local storage and includes food logging, scanning, history, insights, optional sharing, and StoreKit purchase flows.
- The repository also includes the optional Convex sharing backend, Cloudflare workers, and an Astro site. These supporting packages have their own scripts and are not part of an Xcode app build.
- Root-level [`swift-dev.mdc`](./swift-dev.mdc) is the main local coding guidance: prefer idiomatic modern SwiftUI, keep state close to where it is used, use `async/await`, and avoid unnecessary view-model or UIKit-style abstraction layers.

Design for ambiguity explicitly: missing database items, OCR mistakes, incomplete nutrition values, and odd serving sizes are expected and must route through review/edit UX rather than silent assumptions.

## Recommended Native Architecture

### UI and App Structure

- Use SwiftUI as the primary UI framework.
- Keep views small and feature-focused.
- Prefer SwiftUI state tools (`@State`, `@Binding`, `@Observable`, `@Environment`) over introducing view-model layers by default.
- Organize future code by feature areas such as `Logging`, `FoodSearch`, `Scan`, `History`, `Settings`, rather than global `Views/Models/ViewModels` folders.

### Persistence and Privacy

- Keep primary user data in an on-device database.
- Use iOS file protection / data protection for persisted files.
- Store any small secrets, such as optional user-supplied API keys, in Keychain.
- Plan for import/export of user data so people can migrate devices without requiring accounts.
- Optional HealthKit integration is acceptable as an OS-permission-based feature and does not imply an app login system.

## Calculation Rules

- Prefer deterministic math only.
- If nutrients are stored per serving, multiply by consumed servings.
- If nutrients are stored per 100g, compute consumed nutrients from grams consumed.
- If a source only provides a volume-based serving without grams, do not fake precision; require a user-confirmed conversion or manual quantity entry.

## Implementation Notes for Future Agents

- Favor native Swift/SwiftUI solutions even if a cross-platform approach seems possible.
- Build offline-first behavior into every feature: local persistence, cached lookups, graceful network absence, and editable fallbacks.
- Keep the app usable with zero account setup.
- Treat scanning/OCR/network resolution as separate steps so each can fail independently without blocking manual logging.
- Use the existing XCTest target and isolated fixtures for app behavior; keep test resources in the test bundle and avoid real user stores, production services, and unrelated simulators.
- `make quality-build` compiles the app and is not test evidence. `make qa-network` runs the Node-native loopback HTTP/Miniflare runtime QA and registered Convex integration tests; install dependencies in `tools/runtime-qa/` and `convex-backend/` first. There is no root `package.json`.

# Changes Log

`changes-log.md` is the canonical project history file for implemented work, bugs found, decisions made, and validation results.

Detailed implementation trackers live in `implementation-trackers/`
