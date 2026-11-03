# SPEC

TLC reached 66 states and 167 steps. The chart draws 8 states and 15 arrows.
The chart does not draw 88 steps that stay in one chart state.

## Rules that hold
TypeOK, NoStaleAcknowledgment, NoLostEdit, NoDeadlock

## Interpretation and source replay

**No configured invariant failure. This is bounded support for existing guards, not proof of all upload behavior.**

Reachable / representable control states: **66 / 6,480**. Products and count conventions are in the [inventory](../README.md#counting-rules).

[Prevented paths](../FINDINGS.md#dismissed-model-only-failures-and-prevented-paths): SharingSyncService.swift:134–210 coalesces requests, re-reads after authentication and fences completion by identity/attempt. Remote commit can still precede local cancellation; that is explicitly allowed.

### Reader rules

NoStaleAcknowledgment: disabling prevents an old local success acknowledgment. NoLostEdit: a successful settled enabled drain cannot have an unacknowledged edit without dirty work. TypeOK and NoDeadlock also hold.

### Abstraction and omissions

Two edits (revision 0→1→2), including an edit while a previous revision is in flight, two generations, no re-enable after disable, a single request slot and one abstract failure. Does not model arbitrary sequences of edits, payload hashing collisions, food-payload retention, day changes, process-restored uploading metadata, or backend delivery guarantees. No fairness/eventual-success claim.

The view hides no explicit actions. Statechart omits steps that stay in one chart label; the checked model still contains them. Parallel-region charts display changed regions only. See the generated header above for counts.

### Proposed explicit boundary, not implemented

UploadState(attemptID, identityGeneration, requestedRevision, sentRevision, phase) with pure request/edit/settle transitions. Keep remote side effects outside the reducer and preserve the distinction between committed cloud writes and local acknowledgment.

## Chart

![upload statechart](chart.svg)

```mermaid
---
title: "Upload drain and identity cancellation"
---
stateDiagram-v2
  state "Legend" as legend {
    lg0: enabled
    lg1: disabled
  }
  class lg0 blue
  class lg1 tan
  s0: Latest changes acknowledged
  s1: Sharing disabled, no acknowledgment
  s2: Changes waiting to upload
  s3: Authenticating, will reread changes
  s4: Writing latest snapshot
  s5: Sharing disabled, old request settling
  s6: Upload failed, explicit retry needed
  s7: Cloud committed, acknowledgment pending
  [*] --> s0
  s0 --> s1: you disable device sharing
  s0 --> s2: you edit local totals
  s2 --> s1: you disable device sharing
  s2 --> s3: the app requests an upload
  s3 --> s4: authentication finishes and totals are reread
  s3 --> s5: you disable device sharing
  s4 --> s6: the write fails
  s4 --> s5: you disable device sharing
  s4 --> s7: the cloud write commits
  s5 --> s1: the canceled authentication settles or the write fails or the reply settles without reviving a disabled identity
  s6 --> s1: you disable device sharing
  s6 --> s2: you request a retry
  s7 --> s0: the reply settles without reviving a disabled identity
  s7 --> s5: you disable device sharing
  s7 --> s2: the reply settles without reviving a disabled identity
  class s0 blue
  class s1 tan
  class s2 blue
  class s3 blue
  class s4 blue
  class s5 tan
  class s6 blue
  class s7 blue
```

[Exact regeneration](RUN.md). All failures above are model results; only the separately replayed source conflicts are classified as confirmed defects. Owner approval remains pending.
