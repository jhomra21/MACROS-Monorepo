# Camera inline details: implementation plan

Status: implementation authorized; final owner decisions and R1–R9 below override the original recommendations. Base: `origin/main` d53a313 (includes the camera card layout-shift fix). All `file:line` cites are at that commit.

## Final implementation contract (owner decisions and review R1–R9)

- Everything remains editable, including Servings/Grams. One editor owns quantity; the pinned servings row and mode section use its bindings. Every quantity change synchronizes flow.servings to editor.servingsAmount; Log uses editor.loggingAction. panelContent is a snapshot while editing, refreshed on Log or Scan again. Expanded label notes appear only in the editor.
- D6 ships with owner device verification deferred to TestFlight. Keep the frozen still through restart until startScanning succeeds, then fade. The preview remains torn down after Log until Scan again. No simulator claim substitutes for hardware verification (R1).
- Keyboard up: camera viewport height, minimum height, and padding become zero without removing its hierarchy. Keyboard down: camera retains 20–30%. Expanded portrait height is min(0.75 × availableHeight, availableHeight − 170). On SE-class available height 647: card 477, strip 170, drawn strip 138, remaining control gap 16 (R2, R8).
- Extract a value-type FoodLogEditorState and shared form under Features/AddFood/: explicit value ownership and bindings are simpler than an observable reference. Keep LogFoodScreen behavior and all non-camera call signatures unchanged.
- Use a structural content swap, not a Form inside a disabled ScrollView. Add only rowBackground: Color? = nil to FoodDraftEditorForm, preserving other callers. Pass clear for inline rows. Prefer Form; fallback is ScrollView/VStack with shared sections if S1 fails. One native glass container, no tint or added dimming (R4).
- D8 kept: dirty-only “Discard changes?” on Scan again, Retake and Close, with “Discard Changes” and “Keep Editing”. Confirm before softenCameraForDismissal. In one small modifier, iOS 27 uses dismissalConfirmationDialog(_:shouldPresent:actions:message:); iOS 26 uses interactiveDismissDisabled(isDirty). Apply inside FoodCameraSheet. Verify clean/dirty swipe dismissal with the zoom transition and report any limitation (R5).
- D9 kept: failed barcode Enter manually opens inline through recoveryDraftOpened, with failure modes and isolated tests written and observed red before implementation (R6).
- D7 kept: Log stays in camera, collapses to Logged. Verify Log → Scan again → second Log.
- Landscape kept: compact-height AnyLayout side-by-side, approximately 65% card / 35% camera.
- Accessibility Dynamic Type: only Log is pinned; header and quantity scroll. Deterministic, not threshold-based (R7).
- Baseline E12 includes search, saved, manual Continue → Log, common-food reusable-copy message/copy, and grams log. Compare pixel/tree before and after extraction. E2 and E12 are regression guards, not expected red. Capture actual CameraCardLayoutTests heights.csv at main, after extraction and final and diff them (R9).
- Additional E2E: renamed collapsed label → Edit details opens clean; software keyboard on for E8; dirty/clean swipe dismissal; background expanded and return with edits intact and Scan again usable. Run S1 and S3 before S2 and S4, each with artifacts.
- Order: commit 0 contract; commit 1 behavior-preserving extraction; spikes; failure modes then red isolated tests for D8/D9; feature; evidence, checks and cleanup. Use focused follow-up commits as needed.
- Validation: quality-format-check, quality-build, lint-js, full serial iPad suite excluding PurchaseStoreStoreKitTests under /Applications/Xcode-26.4.1.app/Contents/Developer, then defensive-code-review. Evidence must distinguish observed passes, expected reds, blocked scenarios, and owner-only hardware checks.
- Owner device checks: expand, wait 10 s, camera indicator off; Scan again live feed and barcode recognition; background expanded, return, Scan again; after Log indicator remains off until Scan again.
- No widget changes intended. Only overlap anticipated is the short append-only changes-log entry.

The historical proposal below is retained for rationale and source citations; where it recommends dropping grams, dirty confirmation, recovery, or landscape, the contract above is final.

## Owner request and decisions

