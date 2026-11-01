# Apple Root CA G3

`AppleRootCA-G3.cer` is the DER certificate downloaded from Apple's PKI page:
https://www.apple.com/certificateauthority/

Direct source:
https://www.apple.com/certificateauthority/AppleRootCA-G3.cer

SHA-256:
`63343abfb89a6a03ebb57e9b3f5fa7be7c4f5c756f3017b3a8c488c3653e9179`

`root.ts` embeds those same bytes as base64 because Convex bundles modules, not
arbitrary filesystem assets. A unit test checks the embedded bytes against the DER
file. Only this root is trusted. Apple's test root is never trusted by the app.

The two offline verifiers validate signatures, the certificate chain at Apple's
signed date, bundle ID, and environment. Online certificate revocation checks
are disabled as specified; App Store notifications supply purchase revocations.
