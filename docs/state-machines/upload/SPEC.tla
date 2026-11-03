------------------------------ MODULE SPEC ------------------------------
EXTENDS Naturals
VARIABLES enabled, generation, attemptGeneration, phase, local, sent, remote, acknowledged, dirty
vars == <<enabled, generation, attemptGeneration, phase, local, sent, remote, acknowledged, dirty>>
Init == /\ enabled = TRUE /\ generation = 0 /\ attemptGeneration = 0 /\ phase = "idle"
        /\ local = 0 /\ sent = 0 /\ remote = 0 /\ acknowledged = 0 /\ dirty = FALSE
YouEdit == /\ local < 2 /\ local' = local + 1 /\ dirty' = TRUE
           /\ UNCHANGED <<enabled, generation, attemptGeneration, phase, sent, remote, acknowledged>>
RequestUpload == /\ enabled /\ phase = "idle" /\ dirty
                 /\ phase' = "authenticating" /\ attemptGeneration' = generation
                 /\ UNCHANGED <<enabled, generation, local, sent, remote, acknowledged, dirty>>
AuthenticationFinishes == /\ phase = "authenticating" /\ enabled /\ attemptGeneration = generation
                          /\ phase' = "writing" /\ sent' = local /\ dirty' = FALSE
                          /\ UNCHANGED <<enabled, generation, attemptGeneration, local, remote, acknowledged>>
ServerCommits == /\ phase = "writing" /\ phase' = "acknowledging" /\ remote' = sent
                 /\ UNCHANGED <<enabled, generation, attemptGeneration, local, sent, acknowledged, dirty>>
ReplyArrives == /\ phase = "acknowledging"
                /\ acknowledged' = IF enabled /\ attemptGeneration = generation THEN sent ELSE acknowledged
                /\ dirty' = IF enabled /\ attemptGeneration = generation THEN local # sent ELSE dirty
                /\ phase' = "idle"
                /\ UNCHANGED <<enabled, generation, attemptGeneration, local, sent, remote>>
YouDisable == /\ enabled /\ generation = 0 /\ enabled' = FALSE /\ generation' = 1
              /\ acknowledged' = 0 /\ dirty' = FALSE
              /\ UNCHANGED <<attemptGeneration, phase, local, sent, remote>>
CanceledAuthSettles == /\ phase = "authenticating" /\ ~enabled /\ phase' = "idle"
                       /\ UNCHANGED <<enabled, generation, attemptGeneration, local, sent, remote, acknowledged, dirty>>
WriteFails == /\ phase = "writing" /\ phase' = "failed"
              /\ UNCHANGED <<enabled, generation, attemptGeneration, local, sent, remote, acknowledged, dirty>>
YouRetry == /\ phase = "failed" /\ enabled /\ phase' = "idle" /\ dirty' = TRUE
            /\ UNCHANGED <<enabled, generation, attemptGeneration, local, sent, remote, acknowledged>>
Settled == /\ UNCHANGED vars
Next == YouEdit \/ RequestUpload \/ AuthenticationFinishes \/ ServerCommits \/ ReplyArrives
        \/ YouDisable \/ CanceledAuthSettles \/ WriteFails \/ YouRetry \/ Settled
\* Disabled or replaced identities may not acknowledge an old upload.
NoStaleAcknowledgment == enabled \/ acknowledged = 0
\* A settled successful drain must not silently lose an edit.
NoLostEdit == ~(enabled /\ phase = "idle" /\ ~dirty /\ local # acknowledged)
TypeOK == /\ enabled \in BOOLEAN /\ generation \in {0, 1} /\ attemptGeneration \in {0, 1}
          /\ phase \in {"idle", "authenticating", "writing", "acknowledging", "failed"}
          /\ local \in {0, 1, 2} /\ sent \in {0, 1, 2} /\ remote \in {0, 1, 2}
          /\ acknowledged \in {0, 1, 2} /\ dirty \in BOOLEAN
=============================================================================