> "...when users click see details, we don't take them to another page anymore. We remove that existing page entirely, and all that information should show up there in that view. ... expand the card space so we morph it to go even lower vertically, so the camera will occupy that space unless you should press the scan again, and ... everything under your serving size be something that can be scrollable..."

1. Expanded area is fully editable, same as `LogFoodScreen`: name, brand, serving description/grams, all nutrients incl. secondary, Required Review, source notes, reusable-copy notes.
2. Expanded: camera keeps 20–30% of the screen; Scan again stays on it.
3. Only the camera flow changes. Search results and saved foods still push `LogFoodScreen`.

## Summary of design decisions

| # | Decision | Why (evidence) |
|---|---|---|
| D1 | Card states are explicit: Hint/Message, Result, **Details** (new), Logged, Error. "Details" is `detailsEditor != nil` on the sheet; no new reducer phase. | Phases already encode scan progress (`FoodCameraFlow.swift:4-14`). Expansion is presentation plus an edit session, so it does not belong in the reducer. One source of truth, no mirrored flag. |
| D2 | Expanded card = the **same glass container and the same `FoodCameraResultPanel`**, taller. Height is a pure function of the screen (75%), not of measured content. | The card already grows by animating `.frame(height:)` on one glass shape (`FoodCameraSheet.swift:244-246`). `matchedGeometry` only matters for separate glass elements. |
| D3 | Pinned: nutrition header, servings stepper, Log. Scrolls: everything else. | Matches "everything under your serving size". |
| D4 | Share the editor by extracting `LogFoodScreen`'s state and Form composition into `FoodLogEditorModel` (`@Observable`) and `FoodLogEditorSections`. `LogFoodScreen` becomes a thin wrapper. | The pinned header and the Form must read the same live draft. Copying the state would fork the logic. An `@Observable` reference keeps keystroke invalidation inside the card, so the camera sheet body is not re-evaluated per keystroke. |
| D5 | Embed a real `Form` (transparent over the glass) as the only scroller. The outer `ScrollView` is `scrollDisabled` while expanded. | `FoodDraftEditorForm` is `Form`-based and shared by three other screens, so it cannot be changed. This gives row chrome, keyboard dismissal and the keyboard toolbar with zero fork. Spike S1 gates this. |
| D6 | Camera while expanded: **tear the live preview down**. The frozen still stays. Scan again restarts it through the existing `pendingScannerStart` path. | A result dwell used to be seconds; editing a label can be minutes, and the camera privacy indicator would stay lit. The stale-controller risk is handled below. |
| D7 | Log from expanded stays in the camera and collapses to the existing Logged card (same as card Log today). | One log path (`logBarcode(servings:)`). Supports multi-item scanning. Owner question Q2. |
| D8 | Unsaved edits: **confirm only when dirty** on Scan again and Close. Owner question Q1. | A typed label is real work, and the strip's Scan again is one tap away. |
| D9 | "Enter manually" after a failed barcode lookup also opens the inline editor. A new reducer event moves `.recovering` to `.showingBarcode` so Log and Scan again work unchanged. | `showManualRecovery` (`+Actions.swift:212-224`) is a second `logDestination` writer. Deleting the route requires handling it. The no-recovery-draft path (`route = .manual`) is unchanged. |
| D10 | No collapse control in v1. Exits are Log (to Logged) and Scan again. | The owner listed no collapse. A cheap follow-up if wanted. |
| D11 | Keyboard up: the camera strip is not shown (card takes the full space above the keyboard). | About 330 pt of keyboard leaves no room for both. Interpretation of "camera keeps 20–30%": applies when the keyboard is down. |

## 1. State model

Source of truth per state:

| State | Truth | Card content | Card height |
|---|---|---|---|
| Hint / Message | `panelContent` `.hint`/`.message` | status row | measured (`resultContentHeight`) |
| Result | `.barcode`/`.label`, `logged == false`, `detailsEditor == nil` | nutrition row, servings, Details/Edit details + Log (unchanged) | measured, capped 45% (`FoodCameraSheet.swift:77`) |
| **Details** | `detailsEditor != nil` (sheet `@State`, `FoodLogEditorModel?`) | same header + servings, then Form, then Log | **0.75 × `geometry.size.height`** |
| Logged | `.barcodeLogged`/`.labelLogged` | unchanged summary | measured |
| Error | `.error` | unchanged | measured |

