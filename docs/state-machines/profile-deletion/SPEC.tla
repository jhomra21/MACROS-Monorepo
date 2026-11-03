------------------------------ MODULE SPEC ------------------------------
VARIABLES server, local, identity, phase
vars == <<server, local, identity, phase>>
Init == /\ server = "live" /\ local = "enabled"
        /\ identity = "present" /\ phase = "idle"
YouDelete == /\ phase = "idle"
             /\ phase' = IF server = "live" THEN "deleting" ELSE "blocked"
             /\ UNCHANGED <<server, local, identity>>
ServerDeletes == /\ phase = "deleting" /\ server = "live"
                 /\ server' = "deleted" /\ phase' = "acknowledgment"
                 /\ UNCHANGED <<local, identity>>
ReplyArrives == /\ phase = "acknowledgment"
                /\ local' = "cleanup" /\ phase' = "cleaning"
                /\ UNCHANGED <<server, identity>>
ReplyIsLost == /\ phase = "acknowledgment" /\ phase' = "idle"
               /\ UNCHANGED <<server, local, identity>>
CleanupFails == /\ phase = "cleaning" /\ phase' = "retryCleanup"
                /\ UNCHANGED <<server, local, identity>>
YouRetryCleanup == /\ phase = "retryCleanup" /\ phase' = "cleaning"
                   /\ UNCHANGED <<server, local, identity>>
CleanupFinishes == /\ phase = "cleaning" /\ phase' = "done"
                   /\ local' = "off" /\ identity' = "absent"
                   /\ UNCHANGED server
Settled == /\ phase \in {"done", "blocked"} /\ UNCHANGED vars
Next == YouDelete \/ ServerDeletes \/ ReplyArrives \/ ReplyIsLost
        \/ CleanupFails \/ YouRetryCleanup \/ CleanupFinishes \/ Settled
\* Retry Delete must still be able to finish local credential cleanup.
DeletionRecoverable == ~(phase = "blocked" /\ server = "deleted" /\ identity = "present")
\* A cleanup marker must only follow the remote deletion acknowledgment.
MarkerFollowsRemoteDeletion == local # "cleanup" \/ server = "deleted"
TypeOK == /\ server \in {"live", "deleted"} /\ local \in {"enabled", "cleanup", "off"}
          /\ identity \in {"present", "absent"}
          /\ phase \in {"idle", "deleting", "acknowledgment", "cleaning", "retryCleanup", "done", "blocked"}
=============================================================================
