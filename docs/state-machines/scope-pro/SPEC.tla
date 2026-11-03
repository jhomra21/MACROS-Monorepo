------------------------------ MODULE SPEC ------------------------------
VARIABLES connected, scope, pro, storedFoods
vars == <<connected, scope, pro, storedFoods>>
Init == /\ connected = TRUE /\ scope = "macros" /\ pro = TRUE /\ storedFoods = FALSE
YouShareFoods == /\ connected /\ scope' = "foods"
                 /\ UNCHANGED <<connected, pro, storedFoods>>
YouShareMacros == /\ connected /\ scope' = "macros" /\ storedFoods' = FALSE
                  /\ UNCHANGED <<connected, pro>>
YouStopSharing == /\ scope' = "off" /\ storedFoods' = FALSE
                  /\ UNCHANGED <<connected, pro>>
YouRemovePerson == /\ connected' = FALSE /\ scope' = "off" /\ storedFoods' = FALSE
                   /\ UNCHANGED pro
ProExpires == /\ pro /\ pro' = FALSE /\ UNCHANGED <<connected, scope, storedFoods>>
ProRenews == /\ ~pro /\ pro' = TRUE /\ UNCHANGED <<connected, scope, storedFoods>>
UploadFoods == /\ connected /\ scope = "foods" /\ pro /\ storedFoods' = TRUE
               /\ UNCHANGED <<connected, scope, pro>>
UploadWhileIneligible == /\ ~(connected /\ scope = "foods" /\ pro)
                         /\ storedFoods' = FALSE /\ UNCHANGED <<connected, scope, pro>>
Settled == /\ UNCHANGED vars
Next == YouShareFoods \/ YouShareMacros \/ YouStopSharing \/ YouRemovePerson
        \/ ProExpires \/ ProRenews \/ UploadFoods \/ UploadWhileIneligible \/ Settled
VisibleFoods == connected /\ scope = "foods" /\ pro /\ storedFoods
\* Nothing private may be shown once the connection is removed or sharing is off.
NoUnauthorizedRead == VisibleFoods => (connected /\ scope = "foods" /\ pro)
\* Diagnostic rule: food bytes disappear immediately when neither person has Pro.
ImmediatePurgeOnPause == pro \/ ~storedFoods
TypeOK == /\ connected \in BOOLEAN /\ scope \in {"off", "macros", "foods"}
          /\ pro \in BOOLEAN /\ storedFoods \in BOOLEAN
=============================================================================
