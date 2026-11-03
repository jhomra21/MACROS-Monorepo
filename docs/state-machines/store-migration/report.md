# SPEC

TLC reached 7 states and 9 steps. The chart draws 7 states and 7 arrows.
The chart does not draw 2 steps that stay in one chart state.

## CompleteBeforeOpen breaks
The shortest path has 4 steps:
0. Legacy database waiting
1. the app checks for the destination database: Copying database
2. the database copy finishes: Database copied, WAL still missing
3. you relaunch: Relaunched with only database copied
4. the app checks for the destination database: Incomplete migrated store opened

## Rules that hold
TypeOK, NoDeadlock

## Interpretation and source replay

**Confirmed conditional source conflict F2. CompleteBeforeOpen breaks at path step 4.**

Reachable / representable control states: **7 / 20**. Products and count conventions are in the [inventory](../README.md#counting-rules).

[F2 source replay](../FINDINGS.md#f2-a-partially-copied-sqlite-store-is-treated-as-migrated) maps check/copy/interruption/relaunch/open to source. Requires a source WAL holding committed uncheckpointed data. No observed data loss or app fixture run.

### Reader rules

CompleteBeforeOpen: an opened migrated store includes all committed legacy data. TypeOK and NoDeadlock hold; CompleteBeforeOpen breaks.

### Abstraction and omissions

One source with committed WAL data, one destination, one interruption boundary. SHM is omitted because the persistent-state rule concerns base plus WAL. Does not establish that copying an actively changing source is a consistent snapshot. Original legacy artifacts are not deleted.

The view hides no explicit actions. Statechart omits steps that stay in one chart label; the checked model still contains them. Parallel-region charts display changed regions only. See the generated header above for counts.

### Proposed explicit boundary, not implemented

MigrationState: legacy, preparing, copiedAndValidated, published, failed. Use a consistent database snapshot protocol and staged publication with durable recovery, rather than a base-file-exists guard.

## Chart

![store-migration statechart](chart.svg)

```mermaid
---
title: "Local database migration and relaunch"
---
stateDiagram-v2
  state "Legend" as legend {
    lg0: opened
    lg1: copy
    lg2: Breaks CompleteBeforeOpen
    lg3: Path to the CompleteBeforeOpen bug
  }
  class lg0 teal
  class lg1 blue
  class lg2 breaks
  class lg3 bugPath
  s0: Legacy database waiting
  s1: Copying database
  s2: Database copied, WAL still missing
  s3: Copy failed after database
  s4: Relaunched with only database copied
  s5: Complete migrated store opened
  s6: Incomplete migrated store opened
  [*] --> s0
  s0 --> s1: the app checks for the destination database
  s1 --> s2: the database copy finishes
  s2 --> s3: the WAL copy fails
  s2 --> s4: you relaunch
  s2 --> s5: the committed WAL copy finishes
  s3 --> s4: you relaunch
  s4 --> s6: the app checks for the destination database
  classDef breaks fill:#ffecee,stroke:#e72e3b,stroke-width:2.5px,color:#cd2834
  class s0 blue
  class s0 bugPath
  class s1 blue
  class s1 bugPath
  class s2 blue
  class s2 bugPath
  class s3 blue
  class s4 blue
  class s4 bugPath
  class s5 teal
  class s6 teal
  class s6 breaks
  class s6 bugPath
```

[Exact regeneration](RUN.md). All failures above are model results; only the separately replayed source conflicts are classified as confirmed defects. Owner approval remains pending.
