------------------------------ MODULE SPEC ------------------------------
VARIABLES base, wal, phase
vars == <<base, wal, phase>>
\* The legacy source has both artifacts; its WAL contains newer committed rows.
Init == /\ base = FALSE /\ wal = FALSE /\ phase = "launch"
CheckDestination == /\ phase = "launch"
                    /\ phase' = IF base THEN "opened" ELSE "copyBase"
                    /\ UNCHANGED <<base, wal>>
CopyBase == /\ phase = "copyBase" /\ base' = TRUE /\ phase' = "copyWAL"
            /\ UNCHANGED wal
CopyWAL == /\ phase = "copyWAL" /\ wal' = TRUE /\ phase' = "opened"
           /\ UNCHANGED base
CopyFails == /\ phase = "copyWAL" /\ phase' = "failed" /\ UNCHANGED <<base, wal>>
YouRelaunch == /\ phase \in {"failed", "copyWAL"} /\ phase' = "launch"
               /\ UNCHANGED <<base, wal>>
Settled == /\ phase = "opened" /\ UNCHANGED vars
Next == CheckDestination \/ CopyBase \/ CopyWAL \/ CopyFails \/ YouRelaunch \/ Settled
\* An opened migrated store must include all committed legacy data.
CompleteBeforeOpen == phase # "opened" \/ (base /\ wal)
TypeOK == /\ base \in BOOLEAN /\ wal \in BOOLEAN
          /\ phase \in {"launch", "copyBase", "copyWAL", "failed", "opened"}
=============================================================================
