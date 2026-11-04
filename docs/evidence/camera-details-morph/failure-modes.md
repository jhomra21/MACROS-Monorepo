# Failure-first interaction checks

Recorded before implementation, after RED capture at 2026-11-03T21:34:00Z on 7034202.
No new isolated unit tests are planned; the real fixture app and existing full suite are the validators.

- Expansion/collapse replaces or fades two Log buttons instead of moving one continuously.
- Geometry matching scales text, clips the moving button, loses hit testing, or leaves duplicate AX actions.
- Details does not become a reachable Less / Show less control in the persistent header.
- Collapse destroys name, numeric text (including incomplete/invalid input), quantity mode/amount, confirmations, reusable-food choice, or expanded secondary fields.
- E2E follow-up: a valid trailing decimal (`1.`) is normalized by the shared nutrient presentation when focus ends, before collapse. Camera sessions must opt into retaining presented text across blur; other callers must keep their existing presentation behavior. Quantity-multiplier changes must still invalidate the retained display text so old totals cannot appear under a new quantity.
- Compact totals/name/quantity use the original draft, or compact Log saves stale food/servings instead of the edited logging action.
- Grams are presented as editable servings, or a rounded equivalent is reused for logging. Invalid conversions must never enable Log.
- Required Review can be bypassed through compact Log; confirmed zero choices disappear on re-expansion.
- Dirty collapsed Scan again, label Retake, Close, or swipe discards silently.
- Collapse restarts the scanner; reopening Details rebuilds the session; Scan again fails to clear it.
- Reduce Motion still moves controls; keyboard leaves a visible strip or hides Log/Done; landscape loses the 65/35 split; AX5 hides collapse or overlaps strip actions.
- Frame-review follow-up: Reduce Motion must suppress native glass-button label/layout animation as well as the outer card animation. Checking only Log raster endpoints misses Details/Less movement; inspect both controls in the retained frame strip.
- Expanded height changes from 75% / 170 pt floor, or the 960-measurement layout regression fails.

Fix-round failures, established by the parent-reviewed GREEN strips at `6efc374` before this round:

- `green/expand-strip.jpg`, row 1 frames 4–5: the overlay Log outruns the growing card and overlaps Scan again.
- Expand/collapse row 2: two separately rendered summary headers cross-fade at different offsets.
- `green/collapse-strip.jpg`, settled row 3: Details truncates to "Deta..." and Log overflows the original compact row.
- The independent matched-geometry overlay arrives after the card, rather than with its bottom edge.
- The new iPad capture setup needs its own RED cycle before claiming a GREEN comparison.

Round-2 failures established from c8edb61 before editing:

- Less sits above Log and obscures Protein at rest, and Nutrition/Calories during expansion.
- Top-trailing Less could cover or truncate the title, especially at AX5; reserve its own header row at accessibility sizes.
- A footer that does not reduce the Form's safe area could hide the final reusable-food toggle.
- Moving the persistent toggle could regress compact row equality, keyboard dismissal, or Reduce Motion.

RED: `red/expand.mp4`, `red/expand-strip.jpg` (10 fps, row-major 0.0–1.9 s); around 0.7–0.9 s the compact action row and incoming editor bottom Log coexist. `red/expanded.json` contains no Less / Show less control.
