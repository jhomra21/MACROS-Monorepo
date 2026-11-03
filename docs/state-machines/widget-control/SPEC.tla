------------------------------ MODULE SPEC ------------------------------
EXTENDS Integers
VARIABLES legacy, shared, verified, generation, requestGeneration, enabled, pro, request, cachedGeneration, selected
vars == <<legacy, shared, verified, generation, requestGeneration, enabled, pro, request, cachedGeneration, selected>>
Init == /\ legacy = TRUE /\ shared = FALSE /\ verified = FALSE
        /\ generation = 0 /\ requestGeneration = 0 /\ enabled = TRUE /\ pro = TRUE
        /\ request = "idle" /\ cachedGeneration = -1 /\ selected = FALSE
CopyCredential == /\ legacy /\ ~shared /\ shared' = TRUE
                  /\ UNCHANGED <<legacy, verified, generation, requestGeneration, enabled, pro, request, cachedGeneration, selected>>
VerifyCopy == /\ shared /\ verified' = TRUE
              /\ UNCHANGED <<legacy, shared, generation, requestGeneration, enabled, pro, request, cachedGeneration, selected>>
DeleteLegacy == /\ verified /\ legacy' = FALSE
                /\ UNCHANGED <<shared, verified, generation, requestGeneration, enabled, pro, request, cachedGeneration, selected>>
WidgetStarts == /\ shared /\ enabled /\ pro /\ request = "idle"
                /\ request' = "loading" /\ requestGeneration' = generation
                /\ UNCHANGED <<legacy, shared, verified, generation, enabled, pro, cachedGeneration, selected>>
AppDisables == /\ enabled /\ generation = 0 /\ enabled' = FALSE /\ generation' = 1 /\ selected' = FALSE
               /\ UNCHANGED <<legacy, shared, verified, requestGeneration, pro, request, cachedGeneration>>
AppDeniesPro == /\ pro /\ generation = 0 /\ pro' = FALSE /\ generation' = 1 /\ selected' = FALSE
                /\ UNCHANGED <<legacy, shared, verified, requestGeneration, enabled, request, cachedGeneration>>
\* Model the two separate current-control checks with a disk write between.
CheckResponse == /\ request = "loading"
                 /\ request' = IF enabled /\ pro /\ requestGeneration = generation THEN "checked" ELSE "idle"
                 /\ UNCHANGED <<legacy, shared, verified, generation, requestGeneration, enabled, pro, cachedGeneration, selected>>
WriteCache == /\ request = "checked" /\ request' = "written"
              /\ cachedGeneration' = requestGeneration
              /\ UNCHANGED <<legacy, shared, verified, generation, requestGeneration, enabled, pro, selected>>
CheckBeforeReturn == /\ request = "written" /\ request' = "idle"
                     /\ selected' = (enabled /\ pro /\ requestGeneration = generation)
                     /\ UNCHANGED <<legacy, shared, verified, generation, requestGeneration, enabled, pro, cachedGeneration>>
ReadCache == /\ selected' = (enabled /\ pro /\ cachedGeneration = generation)
             /\ UNCHANGED <<legacy, shared, verified, generation, requestGeneration, enabled, pro, request, cachedGeneration>>
Settled == /\ UNCHANGED vars
Next == CopyCredential \/ VerifyCopy \/ DeleteLegacy \/ WidgetStarts \/ AppDisables
        \/ AppDeniesPro \/ CheckResponse \/ WriteCache \/ CheckBeforeReturn \/ ReadCache \/ Settled
\* Credential migration must never remove the only verified identity.
PreserveIdentity == legacy \/ (shared /\ verified)
\* Logical eligibility at modeled control checkpoints, NOT physical WidgetKit redraw.
\* Invalidation revokes selection logically; retained timeline entries are outside this model.
OnlyCurrentDataSelected == selected => (enabled /\ pro /\ cachedGeneration = generation)
\* Overstrong diagnostic: no old-generation file may ever exist.
NoObsoleteFiles == cachedGeneration = -1 \/ cachedGeneration = generation
TypeOK == /\ legacy \in BOOLEAN /\ shared \in BOOLEAN /\ verified \in BOOLEAN
          /\ generation \in {0, 1} /\ requestGeneration \in {0, 1}
          /\ enabled \in BOOLEAN /\ pro \in BOOLEAN /\ request \in {"idle", "loading", "checked", "written"}
          /\ cachedGeneration \in {-1, 0, 1} /\ selected \in BOOLEAN
=============================================================================
