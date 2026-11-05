# Working in MACROS

## Scope and safety

- Work in the active worktree. Preserve user changes, private data, and published history.
- Never erase, reset, or seed the owner's simulator `9843E820-3A2A-4599-9206-D224B3035A47`.
- Reuse existing simulators. Never create one for tests or QA. A new model/runtime may replace an old device only with owner approval.
- Keep at most four simulators booted, at most one stock. The owner fixture and media iPhone stay stock.
- Never shut down reserved, unknown, or actively claimed devices to meet that budget.
- Before using a simulator, acquire its atomic directory lock at `/tmp/macros-sim-locks/<UDID>`. Never take another task's lock; release only your own lock after use.
- Follow [safe selection and the dated inventory](docs/development/simulator-runbook.md). A stale inventory is not permission to change devices or runtimes.
- Do not deploy production Convex, publish releases, apply remote migrations, upload evidence, or deploy services without explicit authorization.
- Keep secrets and private user data out of source, logs, and evidence.

## Product invariants

- Keep food logs and primary data on device. Normal tracking must work offline with no account.
- Cache lookups and handle network absence with editable fallbacks.
- Keep scanning, OCR, and network resolution separate so failure does not block manual logging.
- Route missing foods, OCR mistakes, incomplete nutrients, and odd serving sizes through review/edit UX.
- Use deterministic nutrition math: per-serving values times consumed servings, or per-100g values scaled by consumed grams.
- Never invent grams for a volume-only serving. Require user-confirmed conversion or manual quantity.

## Area map

Read the scoped instructions before editing an area. Root rules apply everywhere.

| Area | Instructions |
| --- | --- |
| Native app and shared source | [Native AGENTS](cal-macro-tracker/AGENTS.md), [Swift guide](docs/development/swift.md) |
| Widget extension | [Widget AGENTS](cal-macro-tracker/CalMacroWidget/AGENTS.md), plus native rules |
| Convex | [Generated backend instructions](convex-backend/AGENTS.md); leave generated AGENTS/CLAUDE blocks intact |
| Workers | [Worker AGENTS](worker/AGENTS.md) |
| Website | [Web AGENTS](web/AGENTS.md), [SEO](web/SEO.md) |
| Architecture and docs | [Documentation map](docs/README.md), [architecture](docs/architecture/README.md) |

## Engineering

- Prefer pure functions, immutable updates, and explicit inputs/outputs. Document unavoidable shared mutation.
- Give each function/module one responsibility. Prefer composition; keep adapters thin and I/O at boundaries.
- Keep related feature logic together. Avoid god-modules, needless layers, and unnecessary state.
- Target O(1) or O(log n) where practical. Use maps/sets rather than repeated scans; avoid accidental quadratic hot paths.
- Do not add timers, animation-frame loops, or self-rescheduling work without a code comment justifying it and deterministic cleanup.
- Use event-driven updates instead of polling where available.
- Verify unclear framework/build behavior against primary docs or public examples before changing structure.
- Some Apple URLs offer Markdown via `.md`; verify the URL rather than assuming all do.

## Validation

- Run the relevant [existing checks](docs/development/validation.md) before finishing. A build is not a test run.
- Use the existing XCTest target and isolated fixtures, never real stores, production services, or unrelated simulators.
- Keep test resources in the test bundle, not the app bundle. Exclude instruction Markdown from synchronized Xcode target membership.
- macOS builds remain deferred unless explicitly requested.
- Use official swift-format with root `.swift-format`. Do not assume other linters exist.
- Keep Oxlint rules, severities, complexity maximum 20, and source coverage intact. Fix owned source, not suppressions.
- Oxlint's Astro script checks do not validate Astro markup. Run the web checks too.
- Use Bun for support packages; there is no root package.json.
- Use `cf` for authorized Cloudflare account/resource tasks, but keep web/worker `wrangler.jsonc` dev/deploy tooling.
- Do not run `cf init`, `cf dev`, `cf build`, or `cf deploy` there during the Astro beta limitation. Re-evaluate migration only when cf docs remove it.

## Documentation and evidence

- [changes-log.md](changes-log.md) is the canonical current app history; it links to older records.
- [Plans](docs/plans/README.md) distinguish active, blocked, completed, and superseded work. Carry unresolved release/device checks forward.
- Do not append routine validation command lists to history. Use one short validation summary when needed.
- Put raw run output in ignored `build/evidence/<date>-<task>/`, not tracked capture directories.
- Track a task README and at most five images totalling 2 MiB. No videos, frame sequences, or xcresult bundles; larger exceptions need a stated reason.
- Follow the [evidence policy](docs/evidence/README.md). The 2 MiB tracked limit is stricter than the owner's general under-5-MB artifact rule.

## Change discipline

- Implement only the requested scope with small, focused diffs. Do not mix refactors and behavior changes unless requested.
- Preserve public contracts unless the change is intentional and documented.
- Review the complete diff for redundant guards, duplicated logic, dead code, and simpler solutions after normal validation.
- Use relevant installed review tools when useful; do not depend on a particular model or an absent skill.
- Fix issues found in that review before stopping; otherwise briefly confirm the diff is clean.