Transitions:

| Trigger | From | To | Notes |
|---|---|---|---|
| Details / Edit details (`FoodCameraResultPanel.swift:296`, `:157`) | Result | Details | `openDetails()` builds the model from `panelContent` (draft, notes, missing, `captureImageData`, servings, `initialDraft = labelInitialDraft ?? draft` for labels, `draft` for barcodes). Replaces `showDetails`/`showLabelReview` (`+Actions.swift:207-230`). |
| Enter manually (with recovery draft) | Error | Details | New reducer event `recoveryDraftOpened` (`.recovering` → `.showingBarcode`), `panelContent = .barcode(blank draft, …)`, model gets `reviewNotes`. Log stays disabled until the name is valid (`canLog`). |
| Log | Details | Logged | `send(.logTapped)` → existing `.log` effect → `logBarcode(servings:)` reads `detailsEditor?.loggingAction` first (`+Actions.swift:168-194`). On success `detailsEditor = nil`, content becomes `…logged: true` from `action.draft` and `action.quantityAmount`. Failure: `logError` alert (existing), stays in Details. The `isSaving` flag still guarantees one commit. |
| Scan again / Retake / Close | Details | Scanning / dismissed | Dirty: `confirmationDialog` ("Discard changes?" with destructive "Discard Changes" and "Keep Editing"). Clean: immediate. On proceed `detailsEditor = nil` inside `resumeScanning` (`+Actions.swift:232-239`), then the existing `.scanAgain`. |
| Keyboard show/hide | Details | Details | Layout only (section 2). Reuse `bottomPinnedKeyboardVisibility` (`BottomPinnedActionBar.swift:159-163`). |
| New scan result | Details | n/a | Unreachable: recognition is stopped on result, the shutter and options are `FrozenHidden` (`FoodCameraSheet.swift:411,458`), and the live preview is torn down. No guard added. |
| Backgrounding | Details | Details | `sceneInactive` is a no-op while not scanning; `sceneActive` only restarts in `.scanning` (`FoodCameraFlow.swift:190-195`). Edits are in `@State` and survive. |
| Error while editing | n/a | n/a | Scanner/OCR errors arrive only in scanning/reading phases. A save error uses the existing alert. The model's own validation uses the Form's `errorBanner`. |
| Reduce Motion | any | any | `layoutAnimation` is already nil (`:268`), so the resize is instant. Content swap uses opacity. |

Dirty = `reviewDraft.normalized().hasMeaningfulChanges(comparedToNormalized: baseline.normalized())` (existing helper, `FoodDraftBehavior.swift:176`), or `servingsAmount != baselineServings`, or any confirmed-zero toggle. `baseline` is captured at model init. It is **not** `initialDraft`, which drives reusable-copy messaging.

## 2. Layout

### Heights

- Portrait: `expandedHeight = min(0.75 × geometry.size.height, geometry.size.height − 170)`. The 170 pt strip floor keeps the Scan again overlay (16 + about 50 pt) and the Close chevron (about 90 pt including the bottom inset) visible (`FoodCameraSheet.swift:322-326`, `:466-467`).
- iPhone 17e (390×844, insets 47/34): `geometry.size.height` is about 763, so the card is about 572 pt and the strip is about 191 + 34 under the home indicator, 26.6% of the screen (drawn rect about 193 pt, 23%). Within the 20–30% target.
- SE-class (375×667, insets 20/0): the card is about 485 pt and the drawn strip about 130 pt. Overlay plus Close leave an 8 pt gap, which is tight but valid; the 170 floor is the guard.
- Landscape (iPhone supports it, `Info-iOS.plist:115-120`; TARGETED_DEVICE_FAMILY = 1, so no iPad layout): when `verticalSizeClass == .compact`, switch the sheet `VStack` to an `HStack` through the same `AnyLayout` pattern the panel uses (`FoodCameraResultPanel.swift:196-199`): card about 65% of the width, strip about 35%. If this exceeds budget, ship portrait-only expansion and keep landscape on today's collapsed card with Details disabled. That is a **scope cut to confirm**, not a silent one.
- Keyboard up: `expandedHeight = geometry.size.height` (the GeometryReader already shrinks by the keyboard safe area; verify in S3). The strip is hidden (opacity 0, no hit testing). Today the viewport `ignoresSafeArea(edges: .bottom)` (`:346`), so it stays under the keyboard, and the layout must not let it push the card.
- Constants live next to the 0.45 cap: `collapsedMaxFraction 0.45`, `expandedFraction 0.75`, `minCameraStrip 170`.

