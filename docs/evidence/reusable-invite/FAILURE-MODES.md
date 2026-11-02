# Reusable invite failure modes (before implementation)

- A second person cannot accept the same live link.
- The same person accepting twice inserts duplicate relationships or grants.
- Reaccepting after removal fails to revive the existing relationship cleanly.
- Expired or revoked links still authorize, including after a previous acceptance.
- A deleted or missing owner's link still authorizes.
- An old consumed (`accepted`) invite becomes reusable, including with a pending duplicate.
- Duplicate live hashes or foreign-owner history authorize ambiguously.
- Creating again revokes a link already sent instead of returning the same local link.
- A cached link is reused after expiry, near expiry, revocation, or an identity change.
- Deleting an acceptor deletes the owner's reusable link.

Coverage: registered Convex integration tests inspect invite/relationship/grant rows;
the HTTP smoke uses disposable A/B/C profiles, checks two acceptors and replay,
revocation/replacement and deleted-owner rejection, and cleans up in `finally`.
Clock-controlled expiry and legacy/corrupt rows remain integration-only because
public HTTP clients cannot forge database rows or advance the server clock.
App reliability coverage is written before app changes; live simulator screenshots
will verify repeated Create Invite returns the same URL without erasing A.
