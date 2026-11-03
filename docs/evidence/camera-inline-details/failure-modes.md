# Failure modes, written before D8/D9 code and tests

## D8 dirty edit session
- Opening an editor, including a collapsed-card renamed label, must be clean.
- Editing then reverting a name or nutrient must return to clean.
- Whitespace-only name changes are not meaningful.
- An invalid numeric token must not silently appear clean even when its parsed value equals the baseline.
- Quantity-only edits (servings, grams, mode), reusable-save toggles and confirmed-zero toggles must be dirty; reverting them restores clean.
- The opened draft is the dirty baseline, not the original label draft used for reusable-copy decisions.
- Pruning resolved zero confirmations must preserve unresolved confirmations.

## D9 recovery transition
- Recovery cannot log before opening its draft.
- recoveryDraftOpened must only transition recovering → showingBarcode, with no capture or lookup side effects.
- Scanning, lookup, capture, OCR, library, label/result and dismissed phases reject it.
- A repeated event cannot reset quantity or allow a second concurrent save.
- After opening recovery, Log uses current servings; double taps yield exactly one effect.
- Scan again resets quantity and saving and resumes only while active.

## Integration risks
- All quantity controls must share the editor binding; flow.servings must equal its action multiplier, including grams mode and changed grams per serving.
- Keyboard visibility must reduce the strip to zero, including its padding/minimum height, without remounting the camera controls.
- Dirty Close must confirm before the transition observer softens the sheet; dirty swipe must not discard silently.
- Expanded editor and Logged state must not recreate a live scanner. A restart must retain the still until startScanning succeeds.
- Logging a second item after Scan again must not reuse the first editor or its capture image.
