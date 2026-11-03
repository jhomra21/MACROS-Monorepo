# SPEC

TLC reached 72 states and 399 steps. The chart draws 10 states and 17 arrows.
The chart does not draw 99 steps that stay in one chart state.
The step current purchases contain no entitlement changes Access and Refresh at the same time.
The step verified current purchases grant local Pro changes Access and Refresh at the same time.

## LocalEqualsCloud breaks
The shortest path has 2 steps:
0. Access No Pro, Store No purchase operation, Refresh Entitlements settled
1. the app requests current entitlements: Access No Pro, Store No purchase operation, Refresh Reading verified entitlements
2. verified current purchases grant local Pro: Access Local Pro, cloud not yet active, Store No purchase operation, Refresh Entitlements settled

## Rules that hold
TypeOK, OnePurchaseOperation, NoDeadlock

## Interpretation and source replay

**LocalEqualsCloud breaks at step 2 and is dismissed as an invalid instantaneous-equality rule. No confirmed payment bug.**

Reachable / representable control states: **72 / 144**. Products and count conventions are in the [inventory](../README.md#counting-rules).

[Dismissed equality diagnostic](../FINDINGS.md#dismissed-model-only-failures-and-prevented-paths): verified StoreKit facts unlock local Pro before optional sharing-backend submission. Local and cloud authority intentionally converge asynchronously and can differ offline.

### Reader rules

OnePurchaseOperation: buy and restore cannot overlap. LocalEqualsCloud is retained as a deliberately rejected diagnostic, not weakened to pass. TypeOK, OnePurchaseOperation and NoDeadlock hold.

### Abstraction and omissions

One Boolean local fact and one Boolean backend fact, one abstract transaction/submission, refresh idle/reading/dirty. No product catalog/pending-purchase UI, transaction chronology, grace-period dates, family sharing, five-profile link cap, duplicate JWS handling, or full notification verification. Backend revocation is independent of local refresh. No eventual-consistency liveness theorem.

The view hides no explicit actions. Statechart omits steps that stay in one chart label; the checked model still contains them. Parallel-region charts display changed regions only. See the generated header above for counts.

### Proposed explicit boundary, not implemented

Independent PurchaseOperation, EntitlementRefresh and SubmissionState regions. Derive VerifiedEntitlements from StoreKit facts; keep cloud coverage and persisted widget access separate rather than constructing a single paid/unpaid enum.

## Chart

![purchases statechart](chart.svg)

```mermaid
---
title: "Local StoreKit access and cloud purchase submission"
---
stateDiagram-v2
  direction LR
  state "Legend" as legend {
    lg0: Breaks LocalEqualsCloud
    lg1: Path to the LocalEqualsCloud bug
  }
  class lg0 breaks
  class lg1 bugPath
  state "At the same time" as all {
    state "Access" as r0 {
      s0: No Pro
      s1: Local Pro, cloud not yet active
      s2: Local and cloud Pro
      s3: Cloud Pro, local refresh pending
      [*] --> s0
      s0 --> s1: verified current purchases grant local Pro [when Refresh is Reading verified entitlements]
      s1 --> s2: Apple verification grants cloud Pro
      s1 --> s0: current purchases contain no entitlement [when Refresh is Reading verified entitlements]
      s2 --> s1: an Apple notification removes cloud access
      s0 --> s3: Apple verification grants cloud Pro
      s2 --> s3: current purchases contain no entitlement [when Refresh is Reading verified entitlements]
      s3 --> s0: an Apple notification removes cloud access
      s3 --> s2: verified current purchases grant local Pro [when Refresh is Reading verified entitlements]
    }
    --
    state "Store" as r1 {
      s4: No purchase operation
      s5: Restoring
      s6: Buying
      [*] --> s4
      s4 --> s5: you restore
      s4 --> s6: you buy
      s5 --> s4: the StoreKit operation finishes
      s6 --> s4: the StoreKit operation finishes
    }
    --
    state "Refresh" as r2 {
      s7: Entitlements settled
      s8: Reading verified entitlements
      s9: Read superseded, must reread
      [*] --> s7
      s7 --> s8: the app requests current entitlements
      s8 --> s7: the refresh is canceled without committing or current purchases contain no entitlement or verified current purchases grant local Pro
      s8 --> s9: another entitlement refresh is requested
      s9 --> s7: the refresh is canceled without committing
      s9 --> s8: the outdated read is discarded
    }
  }
  classDef breaks fill:#ffecee,stroke:#e72e3b,stroke-width:2.5px,color:#cd2834
  class s0 bugPath
  class s1 breaks
  class s1 bugPath
  class s3 breaks
  class s4 bugPath
  class s7 bugPath
  class s8 bugPath
```

[Exact regeneration](RUN.md). All failures above are model results; only the separately replayed source conflicts are classified as confirmed defects. Owner approval remains pending.
