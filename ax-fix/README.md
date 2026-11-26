# AX5 validation and streak badge alignment

Captured on the iPhone 17e simulator (iOS 27.0, Accessibility XXXL) using isolated demo fixtures. Release 1.2 source was `fb128656`; the 1.1 comparison source was `09958a6f`. Raw test outputs and additional scroll-state captures remain in ignored `build/evidence/` folders in their respective worktrees.

## Selected captures

1. `streak-alignment-ax3.png` and `streak-alignment-ax5.png`: badge columns remain aligned at Accessibility 3 and XXXL after reserving equal height for each “Next” caption.
2. `today-1.2-ax5.png` and `today-1.1-ax5-baseline.png`: the bottom macro labels/values meet the fixed bottom controls in the initial viewport in both releases. The issue predates 1.2 and remains an open accessibility/layout follow-up; no 1.2 Today layout change was made.
3. `contact-support-ax5.png`: the support form at XXXL. Additional scroll-state evidence confirms the remaining form rows are reachable.

Onboarding streaks and the tutorial finish card were also checked at XXXL; their lower content is scrollable. The tutorial finish recap becomes fully visible after scrolling. Those additional captures are local and are not included here to stay within the five-image evidence limit.

## Validation notes

- Temporary large-text XCTest routes were used only for isolated fixture capture and removed before release validation.
- Streak badge alignment tests passed at standard, Accessibility 3, and Accessibility XXXL; badge centers were within 1.5 pt.
- In the temporary large-text route, tutorial finish, onboarding streaks, and Contact Support passed and their scrolled states were captured. The Today route has no scroll view; its initial screenshot matches the 1.1 baseline issue. A later capture-only run had 3 passes and 1 failure because that temporary test tried to swipe a nonexistent Today scroll view.
- This is simulator evidence only. It does not close physical-device accessibility checks.
