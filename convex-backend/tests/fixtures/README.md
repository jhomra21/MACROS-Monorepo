# Apple verification fixture

The signed rejection fixture is created in memory in `appleVerifier.test.ts`.
It uses an ephemeral P-256 key and a genuine ES256 signature, which the test
independently verifies before asserting that Apple's verifier rejects it for
lacking an Apple certificate chain. No private key or static JWS is committed.

The original Apple-published test JWS was removed with owner authorization after
Droid-Shield flagged it. This replacement proves rejection of a self-issued
signed token; it does not replace a successful Apple-chain fixture test.

The routing tests inject the `SignedDataVerifier` interface. Integration tests
replace only the `AppleVerifier` methods, leaving registered Convex actions,
authentication, purchase policy, mutations, and HTTP handlers intact.

A real device Sandbox purchase is still required to prove successful Apple-chain
verification in the dev deployment. These fixtures do not provide that evidence.
