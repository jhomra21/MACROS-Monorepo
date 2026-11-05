## 2026-10-30 Widget Taps Keep Your Place; Compact Dashboard Toolbar (TestFlight Build 13)

- Returning to MACROS by tapping a widget popped Settings/Insights back to the Dashboard. Cause: both widgets set `.widgetURL(AppOpenRequest.dashboard.url)`, so every tap delivered `calmacrotracker://dashboard`, and `applyPendingOpenRequest(.dashboard)` reset the navigation stack and sheets. Icon and app-switcher returns never popped (`.onOpenURL` fires once per URL, not on foreground). Fix: removed `widgetURL` from both widgets so WidgetKit simply opens the app, and removed the now-unused `AppOpenRequest.dashboard`, its URL parsing, `dashboardResetToken`, and `DashboardScreen.resetToTodayToken`. `sharing` and `add-food` links are unchanged.
- The four dashboard toolbar icons were spread too wide and the glass capsule touched the ring. Restored the build 10 layout without its offset hack: one `ToolbarItem` with an `HStack(spacing: 8)` of 32 pt icon buttons, plus 8 pt top padding on the ring row.
- Toolbar buttons now use 44 pt hit targets (HIG minimum) with zero spacing, so glyph spacing stays compact.
- Validation: format check, `git diff --check`, Debug build, AppDayContextTests plus LogEntryQueryTests passed (iPad runner); simulator checks (widget tap keeps Settings, cold widget start opens Dashboard, sharing and add-food links) in `build/b13-bugs-2026-10-30/`.

## 2026-10-30 Weight Chart Y-Axis No Longer Anchors At Zero

- Insights weight trend chart uses `chartYScale(domain: .automatic(includesZero: false))` so narrow weight ranges fill the plot. Validation: format check, `git diff --check`, Debug build passed.

## 2026-10-30 Sharing Circle Invites Require Pro (TestFlight Build 13)

- Owner rule: a Pro user initiates every connection. Creating an invite link requires Pro (`PaidFeature.sharingInvites`, `ProPaywallContext.sharingInvites`, paywall benefit listed first in its context). Accepting an invite, enabling sharing, saving the display name, syncing totals, revoking, and all stop/delete actions stay free, so a free user can share back with the Pro user who invited them. Free users cannot connect with each other.
- Sharing screen: the Create Invite Link button and the invite link details sit behind `PaidFeatureGate`; the locked state is a `ProLockedRow`. Revoke Invite stays outside the gate so a lapsed user can still revoke a live invite. The Invite section has a footer stating the rule. The Dashboard share-image button is unrelated and stays free.
- Empty state on the Sharing dashboard no longer tells free users they can invite someone.
- `CURRENT_PROJECT_VERSION` 12 -> 13 in all six configurations; marketing version stays 1.0.
- Validation: see the build 13 evidence report under `build/sharing-pro-b13-2026-10-30/`.

## 2026-10-30 Debug Demo Data Seeder

- Added a DEBUG-only `DemoDataSeeder` that replaces local data with a fixed sample set (goals, imperial profile, 20 saved foods, 90 days of logs, 20 weigh-ins) through `BackupImporter.apply` in replace mode. Settings gained a DEBUG "Developer" section with Grant/Revoke Debug Pro (moved from Pro settings) and Load Demo Data.
- Validation: format check, `git diff --check`, Debug build, and BackupRoundTripTests and InsightsAnalyticsTests pass on the iPad fixture; demo E2E on the iPad fixture (evidence in `build/demo-seed-2026-10-30/`).

## 2026-10-29 TestFlight 12 Owner Feedback Fixes

- Insights: removed the extra "View weight log" card row shown when no weight is in range. The dismissible bottom weight notice is the only weight prompt.
- Dashboard: restored one compact trailing toolbar group (Share, Insights, History, Settings) instead of two groups with a spacer.
- Dashboard: moved the "Today" return button to the leading side under the date title.
- Settings: Save Goals and Recalculate Targets are separate sections again, which removes the stray inset separator between them. An alignment-guide attempt had no visible effect and was dropped.
- Camera: viewport and result-panel insets raised from 8 to 16 points so the frame aligns with the result card. Bottom corners stay clear of the home indicator.
- Evidence: `build/owner-feedback-b12-2026-10-29/REPORT.md`. Build number unchanged (12).