### Morph

Do not use `matchedGeometry` or `glassEffectID`: there is one glass element and no identity change.

- `resultPanel` (`:204-249`): `.frame(height: isDetailsExpanded ? expandedHeight : min(resultContentHeight, maxHeight))`. Keep the one `ScrollView` and the one `FoodCameraResultPanel`. Header and servings keep view identity because `.id(content.kind)` does not change on expansion (`FoodCameraResultPanel.swift:72`). Only the area below servings swaps from the action row to the Form plus Log, so the header does not crossfade.
- `.scrollDisabled(!isResultExpanded || isDetailsExpanded)` (`:242`). The Form is the single scroller; there is no nested scroll to fight.
- The expanded panel gets an inner fixed height (`expandedHeight − 32`) so measured content equals the frame and `resultContentHeight` still agrees with it.
- Animation: add `.animation(layoutAnimation, value: isDetailsExpanded)` and `value: isKeyboardVisible` beside `:80-81`. Both ride the existing `layoutAnimation` (`:268`), which is `nil` until `cameraCardVisible`. **Zoom regression guard:** no new animation modifier may exist outside `layoutAnimation`; expansion cannot happen before reveal (`stagedResultPanel` disables hit testing, `:263`). Reveal, soften and restore code (`:354-378`) is untouched.
- Rename `isResultExpanded` (`:570-577`, it means "has an actionable result") to `hasActionableResult` to avoid colliding with the new state.
- Collapsed height guarantee: the collapsed code path is unchanged except `onReview` is removed from the init and Edit details calls `onDetails`. `CameraCardLayoutTests.swift:47` drops `onReview: {}`; its 960 measurements must stay identical.

### Pinned vs scrolling

```
glass card (single .glassEffect, FoodCameraSheet.swift:246)
 ├ pinned: nutrition header (live from editor.previewDraft × servings)
 ├ pinned: servings stepper
 ├ scrolls (Form, transparent): Source/notes · Required Review · Food · Nutrition (+ Show More) · Save as reusable
 └ pinned: Log (.glassProminent, disabled until editor.canSave)
```

- The expanded header drops the editable label title `TextField` (`:219`). The Name field in the Form is the editor.
- **Dynamic Type accessibility sizes:** the ring is already hidden and the layouts stack (`:185,:197,:265`). If the pinned region plus Log exceed 60% of the card (E2E at AX5 on the SE-class size), the header moves into the scroller (fallback; the criterion is checked in the E2E, not guessed).
- The ordering difference from `LogFoodScreen` (Quantity before the footer) is intentional: quantity is the pinned servings row.
- Small phones, 390 pt: `NutrientInputField` already stacks at accessibility sizes (`NutrientInputField.swift:30-37`).

## 3. Reuse and file plan

Two commits in the implementation PR. Commit 1 is a pure extraction with no behavior change, verified by identical E2E on search and saved-food Log. Commit 2 is the feature.

