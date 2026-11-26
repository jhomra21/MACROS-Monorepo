# Logging streak card

Captured on 2026-11-26 with the iPhone 17 simulator (iOS 27.0).

- `light.png` and `dark.png` show a 90-day streak. The Six Months badge has a half ring and says “90 to go”.
- `ax3.png` is the Accessibility XXXL capture. It exposes a horizontal overflow in the card and following Insights content at this text size. The capture is retained as-is for review.
- The temporary DEBUG fixture test also seeded a five-day streak. It verified the One Week badge label “2 days to go”. The temporary test and seed hook were removed before commit.

The capture test passed 1/1. `LoggingStreakSummaryTests` passed 22/22. `make quality-build` and `make quality-format-check` passed.
