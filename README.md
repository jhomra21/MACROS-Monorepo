# MACROS Pro paywall: stacked plan rows (2026-11-27)

Branch `feature/paywall-rows`. Screenshots are iPhone 17e with local StoreKit prices: settings light/dark, meal-photo context (light), onboarding (dark), and an accessibility XXXL size (light).

## Design choices
- **Three separate cards, not one grouped card.** Yearly is selected by default and carries the accent border, so it needs its own edge. The feature list above is a single card; stacking three more separate cards at the same 20 pt radius and card colour matches the Add Food and onboarding choice rows.
- **Rows:** checkmark.circle.fill / circle on the left, plan name, "7 days free" (or "Best value") in accent under Yearly, price right-aligned with a footnote period line. Selected row gets a 2 pt accent border plus an 8% accent wash.
- **Feature icons** are plain SF Symbols in the macro ring colours (protein blue, carbs orange, fat pink) instead of white glyphs on rainbow gradient tiles. The context feature stays first, accent coloured and semibold.
- Removed the white capsule badge, the gradient icon tiles and the tile layout. Spacing tightened (16 pt stack) so everything, including Terms, Privacy, Restore and Redeem, fits with no scroll. At accessibility sizes the rows stack vertically and the sheet scrolls.
- Plan rows are plain cards (no extra glass), so the CTA is the only glass element. System controls (Close, Not now, links) are untouched.

## Skills used
swiftui-liquid-glass, apple-design, emil-design-eng, impeccable, swiftui-view-refactor. The native-iOS rules in cal-macro-tracker/AGENTS.md took priority.