| File | Change | Est. diff |
|---|---|---|
| `App/FoodLogEditorModel.swift` (new) | `@MainActor @Observable`: draft, numericText, quantityMode, servings/grams, `errorMessage`, `confirmedZeroRequiredNutrients`, `baseline`; derived `loggingAction`, `canSave`, `nutritionPresentation`, `reusableFoodPersistenceMode`, `unresolvedRequiredReviewNutrients`, `combinedReviewNotes`, `reviewSectionTitle`, `isDirty`, `pruneResolvedZeroConfirmations`. Moved from `LogFoodScreen.swift:18-141,290-308`. | +150 |
| `App/FoodLogEditorSections.swift` (new) | `FoodDraftEditorForm` call with `FoodDraftSourceSection`, Required Review, optional `FoodQuantitySection`, reusable footer, the preview-image sheet and prune `onChange`. Moved from `LogFoodScreen.swift:143-217,233-257`. Takes `showsQuantity: Bool`. | +110 |
| `Features/AddFood/LogFoodScreen.swift` | Wrapper: holds `@State model`, the sections view, bottom bar, title, `saveEntry`/`persistEntry`. The init signature and defaults stay byte-identical, so the 4 non-camera call sites (`AddFoodSearchResults:223,303`, `RemoteSearchSelectionScreen:17`, `AddFoodComponents:51`) are untouched. | −170 / +45 |
| `Features/Scan/Camera/FoodCameraDetailsEditor.swift` (new) | Embedded sections + Log row, keyboard-visibility, accessibility focus. | +80 |
| `Features/Scan/Camera/FoodCameraResultPanel.swift` | `detailsEditor` param; expanded branch composes the existing `foodNutritionRow`/`servingsRow` with the editor's values; `isEditable` on `foodTitle`; remove `onReview`. | +45 / −5 |
| `Features/Scan/Camera/FoodCameraSheet.swift` | Delete `logDestination` (`:51`, `:87-97`, `:144-146`) and `FoodCameraLogDestination` (`:600-607`). Add `detailsEditor`, expanded height, keyboard state, landscape layout, discard dialog, `preview` gated on `detailsEditor == nil` plus `scannerController = nil` on expand. | +70 / −35 |
| `Features/Scan/Camera/FoodCameraSheet+Actions.swift` | `openDetails()` replaces `showDetails`/`showLabelReview`; `showManualRecovery` opens the editor; `logBarcode(servings:)` prefers the editor's action; `resumeScanning` clears the editor. | +40 / −25 |
| `Features/Scan/Camera/FoodCameraFlow.swift` | Event `recoveryDraftOpened` (`.recovering` → `.showingBarcode`). | +6 |
| Tests | `FoodCameraFlowTests` +25; new `FoodLogEditorModelTests` +50; `CameraCardLayoutTests` −1. | +75 |
| Docs | `changes-log.md` (one entry), evidence folder `docs/evidence/camera-inline-details/`. | small |

Net app code is about +500 / −250.

Reuse details that need to be exact:
- `FoodDraftEditorForm`, `FoodDraftFormSections`, `FoodQuantitySection`, `FoodDraftSourceSection`, `BottomPinnedActionBar` are **unchanged**; their other callers (`EditLogEntryScreen`, manual entry, reusable food editor) are untouched.
- Transparent Form: apply `.scrollContentBackground(.hidden)` and a formStyle or listStyle from the embedding site only. Spike S1 picks between `.formStyle(.columns)` / `.listStyle(.plain)` and hidden-background grouped rows. Rejected: opaque grouped rows on glass (a second filled surface).
- The Form's `keyboardNavigationToolbar` (`FoodDraftEditorForm.swift:82`) needs a toolbar host. The camera already sits in a `NavigationStack` with only the nav bar hidden (`FoodCameraSheet.swift:84`). Verified in S2.
- Possible behavior difference: today's Edit details for a label passes the panel's (renamed) draft as `initialDraft`; the plan uses `labelInitialDraft ?? draft`, which matches today's card Log (`+Actions.swift:201`). Reusable-copy messaging differs only for external foods with a foodItemID. Confirm in E2E.
- `FoodQuantitySection` is not embedded, which drops grams logging in the camera (Q3).

## 4. The camera while expanded

