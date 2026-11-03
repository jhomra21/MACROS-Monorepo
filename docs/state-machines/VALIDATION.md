# Research validation

Validation is limited to model/tooling/artifact checks. No app behavior was executed.

## Tooling evidence

Installed skill: `/Users/juan/.factory/skills/statechart`.

Source: `https://github.com/cursor/plugins/tree/ae5650febf4320793844c12c4adaa937f417f8da/pstack/skills/statechart`.

Pinned source SHA: `ae5650febf4320793844c12c4adaa937f417f8da`; installation metadata is in `UPSTREAM.md` at the skill path. Installation excludes `scripts/test/`. Bun 1.4.2, mise 2026.10.25, TLC 1.7.4, Java temurin-25, Pele 1.9.0. No repository app dependency or build configuration changed.

The initial scratch smoke model (`phase = idle | done`, Start then terminal stutter) completed:

```text
TLC reached 2 states and 2 steps.
The chart draws 2 states and 1 arrows.
Rules that hold: TypeOK, NoDeadlock
```

The scratch smoke files were `/tmp/macros-statechart-smoke/{SPEC.tla,SPEC.cfg,view.mjs}`, output `/tmp/macros-statechart-smoke/out`. They are not required to regenerate the eight delivered models.

## Model and artifact checks

The final eight model runs completed with the counts in [README.md](README.md#eight-checked-models). No rules were left unchecked. Seven statechart exits of 1 are expected failed invariants/diagnostics; upload's exit is 0. Model failures are explicitly classified in [FINDINGS.md](FINDINGS.md); they are not silently turned into passing rules.

The final scope view has 20 arrows and suppresses nine removal steps; its model is unchanged. The widget model was rerun after separating the two control checks around the disk write, then after clarifying logical selection versus physical WidgetKit display. Final widget count: 69 states, 355 steps, nine chart states and ten arrows.

Final review strengthened upload from one edit to two revisions of edits, so the second edit can arrive while a previous revision is in flight. The original one-edit initial state could not exercise that coalescing case. Final upload count: 66 states, 167 steps, eight chart states and 15 arrows; all configured rules still hold. Its representable control product is 6,480. This model refinement changed no application source.

Every chart was rendered with Pele 1.9.0 and the prescribed high limits. Each SVG sits beside the same-named Mermaid source and contains the light/dark theme and `!important` bug mark CSS. These are generated research charts, not screenshots or app visual evidence.

Static verifier:

```sh
cd /Users/juan/.t3/worktrees/cal-macro-tracker/state-machines && bun docs/state-machines/verify.mjs
```

It checks:

- All 66 ordered inventory IDs and all eight required model bundles.
- Local Markdown file links resolve inside the research checkout.
- Exact expected model/chart counts and no hidden VIEW/SYMMETRY/exploration constraints.
- Committed fenced Mermaid equals each `chart.mmd`.
- Every SVG has a complete root and the injected light/dark mark styles.
- View modules import and expose state/step functions.
- Every file is smaller than 5,000,000 bytes.

`git diff --check` checks whitespace; `xmllint --noout` checks all eight SVGs. Each model's RUN.md documents a fresh output directory and expected exit handling. Regeneration compares the fresh Mermaid and raw report prefix with committed artifacts; generated TLC elapsed times are not byte-stable.

All eight documented regeneration commands were executed successfully. Fresh Mermaid files and raw report prefixes matched the committed artifacts. The upload command was rerun after its final two-edit refinement. Static verification passed for 66 inventory entries, eight model bundles and 161 local Markdown file links; every file is below 5 MB. All eight SVGs passed XML parsing. No unrelated working-tree changes were included.

### Final defensive-code review

Scope: documentation, model abstractions and the two Bun artifact helpers only. Repository architecture guidance and relevant change history were checked after the normal validators. Retained filesystem/output assertions protect external renderer and artifact boundaries; no redundant application guard was removed. The review corrected the underpowered one-edit upload abstraction and the widget physical-display wording. No app refactor, duplicate application helper or speculative defensive cleanup was introduced.

The verifier initially reported the not-yet-written `VALIDATION.md` link; that documentation dependency was resolved. One intermediate model attempt rejected an already-nonempty scratch output directory; subsequent runs use new output folders. An early scratch widget spec lacked integer support for its negative cache sentinel; `EXTENDS Integers` corrected the parse issue before final runs. These are tooling iterations, not app defects.

## Deliberately not run

App builds, app unit/E2E tests, formatter/lint gates unrelated to research artifacts, simulator operations, live sharing mutations/queries, Cloudflare calls, and real-data migration/deletion reproductions. All source-confirmed findings are static replays, with future isolated reproduction procedures in FINDINGS.md.

Only `docs/state-machines/` belongs to this change. The main checkout and active widget checkout were not edited. No PR or merge is part of this research handoff.
