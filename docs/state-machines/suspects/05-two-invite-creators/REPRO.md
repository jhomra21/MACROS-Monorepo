# 05. Two invite creators

**Verdict: BLOCKED (live).** Dev sharing smoke did not run because this worktree had no verified `energized-pigeon-822` configuration. No app change or temporary hook.

## Trigger order and expected user impact

1. A single sharing identity starts `createInvite` twice through two callers before either stores a pending invite.
2. Both callers pass the local pending-invite check and authenticate.
3. Both submit distinct invite hashes; the server's second mutation revokes pending links from the first.
4. Responses arrive in reverse order; the first response is saved last in local storage.

If real, the UI can offer a locally cached link that the second server mutation already revoked.

## Evidence and live attempt

- `cal-macro-tracker/Features/Sharing/SharingSyncService.swift:366–380` has no service-wide in-flight creator guard around the pending check, remote create, and local save.
- A clean Debug app was launched. I attempted to verify the smoke script environment without revealing it; the check failed, so I did not run any backend mutations or create test identities. `live-attempt.log` has no credentials.
- No simulator UI driver was available to invoke two app callers. Reproduce with two concurrent callers against dev using fresh profiles, then delete them through the smoke cleanup path.
