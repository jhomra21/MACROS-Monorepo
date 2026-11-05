# Final defensive-code review

- Scope: d53a313 → final inline editor, shared extraction, Form/quantity defaults, reducer recovery and scanner lifecycle.
- Model-risk reason: final GPT implementation pass, after normal validators, checking for duplicated validation, dead extracted state and impossible-state guards. No subagents per owner instruction.
- Context: AGENTS.md, docs/development/swift.md, docs/history/reference/software-patterns.md, changes-log, changed files, FoodDraftLoggingAction, numeric finalization, FoodQuantityState and repository logging boundary.

## Candidates

1. **Remove:** LogFoodScreen stored initialDraft/reviewNotes/requiredReviewNutrients/previewImageData and assignments. After extraction, every use was inside the editor initialization; all rendering reads editor. The initializer signature stays unchanged. Eight dead lines removed.
2. **Keep:** editor.canSave before camera Log and repository validation. The UI review gate includes intentional-zero confirmations absent from repository validation, so it is not redundant. Repository validation remains an independent persistence boundary.
3. **Keep:** scanner onReady suspension guard. Representable readiness is asynchronous and may arrive after expansion; stop and reject stale controller ownership.
4. **Keep:** optional editor-binding fallback captured during structural removal. SwiftUI may retain a binding callback through its transition; no force unwrap added.
5. **Keep:** native dismissal modifier plus dirty interactive blocking. Actual zoom-cover E2E proved the native API alone loses edits; documented OS behavior, not speculative defense.
6. **Keep unchanged:** pre-existing reducer dismissed guards and quantity validation. They predate this scope and enforce public input boundaries. No unrelated cleanup.
7. **Keep, final focus follow-up:** direct focus and requested-field appearance handling cover different reachable states. E2E proved immediate focus alone fails for an offscreen Protein row; the final Next → Protein / Previous → Calories captures verify both paths. The appearance guard routes one request to one row and clears it, without a timer, retry task or UIKit responder layer.

## Validation

After removal and again after the final focus follow-up: full serial non-StoreKit iPad suite, 242 tests, zero failures; quality-format-check, quality-build and lint-js passed. All 960 layout measurements still match base/extraction byte-for-byte. Fixture patch applies to clean source and is absent from the application. The repeatable core E2E and final non-camera replay passed. Four final E12 raw tree comparisons are unavailable across driver backend schemas; four screenshot pairs remain pixel-identical.

## Final review

Final follow-up reloaded the skill and reviewed the actual diff, shared focus toolbar/Form sections, editor state, reducer, logging action and repository boundary. No further high-confidence redundant-defense findings or cleanup changes. No parallel nutrition/persistence implementation, custom presentation gesture, production polling timer, or dead camera destination remains. Offscreen Next is verified, not deferred. Hardware checks, limited VoiceOver traversal, unavailable iOS 26/narrow-device testing, cross-backend tree comparisons and the E12 native-glass pixel mismatch remain explicit in README.md.
