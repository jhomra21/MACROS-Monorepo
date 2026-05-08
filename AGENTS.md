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

- Inspect project targets and schemes:
  - `xcodebuild -list -project "/Users/juan/Documents/xcode/cal-macro-tracker/cal-macro-tracker.xcodeproj"`
- Build the app from the CLI:
  - `xcodebuild -project "/Users/juan/Documents/xcode/cal-macro-tracker/cal-macro-tracker.xcodeproj" -scheme "cal-macro-tracker" -configuration Debug -destination 'platform=macOS' build`
- Run the full test suite:
  - No test target exists yet in the Xcode project, so there is currently no CLI test command to run.
- Run a single test:
  - Not available until a test target is added.
- Lint / formatting:
  - The repository formatter is the official `swift-format` tool, wired through `make quality-format-check` and `make format` with the root `.swift-format` configuration.
  - No Apple/Swift-official linter is part of the documented repository workflow today.

## Current Codebase Shape

- This repository is currently a minimal single-target SwiftUI app defined by `cal-macro-tracker.xcodeproj`.
- App startup lives in `cal-macro-tracker/cal_macro_trackerApp.swift`, which currently renders `ContentView` in a single `WindowGroup`.
- `cal-macro-tracker/ContentView.swift` is still template-level placeholder UI.
- Source files currently sit directly under `cal-macro-tracker/`; as the app grows, organize by feature rather than by technical layer.
- The project is configured for multiple Apple platforms in build settings, but the product direction for this repository is a native iPhone calorie/macro tracker. Optimize implementation decisions for iPhone-first workflows.
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
- Do not assume tests, linting, or persistence infrastructure already exist in this repository; the codebase is still at template scale and will need those pieces added deliberately.

# Changes Log

`changes-log.md` is the canonical project history file for implemented work, bugs found, decisions made, and validation results.

Detailed implementation trackers live in `implementation-trackers/`
