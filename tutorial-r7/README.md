# Dashboard tutorial round 7 evidence

This requested screenshot transfer set covers the complete light tutorial,
dark-mode opening and finish, accessibility-size opening, Protein step and
finish at two accessibility sizes, plus a composite strip of the finish
transition. It contains 16 PNGs totalling about 3.1 MB. This is an intentional
exception to the repository's usual five-image / 2 MiB evidence limit: all
requested states and the transition strip are included. The 101 MB simulator
recording and raw XCTest result bundles remain in ignored local evidence and
are not tracked here.

## Captures

| File | State |
| --- | --- |
| [01-sharing.png](01-sharing.png) | Light: sharing |
| [02-sharing-return.png](02-sharing-return.png) | Light: return from sharing |
| [03-look-back.png](03-look-back.png) | Light: look back |
| [04-back-to-today.png](04-back-to-today.png) | Light: back to today |
| [05-tap-for-more.png](05-tap-for-more.png) | Light: expand rings |
| [06-protein.png](06-protein.png) | Light: Protein |
| [07-carbs.png](07-carbs.png) | Light: Carbs |
| [08-fat.png](08-fat.png) | Light: Fat |
| [09-finish-light.png](09-finish-light.png) | Light: finish recap |
| [10-sharing-dark.png](10-sharing-dark.png) | Dark: sharing |
| [11-finish-dark.png](11-finish-dark.png) | Dark: finish recap |
| [12-sharing-accessibility.png](12-sharing-accessibility.png) | Accessibility text size: sharing |
| [13-protein-accessibility.png](13-protein-accessibility.png) | Accessibility text size: Protein |
| [14-finish-accessibility.png](14-finish-accessibility.png) | AX5 finish recap: scrolled to show all recap rows above pinned Done |
| [15-finish-transition-strip.png](15-finish-transition-strip.png) | Ten sampled frames through the finish morph |
| [16-finish-ax1.png](16-finish-ax1.png) | AX1 finish recap: all content fits above pinned Done |

## Provenance

- Integration source: `e2f75742` (final Reduce Motion glass morph gating).
- Accessibility fix: feature commit `8d27cc46`, merged as `001cc1de`.
- Simulator: iPhone 17, iOS 27.0, UDID `918D29B9-97D3-42C0-9C47-00605E01E8DB`.
- Toolchain: Xcode 27.0 (27A266a), selected with
  `/Applications/Xcode-26.4.1.app/Contents/Developer`.
- UI test: `TutorialRound7CaptureTests.testCaptureTutorialStatesAndFinishTransition`,
  1 passed, 0 failed, 119.357 seconds.
- Follow-up UI captures used a temporary XCUITest on the same iPhone 17. The
  standard-size finish, AX5 finish, AX1 finish, and AX5 Protein step each passed.
  At AX5, scrolling reveals the remaining recap row while Done stays pinned.
  The Protein step panel remains readable at AX5.
- `make quality-build` and `make quality-format-check` passed for the fix.
- Raw test logs, result bundles, exported attachments, and the 101 MB simulator
  recording are preserved under the ignored local
  `build/evidence/2026-11-25-tutorial-r7/` directory in the main checkout.
- The transition strip was sampled from the same simulator and source during
  an earlier run. That run completed the light and dark captures, then stopped
  during accessibility setup because its Settings scroll limit was too short.
  The final passing run separately verified the accessibility captures.

Screenshots were reduced to a maximum dimension of 1300 px. No user or
production data was used.