## 2026-10-29 App Review Audit Fixes (TestFlight Build 12)

- Added privacy manifests for the app (health, user ID, usage, search history, diagnostics collected for app functionality; UserDefaults CA92.1/1C8F.1, file timestamp C617.1) and the widget (required-reason APIs only). The widget manifest is excluded from the app target's synchronized group.
- Sharing screen now discloses what is uploaded while sharing is off. Settings gained an About section (Privacy Policy, Terms of Use, Support, bundle version footer). Goal review shows a not-medical-advice note. Build number 11 -> 12. Evidence: `build/app-review-fixes-build12-2026-10-29/REPORT.md`.

## 2026-10-29 TestFlight Build 11

- `CURRENT_PROJECT_VERSION` 10 -> 11 in all six configurations (app, widget, tests); marketing version stays 1.0. Branch merged with `origin/main` (web refresh, no conflicts). Evidence: `build/testflight-build11-release-2026-10-29/REPORT.md`.

## 2026-10-29 E2E Delight Pass Fixes

- Log rows, meal detail and meal editor summaries now say "1 serving" instead of "1 servings" (`QuantityMode.formattedSummary`, inflect).
- Camera result panel buttons (Edit details, Log, Details, Scan again, Search online, Enter manually, Open Settings) use `.controlSize(.large)`; the old `.frame(minHeight: 44)` sat outside the glass style and rendered 32-34pt tall.
- `NutrientInputField` stacks title over input at accessibility text sizes so the Settings Daily Goals "kcal" suffix no longer wraps one letter per line.
- Verified on iPhone 18 Pro iOS 27.0 with the local StoreKit Pro seed (removed afterward, app Free). No iPad simulator exists, so the iPad pass was skipped. Reduce Motion, the medium widget and the Lock Screen were not checked. Report: `build/e2e-delight-2026-10-29/REPORT.md`.

## 2026-10-29 Polish Batch 3c

- Carry-overs: log rows read as one VoiceOver element (name, quantity, time, calories, macros). Backup import sheet uses the shared bottom action bar with Merge as the primary action and Replace All Data as the destructive secondary. Small widget seen in light mode on the Home Screen; dark mode and the gallery card were not checked.
- Copy: Title Case buttons and section headers in Backup, Health, Weight, Settings, and Insights. Item counts pluralize with inflection. Food label review copy is plain. Macro order is Calories, Protein, Carbs, Fat in Daily Goals and food forms. Reminder copy uses a curly apostrophe. Weight history headers read "Week of ...".
- Insights: one locked CTA heading "Insights is a Pro feature". Weight card uses the shared accent action button. Chart style picker sizes to content. Nutrient bars use the accent color. Chart grow-in animation removed in favor of a range-change animation.
- Paywall: the trial length comes from the StoreKit introductory offer and the badge is hidden without one. Restore, Redeem, and Retry have 44-point minimum heights. Plan selection animates with a selection haptic.
- Onboarding and Reminders: denied notification alerts offer Open Settings. Reminder footers explain when notifications are off. Health footer explains what MACROS reads and writes. The three-reminder cap lives in one constant used by the scheduler and onboarding.
- Sharing: Start Sharing alert wording, Turn Off Sharing moved to the final destructive section, Share Invite uses a share label with the link as selectable caption, expired-invite footer copy.
- Surfaces: error banners take a per-call-site title. Day change plays a selection haptic. Manual food entry uses the shared bottom Continue bar.
- Validation: format check and diff check pass. Debug simulator build succeeds. InsightsAnalyticsTests, ReminderConfigurationTests, ReminderSchedulerTests, BackupRoundTripTests, and ProEntitlementTests pass (68 of 68). Simulator pass on iPhone 18 Pro covered the log row label, Settings footers, Weight button, Sharing footer, paywall plan selection, Insights lock heading, and the small widget on the Home Screen.

## 2026-10-29 Polish Batch 3b

