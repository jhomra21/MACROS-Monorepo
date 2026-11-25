# Onboarding untangle screenshots

These four simulator captures accompany the tutorial and Pro-card review fixes.
The tutorial step 1, tutorial finish, and onboarding Pro captures are side by
side with archived screenshots from `origin/transfer/onboarding-preview-2026-11-25`.
The current captures are scaled to the baseline dimensions for comparison.
Tutorial step 1 and the onboarding Pro cards retain the same layout and copy.
The finish capture shows a visible difference in ring appearance between
baseline and current; the tutorial completion card and copy remain the same.
The paywall capture records feature-card appearance after making each feature's
visual treatment explicit in its model.

| Image | Scenario |
| --- | --- |
| `tutorial-step-1-comparison.png` | Baseline (left) and current tutorial step 1 |
| `tutorial-finish-comparison.png` | Baseline (left) and current tutorial completion |
| `onboarding-pro-comparison.png` | Baseline (left) and current onboarding Pro |
| `paywall-cards.png` | Pro paywall feature cards |

The UI run verified tutorial ring reachability, swipe progression to Sharing,
skip-to-today behavior, and these screen captures. XCUITest could not directly
invoke SwiftUI's named custom accessibility actions, so those actions were not
claimed as UI-tested.
