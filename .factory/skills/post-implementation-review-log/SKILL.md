---
name: post-implementation-review-log
description: After implementation work, run simplify, validate, run defensive-code-review, update changes-log.md with pre-review and post-review work, then run final validators and diff review. Use when the user asks to run simplify plus defensive-code-review and record missing work in changes-log.md.
user-invocable: true
disable-model-invocation: true
---

# Post-Implementation Review Log

## Goal

Finish implementation work with the repo's preferred cleanup sequence:

1. run `/simplify`
2. apply only scoped, justified simplify findings
3. validate
4. run `/defensive-code-review`
5. apply only high-confidence redundant-defense cleanup
6. update `changes-log.md` with work done before and after the review skills
7. run final validators and final diff review

Use this as an end-of-workflow skill, not at task start.

## When to use

Use when the user asks for any variation of:

- "run `/simplify` and then `/defensive-code-review`"
- "after that add all work done to `changes-log.md`"
- "add all work from before skills and after skills to the changes log"
- "run cleanup reviews and update the changelog"

Do not use for trivial one-line edits unless the user explicitly asks.

## Required context

Before invoking cleanup skills:

1. Read `AGENTS.md`, `SOFTWARE_PATTERNS.md`, and relevant local guidance such as `swift-dev.mdc`.
2. Inspect current work with:
   - `git status --porcelain`
   - `git diff --stat`
   - `git diff --name-only`
   - targeted `git diff` for changed source files and `changes-log.md`
3. Read the changed files and nearby callers/helpers needed to understand the real behavior.
4. Read the relevant section of `changes-log.md` before editing it.
5. Determine which validators are relevant from `Makefile`, package scripts, project guidance, or the changed area.

## Workflow

### 1. Snapshot the completed implementation

Capture what existed before cleanup:

- changed files
- user-visible behavior or internal fix
- validation already run
- known unresolved issues

This matters because `changes-log.md` must describe the original implementation work, not only the final cleanup diff.

### 2. Run `/simplify`

Invoke the existing simplify skill.

If the skill launches review agents, wait for all results. Aggregate findings into:

- accepted fixes
- intentionally skipped findings
- no findings

Apply only behavior-preserving, scoped simplifications. Skip broad refactors, destabilizing abstractions, or suggestions that would mix unrelated cleanup into the user's feature work.

### 3. Validate after simplify

Run relevant validators before `/defensive-code-review`.

For this repository, common validators include:

- `git diff --check`
- `make quality-format-check`
- iOS simulator build via XcodeBuildMCP or `make quality-build`
- area-specific worker/web checks when files under `worker/` or `web/` changed

Fix failures before continuing. Do not run `/defensive-code-review` on an unvalidated implementation unless the user explicitly accepts that risk.

### 4. Run `/defensive-code-review`

Invoke the existing defensive-code-review skill only after validators pass.

Apply only candidates that are proven redundant by real code. Keep guards and fallbacks that protect:

- persistence/schema migration
- network/OCR/barcode/search ambiguity
- user-editable input and review flows
- widget/read-only fallback display
- async cancellation, stale-result ordering, or lifecycle races

If a candidate is speculative, keep it and note why.

### 5. Update `changes-log.md`

Find the existing feature/history section that owns the work. Prefer updating that section over creating a duplicate section.

Record all missing work from both sides of the cleanup boundary:

#### Original implementation work

Add concise bullets for:

- what changed before `/simplify`
- files/layers involved
- root cause or behavior fixed

#### Simplify work

Add concise bullets for:

- findings accepted and fixes made
- or "simplify review found no scoped cleanup needed"
- or findings intentionally deferred because they were broad/out of scope

#### Defensive-code-review work

Add concise bullets for:

- redundant defensive code removed
- or "defensive-code review found no high-confidence redundant guards / impossible branches"

#### Validation

Follow the repo rule from `AGENTS.md`: do not append routine command lists unless explicitly requested. Use one short validation summary line, for example:

```md
- The follow-up passed whitespace diff validation, formatter validation, iOS simulator build, simplify review, defensive-code review, and final diff review.
```

## Changelog placement rules

- If the changed work belongs to an existing section, update that section.
- If no section exists, create the smallest appropriate subsection under the relevant top-level feature area.
- Do not duplicate old history.
- Do not document every command output; summarize the validation outcome.
- If `changes-log.md` already contains part of the story, add only the missing pre-skill or post-skill pieces.
- Keep bullets factual and evidence-backed. Do not invent product rationale beyond what code/session evidence supports.

## Edge cases

### `/simplify` has no findings

Do not force a code change. Record only if the user requested all review work in `changes-log.md`, e.g.:

```md
- A simplify review found no scoped reuse, quality, or efficiency cleanup needed.
```

### `/simplify` suggests broad refactors

Skip broad changes unless directly required. Note the reason:

```md
- Simplify review noted broader shared-bottom-bar duplication, but it was left unchanged to keep this follow-up focused.
```

### `/defensive-code-review` has no candidates

Do not invent cleanup. Record:

```md
- A defensive-code review found no high-confidence redundant guards, duplicated validation, or impossible-state branches.
```

### Defensive review finds one proven candidate

Validate it against code, apply the smallest removal, rerun validators, then record both the finding and fix.

### Validators fail

Stop changelog finalization until failures are fixed. If a failure is unrelated or cannot be fixed in scope, explain clearly and ask before proceeding.

### `changes-log.md` is already modified

Review the existing changelog diff first. Preserve good entries, add missing before/after-skill work, and avoid rewriting unrelated history.

## Final validation and review

After changelog updates:

1. Run final validators relevant to all changed files.
2. Run `git diff --check`.
3. Review final `git diff` for:
   - behavior drift
   - dead code
   - duplicate logic
   - changelog accuracy
   - accidental routine validation spam
4. Confirm `git status --porcelain` shows only intended files.

## Output format

```md
## Review cleanup

- Simplify:
- Defensive-code-review:
- Changelog:

## Validation

- Commands:
- Results:

## Final review

- Changed files:
- Findings:
- LGTM / Follow-up needed
```
