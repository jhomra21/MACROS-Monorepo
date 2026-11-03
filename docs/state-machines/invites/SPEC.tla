------------------------------ MODULE SPEC ------------------------------
VARIABLES age, oldStatus, newStatus, cached, phase
vars == <<age, oldStatus, newStatus, cached, phase>>
Init == /\ age = "fresh" /\ oldStatus = "pending" /\ newStatus = "absent"
        /\ cached = "old" /\ phase = "idle"
TimePasses == /\ age = "fresh" /\ age' = "lastHour"
              /\ UNCHANGED <<oldStatus, newStatus, cached, phase>>
YouCreate == /\ phase = "idle" /\ newStatus = "absent"
             /\ phase' = IF age = "fresh" THEN "reused" ELSE "creating"
             /\ UNCHANGED <<age, oldStatus, newStatus, cached>>
ServerReplaces == /\ phase = "creating"
                  /\ oldStatus' = "revoked" /\ newStatus' = "pending" /\ phase' = "reply"
                  /\ UNCHANGED <<age, cached>>
ReplyArrives == /\ phase = "reply" /\ cached' = "new" /\ phase' = "finished"
                /\ UNCHANGED <<age, oldStatus, newStatus>>
ReplyLost == /\ phase = "reply" /\ phase' = "lost"
             /\ UNCHANGED <<age, oldStatus, newStatus, cached>>
YouAcceptOld == /\ phase \in {"idle", "reused", "finished", "lost"}
                /\ phase' = IF oldStatus = "pending" THEN "connected" ELSE "unavailable"
                /\ UNCHANGED <<age, oldStatus, newStatus, cached>>
Settled == /\ phase \in {"reused", "finished", "lost", "connected", "unavailable"}
           /\ UNCHANGED vars
Next == TimePasses \/ YouCreate \/ ServerReplaces \/ ReplyArrives \/ ReplyLost \/ YouAcceptOld \/ Settled
\* Create Invite keeps the same link until it expires or you revoke it.
KeepValidLink == oldStatus = "pending"
\* A link the app offers as current must not already have been replaced.
CachedLinkIsLive == phase # "lost" \/ cached # "old" \/ oldStatus = "pending"
\* A reusable live link remains pending after acceptance.
AcceptanceDoesNotConsume == phase # "connected" \/ oldStatus = "pending"
TypeOK == /\ age \in {"fresh", "lastHour"} /\ oldStatus \in {"pending", "revoked"}
          /\ newStatus \in {"absent", "pending"} /\ cached \in {"old", "new"}
          /\ phase \in {"idle", "reused", "creating", "reply", "finished", "lost", "connected", "unavailable"}
=============================================================================
