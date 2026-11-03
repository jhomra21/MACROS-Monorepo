# SPEC

TLC reached 69 states and 355 steps. The chart draws 9 states and 10 arrows.
The chart does not draw 243 steps that stay in one chart state.

## NoObsoleteFiles breaks
The shortest path has 5 steps:
0. Credentials Legacy identity only, Widget No macros published
1. the app copies the identity: Credentials Shared copy awaiting verification, Widget No macros published
2. WidgetKit requests a person: Credentials Shared copy awaiting verification, Widget Loading current person
3. the response passes the first current-control check: Credentials Shared copy awaiting verification, Widget Loading current person
4. the app disables sharing and rotates generation: Credentials Shared copy awaiting verification, Widget Access stopped
5. the cache write uses the request's generation: Credentials Shared copy awaiting verification, Widget Access stopped, obsolete cache inert

## Rules that hold
TypeOK, PreserveIdentity, OnlyCurrentDataSelected, NoDeadlock

## Interpretation and source replay

**IN FLUX. NoObsoleteFiles breaks at step 5 and is dismissed. PreserveIdentity and OnlyCurrentDataSelected hold for the bounded success/checkpoint abstraction.**

Reachable / representable control states: **69 / 3,072**. Products and count conventions are in the [inventory](../README.md#counting-rules).

[Dismissed widget diagnostic](../FINDINGS.md#dismissed-model-only-failures-and-prevented-paths): prewrite current-control check passes, app rotates generation, then old-generation disk write lands. Generation/person/day-keyed reads make it inert; final current-control check rejects the old response.

### Reader rules

PreserveIdentity: retain the legacy identity or a verified shared copy. OnlyCurrentDataSelected: logical current-control selection cannot use disabled, denied or obsolete-generation data. NoObsoleteFiles is an intentionally overstrong physical-cleanup diagnostic. TypeOK and NoDeadlock hold.

### Abstraction and omissions

Success-only legacy→shared identity migration, one request, two generations, Boolean Pro, one cache generation. Does not model Keychain errors/duplicate query selection, migration-error latch, token exchange ownership, people/default/day changes, Pro unknown, offline status taxonomy, or midnight timelines. Those are inventory follow-ups, not proven safe here. selected means logical eligibility at control checkpoints; invalidation revokes it in the abstraction. It is NOT physical WidgetKit presentation. Already-rendered entries, OS refresh timing and the last-check-to-return race are outside this model.

The view hides no explicit actions. Statechart omits steps that stay in one chart label; the checked model still contains them. Parallel-region charts display changed regions only. See the generated header above for counts.

### Proposed explicit boundary, not implemented

CredentialMigrationState, immutable WidgetLoadContext and WidgetOutcome remain separate. Use generation-scoped cache and token ownership; do not infer instantaneous widget redaction from a control write.

## Chart

![widget-control statechart](chart.svg)

```mermaid
---
title: "IN FLUX: widget credential migration and generation fence"
---
stateDiagram-v2
  direction LR
  state "Legend" as legend {
    lg0: Breaks NoObsoleteFiles
    lg1: Path to the NoObsoleteFiles bug
  }
  class lg0 breaks
  class lg1 bugPath
  state "At the same time" as all {
    state "Credentials" as r0 {
      s0: Legacy identity only
      s1: Shared copy awaiting verification
      s2: Both copies verified
      s3: Verified shared identity
      [*] --> s0
      s0 --> s1: the app copies the identity
      s1 --> s2: the app verifies byte-for-byte equality
      s2 --> s3: the app deletes the specifically scoped legacy item
    }
    --
    state "Widget" as r1 {
      s4: No macros published
      s5: Access stopped
      s6: Loading current person
      s7: Current-generation macros selected
      s8: Access stopped, obsolete cache inert
      [*] --> s4
      s4 --> s5: the app disables sharing and rotates generation or the app denies Pro and rotates generation
      s4 --> s6: WidgetKit requests a person [unless Legacy identity only]
      s6 --> s5: the app disables sharing and rotates generation or the app denies Pro and rotates generation
      s5 --> s8: the cache write uses the request's generation [unless Legacy identity only]
      s6 --> s7: the provider checks current control again before returning or the widget reads only the current generation
      s6 --> s8: the app disables sharing and rotates generation or the app denies Pro and rotates generation
      s7 --> s8: the app disables sharing and rotates generation or the app denies Pro and rotates generation
    }
  }
  classDef breaks fill:#ffecee,stroke:#e72e3b,stroke-width:2.5px,color:#cd2834
  class s0 bugPath
  class s1 bugPath
  class s4 bugPath
  class s5 bugPath
  class s6 bugPath
  class s8 breaks
  class s8 bugPath
```

[Exact regeneration](RUN.md). All failures above are model results; only the separately replayed source conflicts are classified as confirmed defects. Owner approval remains pending.
