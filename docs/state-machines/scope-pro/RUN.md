# Regenerate scope-pro

Sources: main `da00befaae3d9954c7046f80570bda4936f918d7`; widget-only source `c5e38440b8d0b375aad6908bd265da64c93775a1` is **IN FLUX**.

Prerequisites: Bun 1.4.2, mise 2026.10.25, installed statechart skill source SHA `ae5650febf4320793844c12c4adaa937f417f8da`, TLC 1.7.4, Java temurin-25. Skill location: `/Users/juan/.factory/skills/statechart`. TLC/Java setup is managed by the skill; do not run app tooling.

Install only the pinned SVG renderer outside the repository, if needed:

```sh
cd /tmp && mkdir -p pele && cd /tmp/pele && bun add --exact pele@1.9.0
```

Exact model and rendering command, with a freshly allocated output directory. No production service or app test is involved:

```sh
cd "/Users/juan/.t3/worktrees/cal-macro-tracker/state-machines/docs/state-machines/scope-pro" && OUT="$(mktemp -d /tmp/macros-scope-pro-XXXXXX)" && if /Users/juan/.factory/skills/statechart/scripts/statechart "/Users/juan/.t3/worktrees/cal-macro-tracker/state-machines/docs/state-machines/scope-pro/SPEC.tla" --config "/Users/juan/.t3/worktrees/cal-macro-tracker/state-machines/docs/state-machines/scope-pro/SPEC.cfg" --view "/Users/juan/.t3/worktrees/cal-macro-tracker/state-machines/docs/state-machines/scope-pro/view.mjs" --out "$OUT"; then RC=0; else RC=$?; fi && test "$RC" -eq 1 && cd "/Users/juan/.t3/worktrees/cal-macro-tracker/state-machines" && bun "/Users/juan/.t3/worktrees/cal-macro-tracker/state-machines/docs/state-machines/render.mjs" "$OUT" /tmp/pele && printf 'Generated model and SVG in %s\n' "$OUT"
```

Expected statechart exit: **1**. The documented invariant/diagnostic failure is expected; inspect the generated report, not just the process exit. A different failure or count must be investigated. Expected reachable / representable count: **10 / 24**. No VIEW, SYMMETRY or exploration constraints. No fairness/liveness claim.

The fresh output contains raw `report.md`, `tlc.out`, `chart.mmd` and rendered `chart.svg`. Committed report.md additionally includes human source replay, omissions and fenced Mermaid text; preserve that commentary when refreshing artifacts. SVG generation uses Pele's synchronous render API, the repository's `colors.css`, and options `{limit: 1_000_000, outputLimit: 8_000_000, maxEdges: 10_000}`.

The view suppresses all YouRemovePerson arrows except the complete Foods stored and visible → Relationship removed, foods deleted arrow. Nine model steps are hidden, not unchecked. All chart states remain reachable; the disconnected state has no nonstuttering outgoing model transition. Same-label steps are also omitted by statechart.

[Interpretation, reader rules and source replay](report.md).
