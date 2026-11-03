------------------------------ MODULE SPEC ------------------------------
VARIABLES roster, originalSnapshot, cached, visibility, task, attempt, wire
vars == <<roster, originalSnapshot, cached, visibility, task, attempt, wire>>
Init == /\ roster = "visible" /\ originalSnapshot = TRUE /\ cached = FALSE
        /\ visibility = "unknown" /\ task = "current" /\ attempt = 0 /\ wire = "none"
LiveDayArrives == /\ task = "current" /\ roster = "visible"
                  /\ cached' = TRUE /\ visibility' = "shared" /\ wire' = "none"
                  /\ UNCHANGED <<roster, originalSnapshot, task, attempt>>
OtherRemovesYou == /\ roster = "visible" /\ roster' = "removed"
                   /\ cached' = FALSE /\ visibility' = "unknown"
                   /\ UNCHANGED <<originalSnapshot, task, attempt, wire>>
OtherStopsSharing == /\ roster = "visible" /\ roster' = "notShared"
                     /\ cached' = FALSE /\ visibility' = "unknown"
                     /\ UNCHANGED <<originalSnapshot, task, attempt, wire>>
PermissionReply == /\ roster = "notShared" /\ visibility' = "notShared"
                   /\ UNCHANGED <<roster, originalSnapshot, cached, task, attempt, wire>>
QueryFails == /\ roster = "removed" /\ task' = "failed"
              /\ UNCHANGED <<roster, originalSnapshot, cached, visibility, attempt, wire>>
ChangeDay == /\ attempt = 0 /\ attempt' = 1 /\ cached' = FALSE
             /\ task' = "current" /\ visibility' = "unknown" /\ wire' = "old"
             /\ UNCHANGED <<roster, originalSnapshot>>
\* A canceled stream's value cannot reach cachePersonDay.
OldReplyIgnored == /\ wire = "old" /\ wire' = "none"
                   /\ UNCHANGED <<roster, originalSnapshot, cached, visibility, task, attempt>>
Settled == /\ UNCHANGED vars
Next == LiveDayArrives \/ OtherRemovesYou \/ OtherStopsSharing \/ PermissionReply
        \/ QueryFails \/ ChangeDay \/ OldReplyIgnored \/ Settled
\* Mirrors currentPerson's fallback to the screen's original person.
Rendered == visibility # "notShared" /\ roster # "notShared" /\ (cached \/ originalSnapshot)
\* Once removal reaches this device, that person's macros must disappear.
RemovedMeansHidden == roster # "removed" \/ ~Rendered
\* Explicit not-shared replies must not retain a visible snapshot.
NotSharedMeansHidden == visibility # "notShared" \/ ~Rendered
TypeOK == /\ roster \in {"visible", "removed", "notShared"} /\ originalSnapshot \in BOOLEAN
          /\ cached \in BOOLEAN /\ visibility \in {"unknown", "shared", "notShared"}
          /\ task \in {"current", "failed"} /\ attempt \in {0, 1} /\ wire \in {"none", "old"}
=============================================================================
