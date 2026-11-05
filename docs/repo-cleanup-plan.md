# MACROS repo cleanup proposal

Research date: 2026-11-05. Base: `074b109`. Owner-approved cleanup implemented on `chore/repo-cleanup`; see the scope and checklist below.

Apple configuration follow-up: item 8 is now implemented separately on `chore/apple-config`. The three Info plists and `MACROSPro.storekit` live in `config/apple/`; the shared scheme uses `../../config/apple/MACROSPro.storekit`. Root paths below describe the original research baseline, not current configuration.

## Recommendation

Keep the existing app, backend, worker, web, and tools directories. Fix the documentation first. Stop committing full QA capture runs. Archive completed plans without losing their unresolved release checks. Move the four Apple configuration files only in a separate, validated change.

There is no evidence that MACROS needs an `apps/*` migration, a generated Xcode project, or one Swift package per feature. Those changes would cost more than they solve.

Only this document changes in this branch. No source files, simulator state, deployments, instructions, or existing evidence were changed. The research used the isolated `repo-cleanup` worktree and read-only inspections of reference checkouts.

## Measured baseline

Counts cover tracked files at the base commit. Sizes below are file-content bytes, not compressed Git objects.

| Area | Files | Size or finding |
| --- | ---: | --- |
| `docs/` | 1,107 | 110,410,577 bytes |
| `docs/evidence/` | 1,081 | 103,499,412 bytes, 98.70 MiB, across 18 folders |
| Other files in `docs/` | 26 | Includes deliberate App Store creative assets and the label fixture |
| `implementation-trackers/` | 26 | 392,745 bytes |
| `AGENTS.md` | 1 | 12,769 bytes, 152 lines |
| `README.md` | 1 | 13,947 bytes, 316 lines |
| `swift-dev.mdc` | 1 | 4,514 bytes, 166 lines |
| `SOFTWARE_PATTERNS.md` | 1 | 2,928 bytes, 85 lines |
| `changes-log.md` | 1 | 305,779 bytes, 2,651 lines |
| `web/web-changes-log.md` | 1 | 59,811 bytes, 859 lines |
| Git object packs on this Mac | 3 | 455.51 MiB, not the earlier Windows estimate of 433 MB |
| `.github/` | 0 tracked files | Quality commands exist, but there is no checked-in GitHub Actions workflow |

The source-area counts also match the Windows inventory: native app 239 files, tools 79, web 77, workers 46, backend 45, tests 37, and `.factory/` 13. All these counts and the documentation and evidence measurements above were independently repeated here.

`git count-objects -vH` also reported two garbage entries, 4.24 KiB. That is a local Git-maintenance observation, not a reason to delete anything in this proposal. Worktrees share the object store, so pack size is not this branch's incremental cost.

## What the six reference codebases actually do

Local snapshots are not assumed to be current upstream. These observations come from tracked trees and file contents, not the folder names.

### diffusionstudio/monorepo-new

Inspected `/Users/juan/Documents/monorepo-new`, `main`, `58417229`.

- Root has `apps/`, `packages/`, `README.md`, `PLUGIN_API.md`, `package.json`, `bun.lock`, `Dockerfile`, and `fly.toml`.
- `README.md`, 48 content lines, says the proprietary API lives in `apps/api/`; clients live in another repo. `packages/api-contract/` owns public schemas and generated router types.
- Root `package.json` declares `"workspaces": ["apps/*", "packages/*"]`. The README explicitly says to regenerate and commit the public contract, while rejecting private-type leaks.
- No tracked `AGENTS.md` or `CLAUDE.md` was found. No dedicated ADR directory or changelog appeared in the inspected tree. Do not invent an agent-instruction convention for it.
- Root `.gitignore` excludes `dist`, `build`, `dist-contract`, `node_modules`, environment files, `.claude`, and `.claire`.
- CI is `.github/workflows/fly-deploy.yml`; root scripts delegate `lint` and `check` to packages.

Fit for MACROS: make ownership and generated-file policy explicit. Do not copy the workspace naming just because it looks tidy. MACROS has a working Xcode project and separately installed support packages.

### sst/opencode, v2

Inspected `/Users/juan/Documents/opencode`, branch `v2`, `aeed4b6375`.

- Root has `packages/`, `services/`, `sdks/`, `script/`, `infra/`, `specs/`, `perf/`, and `artifacts/`, plus `bun.lock`, `turbo.json`, `.oxlintrc.json`, and `.github/workflows/`.
- Root `AGENTS.md` is 191 content lines. It describes dependency direction, generated clients, branch policy, commands, and style. Its first rule requires `packages/client` regeneration after public protocol changes.
- Instructions narrow by area: `packages/app/AGENTS.md`, 58 content lines; `packages/tui/AGENTS.md`; `packages/app/e2e/AGENTS.md`; `packages/app/e2e/performance/AGENTS.md`; `services/www/src/docs/AGENTS.md`. These are specific instructions, not duplicated root files.
- Architecture is recorded in `specs/v2/event-stream-architecture.md`, `session.md`, `provider-policy.md`, and `tools.md`. Product docs also live under `packages/web/src/content/docs/`.
- A `.changeset/` directory exists, but root instructions explicitly say, "This repository does not use Changesets." Directory presence is not proof of the current release process.
- Root `.gitignore` excludes `tmp`, `.worktrees`, `.turbo`, `.typecheck-profiles`, `logs/`, and `UPCOMING_CHANGELOG.md`. Some artifacts are nevertheless tracked, including a root screenshot. It is not an artifact-free ideal.
- CI includes `.github/workflows/check.yml`, `test.yml`, `publish.yml`, and `release-github-action.yml`.

Fit: root rules plus scoped rules and durable architecture docs. Do not copy its long style guide, service architecture, or obsolete directories.

### solidjs-community/solid-primitives

Inspected `/Users/juan/Documents/solid-primitives`, `main`, `c7b608c5`.

- Root has `packages/`, `site/`, `configs/`, `scripts/`, `template/`, `CONTRIBUTING.md`, `.changeset/`, `pnpm-workspace.yaml`, and shared lint/format configs.
- `packages/storage/` contains `src/`, `test/`, `dev/`, `README.md`, `CHANGELOG.md`, `package.json`, and `tsconfig.json`. Documentation and release history follow the independently published package.
- No tracked `AGENTS.md` or `CLAUDE.md` was found. `CONTRIBUTING.md`, 132 content lines, owns contribution stages, design rules, setup, and tooling.
- `.changeset/` and package changelogs support granular releases. No separate ADR convention appeared in the inspected paths.
- `.gitignore` excludes coverage, dependency/build directories, temporary files, and local Netlify output.
- Root `eslint.config.mjs` and `.prettierrc` are shared. CI lives in `.github/workflows/tests.yml`, `format.yml`, and `release.yml`.

Fit: document a component where people work on it. MACROS does not independently publish dozens of packages, so package-specific release automation would be unnecessary.

### earendil-works/pi

Inspected `/Users/juan/Documents/pi`, `main`, `71dca871b`.

- Root `packages/` includes `agent`, `ai`, `coding-agent`, `protocol`, `server`, `tui`, and `session-backends`.
- Root `AGENTS.md` is 124 content lines. Sections cover code quality, commands, dependency security, Git, and issue handling. No additional tracked files named `AGENTS.md` or `CLAUDE.md` appeared.
- The root says checks are not tests and says not to edit `packages/ai/src/models.generated.ts` directly. That distinction is useful for MACROS.
- Durable docs include `packages/agent/docs/harness.md` and `assistant-durability.md`; release history includes `packages/ai/CHANGELOG.md` and `packages/coding-agent/CHANGELOG.md`.
- `.gitignore` excludes `.artifacts/`, coverage, CPU profiles, binary distributions, local plans, logs, and generated provider data. It deliberately retains useful generated source and documentation.
- Root `biome.json`, `vitest.base.ts`, and `.github/workflows/ci.yml` centralize shared checks. This checkout uses npm, not Bun.

Fit: keep small reproducible reports, not raw capture directories; distinguish generated source from disposable output. Do not import pi's backward-compatibility or dependency-upgrade rules into MACROS.

### anomalyco/opentui

No local checkout appeared in the listed reference directories. Inspected GitHub tree `e4ad5867eae1051a2c1877b08d88bbcaf12b7209`.

- Root has `packages/`, `scripts/`, `api/`, `AGENTS.md`, `bun.lock`, `.oxlintrc.json`, `.oxfmtrc.json`, and `.github/`.
- Root `AGENTS.md` is 62 content lines. It separates engineering, tooling, verification, and portable FFI rules. `packages/web/AGENTS.md` narrows the web rules. `packages/web/src/content/SKILL.md` is also tracked.
- `api/README.md` defines release-specific API records in `api/<version>.txt`. It explains how scripts produce and verify them. This is a purpose-built release record, not an unbounded daily work diary.
- `.gitignore` excludes `screenshot-*.png`, crash dumps, logs, coverage, `out`, `dist`, and packed archives. It explicitly re-includes `/api/*.txt` after ignoring `*.txt`.
- CI includes `.github/workflows/format-lint.yml`, `build-core.yml`, `bench-native-smoke.yml`, `prepare-release.yml`, and `release.yml`. No conventional ADR directory appeared in the inspected tree.

