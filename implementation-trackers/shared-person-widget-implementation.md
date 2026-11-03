# Shared-person widget implementation

Base: `8ebd989`, build 28. Branch: `feat/shared-person-widget`.
Source of truth: the copied plan and review; review changes 1–11 govern.
Release stays blocked until 1.0 approval and the production cutover.

## Progress

- [x] First commit preserves both source documents.
- [x] Failure inventory and acceptance tests predate production code.
- [x] Red dev HTTP smoke and registered integration run captured.
- [x] Optional `personDay.includeFoods`; no new query, schema, helper, or error codes.
- [x] Dev-only deployment after check/integration; final insights record two predeployment OCC retry warnings.
- [x] Keychain add-only scope, launch migration, private invites/JWTs, shared configuration.
- [x] Single atomic protected app-written control; generation-bound today-only cache.
- [x] Sharing default setting, Pro context, disclosure, privacy-label goals.
- [x] Nonisolated/Sendable intent and DTOs, HTTP provider, midnight blank entry.
- [x] Five families reuse existing layouts; own-day remains URL-free.
- [x] One person deep link resolves the live dashboard before opening the screen.
- [x] Format check, quality build, JavaScript lint.
- [x] Final full serial iPad suite: 232 passed, StoreKit class explicitly excluded; iPad shut down.
- [x] Paired live E2E, build-28 in-place upgrade, five installed families, picker, default isolation, and person links.
- [x] Natural extension refresh observed; A and B restored and verified on the unchanged slim profile, then shut down.
- [x] Final suite includes token freshness; defensive review and requirements 1–11 self-review complete (`REVIEW.md`); no proven redundant code found.
- [ ] Evidence copied and pushed to the designated documentation branch.

## Evidence and constraints

See `docs/evidence/shared-person-widget-e2e/README.md`.
Backend check: 20 tests; registered integration: 76 tests. Final reruns passed.
The live smoke includes a passing bad-signature JWT HTTP 401 assertion and succeeds
for available cases; a genuinely signed expired JWT fixture is not available.
Prewritten iPad tests verify Keychain group migration/idempotence, private invites,
legacy update/delete behavior, and spring/fall DST midnight/refresh math.
The added expiry-policy case was committed before policy extraction, per owner
approval; its final iPad run passed, along with the three earlier widget tests.

Two slim-disabled dependencies were temporarily enabled only on A with owner
approval: com.apple.linkd for intent indexing and com.apple.siriactionsd for
VoiceShortcuts-backed intent execution. No other service or profile file changed.
The first experiment and final post-capture restore were verified. The natural
refresh was observed at 30m 19s after app force-quit; the widget's Updated label
advanced but the backend nutrition remained 650 kcal, P40/C80/F20. B needed no
service change. Both simulators are shut down.

The actual intent file passes strict Swift 6 warnings-as-errors typechecking
with MainActor defaults and off-main synchronous use. It uses Sendable inference
plus explicit nonisolated synchronous members instead of type-level nonisolated
on the SDK's reference-backed @Parameter storage. No unsafe annotation/suppression.

Simulator app/extension code signatures have empty entitlement dictionaries
(simulator signing), so they cannot prove distribution provisioning or hardware
first-unlock protection. Those checks remain release gates.

Owner clarified the budget is four booted devices. The iPad may be shut down
between tests after checking active xcodebuild processes. The media Pro Max must
not be touched; paired A/B E2E waits for that job to shut it down. Air stays on.
