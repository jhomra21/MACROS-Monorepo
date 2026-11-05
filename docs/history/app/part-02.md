## 2026-10-31 TestFlight Build 20

- Pre-submission polish: one shared onboarding header and layout, no bell bounce, Back on Reminders; tutorial spotlight tracks targets with no halo loop, updates text in place, and ends with a What's New-style Done card; camera errors keep the shutter and photo menu, and servings/name edits no longer move the camera layout; includes review fixes.
- Validation: bounded Debug build, format check, and serial non-StoreKit iPad suite passed (198 tests, 0 failures).

## 2026-10-31 Pre-submission polish

- Tutorial: the spotlight morphs only on step changes, tracks moving targets without lag, and collapses until the current target has a rect; static focus outline; caption text updates in place; full-height caption fallback in landscape and AX sizes; Dashboard scrolls to the rings on start; readiness is stored; 44 pt Skip/action targets; Reduce Motion gating. Camera: only barcode and label results freeze the viewport, layout animates on panel kind rather than content, the barcode capture task is tracked and cancelled.
- Onboarding now uses one shared `OnboardingHeader` (static symbol, title, subtitle) and one set of insets, spacing and card radius on every step, with the pinned bar's fade matching the grouped background and no spinner shift. Welcome animates its rings once, Reminders keeps Back (hidden only while the permission request runs) and has no bounce, the locked "More reminders" card is a real button, and Your targets stacks its macro columns at accessibility sizes.
- Validation: format/diff checks, iPhone 17 frame captures and screenshots, and the serial non-StoreKit iPad suite (198 tests, 0 failures) passed; dark-mode onboarding captures were not obtained (see report).

## 2026-10-31 TestFlight Build 19

- Welcome screen content centered again after build 18 shifted it left.
- Validation: iPhone 17 light/dark and accessibility-extra-extra-extra-large captures show centered rings and wrapped, scrollable labels; bounded Debug build and format/diff checks passed; serial non-StoreKit iPad suite passed (198 tests, 0 failures).

## 2026-10-31 TestFlight Build 18

- Tutorial redesign dims the whole screen, shapes the spotlight and focus ring to each target, uses a one-way swipe hand and solid caption card, and ends with a recap; Reminders onboarding is redesigned; Welcome animates macro rings and keeps its labels and Get Started action usable at accessibility sizes.
- Validation: bounded Debug build, format check, diff check, and serial non-StoreKit iPad suite passed (198+ tests, 0 failures).

## 2026-10-31 Tutorial and reminders design pass

- Tutorial spotlight now follows its target (circle for the rings, rounded rect for the legend, capsule for the Today pill) and morphs between them; the scrim is darker with a feathered cutout and a breathing focus ring so the highlight reads in light and dark. The caption is a solid elevated card with step dots, and the end screen is a completion card with a recap and Done button.
- Reminders onboarding has a bell hero, icon-tile rows, a PRO badge on the locked card, and stacks rows at accessibility sizes. Behavior is unchanged.
- Onboarding Welcome now opens with independently animated, randomized macro rings.
- Validated: format check, 198 tests on the iPad runner (StoreKit class skipped), iPhone 17 screenshots in light, dark and 3XL under `docs/evidence/design-pass/`.

## 2026-10-31 TestFlight Build 17

- First-run guided Dashboard tutorial with Settings replay; camera result card now uses the shared food row with a goal ring, serving size text and totals that follow the servings stepper; camera hint text centered; camera stays dark in light mode.
- Validation: bounded Debug build, format check, diff check, and serial non-StoreKit iPad suite passed (198 tests, 0 failures).

## 2026-10-31 Dashboard tutorial

