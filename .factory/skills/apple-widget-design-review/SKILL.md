---
name: apple-widget-design-review
description: Review or guide iOS WidgetKit design work against Apple HIG widget guidance and this app's WidgetKit conventions. Use when designing, implementing, or reviewing widgets, Lock Screen accessory widgets, StandBy/CarPlay behavior, widget rendering modes, widget previews/placeholders, or widget interactions.
---

# Apple Widget Design Review

## Overview

Use this skill whenever work touches WidgetKit surfaces or widget design decisions. Review the widget as a glanceable, context-adaptive app extension, not as a miniature app screen.

Primary sources:
- Apple Human Interface Guidelines: Widgets
- Current app code under `cal-macro-tracker/CalMacroWidget/`
- Project guidance in `AGENTS.md`, `swift-dev.mdc`, and relevant `changes-log.md` entries

## When to Use

Use for:
- Designing or reviewing Home Screen widgets.
- Designing or reviewing Lock Screen accessory widgets.
- Checking StandBy, CarPlay, tinted, clear, accented, or vibrant behavior.
- Reviewing WidgetKit timeline refresh, deep links, placeholders, gallery copy, or interactivity.
- Implementing new widget families or changing existing widget layouts.

Do not use for unrelated SwiftUI screens unless they directly share widget components.

## Required Context

Before giving design guidance or editing code:

1. Read relevant local instructions (`AGENTS.md`, `swift-dev.mdc`) and changed widget files.
2. Inspect widget declarations:
   - `WidgetBundle`
   - `StaticConfiguration` / `AppIntentConfiguration`
   - `.supportedFamilies(...)`
   - `.containerBackground(for: .widget)`
   - `.widgetURL(...)`, `Link`, `Button`, `Toggle`, or App Intent usage
3. Inspect shared widget visuals, especially `MacroRingSetView`, `MacroSummaryColumnView`, and other reused components.
4. Check `changes-log.md` for prior widget decisions and fragile visual contracts.
5. Identify target contexts before reviewing layout:
   - iPhone Home Screen / Today View
   - iPhone Lock Screen accessory
   - StandBy / CarPlay
   - iPad Home Screen / Lock Screen, if supported
   - Mac, watchOS, or visionOS only when the widget target supports them

## Apple HIG Review Workflow

### 1. Define the widget's job

- Confirm the widget exposes essential information or a focused action related to the app's main purpose.
- Reject icon-only or app-launcher designs unless they add clear value.
- Prefer timely, dynamic information that changes throughout the day.
- For this app, prioritize daily calories, macro progress, logging status, or one focused logging shortcut.

### 2. Match family to content

- Small widgets should show one primary idea.
- Medium and larger widgets may add supporting data, trends, or simple actions.
- Accessory widgets must show a very limited amount of information.
- Do not simply stretch small-widget content to fill larger families.
- Do not assume Home Screen support implies Lock Screen support; verify `.supportedFamilies(...)`.

### 3. Check context and rendering modes

Review each supported family against the modes it can enter:

- **Full color**: preserve light/dark appearance and semantic colors.
- **Accented / tinted / clear**: expect desaturation and system tinting; group accent content deliberately with `widgetAccentable(_:)`.
- **Vibrant**: for Lock Screen and low-light StandBy, verify grayscale contrast, hierarchy, and legibility.
- **StandBy / CarPlay**: expect the small system widget to scale up with background removed; prioritize large text and avoid relying on rich color or background fills.
- **Accessory**: expect monochrome/vibrant treatment on Lock Screen; avoid detailed color semantics.

### 4. Review density, margins, and typography

- Prefer standard widget margins, generally 16pt.
- Use tighter margins around 11pt only for justified graphics, buttons, or grouped shapes.
- Keep content away from rounded widget corners; use `ContainerRelativeShape` or system widget containers when appropriate.
- Prefer system fonts, text styles, and SF Symbols.
- Avoid text below 11pt.
- Avoid rasterized text; use real `Text` so Dynamic Type and VoiceOver work.
- Preserve glanceability: if it needs careful reading, move detail to a larger family or the app.

### 5. Review color and imagery

- Use color to support information, not compete with it.
- Never rely on color alone; pair color with text, symbols, labels, or shape.
- Treat full-color images carefully in tinted/clear appearances; reserve them for true media-like content.
- Confirm macro colors remain understandable when desaturated or tinted.

