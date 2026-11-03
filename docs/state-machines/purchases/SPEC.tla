------------------------------ MODULE SPEC ------------------------------
VARIABLES purchasing, restoring, refresh, pro, submission, backend
vars == <<purchasing, restoring, refresh, pro, submission, backend>>
Init == /\ purchasing = FALSE /\ restoring = FALSE /\ refresh = "idle"
        /\ pro = FALSE /\ submission = "none" /\ backend = FALSE
YouBuy == /\ ~purchasing /\ ~restoring /\ purchasing' = TRUE
          /\ UNCHANGED <<restoring, refresh, pro, submission, backend>>
YouRestore == /\ ~purchasing /\ ~restoring /\ restoring' = TRUE
              /\ UNCHANGED <<purchasing, refresh, pro, submission, backend>>
OperationSettles == /\ purchasing \/ restoring
                    /\ purchasing' = FALSE /\ restoring' = FALSE
                    /\ UNCHANGED <<refresh, pro, submission, backend>>
RequestRefresh == /\ refresh = "idle" /\ refresh' = "reading"
                  /\ UNCHANGED <<purchasing, restoring, pro, submission, backend>>
NewRefreshWhileReading == /\ refresh = "reading" /\ refresh' = "dirty"
                          /\ UNCHANGED <<purchasing, restoring, pro, submission, backend>>
DiscardOutdatedRead == /\ refresh = "dirty" /\ refresh' = "reading"
                      /\ UNCHANGED <<purchasing, restoring, pro, submission, backend>>
CommitVerifiedFacts == /\ refresh = "reading" /\ refresh' = "idle" /\ pro' = TRUE
                       /\ UNCHANGED <<purchasing, restoring, submission, backend>>
CommitNoEntitlement == /\ refresh = "reading" /\ refresh' = "idle" /\ pro' = FALSE
                       /\ UNCHANGED <<purchasing, restoring, submission, backend>>
CancelRefresh == /\ refresh # "idle" /\ refresh' = "idle"
                 /\ UNCHANGED <<purchasing, restoring, pro, submission, backend>>
SubmitVerifiedPurchase == /\ pro /\ submission = "none" /\ submission' = "inFlight"
                          /\ UNCHANGED <<purchasing, restoring, refresh, pro, backend>>
SubmissionFails == /\ submission = "inFlight" /\ submission' = "none"
                   /\ UNCHANGED <<purchasing, restoring, refresh, pro, backend>>
ServerAcceptsPurchase == /\ submission = "inFlight" /\ submission' = "accepted" /\ backend' = TRUE
                        /\ UNCHANGED <<purchasing, restoring, refresh, pro>>
AppleRevokesRemotely == /\ backend /\ backend' = FALSE
                       /\ UNCHANGED <<purchasing, restoring, refresh, pro, submission>>
Settled == /\ UNCHANGED vars
Next == YouBuy \/ YouRestore \/ OperationSettles \/ RequestRefresh \/ NewRefreshWhileReading
        \/ DiscardOutdatedRead \/ CommitVerifiedFacts \/ CommitNoEntitlement \/ CancelRefresh
        \/ SubmitVerifiedPurchase \/ SubmissionFails \/ ServerAcceptsPurchase \/ AppleRevokesRemotely \/ Settled
\* Buying and restoring must not run at the same time.
OnePurchaseOperation == ~(purchasing /\ restoring)
\* Deliberately overstrong diagnostic: local and cloud access always agree.
LocalEqualsCloud == pro = backend
TypeOK == /\ purchasing \in BOOLEAN /\ restoring \in BOOLEAN
          /\ refresh \in {"idle", "reading", "dirty"} /\ pro \in BOOLEAN
          /\ submission \in {"none", "inFlight", "accepted"} /\ backend \in BOOLEAN
=============================================================================