- Feature: the first time the Dashboard shows (new and existing users), a dimmed guided overlay spotlights each target, an animated hand demonstrates, and the user performs the real action: swipe left to Sharing, swipe back, swipe right for the previous day, tap Today, tap the rings, then tap Protein, Carbs and Fat. Events advance `DashboardTutorial` only on the current step; Skip and Done persist `hasCompletedDashboardTutorial`. Settings > About has "Show Dashboard Tips" to replay it. Reduce Motion, VoiceOver and Switch Control get a static hand and a prominent action button.
- Decision: only completion is persisted, so a killed app restarts from step 1; the tutorial pauses (step kept) while a sheet or History, Insights or Settings is open.
- Validation: format check, `git diff --check`, and the serial non-StoreKit suite passed; the full run, skip, replay and Reduce Motion were exercised on the simulator. Follow-up fixes hide the dimmed dashboard from accessibility, gate tutorial swipes, restore yesterday's starting date, and place scrollable captions safely around the spotlight, with tutorial actions stacked at accessibility text sizes. The dim layer is the touch sink, the dashboard is hidden from accessibility while the tutorial runs, and only the list's scrolling is disabled so the caption can scroll at large text sizes.
- Fix: the swipe hand now starts at the swipe's start point and resets only while invisible, so it moves one way; and the overlay moved to `AppRootView` so the navigation and bottom bars are dimmed too (targets report global frames into `DashboardTutorial.frames`, DashboardScreen registers its action via `performAction`, and the done card is centered between the bars).

## 2026-10-31 Camera Card Polish

- Redesign: camera results reuse the shared food nutrition row with a 44 pt daily-goal ring, servings/total-weight text and an accessibility-size stacked fallback; center the hint row and remove its extra top inset. Shared-row padding stays 16 pt by default, unchanged for existing Dashboard and Add Food rows.
- Validation: iPhone Air dark/light screenshots and the Dashboard/Add Food row comparison captured under `build/camera-card-polish/`; Debug build, format check, `git diff --check`, and serial non-StoreKit simulator suite passed (198 tests, 0 failures). Barcode lookup could not connect, so card screenshots use the oat-crunch label fixture. Follow-up fixes compute consumed nutrition once, share the stacked row, normalize serving text and quantities, and keep the camera viewport/card dark in light appearance.

## 2026-10-30 Camera Controls Hide While The Picture Is Frozen

- Fix: while a result is showing, the shutter and the options menu fade out with an 8 pt downward move (opacity only under Reduce Motion), are not hit-testable and are `accessibilityHidden`; the back chevron stays. They return on Scan again in the same single transaction as the card, viewport, still and overlay button.
- Validation: format check, `git diff --check`, and the serial non-StoreKit suite on the iPad runner passed (198 tests, 0 failures); the hide and return were recorded on the simulator.

## 2026-10-30 Camera Freezes On A Blurred Still

- Decision: `DataScannerViewController` cannot pause its camera, and recreating it costs a 0.5-1 s cold start plus the reveal animation on every Scan again, so the session keeps running (recognition is already stopped) and a sharp (unblurred), screen-sized still with a 0.2 dim covers the viewport while a result shows; the Scan again/Retake glass button sits centered at the top, 16 pt from the viewport edge. The still comes from `capturePhoto()` at barcode detection (fallback: dim only), the OCR capture, or the imported photo; it is cleared on Scan again and on dismissal.
- Validation: format check, `git diff --check`, and the serial non-StoreKit suite on the iPad runner passed (198 tests, 0 failures); the photo-import freeze and unfreeze were recorded on the simulator; the `capturePhoto()` barcode path needs a device.

## 2026-10-30 Camera Scan Again Moves Into The Viewport

- Cause: the viewport only moved with the card in the same transaction when the height measurement happened to land with it, and Scan again/Retake lived inside the information card, making it taller and busier.
- Fix: the `.animation` modifiers (`value: panelContent`, `value: resultContentHeight`) now sit on the VStack holding card and viewport, so both resize in one transaction; one curve (`.smooth(duration: 0.3)`, 0.15 s ease-out crossfade under Reduce Motion). While a result shows, the viewport gets a 0.35 black dim over the preview (not the controls) and a centered glass-prominent "Scan again"/"Retake" button (scale 0.9 + opacity, opacity only with Reduce Motion). The card no longer has any retry button; the live-preview layer has no blur.
- Validation: format check, `git diff --check`, and the serial non-StoreKit suite on the iPad runner passed (198 tests, 0 failures).