### 6. Review content freshness

- Widgets are periodic, not real-time.
- Use timelines and app-triggered `WidgetCenter` reloads for relevant data changes.
- Use system date/time rendering where possible instead of burning refresh opportunities.
- If users may check more often than the widget can update, consider displaying freshness text.
- For live, frequent, limited-duration updates, consider Live Activities instead of widgets.

### 7. Review interactions and deep links

- Default widget taps should open the app at the relevant location.
- Buttons and toggles must be simple, directly related to widget content, and not turn the widget into an app-like UI.
- Inline accessory widgets offer only one tap target.
- Verify `.widgetURL(...)`, `Link`, App Intent buttons, or toggles route to the correct app state.
- Keep targets confident and uncluttered.

### 8. Review previews, placeholders, and gallery copy

- Placeholder content should help people recognize the widget using static structure plus semi-opaque placeholders for dynamic data.
- Gallery previews should use realistic data, not empty or misleading states.
- Widget descriptions should be succinct, begin with an action verb, and avoid “This widget shows…”, “Use this widget to…”, or “Add this widget…”.
- Group sizes together with one description when they represent the same widget concept.

## Repo-Specific Rules

- Keep widget work native SwiftUI + WidgetKit.
- Preserve local-first behavior; widgets should read shared on-device data and degrade gracefully to empty/placeholder states.
- Reuse shared macro-rendering components instead of cloning widget-only rings unless there is a proven design reason.
- Preserve known macro ring contracts from `changes-log.md`; do not rewrite ring rendering casually during widget design work.
- Keep app entry routing through existing `AppOpenRequest` patterns where applicable.
- Ensure mutations that affect dashboard/widget data trigger `WidgetTimelineReloader.reloadMacroWidgets()`.
- Avoid adding account/login assumptions to widget states.
- For ambiguous nutrition data, prefer review/edit flows in the app rather than silently inventing precision in the widget.

## Implementation Checklist

When editing widget code:

1. Add or change only the families that provide distinct value.
2. Keep each family layout independently designed for its space.
3. Use `@Environment(\.widgetFamily)` and `@Environment(\.widgetRenderingMode)` when layout or color must adapt.
4. Add `.containerBackground(for: .widget)` with the correct WidgetKit background behavior.
5. Use `widgetAccentable(_:)` only for content that should belong to the accent group.
6. Keep timeline loading fast and deterministic.
7. Keep placeholder and snapshot data realistic.
8. Verify widget URLs or interactions open the correct destination.
9. Avoid full app navigation, forms, dense lists, or complex controls inside widgets.

## Review Checklist

Return concrete issues when any of these fail:

- The widget's purpose is unclear or duplicates the app icon.
- A family declares support without a layout that fits that family.
- Lock Screen/accessory content is too dense.
- Text is too small, clipped, rasterized, or inaccessible.
- Meaning depends only on color.
- Tinted/clear/vibrant modes would lose contrast or hierarchy.
- StandBy/CarPlay would rely on a removed background or fine detail.
- Interactions are too complex, too numerous, or route to the wrong app location.
- Timelines imply real-time updates that widgets cannot provide.
- Placeholder/gallery copy is empty, misleading, or not action-oriented.
- A repo-specific shared visual contract is duplicated or casually rewritten.

## Verification

For code changes, run the relevant project validators before finishing:

```sh
git diff --check
make quality-format-check
xcodebuild -project "/Users/juan/Documents/xcode/cal-macro-tracker/cal-macro-tracker.xcodeproj" -scheme "cal-macro-tracker" -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

When feasible, also verify widget previews or simulator screenshots for:
- system small and medium widgets
- accessory inline, circular, and rectangular widgets
- light/dark appearances
- accented/tinted/clear behavior
- Lock Screen or StandBy behavior when relevant

If visual validation is blocked, state exactly what was reviewed in code and what remains for manual device/simulator verification.

## Output Format

For reviews, use:

```md
## Widget design review
- Scope:
- Supported families/contexts:

## Findings
- [Priority] Title
  - Evidence:
  - HIG rule:
  - Fix:

## Edge cases checked
- Rendering modes:
- StandBy/CarPlay:
- Accessory constraints:
- Interactions/deep links:
- Placeholder/gallery:

## Validation
- Commands/screenshots:
- Result:
```

If there are no issues, say `LGTM` and briefly list the contexts and edge cases checked.
