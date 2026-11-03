# SPEC

TLC reached 12 states and 22 steps. The chart draws 9 states and 11 arrows.
The chart does not draw 10 steps that stay in one chart state.

## KeepValidLink breaks
The shortest path has 3 steps:
0. Valid invite, more than one hour left
1. the invite enters its final hour: Valid invite, less than one hour left
2. you choose Create Invite: Requesting a replacement
3. the server replaces the previous link: Old link revoked, new reply pending

## CachedLinkIsLive breaks
The shortest path has 4 steps:
0. Valid invite, more than one hour left
1. the invite enters its final hour: Valid invite, less than one hour left
2. you choose Create Invite: Requesting a replacement
3. the server replaces the previous link: Old link revoked, new reply pending
4. the new-link reply is lost: App still offers revoked old link

## Rules that hold
TypeOK, AcceptanceDoesNotConsume, NoDeadlock

## Interpretation and source replay

**Confirmed source conflict F4. KeepValidLink breaks at step 3; CachedLinkIsLive breaks at step 4.**

Reachable / representable control states: **12 / 128**. Products and count conventions are in the [inventory](../README.md#counting-rules).

[F4 source replay](../FINDINGS.md#f4-a-valid-invite-is-replaced-early-and-a-lost-reply-leaves-the-revoked-link-cached) explains final-hour replacement and lost reply. Both marks can occur on the cached-old-link state; the shortest paths identify which rule first breaks.

### Reader rules

KeepValidLink: Create Invite preserves the existing valid link until expiry or explicit revoke. CachedLinkIsLive: the offered current link is not already replaced. AcceptanceDoesNotConsume: accepting a reusable live link leaves it pending. TypeOK, acceptance and NoDeadlock hold.

### Abstraction and omissions

One owner, one old link, one replacement; time buckets fresh/final hour, both unexpired. No natural expiry, explicit revoke, concurrent create callers, quotas, or token entropy. KeepValidLink is intentionally scoped to this unexpired/no-explicit-revoke execution; do not apply it after adding expiry without its condition. AcceptanceDoesNotConsume encodes the reusable-link contract, not all relationship directions.

The view hides no explicit actions. Statechart omits steps that stay in one chart label; the checked model still contains them. Parallel-region charts display changed regions only. See the generated header above for counts.

### Proposed explicit boundary, not implemented

InviteState: none, valid(link), revoking, creating(operationID), reconciling, failed. Preserve the approved validity contract and reconcile uncertain create outcomes before advertising cached state.

## Chart

![invites statechart](chart.svg)

```mermaid
---
title: "Reusable invite, replacement, and lost reply"
---
stateDiagram-v2
  state "Legend" as legend {
    lg0: replaced
    lg1: live
    lg2: Breaks CachedLinkIsLive or KeepValidLink
    lg3: Path to the CachedLinkIsLive or KeepValidLink bug
  }
  class lg0 orange
  class lg1 teal
  class lg2 breaks
  class lg3 bugPath
  s0: Valid invite, more than one hour left
  s1: Recipient connected, link still reusable
  s2: Same invite returned
  s3: Valid invite, less than one hour left
  s4: Requesting a replacement
  s5: Old link revoked, new reply pending
  s6: New link saved, old recipients blocked
  s7: App still offers revoked old link
  s8: Old recipient cannot connect
  [*] --> s0
  s0 --> s1: someone opens the original link
  s0 --> s2: you choose Create Invite
  s0 --> s3: the invite enters its final hour
  s2 --> s1: someone opens the original link
  s3 --> s1: someone opens the original link
  s3 --> s4: you choose Create Invite
  s4 --> s5: the server replaces the previous link
  s5 --> s6: the new link reaches your phone
  s5 --> s7: the new-link reply is lost
  s6 --> s8: someone opens the original link
  s7 --> s8: someone opens the original link
  classDef breaks fill:#ffecee,stroke:#e72e3b,stroke-width:2.5px,color:#cd2834
  class s0 teal
  class s0 bugPath
  class s1 teal
  class s2 teal
  class s3 teal
  class s3 bugPath
  class s4 teal
  class s4 bugPath
  class s5 orange
  class s5 breaks
  class s5 bugPath
  class s6 orange
  class s6 breaks
  class s7 orange
  class s7 breaks
  class s7 bugPath
  class s8 orange
  class s8 breaks
```

[Exact regeneration](RUN.md). All failures above are model results; only the separately replayed source conflicts are classified as confirmed defects. Owner approval remains pending.