## 2026-10-30 Camera Result Card Morphs From The Hint

- Cause: `resultPanel` swapped an if/else (scrolling card vs. plain panel), so SwiftUI replaced the hint with the card in one frame; the clear cover background let Add Food show through; the Details/Log/Scan again buttons sat at natural widths and wrapped.
- Fix: one stable glass container whose height animates from a measured content height (cap 0.45 of the screen, scroll only when expanded), content crossfades with `.id(kind)` + `.blurReplace`, one animation source (none with Reduce Motion), a solid black backdrop inside the navigation content, and a rebuilt card (name + 44 pt retry, kcal, macro capsules in the standard ring colors, servings row, Details hugging + prominent full-width Log, clearer Logged and error layouts).
- Review fixes: barcode still capture is guarded by a scan-session token, frozen controls stay hidden throughout interactive dismissal, and the narrow-width macro fallback stacks individual capsules vertically.
- Validation: format check, `git diff --check`, and the serial non-StoreKit suite on the iPad runner passed (198 tests, 0 failures); recordings on the iPhone Air simulator show the card growing over about 14 frames.

## 2026-10-30 TestFlight Build 16

- Since build 15: the camera result card grows from the hint banner while the camera frame shrinks in the same animation, with a solid backdrop; the card shows item info with Details and Log; after a scan, the camera picture freezes on the scanned image with Scan again/Retake floating at the top while the shutter and options hide.
- Validation: Debug build, format check, `git diff --check`, and the serial non-StoreKit suite on the iPad runner passed (198 tests, 0 failures).

## 2026-10-30 TestFlight Build 15

- Since build 14: Add Food Search/Manual switch is stable on first tap and lives in the navigation bar with an animated switch; on-device search results no longer flash while typing.
- Validation: format check, `git diff --check`, and the serial non-StoreKit suite on the iPad runner passed (198 tests, 0 failures).

## 2026-10-30 Add Food Mode Switch Keeps A Stable View Tree

- Cause: `addFoodSearchable` wrapped the whole Add Food screen in an if/else `@ViewBuilder`, so every Search/Manual switch changed the structural identity of the entire subtree and rebuilt the navigation search drawer. On a fresh install the Manual form could lag the picker by about 0.5-1 s (the reported "picker says Manual, content stays"). I could not reproduce a permanent failed switch in 9 simulator attempts.
- Fix: `.searchable` and `.onSubmit(of: .search)` now sit on `SearchFoodListView` inside the `.search` branch, preserving the stable view tree; Manual still has no search field; the Search/Manual picker now lives in the navigation bar and mode changes animate smoothly over 0.25 seconds, while Camera and its zoom source are unchanged. During search, existing on-device results stay visible instead of flashing the loading row.
- Validation: format check, `git diff --check`, and the serial non-StoreKit suite on the iPad runner passed (198 tests, 0 failures); 7 cold simulator attempts after the fix showed Manual on the first tap.

## 2026-10-30 TestFlight Build 14

- Since build 13: the weight chart y-axis no longer starts at zero; widget taps no longer pop the navigation stack (`widgetURL` removed); the compact dashboard toolbar with 44 pt hit targets; and the simslim QA profile (tooling only).
- Validation: format check, `git diff --check`, and the serial non-StoreKit suite on the iPad runner passed (198 tests, 0 failures).

## 2026-10-30 simslim QA Simulator Profile

- Added `tools/sim/macros-slim.json` and raised the simulator budget to four (maximum one stock), backed by settled measurements (7.38 GB slim iPhone 17, 10.56 GB stock iPhone 18 Pro Max), 198 passing iPad tests, and four-device measurements. Smoke checks passed except the widget gallery, blocked by UI automation; see `docs/evidence/simslim/`.