| Topic | Decision |
|---|---|
| Session | Tear down the `DataScannerViewController` on expand: `preview` renders only when `canLiveScan && detailsEditor == nil`; on expand set `scannerController = nil`. The existing comment (`FoodCameraSheet.swift:302-305`) justified staying hot for seconds; editing is unbounded. |
| Restart | Scan again → `.scanAgain` effect `.startScanning` → `startScanner()` finds `scannerController == nil` → `pendingScannerStart = true` → `onReady` of the new preview starts it (`:543-546`, `+Actions.swift:259-263`). This is the same path as first launch. Cost: about 0.5–1 s cold start on Scan again (cited in `changes-log.md:130`). If device QA finds this objectionable, revert to keep-running (one conditional). |
| `stopScanning` with nil controller | Already optional-chained (`:503`). |
| Freeze-frame | Keep `frozenImage` (`:306-316`). It is `scaledToFill` center-cropped into the short strip. E2E screenshot checks the crop reads sensibly. The existing 0.2 dim stays, since it is not Liquid Glass. |
| Torch | Already off: a result implies a non-scanning phase (`torchToggled` only in `.scanning`, `FoodCameraFlow.swift:77`), and the options rail is hidden while frozen. Nothing to add. |

## 5. Accessibility and Liquid Glass

- VoiceOver order is natural top to bottom: card header, servings, Form, Log, then Scan again and Close. On expand, post `AccessibilityNotification.LayoutChanged` and move `@AccessibilityFocusState` to the header (trait `.isHeader`, label "Food details"). After Log, post an `AccessibilityNotification.Announcement("Logged")`.
- Strip controls already hide from VoiceOver while frozen (`FrozenHidden`, `:586-597`); Scan again and Close stay reachable. Close and Scan again are 44 pt+ targets.
- Liquid Glass: one `.glassEffect(.regular, in: .rect(cornerRadius: 24))` on the container, kept as is (`:246`). No `glassEffect` on rows, sections or the header. No tints and no extra dimming. Log keeps `.glassProminent` and the capsule shape with `controlSize(.large)` (`:298`). Scan again keeps `.glassProminent` (`:288`). The Form is transparent.
- Honest note: glass-style buttons already sit inside the glass card today (`FoodCameraResultPanel.swift:294-312`). This plan adds no new glass layer. It does not fix that precedent.

## 6. Removal checklist

Grep confirms `FoodCameraLogDestination` and `logDestination` are referenced only in `FoodCameraSheet.swift` (`:51,87,144,600`) and `FoodCameraSheet+Actions.swift` (`:209,217,228`); no test or other feature uses them.

Delete: `logDestination` state, the `navigationDestination(item: $logDestination)`, its `onChange`, the `FoodCameraLogDestination` struct, `showDetails`, `showLabelReview`, the panel's `onReview` closure. **Keep:** `route`/`FoodCameraRoute` (`:735-739`) for Search online and the no-recovery manual path; `captureImageData` (feeds the preview-image action) and `labelInitialDraft`; the `logError` alert (`:191-201`).

## 7. Test plan (E2E first; red before green)

Rule check: no unit tests after code. Two isolated suites are justified because they are pure and cheap; their failure modes are listed first and the tests are written before the code.

**Isolated, written first**
- `FoodCameraFlowTests`, new event `recoveryDraftOpened`. Failure modes: accepted from `.scanning`/`.showingLabel`/`.lookingUp` (must be rejected); Log still rejected from `.recovering` without it; `isSaving` double commit after it; `scanAgain` afterwards fails to reset servings; dismissed phase accepts it; second event re-enters. Existing tests at `FoodCameraFlowTests.swift:138-196` are the pattern.
- `FoodLogEditorModelTests`, `isDirty`. Failure modes: edit then revert text reads dirty; invalid numeric text ("1.") reads clean; servings-only change; confirmed-zero toggle; name whitespace-only edit; baseline vs `initialDraft` mixed up for labels; opening a label with a collapsed-card rename reads dirty at open.

**E2E**

Setup: iPhone 17e (390 pt) simulator from the repo inventory, never the owner fixture; iOS 27.0; Debug build; the T3 device tools. Label path: `xcrun simctl addmedia <udid> docs/app-store/fixtures/oat-crunch-nutrition-label.png`, then Camera → More → Choose a Photo. Barcode path: `docs/evidence/camera-card-layout-shift/fixture.patch`, applied temporarily, never committed. Extend it with a `-CameraLayoutFixture label-missing` variant (DEBUG only) that sets `missingNutrients` because no committed fixture has unreadable values. Red: run each scenario on `origin/main`; Details pushes a page, so the "no push + card ≥ 70%" assertion fails. Green: same script after.