- Dynamic Type: onboarding goal and body-profile rows use a minimum height and stack label over field at accessibility sizes. The fixed Form height on target review is removed. Top bar, paywall hero, and onboarding icon sizes now scale with text. Fat label reads "Fat".
- Confirmations: deleting a log entry or a saved food asks first with a confirmation dialog. Swipe-to-delete is unchanged. Weight deletes and Health authorization errors show in the error banner. Health sync shows a progress indicator and status text in the section footer.
- VoiceOver: keyboard toolbar buttons are labeled, log rows include calories and macros, the dashboard day header steps days with adjust actions, the macro legend has a Change Color action, insight charts expose range and average, and goal field labels are buttons.
- Sheets: weight entry uses medium and large detents with a grabber and the shared keyboard toolbar. Add Food and Edit Entry sheets use the large detent with a grabber. Food pickers show "Choose Foods" with an Add button. The launch placeholder is now a blank background.
- Widgets: small widget margins widen to 14 and 12 points. Previews show sample values and placeholders are redacted. The Lock Screen widget is named "Macros Lock Screen".
- Decision: the saved-food delete dialog omits the meal-usage warning because delete is disabled while a food is used in a meal.
- Decision: the launch error view has no Try Again button because the launch state has no retry path. It shows a close-and-reopen hint instead.
- Validation: format check and `git diff --check` pass; Debug simulator build succeeds; `WidgetAppearanceStorageTests`, `FoodItemLocalSearchTests`, `GoalCalculatorTests`, and `WeightAnalyticsTests` pass 37 of 37. Simulator checks: dashboard and Today pill at the largest accessibility text size, Add Food at default text size, Weight entry keyboard toolbar, and the Delete Entry confirmation. Other device checks are unverified (see the batch 3b report).

## 2026-10-29 Polish Batch 3a

- Native surfaces: content cards (History week card, Insights cards and weight card, onboarding choice and reminder cards, goal rows, body profile rows) use the standard card background through `appCardBackground(cornerRadius:)`. Glass stays on the floating controls: Today pill, Insights range and weight notice, paywall plan buttons, bottom bars, camera controls, and suggestion pills (now 44pt minimum height).
- Add Food: Cancel is the leading toolbar action, the Search and Manual switch is a segmented control under the title with no animation wrapper, and Done is removed.
- Dashboard: the top-right actions are two toolbar groups split by a fixed `ToolbarSpacer`, with icon-only labelled buttons.
- Settings: Pro, Daily Goals (Save and Recalculate share one section), Food Suggestions, Macro Ring Colors, Widget Background, Reminders, Apple Health, Weight, Sharing, saved foods, then Backup last. Locked Pro rows share `ProLockedRow`, which opens the paywall. The Sharing disclaimer stays on the Sharing screen only. The ring Reset button uses a bordered style.
- Onboarding: the locked additional-reminders card opens the Reminders paywall.
- Backup: Merge is the primary action and Replace All Data is a destructive glass button. The import sheet and error banner attach to the section.
- Paywall: the close control uses the system close role, the selected plan has a 2pt accent ring, and the success action reads "Done".
- Scope: visual and structural changes only. Import summary, the onboarding path, the success CTA, and the Reset button were not reachable on the test device and remain unverified.
- Validation: format check and `git diff --check` pass; Debug simulator build succeeds; `ProEntitlementTests`, `InsightsAnalyticsTests`, and `BackupRoundTripTests` pass 60 of 60 on the iPhone 18 Pro iOS 27.0 simulator.

## 2026-10-29 Polish Batch 2

- Camera options: the ellipsis toggle and its option circles share a `GlassEffectContainer(spacing: 12)` with `glassEffectID` and `matchedGeometry`, so the circles grow out of and collapse back into the toggle. The slide-in transition is removed. The back and shutter controls stay separate glass controls. Under Reduce Motion the change is not animated.
- Animation scope: the result-expanded animation moved onto the result panel, which also animates its height as the hint, lookup, and result states change. The NavigationStack no longer animates unrelated pushes.
- Haptics: a medium impact plays when a barcode is detected and lookup starts. The success haptic plays only after a successful log.
- Result panel: the primary action uses `glassProminent` and secondary actions use `glass`, all with a 44pt minimum height. The missing-nutrients warning has an icon. The line reads "kcal", the servings stepper uses monospaced digits, and the permission-denied copy is one constant. The camera back control is labelled "Close camera". The log-error alert uses a curly apostrophe.
- Scope: Debug build, `FoodCameraFlowTests`, and simulator checks on the iPhone 18 Pro iOS 27.0. Not verified on a physical device or with VoiceOver. Haptics cannot be observed in the simulator.
- Validation: `make quality-format-check` and `git diff --check` pass; `FoodCameraFlowTests` passed 25 of 25.