Fit: concise root instructions, explicit exceptions for useful generated records, and checks at the relevant package boundary. Do not add native FFI conventions to a SwiftUI app.

Sources: [tree](https://github.com/anomalyco/opentui/tree/e4ad5867eae1051a2c1877b08d88bbcaf12b7209), [agent guide](https://github.com/anomalyco/opentui/blob/e4ad5867eae1051a2c1877b08d88bbcaf12b7209/AGENTS.md), [API history](https://github.com/anomalyco/opentui/blob/e4ad5867eae1051a2c1877b08d88bbcaf12b7209/api/README.md).

### joshpuckett/dialkit

Inspected `/Users/juan/Documents/dialkit`, `main`, `4ae7f55`.

- Root has `src/`, `docs/`, `scripts/`, `example/`, `examples/`, `README.md`, `CONTRIBUTING.md`, `package.json`, and `tsup.config.ts`. It stays a small library rather than becoming a workspace.
- Framework adapters are `src/solid/`, `src/svelte/`, `src/vue/`, and `src/vanilla/`; tests sit beside source.
- `docs/reference.md`, `docs/timeline.md`, and `docs/2.0-evaluation.md` separate API reference, feature docs, and an evaluation. No dedicated changelog or ADR tree appeared.
- No tracked agent instruction file exists. Root `.gitignore` explicitly ignores `CLAUDE.md`, `AGENTS.md`, and `.claude-plan.md`. That is an observation, not a recommendation for MACROS.
- `CONTRIBUTING.md`, 34 content lines, explains generated browser fixtures and concrete checks. `.toolbar-fixtures/`, `dist/`, and generated adapter files are ignored.
- No tracked `.github/workflows/` appeared. Build and typecheck commands live in `package.json`; framework-specific TypeScript configs remain at root.

Fit: keep verification scripts and ignore their generated output. Do not copy the decision to hide agent instructions, since MACROS depends on shared agent rules.

## iOS and macOS references in 2026

I queried the public repo API sorted by pushed time, including pagination. `fayazara` returned 211 repositories; `mattt` returned 157. The public-name catalog is appended below. API timestamps describe pushes, not necessarily feature releases or original authorship. Forks were excluded from the detailed sample.

The sample is six Swift repositories from fayazara and five from mattt. It mixes real macOS apps with Swift packages that support iOS. It is evidence about these projects, not a claim that all iOS teams use one architecture in 2026.

### fayazara

| Repo, last push, inspected commit | Layout, targets, configuration, and tests | Tooling, instructions, docs, and releases |
| --- | --- | --- |
| [Screendrop](https://github.com/fayazara/Screendrop), Nov 2, `70ffcce0` | `Screendrop.xcodeproj`; `Screendrop/` is mostly flat Swift files, with `Engine/` and assets. `Screendrop/Info.plist` and `Screendrop.entitlements` are target-local. Shared normal and Dev schemes separate bundle IDs. `AGENTS.md` says no test target; `scripts/check-editor-cancellation.swift` and other focused checks exist. | Root `AGENTS.md`, 8,425 characters, is detailed and machine-specific. `.agents/skills/build-screendrop/`, `build-and-run-screendrop/`, `release-screendrop/`, and `macos-notch-ui/` are tracked. `docs/editor-performance.md` and `export-performance.md` hold focused notes. No workflow or dedicated Swift formatter config appeared in the recursive tree. Go helper `cmd/screendrop-release/`, `appcast.xml`, GitHub DMG releases; latest `v0.37.1`. |
| [Kaze](https://github.com/fayazara/Kaze), Oct 16, `1a76ab51` | `Kaze.xcodeproj`; `Kaze/App`, `Audio`, `Cloud`, `Core`, `Data`, `Engines`, `Formatting`, `Input`, `Output`, `System`, `UI`; `Kaze/Info.plist`, `Kaze.entitlements`; `Vendor/Whistle/`. No separate test directory appeared. Debug binary has `--selftest` paths documented in README. | `.agents/skills/build-kaze/`, `build-and-run-kaze/`, and `release-kaze/`; no root AGENTS/CLAUDE or checked-in workflow/formatter config appeared. README distinguishes `Kaze Dev` from release. `cmd/kaze-release/`, Sparkle `appcast.xml`, latest DMG `v1.2.0`. `.gitignore` excludes `build/`, `DerivedData/`, `.build/`. |
| [shiki-swift](https://github.com/fayazara/shiki-swift), Oct 3, `05563c88` | SwiftPM library plus `shiki-swift.xcodeproj` demo. `Sources/ShikiCore`, `Shiki`, `ShikiUI`, `ShikiDiffs`, and C bridges. Corresponding `Tests/*Tests`, `Tests/RegexBridge`, and `Fixtures/`. Manifest explicitly excludes build-time provenance records from runtime resources. | `Documentation/Diffs/`, `Scripts/README.md`, `Scripts/tests/`, `THIRD_PARTY_NOTICES.md`, `LICENSES/`, root `CHANGELOG.md` and `RELEASING.md`. No AGENTS/CLAUDE, CI workflow, or dedicated formatter config appeared. `Scripts/release.sh --dry-run` validates before tagging. Latest package release `0.1.2`. |
| [Swift-Diffs](https://github.com/fayazara/Swift-Diffs), Sep 19, `7005d406` | `Package.swift`, `Sources/SwiftDiffs`, `Sources/CSDRegex`, `Tests/SwiftDiffsTests`, `Tests/RegexBridge`; separate `swift-diffs.xcodeproj` and `swift-diffs/` demo. No Tuist/XcodeGen descriptor appeared. | `Documentation/PARITY.md`, `NATIVE-PLATFORM-CONTRACTS.md`, audits and upstream manifests; `Scripts/test.sh` and oracle generators. No AGENTS/CLAUDE, checked-in workflow, formatter config, or GitHub release appeared. README contains validation and limits. Do not copy its many audit documents without a lifecycle policy. |
| [boop](https://github.com/fayazara/boop), Sep 14, `5e2eaea8` | `Boop.xcodeproj`; `Boop/AI`, `Capture`, `Resources`, `Support`, `UI`; `Boop/Info.plist`. README documents popup-placement and OCR checks under `scripts/`; no XCTest target directory appeared. | `.agents/skills/build-boop/`, `build-and-run-boop/`, `release-boop/`; no root AGENTS/CLAUDE, workflow, or dedicated formatter config appeared. `cmd/boop-release/`, `appcast.xml`, latest DMG `v0.1.1`. Ignore rules exclude release artifacts. |
| [cobe-swift](https://github.com/fayazara/cobe-swift), Jul 31, `f43d2991` | SwiftPM-only. `Sources/Cobe/` library and `Sources/CobeDemoApp/` executable; no Xcode project, plist, tests, CI, or agent files appeared in the recursive tree. | Small README and manifest. No dedicated lint/format config, changelog, or GitHub release appeared. Useful as a small package example, not as a complete application quality model. |

Concrete excerpts:

- Kaze root `README.md`: "Build the `Kaze Dev` scheme ... or `Kaze` ... Dependencies resolve through Swift Package Manager."
- Screendrop `AGENTS.md`: `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and `SWIFT_APPROACHABLE_CONCURRENCY = YES`. Its guide also says, "No test target exists. Build success is the only automated verification." MACROS must not adopt that last rule.
- shiki-swift `Package.swift`: `.library(name: "ShikiCore", targets: ["ShikiCore"])` and `.library(name: "ShikiUI", targets: ["ShikiUI"])`; runtime resources use `.copy("Resources/grammars")`, `.copy("Resources/themes")`, and `.copy("Resources/licenses")`, with audit records excluded.
- shiki-swift `RELEASING.md`: "Move the **[Unreleased]** entries in `CHANGELOG.md` under a new `## [X.Y.Z] - YYYY-MM-DD` heading"; `Scripts/release.sh X.Y.Z --dry-run` runs checks without tagging or pushing.
- cobe-swift `Package.swift`: `.executableTarget(name: "CobeDemoApp", dependencies: ["Cobe"])`, separate from its library.

The related [macos-app-skills](https://github.com/fayazara/macos-app-skills/tree/a60365ae85bfc3d1f2f8b260b080d77bfb2f3ec0) repo has `build/SKILL.md`, `release/SKILL.md`, `auto-update/SKILL.md`, `macos-patterns/SKILL.md`, `notch-ui/SKILL.md`, and `settings-ui/SKILL.md`. MACROS already has five versioned Swift/WidgetKit skills under `.factory/skills/`. Reuse that arrangement instead of installing another overlapping skill collection.

### mattt

| Repo, last push, inspected commit | Layout, targets, configuration, and tests | Tooling, instructions, docs, and releases |
| --- | --- | --- |
| [iMCP](https://github.com/mattt/iMCP), Nov 5, `6284060d` | `iMCP.xcodeproj`, separate `App/`, `Helper/`, `CLI/`, `Shared/`, and `Tests/imcp-serverTests/`. App and helper have their own `Info.plist` and entitlements. `App/Integrations/`, `Services/`, and `Views/` separate responsibilities. | `.swift-format`; `.github/workflows/ci.yml` lints, builds, and tests separately, selecting Xcode explicitly. `Scripts/release.sh` is shared with `.github/workflows/release.yml`, whose manual runs default to dry-run. `Assets/README.md`, `README.md`, `SECURITY.md`; no AGENTS/CLAUDE or SKILL files appeared. Latest release `1.8.3`, zip and appcast assets. No root changelog appeared. |
| [AnyDecisionModel](https://github.com/mattt/AnyDecisionModel), Nov 5, `281ccc77` | SwiftPM-only library; `Sources/AnyDecisionModel`, `Tests/AnyDecisionModelTests/Fixtures`; iOS/macOS 26 minimum in manifest; optional MLX/CoreAI/Llama traits. No app plist is needed for a library. | `.swift-format`, `mise.toml`, `.github/workflows/ci.yml`; separate base tests and optional MLX coverage, toolchain matrix. README gives usage and backend requirements. No agent files or root changelog appeared. Latest GitHub release `0.7.0`. |
| [AnySpeechRecognizer](https://github.com/mattt/AnySpeechRecognizer), Nov 2, `fd305213` | SwiftPM library plus `hear` CLI. `Sources/AnySpeechRecognizer`, `Sources/CLI`, `Tests/AnySpeechRecognizerTests`, `Tests/Fixtures`, and model-conversion utilities under `Tools/`. `swiftLanguageModes: [.v6]`. | `.swift-format`, `mise.toml`, dependabot, `.github/workflows/ci.yml`. CI says "Test without model downloads", keeping ordinary validation independent of large external assets. No agent files or root changelog appeared. Latest GitHub release `0.1.0`. |
| [ollama-swift](https://github.com/mattt/ollama-swift), Nov 2, `549699a7` | SwiftPM library, `Sources/Ollama`, `Tests/OllamaTests`, `Package.swift` and compatibility `Package@swift-5.swift`. No app or plist. | `.github/workflows/ci.yml` builds and tests on explicit Xcode versions. No `.swift-format`, agent files, or root changelog appeared in this tree. README owns installation/API examples. Latest release `1.9.2`. Do not attribute its neighbors' formatter config to it. |
| [EventSource](https://github.com/mattt/EventSource), Nov 2, `bb4b6127` | SwiftPM library, `Sources/EventSource`, `Tests/EventSourceTests`, `Package.swift`, `Package@swift-6.0.swift`. CI covers default and AsyncHTTPClient variants on macOS and Linux. | Root `.swift-format`; CI runs `swift format lint --recursive . --strict`, `swift build`, and `swift test` separately. README, no agent files or root changelog appeared. Latest release `1.6.0`. |

Concrete excerpts:

- iMCP `.github/workflows/ci.yml`: `DEVELOPER_DIR: "/Applications/Xcode_${{ matrix.xcode }}.app/Contents/Developer"` and `swift format lint --strict --recursive .`. It keys build caches on the exact Xcode build number.
- iMCP `.github/workflows/release.yml`: manual `dry_run` defaults to `true`; publication requires the version's tag. Borrow the separation between validation and publication, not its macOS signing pipeline.
- AnyDecisionModel `Package.swift`: `.testTarget(name: "AnyDecisionModelTests", dependencies: ["AnyDecisionModel"], resources: [.copy("Fixtures")])`.
- AnyDecisionModel CI: `swift build --build-tests`, then `swift test --skip-build`. A build is not a passing test run.
- AnySpeechRecognizer `Package.swift`: `.executableTarget(name: "hear", ... path: "Sources/CLI")`. Its CI runs `xcrun swift test` without model downloads.

### Practices that fit MACROS

1. Keep a normal checked-in Xcode project for the signed app and WidgetKit extension. The sampled apps do this. None demonstrates a need to migrate MACROS to Tuist or XcodeGen.
2. Keep configuration close to its target, or in a small explicit configuration directory outside synchronized source groups.
3. Keep fixtures in test targets. MACROS already does this with migration stores, barcode images, and `config/apple/MACROSPro.storekit`.
4. Keep official `swift-format`, explicit toolchain selection, and separate build/test reports.
5. Write task-specific build/release instructions that link to scripts. Do not embed private machine setup throughout a global rules file.
6. Separate release notes from engineering work logs. Shiki's versioned changelog is a better model for a release summary than MACROS' current daily diary.

Practices that do not fit: Screendrop's mostly flat source directory and lack of a test target; macOS-only Sparkle/Homebrew/notarization pipelines; package compatibility manifests without an actual multi-Swift-version requirement; model-download matrices; automatically giving agents authority to publish releases; and extracting every feature into SwiftPM merely because libraries use `Sources/` and `Tests/`.

## Concrete documentation problems

### Stale facts and factual corrections

These are current facts at research time. Historical test outcomes should remain dated, not be rewritten as though old tests ran on today's setup.

| Location and claim | Verified current value or action |
| --- | --- |
| `AGENTS.md` uses the owner's absolute project path in the `xcodebuild -list` example | Use `-project "cal-macro-tracker.xcodeproj"` from the active worktree. This proposal's worktree is `/Users/juan/.t3/worktrees/cal-macro-tracker/repo-cleanup`; do not replace one permanent machine path with another. |
| `AGENTS.md` says iOS 27.0 is the only installed simulator runtime | `xcrun simctl list runtimes` lists iOS 26.5, build `23F77`, and iOS 27.0, build `24A434`. There are no 26.5 devices. All six existing devices are iOS 27.0. The owner's removal note and live inventory disagree; use live inventory for selection. No runtime was removed during research. |
| Owner request suspects `9843E820` is gone | `9843E820-3A2A-4599-9206-D224B3035A47`, iPhone 18 Pro, still exists and was Shutdown. Preserve its protected status. Existence does not independently establish what private data it contains. |
| `AGENTS.md` calls Xcode 26.4 the default | `xcode-select -p` is `/Applications/Xcode-26.4.1.app/Contents/Developer`; its `xcodebuild -version` is Xcode **27.0**, build `27A266a`. `/Applications/Xcode.app` is Xcode **26.4**, build `17E192`. Folder names are misleading. |
| StoreKit section says not to use Xcode 27 because an older probe hung | Keep the old result as a dated compatibility note. Do not infer a current StoreKit pass or failure. Use explicit `DEVELOPER_DIR` for the documented known-good 26.4 probe, and rerun `PurchaseStoreStoreKitTests` before promoting any toolchain to current recommendation. This proposal did not run payment tests. |
| `README.md` says shared scheme references `../../FullUnlock.storekit` | Current reference is `../../config/apple/MACROSPro.storekit` after item 8. Old file is absent. `make quality-storekit` verifies the scheme, test resource, prices, and four product IDs. |
| README describes premium solely as "Full Unlock" | The `ProPlan` enum is in `cal-macro-tracker/Features/Purchases/PurchaseStore.swift`; the catalog contains `macros.pro.yearly`, `macros.pro.monthly`, `macros.pro.lifetime`, and legacy `fullunlock001`. Describe MACROS Pro and distinguish the legacy non-consumable. |
| README says Node `>=22.12.0` for web | `web/package.json` declares `>=22.23.4`, with Bun `1.4.4`. Runtime-QA documentation separately says Node 22.18+ for native TypeScript. Do not collapse these requirements into one unverified minimum. |
| README says "Swift 6" without distinguishing compiler and language mode | Project target settings currently have `SWIFT_VERSION = 5.0`, with iOS deployment target 26.0. A Swift 6 compiler does not imply Swift 6 language mode. Document the distinction; do not change language mode during cleanup. |
| `swift-dev.mdc` lists `@ObservableObject` as a property wrapper | The protocol is `ObservableObject`; the relevant wrappers are `@StateObject` and `@ObservedObject`. MACROS targets iOS 26, so pre-iOS-17 fallback guidance is not a current requirement. Keep `@Observable` guidance and remove the misleading wrapper example. |
| Old architecture tracker says there is no documented CLI test command | Root README and AGENTS now document serial `xcodebuild test` with 30/45-second allowances and class selectors. Preserve the tracker as historical, with a superseded banner. |
| `shared-person-widget-plan.md` still opens "implementation plan only" | The implementation tracker has 17 checked items and `docs/evidence/shared-person-widget-e2e/`. Mark the original plan implemented/superseded, while preserving release and hardware blockers. Do not claim production cutover happened. |
| `launch-program-tracker.md` contains a Mac-only-Xcode/Windows-only-docs work allocation and older build numbers | These are dated workstream instructions, not repo-wide truths. Keep them in the archive. `project.pbxproj` currently sets `MARKETING_VERSION = 1.0` and `CURRENT_PROJECT_VERSION = 33`. This is source configuration, not proof of an uploaded or approved build. Current release status requires App Store Connect verification, which was outside this research. |
| Root instructions broadly promise Apple docs render Markdown by appending `.md` | The build-settings reference worked. Narrow this to a useful documentation tip, not a universal guarantee about every Apple URL. |

The existing simulator list is mostly correct, despite its stale date. Record the full observed set in a dated local-environment runbook, not as permanent inventory in root instructions:

| Device | UDID | Observed state |
| --- | --- | --- |
| Protected iPhone 18 Pro | `9843E820-3A2A-4599-9206-D224B3035A47` | Shutdown |
| `MACROS-iPhone-18-Pro-Max-2026-10-30` | `D16C3D35-889F-404F-BDD4-C640A6DBC4EF` | Shutdown |
| iPhone 17e | `F976E800-DA1F-4F20-B755-DFD964E33975` | Shutdown |
| iPhone Air | `844B72D7-D128-4607-AB2E-6C14B024618F` | Shutdown |
| iPhone 17 | `918D29B9-97D3-42C0-9C47-00605E01E8DB` | Shutdown |
| `MACROS-iPad-Air-11-2026-10-29` | `E91B597B-CE57-4C0B-A8A4-51CBDC3386AB` | Shutdown |

The four-booted/one-stock budget and protected-fixture rule are owner policy, not stale facts. Preserve them. Slimming status and old memory measurements were not reverified because `simslim verify` requires booted devices. Do not present them as current measurements.

### Duplication and ownership

- Root AGENTS repeats feature organization, SwiftUI state ownership, composition, concurrency, and local-first rules already in `swift-dev.mdc`. Keep project constraints in root and language-specific detail in one Swift document.
- README repeats repo structure, setup, quality commands, architecture, and test commands. It should introduce MACROS and link to contributor documentation rather than compete with AGENTS as the operational manual.
- `SOFTWARE_PATTERNS.md` is generic advice, last changed 2026-04-02 at `dd0276b`. Its classification table has no concrete MACROS example. The only discovered inbound filename mention is `docs/evidence/camera-inline-details/defensive-review.md`. Archive it as historical reference or retire it after review; do not call it entirely unreferenced.
- `convex-backend/AGENTS.md` and `CLAUDE.md` are byte-identical generated-marker blocks. Both direct readers to `convex/_generated/ai/guidelines.md`. Keep the generator-managed blocks intact until `convex ai-files` regeneration behavior is confirmed. A hand-edited wrapper that the generator overwrites is not a durable deduplication.
- `web/SEO.md` is area-specific and belongs near the site. Root AGENTS' long-form-copy, primary-source, screenshot, and zero-extra-JavaScript rules belong in `web/AGENTS.md`.
- `.factory/skills/apple-widget-design-review/SKILL.md` points to `swift-dev.mdc`. Moving the Swift document requires updating this machine-read dependency, not just README links.
- A model-version-specific cleanup-skill requirement in AGENTS is fragile. Replace it with the durable instruction to review the complete diff for redundant code and use installed relevant review tools. Do not require a skill absent from the repository.

### Completed trackers are not the same as closed release work

Archive-ready after checking their final status and links: `architecture-refactor-implementation-tracker.md`, `insights-implementation-tracker.md`, `backup-export-import-tracker.md`, `camera-inline-details-plan.md`, `insights-long-ranges-tracker.md`, `packaged-food-search-reliability-tracker.md`, and `state-machine-fixes.md`.

Examples of evidence: architecture has 46 checked and zero unchecked boxes; insights has 55 checked and zero unchecked, plus "None remaining for V1"; backup explicitly says implementation is complete; camera explicitly says implemented and simulator-validated. Preserve their limitations.

Do not auto-archive based on unchecked-box counts. Of the 26 files, many use prose instead. Specific unresolved work includes:

- `testflight-release-tracker.md`: three unchecked items and hardware/release checks.
- `meals-implementation-tracker.md`, `sharing-implementation-tracker.md`, and `unified-camera-tracker.md`: each has one unchecked item.
- `retention-polish-tracker.md`: no unchecked boxes, but barcode 429 device validation is explicitly unverified.
- `shared-person-widget-implementation.md`: implementation checked off, release still blocked on approval/cutover.
- `pro-subscription-storekit-tracker.md`: distinguishes old failures, later partial passes, and device/account requirements.

Create `docs/plans/README.md` with active, completed, superseded, and blocked states. Move open obligations into active plans with owner and verification condition before archiving their source trackers. Original dated results remain unchanged.

### Evidence inventory and references

The reference scan searched tracked text outside evidence for each folder name. This catches shorthand references but does not prove that every reference is a live link. It also does not cover issues, PRs, or external bookmarks. The table lists meaningful references, excluding generic text collisions.

| Folder under `docs/evidence/` | Files | MiB | Inbound references outside evidence |
| --- | ---: | ---: | --- |
| `shared-person-widget-e2e` | 83 | 37.45 | root history, widget implementation tracker and plan |
| `camera-inline-details` | 291 | 11.61 | root history, camera plan |
| `collection-feedback-loop` | 50 | 10.33 | root history |
| `camera-details-morph` | 93 | 6.65 | root history |
| `web-rings` | 23 | 6.20 | No outside-evidence reference found |
| `web-consistency` | 93 | 4.26 | web history |
| `camera-card-layout-shift` | 117 | 4.20 | root history, camera plan |
| `web-seo` | 17 | 4.12 | root history, web history, `web/SEO.md` |
| `web-articles` | 31 | 3.61 | web history |
| `web-refresh-build-32` | 23 | 3.26 | web history, App Store creative-assets README |
| `review-prompt-timing` | 33 | 2.47 | root history |
| `weight-unit` | 50 | 0.82 | root history |
| `state-machine-fixes-2` | 48 | 0.74 | root history |
| `unified-food-search` | 40 | 0.71 | root history, packaged-food tracker |
| `state-machine-fixes` | 46 | 0.70 | root history, state-machine tracker |
| `web-og` | 11 | 0.67 | web history, `web/SEO.md` |
| `insights-weight-card-width` | 13 | 0.60 | root history |
| `search-row-polish` | 19 | 0.31 | root history |

The automated name scan also matched `worker/usda-proxy/src/foodSearchRoute.ts` for `unified-food-search`. Inspection showed a logging phase string, not a dependency on the evidence directory. Do not rewrite source just to eliminate that match.

Proposed evidence policy:

- Run outputs go in already-ignored `build/evidence/<date>-<task>/`. Runtime QA already uses ignored `build/runtime-qa/`.
- Keep a small tracked report per task under `docs/evidence/<task>/README.md`, with source commit, toolchain/runtime, isolated fixture, command or exact UI steps, expected/observed outcomes, and explicit blocked cases.
- Default tracked allowance is 2 MiB per task, at most five selected images, and no raw videos, frame sequences, repeated logs, or `.xcresult` bundles. A larger exception needs a reason in the report. These are proposed limits, not current enforced policy.
- Keep reproducible fixtures and scripts tracked where their tests use them. Do not blanket-ignore PNG, JSON, SQLite, or patches. Migration WAL/SHM fixtures, the oat-label fixture, website screenshots, and deliberate App Store creative assets are not disposable QA output.
- For old evidence, first build a file manifest with SHA-256, byte size, original commit/path, destination, and retrieval instructions. Ask the owner to choose a durable archive such as an approved private object-storage bucket or release asset. No upload is authorized by this proposal.
- Verify a complete restore and the archive's access/retention policy before removing binary captures from the current tree. Keep report paths stable. Update image links in reports and external-facing docs, preserving unresolved QA evidence.
- Prefer an external archive for one-off captures. Git LFS is reasonable only for a small set of repeatedly revised binary fixtures whose availability is required at checkout. It adds client/auth/CI requirements and quotas. It is not a good default for 1,081 historical run outputs.
- Removing files in a normal commit does not reduce old clone history. No `filter-repo`, BFG, `git lfs migrate`, force push, shared-object cleanup, or history rewrite is proposed without explicit owner approval and a separate recovery plan.

### Root files and dead-file candidates

No Apple rule requires the three Info plists or StoreKit catalog to remain at repo root. Apple's [build settings reference](https://developer.apple.com/documentation/xcode/build-settings-reference.md) defines `INFOPLIST_FILE` as "The project-relative path to the property list file". The obstacle is MACROS' actual path contracts.

- `project.pbxproj` now has `INFOPLIST_FILE = "config/apple/Info-iOS.plist"`, conditional `"INFOPLIST_FILE[sdk=macosx*]" = "config/apple/Info-macOS.plist"`, and widget `config/apple/Info-Widget.plist`, in both configurations. The macOS file is still referenced, even though macOS builds are deferred. Do not delete it as dead.
- `config/apple/MACROSPro.storekit` has an explicit PBX file reference and is a resource of the test target. The shared scheme resolves it from `xcshareddata` as `../../config/apple/MACROSPro.storekit`. `tools/quality/validate_storekit_config.py` hard-codes the scheme identifier and checks PBX text. The filename is also referenced in App Store and purchase docs.
- Source groups are `PBXFileSystemSynchronizedRootGroup`, with membership exceptions for widget/shared source. Put moved configuration in `config/apple/`, outside the synchronized app tree, to avoid accidental resource membership.
- Keep `.swift-format` and `.oxlintrc.json` at root. `Makefile` and developer tools explicitly discover them there. Keep `.periphery.yml`, `.xcodebuildmcp/config.yaml`, and package-local Wrangler/Astro/TypeScript configs unless a concrete issue calls for moving them.
- `cal-macro-tracker.xcodeproj/xcuserdata/juan.xcuserdatad/xcschemes/xcschememanagement.plist` is tracked despite ignore rules. Last change: 2026-04-27, `5da61e8`. No inbound text references found. Remove it from tracking only after verifying the shared schemes remain visible in a fresh clone.
- `cal-macro-trackerTests/GoalCalculatorTests.md`, last changed 2026-10-25 at `c9fc7d7`, has no inbound filename references. Its contents are a useful failure-mode specification. Link or relocate it, do not discard it as dead.
- `swift-dev.mdc`, last changed 2026-04-02 at `dd0276b`, is actively linked by AGENTS, the widget skill, and multiple plans. It is not dead.
- Before the path move, `config/apple/Info-macOS.plist` last changed 2026-05-08 at `7401216`; `config/apple/MACROSPro.storekit` last changed 2026-10-25 at `5126cff`. Age alone says nothing about whether they are used.
- Keep `tools/oxlint/anti-slop/anti-slop-pristine-snapshot.tar.gz`, `SHA256SUMS`, `UPSTREAM.md`, and vendored licenses. The archive is provenance, not stray build output.
- Keep Convex `_generated` files and `worker-configuration.d.ts` for now. Their scripts and consumers define whether they belong in Git. The cleanup must not substitute a generic "delete generated files" rule for an audit.

## Proposed layout

These trees are abbreviated. Unshown source files remain in place.

### Before

```text
/
├── AGENTS.md
├── README.md
├── swift-dev.mdc
├── SOFTWARE_PATTERNS.md
├── changes-log.md
├── Info-iOS.plist
├── Info-macOS.plist
├── Info-Widget.plist
├── MACROSPro.storekit
├── Makefile, .swift-format, .oxlintrc.json, .periphery.yml
├── .xcodebuildmcp/config.yaml
├── .factory/skills/
├── cal-macro-tracker.xcodeproj/
├── cal-macro-tracker/{App,Data,Features,Shared,CalMacroWidget,...}/
├── cal-macro-trackerTests/{Fixtures,...}/
├── convex-backend/{AGENTS.md,CLAUDE.md,convex,tests,scripts,...}/
├── worker/{auth,usda-proxy}/
├── web/{SEO.md,web-changes-log.md,src,public,migrations,...}/
├── tools/{quality,runtime-qa,oxlint,food-db,media,release,sim}/
├── implementation-trackers/                 # 26 mixed-status documents
└── docs/
    ├── app-store/
    ├── design/
    ├── research/
    └── evidence/                           # full capture runs and reports mixed
```

### After

```text
/
├── AGENTS.md                               # short, repo-wide rules and routing
├── README.md                               # product, quickstart, docs links
├── changes-log.md                          # brief current log and archive index
├── Makefile, .swift-format, .oxlintrc.json, .periphery.yml
├── .xcodebuildmcp/config.yaml
├── .factory/skills/                         # retained, links updated
├── config/apple/                           # separate optional path-migration commit
│   ├── Info-iOS.plist
│   ├── Info-macOS.plist
│   ├── Info-Widget.plist
│   └── MACROSPro.storekit
├── cal-macro-tracker.xcodeproj/             # shared schemes retained
├── cal-macro-tracker/
│   ├── AGENTS.md                           # native rules, no machine inventory
│   ├── App/
│   ├── Data/
│   ├── Features/
│   ├── Shared/
│   └── CalMacroWidget/AGENTS.md             # only widget-specific constraints
├── cal-macro-trackerTests/                  # existing tests and fixtures retained
├── convex-backend/                         # generated agent blocks preserved initially
│   ├── AGENTS.md
│   ├── CLAUDE.md
│   └── ...
├── worker/
│   ├── AGENTS.md                           # shared worker checks and deploy caution
│   ├── auth/
│   └── usda-proxy/
├── web/
│   ├── AGENTS.md                           # editorial and web-specific rules
│   ├── SEO.md
│   ├── web-changes-log.md                   # short current entries and archive links
│   └── ...
├── tools/                                  # existing subdirectories retained
├── build/evidence/                         # ignored local output, not a tracked folder
└── docs/
    ├── README.md                           # documentation map and ownership
    ├── development/
    │   ├── setup.md
    │   ├── validation.md
    │   ├── swift.md                        # consolidated swift-dev.mdc
    │   └── simulator-runbook.md            # dated inventory, discovery, safe selection
    ├── architecture/
    │   ├── README.md                       # actual boundaries and source pointers
    │   └── decisions/                     # add records only when a real decision occurs
    ├── plans/
    │   ├── README.md                       # active/completed/blocked/superseded index
    │   ├── active/
    │   └── archive/
    ├── history/
    │   ├── app/
    │   ├── web/
    │   └── reference/software-patterns.md   # historical, not normative
    ├── evidence/
    │   ├── README.md                       # retention, archive, and size rules
    │   └── <task>/README.md                # stable reports plus selected small assets
    ├── app-store/                          # current release/listing material stays
    ├── design/
    ├── research/
    └── repo-cleanup-plan.md
```

No directory needs a placeholder commit. In particular, do not create empty decisions, active-plan, or history subtrees just to match this diagram.

## Implementation sequence, risks, and verification

Each item should be a separately reviewable change. Low risk means docs or metadata only; medium means tools, links, or build paths change. High risk needs owner approval and a separate execution plan.

1. **Correct stale facts and shorten README, low risk.** Fix StoreKit naming, Pro wording, Node requirement, compiler/language-mode distinction, and worktree-relative commands. Link to a new setup/validation guide. What could break: copied commands, doc anchors, and links used by agents. Verify every command against Makefile/package scripts, run `make quality-storekit`, inspect both shared schemes, and check relative links. Do not claim payment tests passed.
2. **Split AGENTS by scope, medium risk.** Target 60-90 root lines and less than 6 KiB, with links to native, widget, web, worker, and backend guidance. Preserve all safety and nutrition rules. Move simulator details and long examples to docs. What could break: agent instruction discovery, conflicting scope, or new Markdown resources picked up by Xcode synchronized groups. Verify the root routing table, read each applicable instruction chain from its area, inspect app/widget resource output after a build, and compare old obligations against a rule-by-rule checklist.
3. **Consolidate Swift and architecture guidance, low risk.** Move corrected `swift-dev.mdc` content to `docs/development/swift.md`. Archive generic SOFTWARE_PATTERNS prose and write architecture docs from actual app/service boundaries. What could break: `.factory` skill links, tracker references, external links to old paths. Update all tracked consumers, use temporary forwarding stubs if external compatibility is needed, and scan the diff for duplicated normative rules. Keep historical line references explicitly tied to their commits.
4. **Separate active plans from completed records, medium risk.** Move the seven archive-ready candidates first; resolve mixed-status trackers separately. What could break: relative evidence links, links from history, agent prompts expecting `implementation-trackers/`, or hidden release blockers. Verify every moved document's links; index each old/new path; enumerate every open checkbox and prose blocker before and after. Do not close device/account checks by filing the document away.
5. **Split the two large histories, low risk.** Keep `changes-log.md` as the canonical current entry point, with short current entries and links to chronological archives in `docs/history/app/`. Do the same for `web/web-changes-log.md` and `docs/history/web/`. Split at dated section boundaries; do not rewrite historical results. What could break: deep anchors and relative evidence links. Preserve stable anchors or add an old-heading-to-archive index, update links, compare all section headings and content before/after, and verify no records disappeared. Proposed current-log budget is 20 KiB each, not an arbitrary deletion cutoff.
6. **Stop future capture bloat, low risk.** Document ignored `build/evidence/`, the 2 MiB/five-image default, and exceptions. Later add a small changed-file size check under `tools/quality/`, wired through Makefile and any future CI. What could break: E2E scripts writing tracked paths and agents assuming every capture must be committed. Inventory output paths first. Verify a real disposable QA run writes only ignored output and retains a repeatable report. Test the future size check on an allowed fixture, an oversized run, and a documented exception before enabling it.
7. **Archive old binary evidence, medium risk; history rewrite high risk and excluded.** Start with `web-rings`, which has no discovered outside-evidence reference, then duplicate frame-heavy camera runs. Keep widget authorization/revocation and blocked-scenario reports available. What could break: image embeds, PR links, audit reproducibility, archive access. Require owner-approved storage, checksummed manifest, full restore test, link audit, and report review before normal Git removals. No upload or LFS migration occurs as part of this proposal.
8. **Move Apple configuration only if root tidiness still matters, medium risk.** Move three plists and the catalog to `config/apple/`; update all Debug/Release and conditional PBX settings, PBX file reference, shared scheme identifier to `../../config/apple/MACROSPro.storekit`, and the validator's expected identifier/text checks. What could break: Xcode references, catalog test resources, scheme resolution, release scripts, docs, and macOS conditional configuration. Verify `plutil -lint`, `xcodebuild -list`, iOS simulator `-showBuildSettings` for app/widget/test targets, `make quality-storekit`, `make quality-build`, and serial `PurchaseStoreStoreKitTests` on a safe available device with explicit compatible toolchain. Inspect built bundles to ensure no duplicate Info.plist resources. Statically verify the deferred macOS setting, without running a macOS build. Keep entitlements, privacy manifests, and target IDs unchanged.
9. **Remove proven personal metadata and resolve backend instruction duplication, low risk for xcuserdata, medium for generated instructions.** Untrack only the personal scheme-management plist; keep shared `.xcscheme` files and `Package.resolved`. For Convex, first inspect `bunx convex ai-files status` and generator ownership, without installation or regeneration. What could break: scheme discovery, IDE preferences, Claude guidance, or generator drift. Verify a fresh clone lists both shared schemes. Preserve both generated blocks unless a supported single-source setup is demonstrated; then test discovery with the tools the team actually uses.
10. **Document and enforce existing quality commands, medium risk if CI is added.** Keep config placement and package boundaries unchanged. A future `.github/workflows/quality.yml` can call existing Makefile/package checks, with path filters and a supported Mac runner for native work. What could break: CI source coverage, unavailable runtimes, missing dependencies, generated-type diffs, worker deploy configs, and accidental deployment through `bun run deploy`. First record a local baseline; use frozen Bun installs, existing lint/format rules, `make qa-network`, and explicit bounded serial iOS tests. Web uses `bun run check` and `bun run build`, not deploy, since deploy also applies remote D1 migrations. Validate future workflows in an isolated branch and keep production credentials out of validation jobs.

The first cleanup PR should contain items 1-3 only. Next handle plans/history and future evidence policy. Archive binaries only after storage approval. Apple configuration moves and CI are optional follow-ups, not prerequisites for useful cleanup.

## Proposed root AGENTS outline

The root should remain an instruction file, not become a second README.

```text
# Working in MACROS
## Scope and safety
  Use the active worktree. Preserve user changes and private data.
  Never reset/seed the protected owner simulator.
  Discover and reuse existing devices. Never create one for QA or tests.
  Only replace devices when a new model/runtime is needed, per owner policy.
  Never shut down reserved, unknown, or actively claimed devices.
  Keep the four-booted/one-stock budget and reserved-device constraints.
  No production deploys or release publication without authorization.
## Product invariants
  Local-first, no required account.
  Deterministic serving/grams math.
  Missing nutrition and uncertain scans require editable review.
  Keep secrets out of source, logs, and evidence.
## Area map
  Native -> cal-macro-tracker/AGENTS.md and docs/development/swift.md
  Widgets -> cal-macro-tracker/CalMacroWidget/AGENTS.md
  Backend -> convex-backend/AGENTS.md and generated Convex guidelines
  Workers -> worker/AGENTS.md
  Website -> web/AGENTS.md
## Validation
  Run relevant existing checks. A build is not a test.
  Root make targets and package checks link to docs/development/validation.md.
  Keep tests isolated. Do not change lint rules to hide findings.
  macOS builds remain deferred.
## Documentation and evidence
  README introduces the product; docs/README maps operational docs.
  Current history entry points link to archives.
  Plans declare status; reports declare limitations.
  Raw outputs go under ignored build/.
## Change discipline
  Small diffs. No opportunistic migrations.
  Review for redundant code and dead paths before finishing.
```

The native file owns SwiftUI/Observation, concurrency, persistence, test-fixture ownership, and synchronized-group cautions. The widget file owns WidgetKit constraints and links to the existing widget skill. The worker file owns common local checks and deploy safety; add child instructions only if auth and food-search rules actually diverge. The web file owns editorial/source rules, Astro checks, SEO guidance, D1 migrations, and screenshot policy. Keep backend generated instructions until their tool-supported ownership is clear.

`docs/development/simulator-runbook.md` should contain discovery commands, explicit Xcode selection, the dated inventory above, StoreKit compatibility evidence, and safe-device selection. Root must still contain the owner-fixture prohibition, so safety does not depend on agents opening an optional runbook.

Do not let added nested AGENTS files silently become bundled app/widget resources. Verify Xcode membership and built outputs when implementing the split.

## Changes I recommend not making

- Do not rename the repo directories into `apps/ios`, `apps/web`, or `packages/*` in this cleanup. Makefile, quality scripts, runtime QA imports, Wrangler configuration, doc links, Xcode groups, and developer tooling already depend on current paths.
- Do not introduce Tuist, XcodeGen, a root JS workspace, or a new package manager to solve documentation clutter.
- Do not split app features into Swift packages without a measured build/test/reuse benefit. Keep current feature folders.
- Do not change Swift language mode, concurrency settings, deployment target, bundle IDs, entitlements, app groups, signing, schema, or nutrition behavior.
- Do not remove the macOS plist, test migration database sidecars, generated Convex APIs, worker declarations, license/provenance archives, website screenshots, or App Store assets because their extensions look generated.
- Do not replace the official formatter or weaken Oxlint rules, complexity threshold, or source coverage.
- Do not delete old trackers before preserving unresolved release and device requirements.
- Do not claim ignored local `build/` reports are durable archive links. Some historical trackers already point to machine-local paths.
- Do not rewrite Git history or migrate existing history to LFS without separate owner approval. Ordinary deletions will not shrink old packs.
- Do not prune shared worktree objects, remove runtimes, erase simulators, deploy services, run App Store publication, or upload evidence as part of repo cleanup.

## Research and proposal validation

Read root AGENTS first, then Swift guidance and the optional personal `unslop` writing instructions. Inspected tracked files, package scripts, project/scheme references, ignore rules, last-change dates, all 26 tracker status summaries, all 18 evidence-folder sizes and inbound text references, local reference trees, public GitHub trees, representative manifests/workflows/readmes, and latest release records.

Read-only simulator checks were `xcrun simctl list devices` and `list runtimes`. Toolchain checks were `xcode-select -p`, active `xcodebuild -version`, and explicit `/Applications/Xcode.app/.../xcodebuild -version`. No simulator was booted. `make quality-storekit` passed. No app build, payment test, E2E run, deployment, App Store Connect check, or archive upload was needed or performed for this document-only proposal.

Reference absence statements mean no matching tracked file appeared in the inspected tree. They do not imply a project has no private automation. GitHub data is a dated snapshot. The proposal needs a fresh inventory before implementation.

Public API sources:

- `https://api.github.com/users/fayazara/repos?per_page=100&sort=pushed`, pages 1-3, with empty page 4 confirming the end.
- `https://api.github.com/users/mattt/repos?per_page=100&sort=pushed`, pages 1-2.
- `https://api.github.com/repos/<owner>/<repo>/git/trees/HEAD?recursive=1`, plus raw files at the inspected heads.
- `https://api.github.com/repos/<owner>/<repo>/releases?per_page=1`.

No GitHub write occurred during research. The requested branch push contains this proposal only.

## Public repository name catalog

This is the full public-name inventory returned by the paginated user-repository endpoints on the research date. It includes forks and non-Swift projects. The detailed sample above excludes forks. Names are listed in API pushed order within each page.

### fayazara

Page 1, 100 repositories:

`homebrew-tap`, `Screendrop`, `godraw`, `coworkers`, `screendrop-worker`, `Kaze`, `fayazara`, `eleven`, `robot-heads`, `Libraries.dev`, `shaders`, `shiki-swift`, `tanstack-start-workers-template`, `Search`, `Swift-Diffs`, `ballance`, `boop`, `cloudflare-computer-example`, `site-doctor-demo`, `headlesstools`, `analytics`, `marktui`, `x-profile-api`, `waku`, `cf-developers-day-blr`, `thinking-orbs`, `cloudtable`, `postui`, `xray`, `docs-starter`, `tinycast`, `mintlify-starter`, `portfolio-site-template`, `cobe-swift`, `cf-aig-demo`, `hand-drawn-lucide-icons`, `cfargus-sandbox`, `ghostty`, `kero`, `glaze-email-worker-template`, `pdfstudio-demo`, `pdfstudio`, `moondream`, `bangalore.fyi`, `cloudflare-docs`, `doodleflare`, `kumo-ai-blocks`, `oh-hi-mark`, `ai-review-agent-workshop`, `what-can-brower-run-do`, `alfred`, `cloudflare-wrapped`, `opencode-stats`, `macos-app-skills`, `Dot-Matrix-Loaders`, `cf-for-startups-copy`, `voice-agents-workshop`, `docs-to-mcp`, `fixtures`, `youtube-thumbnail-generator`, `infinite-workers-canvas`, `typewhisper-mac`, `clearly`, `orgchart`, `linkpreview-web`, `cf-webanalytics`, `linkpreview-analytics`, `demo-dashboard`, `demo-docs`, `demo-blog`, `demo-website`, `webhookflare`, `bloom-share-app`, `bloom-share-personal`, `test-123`, `cf-sealion-api-demo`, `cf-sealion`, `cf-sealion-demo`, `bucketdrop`, `sealion-llm-example`, `templates`, `teleprompter-old`, `pocketvue`, `supersaas-new-test`, `whereami`, `talk-to-gmail`, `twitter-ai-agent`, `agents-starter`, `logspot`, `automa`, `RMBG-2.0`, `chat`, `vue-pdf`, `nuxt-better-auth`, `ui`, `docus`, `prose-components-spa`, `favicon-fetch`, `postiz-app`, `db0`.

Page 2, 100 repositories:

`unemail`, `workers-ses`, `onelink`, `vtracer-ts`, `lucide`, `xsai`, `hono-xsai-app-repro`, `nitro-xsai-app-repro`, `simple-nuxt-ui-starter`, `animated-lucide-vue`, `tanstack-router-react-query`, `tanstack-router-test`, `llm-markdown-codebase`, `pocketbase-nuxt`, `feedbackjar`, `module-starter`, `brick-breaker`, `hono-stripe-test`, `nitro-stripe-test`, `stripe-recommendations`, `mintlify-docs`, `drizzle-do-sqlite-demo`, `vscode-cf-workers`, `Awesome-Black-Friday-Cyber-Monday`, `nuxt-auth-utils`, `useEmail`, `nuxt-ui-3-test`, `test-typescript-package`, `supersaas-jwt-auth`, `testtttttt`, `nuxthub-ratelimit`, `domain-test`, `ts-lib-starter`, `nuxt.com`, `vue-sonner`, `feedful`, `v-extension`, `Imbox`, `whoiser`, `zooper`, `Framework-Wars`, `vuelidate-test`, `nitro-s3`, `hono-s3`, `saas-hooks`, `test-spr`, `documentation`, `transformers.js`, `nuxt-font-repro`, `SaaS-Boilerplate`, `codeshare`, `static-files`, `libsql-studio`, `ramadan-times`, `hat.sh`, `radix-vue-reproduction`, `ip-api`, `google-indexing-script`, `next13-lms-platform`, `guess-the-emojis`, `monaco-vue`, `narrate-amitji`, `NuxtChat`, `sketch-to-ui`, `nuxt-content`, `vue-use-fixed-header`, `pocketbase-nuxt-example`, `background-removal-js`, `nuxt-prepare`, `pocketbase`, `vuefire-demo`, `pocketbase-js-sdk`, `hawa`, `parser`, `docs`, `bring-back-twitter-bird`, `nuxt-todos-edge`, `NextList`, `metaspy`, `ramadan-table`, `nuxt-icon`, `tailwind-components`, `bmi-calculator-example`, `telegram-bot-example`, `razorpay-nuxt-example`, `nuxt-tailwind-darkmode`, `Covid`, `git-stars`, `ninja-keys`, `teledrive`, `vue-chatwoot-plugin`, `nuxt-image-issue-reproduction`, `zen-hackernews`, `screenshot`, `publish-to-github-action`, `my-blog`, `fluenticons-old`, `gatsby-plugin-chatwoot`, `tailwindcss-toggle`, `YT-Live`.

Page 3, 11 repositories:

`nuxt-stripe`, `favicon-resolver`, `Gson`, `devto-clone`, `blowhorn-clone`, `razorpay-test`, `iptv-1`, `bmi-calculator`, `Indian-Cities`, `Indian-Cities-API`, `potrace`.

### mattt

Page 1, 100 repositories:

`iMCP`, `AnyDecisionModel`, `LiteRT-LM`, `homebrew-tap`, `things-cli`, `mlx-swift-lm`, `paseo-microphone`, `paseo-creator-micro`, `AnySpeechRecognizer`, `tailscale`, `ollama-swift`, `EventSource`, `libtailscale`, `newage`, `rePossess`, `lore-swift`, `AnyDecisionModel-Examples`, `huggingface-blog`, `swift-toml`, `Ontology`, `Envelope`, `onegaishimasu`, `olleh`, `emcee`, `aseprite-py`, `preowned`, `TopoText`, `TSRP`, `Companion`, `IntervalTree`, `llama.swift`, `PartialJSONDecoder`, `Madrid`, `Replay`, `mlx`, `PollenPet`, `coreai-kit`, `jishuken`, `api`, `ResAgent`, `deno-llama`, `deno-mlx`, `aseprite-mcp`, `nacha-lsp`, `mattt`, `panache`, `swift-yyjson`, `swift-yyjson-benchmark`, `obsidian-AI-exporter`, `asana-cli`, `URLPattern`, `HuggingFaceFSKit`, `HuggingSpace`, `hf-workflows`, `mlx-swift`, `swift-xgrammar`, `swift-embeddings`, `swift-xet-rust-ffi`, `swift-configuration-toml`, `yyjson`, `git-snapshot-import`, `llama.cpp`, `supertone-swift`, `chat-ui-swift`, `LlamaBarn`, `UserAgent`, `bfl-python`, `astro`, `JSONSchema`, `Uncertain`, `LinkedList`, `WebVTT`, `bestline-swift`, `JSONLines`, `URITemplate`, `FileSystemMonitor`, `Uncertain-Distribution-Visualizer`, `swiftly-action`, `Subprocess`, `libsql-swift`, `swift-realtime-openai`, `vscode-extension-uniffi-udl`, `hype`, `golang-jwt`, `workos-go`, `docs`, `hello-flask-uv`, `transformers`, `OpenAPIKit`, `OpenAI`, `documentation-block`, `sinatra-param`, `linguist`, `tree-sitter-jsdoc`, `azure-storage-ruby`, `swift-package-manager`, `TransformerKit`, `DBSCAN`, `swift-evolution`, `example-package-deckofplayingcards`.

Page 2, 57 repositories:

`swift-package-registry-oas`, `CommonMarkAttributedString`, `GroundControl`, `Orbiter`, `CargoBay`, `docsetutil-validate-action`, `docurium`, `licensed`, `commoditize`, `Euler`, `terminal-share`, `WebPImageSerialization`, `SkyLab`, `rack-subdomain`, `swift-registry`, `swift-package-registry-codeartifact`, `swift-registry-benchmark-harness`, `InflectorKit`, `vscode-unicorn`, `swift-package-serialization-lambda`, `Surge`, `Antenna`, `Ono`, `tree-sitter-swift`, `rack-newsstand`, `CHChromaHashView`, `NFPA704View`, `AnyJSON`, `NSEtcHosts`, `core_data`, `rack-push-notification`, `FormatterKit`, `rack-smart-app-banner`, `rack-passbook`, `rack-in-app-purchase`, `rack-remote-configuration`, `rack-scaffold`, `rack-typekit`, `rack-http-logger`, `rack-heroku-no-such-app`, `MsgPackSerialization`, `GeoJSONSerialization`, `AnimatedGIFImageSerialization`, `Xcode-Licensed-Templates`, `vCardSerialization`, `CupertinoYankee`, `Navajo`, `Godzippa`, `Chroma-Hash`, `BritishInvasion`, `TTTLocalizedPluralString`, `NSSortDescriptor-WilsonRank`, `Morse.js`, `glitz`, `UIFontSerialization`, `TTTRandomizedEnumerator`, `Sonic-Hash`.

## Implemented scope and obligation checklist

Status: implemented: `366569f`, `a5a9f18`, `c11cb46`, `b21b3ae`, `edbd61c`, `f6a3c0a`, `fff5abc`, `bdba673`, `b68c367`. The last two commits record link validation/obligations and Linux CI. This status supersedes the proposal-only wording in the research record.

Owner approval on 2026-11-05 expands the original proposal: items 1-6 and 9, old evidence-media removal, and Linux-only CI run now. Apple configuration moves remain excluded. Git history is the recovery archive, so no external upload/restore prerequisite applies to these approved normal deletions. Keep docs/app-store and web/src/assets/app-images untouched. Keep all generated Convex instruction blocks intact.

The old root AGENTS snapshot is `074b10994f1b68d9d7a8d6c54ed7effb90d5f1f5:AGENTS.md`. Line ranges below refer to that snapshot, not a moving working-tree file. Every obligation has a destination. Historical claims were corrected, not promoted to current verification.

| Old lines | Obligation | New location and disposition |
| --- | --- | --- |
| 5-8 | Avoid shortcuts and unsupported plausible code | Root Change discipline and Engineering, primary-source verification and complete-diff review |
| 12 | Review simpler approaches, redundant/duplicate/dead code; fix findings or confirm clean | Root Change discipline, after normal validation |
| 14-15 | Do only requested scope, concise changes, respect existing code | Root Change discipline |
| 17 | Read Swift guidance | Root Area map, native AGENTS, docs/development/swift.md |
| 19 | Verify unclear framework/build/project behavior with primary docs/public examples | Root Engineering |
| 21-22 | Apple Markdown tip | Root Engineering narrows it to URLs verified individually; no universal rendering promise |
| 26 | Pure functions, immutability, explicit inputs/outputs | Root Engineering |
| 27 | Single responsibility | Root Engineering |
| 29 | Practical O(1)/O(log n) | Root Engineering |
| 30 | No accidental quadratic hot paths | Root Engineering |
| 31 | Map/Set indexing instead of repeated scans | Root Engineering |
| 33 | Timers/animation frames/self-scheduling need justification and deterministic cleanup | Root Engineering |
| 34 | Prefer events over polling | Root Engineering |
| 35 | Document shared mutation | Root Engineering |
| 39-41 | Reduce layers and state readers must track | Root Engineering, native AGENTS state ownership |
| 45 | Keep app logic organized | Native AGENTS feature organization; architecture guide |
| 46 | Composition, no god-modules | Root Engineering |
| 47 | Thin deterministic adapters, I/O at boundaries | Root Engineering |
| 51 | Focused diff, no unrequested refactor/behavior mixing | Root Change discipline |
| 52 | Preserve contracts or document intentional change | Root Change discipline |
| 53 | Validate before finishing | Root Validation; docs/development/validation.md |
| 54 | No routine command lists in history, one short summary if needed | Root Documentation and evidence |
| 55 | Final cleanup review after normal validators, not each edit | Root Change discipline replaces model-specific skill mandate with complete-diff review and relevant installed tools, as the approved plan requests |
| 59 | Four booted, one stock maximum | Root Scope and safety; simulator runbook |
| 59 | iPad/17/17e/Air slim; owner/media stay stock | Simulator runbook profiles/roles; root retains stock prohibition |
| 59 | simslim install, verify booted, repair with profile | Simulator runbook exact profile/commands |
| 59 | Dated 7.4/10.6 GB measurements | Simulator runbook labels 2026-10-30 numbers historical, not reverified |
| 59 | Never shut down reserved/unknown/claimed devices for budget | Root Scope and safety; runbook lock ownership |
| 60 | One model per iOS version, old runtime inventory | Simulator runbook current discovery/inventory; root forbids stale inventory as authority; exact-one policy retained below |
| 61 | Protected owner fixture must never be erased/reset/seeded | Root Scope and safety, native/widget AGENTS, simulator runbook |
| 62 | Pro Max demo/media role and 9:41 status | Simulator runbook; root stock rule |
| 63 | iPad test runner, compatibility mode | Simulator runbook and serial test selection |
| 64 | Empty 17/17e/Air QA devices | Simulator runbook dated roles/inventory |
| 65 | No device creation for QA/tests | Root Scope and safety; simulator runbook |
| 65 | Reuse disposable devices, task-scoped erase/reinstall/settings/demo allowed, leave usable | Simulator runbook Safety and ownership, never the owner fixture |
| 65 | Clean installs use iPad/empty iPhone | Simulator runbook |
| 65 | Only a new model/runtime may replace an old device | Root Scope and safety; simulator runbook, owner approval required |
| 66 | StoreKit compatibility, select known-good Xcode explicitly | Simulator runbook dated probe results and DEVELOPER_DIR; no payment pass claimed |
| 67-68 | List targets/schemes | Setup and validation guides use worktree-relative project path |
| 69-70 | make quality-build, build is not tests | Root Validation, setup/validation guides |
| 71-82 | Serial iOS tests on iPad, not owner fixture, 30/45-second limits | Native AGENTS and validation/runbook exact command |
| 83-95 | Supported class selector with same serial/timeouts | Validation guide InsightsAnalyticsTests selector and unchanged flags |
| 96 | Shared app scheme runs XCTest; fixtures in test bundle, not app | Native AGENTS and validation/architecture guides |
| 97 | Defer macOS unless asked | Root Validation, setup/runbook |
| 98 | cf account/resource operations | Root Validation, worker/web AGENTS |
| 98 | Keep wrangler.jsonc dev/deploy; no cf init/dev/build/deploy during Astro beta | Root Validation, worker/web AGENTS |
| 98 | Re-evaluate cf migrate only after docs remove limitation | Root Validation |
| 100 | Official swift-format via make targets/root config | Root Validation; validation guide exact scope/options |
| 101 | Isolated Bun/Oxlint, vendored rules, error severities, max complexity 20, keep coverage, no suppressions | Root Validation and validation guide, tools/oxlint instructions retained |
| 102 | Astro script lint is not template checking; Swift formatting separate | Root Validation and web AGENTS |
| 103 | Do not assume an additional linter | Root Validation |
| 107 | App/widget/test targets and shared test scheme | Setup and architecture guides |
| 108 | SwiftUI/SwiftData native feature boundaries | Architecture guide with actual source pointers |
| 109 | Optional support packages, separate scripts, outside Xcode build | Setup/architecture guides and root Area map |
| 110 | Idiomatic SwiftUI, close state, async/await, no unnecessary view-model/UIKit layers | Native AGENTS and moved Swift guide |
| 112 | Ambiguous foods/OCR/nutrition/servings require edit/review | Root Product invariants |
| 118 | SwiftUI primary | Native AGENTS |
| 119 | Small feature-focused views | Native AGENTS |
| 120 | Native state wrappers before view-model layers | Native AGENTS and Swift guide |
| 121 | Feature organization, not global type folders | Native AGENTS |
| 125 | On-device primary database | Root Product invariants; native AGENTS |
| 126 | File/data protection | Native AGENTS and architecture storage pointer |
| 127 | Keychain for small secrets | Native AGENTS |
| 128 | Account-free import/export | Native AGENTS |
| 129 | HealthKit optional OS permission, no login implication | Native AGENTS |
| 133 | Deterministic math | Root Product invariants |
| 134 | Per-serving times consumed servings | Root Product invariants |
| 135 | Per-100g scaled to grams | Root Product invariants |
| 136 | Volume without grams requires confirmed conversion/manual entry | Root Product invariants |
| 140 | Prefer native Swift/SwiftUI over cross-platform abstraction | Native AGENTS |
| 141 | Offline-first persistence/cache/network fallback | Root Product invariants |
| 142 | Zero account setup | Root Product invariants |
| 143 | Separate scan/OCR/network failure paths; manual logging available | Root Product invariants |
| 144 | Existing XCTest, isolated fixtures/test bundle; no real stores, production or unrelated devices | Root Validation and native AGENTS |
| 145 | All long-form web copy gets unslop automatically | web/AGENTS.md, including guides/blog/other page copy |
| 145 | Primary health/nutrition sources and current app behavior claims | web/AGENTS.md |
| 145 | Real screenshot assets or authorized media captures | web/AGENTS.md |
| 145 | Static SVG/HTML/CSS illustrations, no extra client JS | web/AGENTS.md |
| 146 | Build not tests; qa-network original loopback Workers plus registered Convex tests; install package deps; no root package.json | Root Validation; setup/validation guides and worker AGENTS |
| 150 | Canonical app history includes work/bugs/decisions/results | Root Documentation and evidence, current changes-log entry point and archive heading index |
| 152 | Detailed implementation trackers | docs/plans/README.md routes 26 moved sources by status, active obligations and before/after inventory |

Additional owner policies remain explicit: atomic simulator locks at `/tmp/macros-sim-locks/<UDID>`, no production Convex deploy without approval, and tracked evidence limited to five images/2 MiB per task. The three build-33 folders are unchanged exceptions. Existing raw reports stay readable, with old media retrieved at the recorded main SHA. No fixture, simulator, runtime, deployment, signing setting, Info.plist, or StoreKit path was changed.

## Preservation and validation notes

- Root AGENTS is 76 lines and 5,655 bytes before the final documentation audit, under the 60-90-line/6-KiB budget.
- All 26 trackers survive; six source unchecked boxes remain six. The active inventory enumerates 195 conservative prose/checkbox candidates; the follow-up list assigns owners and closure evidence. No cleanup commit signs off a release/device gate.
- History prose/results remain verbatim. Eight Markdown link destinations were repaired for moved archives/plans; the archive indexes preserve every heading. Old filenames in historical archives, this proposal, and the untouched App Store audit are intentional historical mentions, not live instructions.
- Before media removal, origin/main was `074b10994f1b68d9d7a8d6c54ed7effb90d5f1f5`. The ignored build/repo-cleanup manifest/report lists all deleted paths, byte sizes, checksums and per-folder counts. The three keep folders and all App Store/README assets are checked against that baseline.
- Local checks pass: StoreKit config, JS lint, official Swift formatting, native build, both shared schemes, no Markdown in app/widget bundles, web check/build, OG clean/repeat/title/draft checks, Worker tests, offline runtime HTTP and registered Convex integrations. No XCTest/simulator run is claimed by cleanup.
- Linux CI uses contents-read permission, SHA-pinned actions, frozen installs and per-job path selection. Jobs cover JS lint, web check only, Worker checks/tests, Convex offline tests and runtime QA. No macOS/Xcode, build/deploy, credentials, or artifact upload jobs.
- All CI package commands were rerun on this Mac with isolated Bun 1.4.4 and Node 26.5.0. Auth passed 3 tests, food proxy 92, Convex 20 unit and 76 registered integration tests, and runtime QA 59 assertion groups across 129 loopback HTTP requests. Web check and JS lint passed. These are local results, not a claim that GitHub's Linux jobs have run.
- Swift CI is omitted: local Homebrew swift-format is 602.0.0, the toolchain formatter reports main, and no local container runtime is available to validate an exact Swift 6 Linux match. The required local formatting gate remains unchanged.
- The unslop writing instructions were read and applied to new/rewritten guidance. Dated history, tracker result text, generated backend blocks and retained evidence reports were not rewritten for style.

The rest of this document is the original research/proposal record. Its proposed sequencing, old paths and optional Apple layout describe that record, not extra authorization for this cleanup.