| # | Scenario | Assertion | Artifact |
|---|---|---|---|
| E1 | Expand (barcode, label) | Details does not push; card frame height is 70–80% of the screen; strip is 20–30%; Scan again visible | `heights.json` (card and strip frames), before/after screenshots |
| E2 | Morph smoothness and zoom guard | Frame-sampled recording of expand and of camera open from the dashboard. Card x-range stays inside safe width for the whole zoom; no pop of header; no wide zoom (regression of the build-28 fix) | recording, contact sheet, `zoom-frames.json` |
| E3 | Edit a nutrient | Calories 160 → 200; header kcal updates live; Log writes 200 kcal | accessibility-tree JSON, dashboard screenshot |
| E4 | Required Review (`label-missing`) | Log disabled; confirm-zero toggles enable it; value entry also enables it | before/after screenshots, tree JSON |
| E5 | Log from expanded | Collapses to Logged; entry exists with edited values; reusable copy created only when messaged | dashboard screenshot, Logged card screenshot |
| E6 | Scan again, dirty | Dialog appears; Keep Editing preserves text; Discard returns to the live camera with edits gone | three screenshots |
| E7 | Scan again and Close, clean | Immediate, no dialog | screenshot pair |
| E8 | Keyboard | Tap a nutrient field: strip hidden, card fills space above keyboard, field visible, toolbar Next/Done works, Done restores the 75% layout | screenshot per state, frames JSON |
| E9 | Accessibility size + SE-class size | Accessibility Extra Large and the largest accessibility size on 390 pt and on an SE-class size (reuse the existing device inventory; do not create one): pinned region under 60% of the card; strip floor 170 pt | screenshots, `heights.json` |
| E10 | VoiceOver and Reduce Motion | Focus lands on "Food details"; order as in section 5; Reduce Motion: instant resize, no blur or offset | tree JSON, short recording |
| E11 | Enter manually | Failed lookup → Enter manually opens inline; Log disabled until a name; then logs | screenshots |
| E12 | Regression: other callers | Search result and saved food still push `LogFoodScreen`; layout and Log unchanged | before/after screenshot pairs (commit 1 must be pixel-identical) |
| E13 | Landscape | Side-by-side layout (or documented cut) | screenshot |

Gates before the feature commit (each produces an artifact; if one fails, the plan's fallback applies):
- S1 Form transparent on glass: rows readable, no second filled surface.
- S2 Keyboard toolbar inside the camera `NavigationStack`.
- S3 Frame morph plus keyboard height without double animation.
- S4 The glass shape follows the animated frame without artifacts.

Final validation: `make quality-format-check`, `make quality-build`, `FoodCameraFlowTests`, `FoodLogEditorModelTests`, `CameraCardLayoutTests` (960 measurements unchanged), and the full serial iPad suite excluding `PurchaseStoreStoreKitTests`. Then `/defensive-code-review` per `AGENTS.md`.

## 8. Risks and owner questions

Risks (engineering, with mitigations above): `Form` styling on glass (S1); keyboard geometry (S3); landscape cost; accessibility-size pinned region; cold start after teardown; extraction touching `LogFoodScreen` (isolated in commit 1).

**Q1. Scan again or Close with unsaved edits.** Options: discard silently / confirm always / confirm only when dirty. **Recommend: confirm only when dirty.** A label with typed values is real work, and a clean expand-and-leave shouldn't nag.

**Q2. After Log from the expanded card.** Options: stay in the camera and show the Logged card (today's card Log) / close the camera (today's Details → Log). **Recommend: stay in the camera.** It supports scanning several items and keeps one log path. This changes today's Details → Log, which closes the sheet.

**Q3. Grams logging mode.** The Details page offers Servings/Grams. The pinned servings stepper replaces the Quantity section, so the camera loses grams logging (the card Log is servings-only today). Options: accept / keep the Quantity section in the scroller and unpin the stepper. **Recommend: accept.** It is what the owner described ("under your serving size"), and grams are still available from search and saved foods.
