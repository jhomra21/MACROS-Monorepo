# 05. Two invite creators

**Verdict: CONFIRMED against the dev backend, with a temporary response-delay hook. Severity: medium.**

## Repeatable event order

1. Use two fresh dev identities, Owner and Peer, as described in the [run notes](../README.md#repeating-the-investigation). Attach Owner to the isolated Debug app through the private identity override. Do not reuse an existing device identity.
2. Enable Sharing. Set `suspect-invite-delay` to `60`, then open Create Invite and tap **Create Invite Link**.
3. Caller 1 commits remotely, then pauses before saving its result. While it is paused, open `calmacrotracker://sharing` to replace the navigation stack, open a second Create Invite screen, and tap **Create Invite Link** again.
4. Caller 2 passes the still-empty local cache check, creates another invite, and saves it. Let caller 1 resume and save last.
5. Reopen Sharing. Compare the displayed cached link with private hashes of the two created tokens, without printing either. From Peer, attempt acceptance of each hash against dev.

## Observed result and artifacts

[Trace](live-repro.log):

```text
1793704025.352... call 1
1793704025.957... committed 1, then paused
1793704029.901... call 2
1793704030.299... committed 2
1793704030.323... saved 2
1793704089.044... saved 1
```

[Backend check](backend-check.log): call 1 rejected as revoked/unavailable; call 2 accepted. [Displayed-cache check](cached-link-check.log): the displayed link matched call 1. Thus the app actually offered the revoked link, not just an abstract out-of-order result.

No real token, token hash, invite URL, profile secret, or JWT appears in committed evidence. No invite-screen screenshot was retained. [Both test profiles were deleted](../backend-cleanup.log).

## Source, impact, and minimal proposed fix

Baseline `cal-macro-tracker/Features/Sharing/SharingSyncService.swift:366–380` has no service-wide in-flight creator. `convex-backend/convex/sharing.ts:69–84` revokes previous pending invites when creating a new one. Both replies pass the same identity-generation check; that check does not order operations for the same identity.

Users can share a dead invitation that looks current. Share one in-flight creation task across all callers in the service, covering cache check through remote result and local persistence. Ensure only that owned operation may publish/save, and reconcile uncertain remote results. A screen-local busy flag is insufficient. Preserve reusable-link behavior; this is not a request to make links one-shot.

## Exact temporary hook

A DEBUG ordinal was incremented per service call. Immediately after `accountActions.createInvite` returned, ordinal 1 awaited `SuspectProbe.pause("invite-delay")`; both calls logged commit/save order. SHA-256 hashes were written only to private simulator `tmp` files for the acceptance check. The helper hashed the displayed token privately and emitted only its call ordinal. [Full hook patch](../temporary-hooks.patch.txt). Hooks, local token, override, hashes, and fresh credentials were removed.
