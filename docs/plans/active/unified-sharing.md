# Unified sharing

Status: active. Owner decisions recorded 2026-11-10; the research plan from that day follows.

Progress: phase 1 merged. Phases 2 and 3 implemented on `app/share-screen` and awaiting owner review: Home share button opens a Share sheet (Story/Post/Square, Rings/Macros/Full, editable caption copied on Share, "Share with a person" row). `NSPhotoLibraryAddUsageDescription` added; Save Image saved nothing on the simulator without it. Evidence: [unified-sharing evidence](../../evidence/unified-sharing/README.md). Phase 4 (Instagram Stories) is not started.

Round 2 (TestFlight build 34 feedback, branch `app/share-menu`): the Share sheet opens at full height, and the person row is gone from it. The Home share button opens a menu with "Post an image" and "Live sharing". Evidence: [Round 2](../../evidence/unified-sharing/README.md#round-2-menu-and-full-height).

## Owner decisions (2026-11-10)

- Round 2 decision: the Home share button opens a menu with "Post an image" (opens the Share sheet) and "Live sharing" (Sharing dashboard for Pro with sharing on, setup otherwise). The sheet has only the large detent. This supersedes the "Share with a person" row below. The swipe past today still opens Sharing.

- Direction approved: one Share entry on Home with "Post an image" and "Share with a person". Shared presentation code. Person-sharing backend stays separate.
- Build now: phase 1 (code cleanup), phase 2 (share screen with Story/Post/Square sizes, detail choice, caption), phase 3 ("Share with a person" row).
- Not now: Instagram Stories button (needs a Meta developer app), Snapchat, TikTok SDK.
- Posting: one Share button opens the system share sheet with the image attached; the caption is copied to the clipboard automatically when Share is tapped, with a short "Caption copied" note. No per-app icon buttons (not possible without each platform's developer registration).
- Default caption: "My macros today, tracked with MACROS. macrosios.com". Editable; hashtags off.
- Image default: rings and macros only. Extra nutrition (fiber, sugars, sodium, cholesterol, saturated fat) is opt-in. Food names never appear on the image.
- Keep the swipe past today on Home that opens Sharing.

## Research plan (Fable 5.2, 2026-11-10)

Research only. No code, builds, or simulator runs were done. Paths are relative to `cal-macro-tracker/`.

### Short answer

Do not merge the two features. Unify the entry point and the small pieces of presentation code they share. Keep the data paths and backend separate.

They are different products that happen to share a word. The image share is a one-time public broadcast of a rendered picture, made on device, with no account. Person sharing is a live, private, revocable sync with identity, grants, and Pro rules. Forcing them into one model would pull Convex and auth concepts into a feature that must work offline and free.

### A. What to unify, and at what layer

**What exists today**

- Image share: toolbar button in `Features/Dashboard/DashboardShareSupport.swift:8-15`, render in `DailyShareImageExporter.swift:31-48`, card in `DailyShareCardView.swift:8-25`, sheet presented at `DashboardScreen.swift:132-133`.
- Person sharing: reached by swiping past today (`DashboardScreen.swift:381-388`) or Settings (`Features/Settings/SettingsScreen.swift:64-66`). There is no visible button for it on Home.

**Unify: entry point (yes).** One Share button on Home that offers "Post an image" and "Share with a person". This fixes the real user problem: person sharing is hidden behind a swipe, and the two features look unrelated.

**Unify: presentation code (yes, small).** Duplication found:

1. Three share sheet wrappers. `ShareSheet` (`DailyShareImageExporter.swift:83-91`) and `URLShareSheet` (`App/URLShareSheet.swift:4-12`) are the same `UIActivityViewController` wrapper with different payloads. Invites use `URLShareSheet` in `SharingDashboardScreen.swift:75` but `ShareLink` in `SharingScreen.swift:58`. Pick one path.
2. `SharedDailySnapshot` to `NutritionSnapshot` conversion is written twice: `SharingPersonScreen.swift:60-65` and `SharingDashboardScreen.swift:108-111`. Add one `totals` property beside `macroGoalsSnapshot` (`SharingSyncModels.swift:175`).
3. The "kcal, P, C, F" summary line is hand-built in `SharingDashboardScreen.swift:166-168`, `SharingPersonScreen.swift:91-95` and `:138`, `Shared/FoodNutritionRow.swift:59`, and `Features/Insights/InsightsChartCards.swift:180`. One formatter.
4. Rings plus macro columns are composed separately in `DailyShareCardView.swift:12-15` and `SharingPersonScreen.swift:69-87`. Both already use `MacroRingSetView`, so the renderer is shared. Extract one "day summary" view that takes totals, goals, and a detail level.

**Unify: one detail-level type (yes, local only).** A `ShareDetail` enum (`rings`, `macros`, `macrosAndFoods`) that says what a card shows. The image share uses it as a user choice. `SharingOutgoingScope` (`SharingSyncModels.swift:76-80`) stays the server grant and maps to it for display. Do not make them the same type: one is a rendering option, the other is an authorization record with server meaning.

**Keep separate.** Convex, `worker/auth`, `SharingSyncService`, identity, invites, the widget, and Pro gating. The image share must never import any of it. No image upload, no public profile pages.

**Cleanup to fold in.** `SharingScope` (`SharingSyncModels.swift:82-84`) looks like a leftover next to `SharingOutgoingScope`; confirm against the v2 plan before removing. The temporary preview at `DailyShareCardView.swift:58-60` is marked for removal.

### B. Making social posting easier

**What the image reveals today.** Date, rings, macro columns, and secondary nutrition (fiber, sugars, sodium, cholesterol, saturated fat) at `DailyShareCardView.swift:17`. No food names, no weight. The default should be rings and macros only, with secondary nutrition as an opt-in.

**Current gaps.** One format (390 pt wide, variable height), no caption, no link, and the sheet goes through a custom `UIActivityItemSource`.

| Option | What it takes | Trade-off |
| --- | --- | --- |
| `ShareLink` with a `Transferable` image and `message:` caption | No SDK, no registration | Apple says only "some share activities support subject and message fields", so the caption is best effort. Add a "Copy caption" button. |
| Instagram Stories | URL scheme `instagram-stories://share?source_application=<id>` plus pasteboard keys `com.instagram.sharedSticker.backgroundImage` or `stickerImage`; add `instagram-stories` to `LSApplicationQueriesSchemes` | No SDK in the binary. Meta requires a Facebook App ID since January 2023, so you must register a Meta developer app. Background minimum 720x1280, 9:16 recommended. Writes to the general pasteboard for up to 5 minutes. |
| Snapchat Creative Kit Lite | URL scheme plus pasteboard, no SDK | Requires registration at kit.snapchat.com and prior approval from Snap, plus a Client ID. Do not enable the optional IDFV sharing. |
| TikTok Share Kit | TikTok OpenSDK (Swift package), developer app approval, client key in `Info.plist`, URL handling in the app delegate | A real third-party SDK. It shares by Photos `localIdentifiers`, so the image must first be saved to the user's library. Last release 2.5.0 in September 2024. Not worth it now. |
| X | System share sheet for images. The web intent `https://x.com/intent/tweet` takes `text`, `url`, `hashtags`, `via` only | The intent has no image parameter. Text and link only, so the share sheet is the right route. |

**Formats.** Story 9:16 at 1080x1920, feed 4:5 at 1080x1350, square 1080x1080. 9:16 is what Meta and Snap recommend. The 4:5 feed size is a common convention that I did not verify in Meta's docs.

**Caption.** "My macros today, tracked with MACROS. macrosios.com" with hashtags off by default. Always editable.

**Recommended first step.** Native share sheet with three formats, a detail picker, and a caption with copy. No SDK, no registration, no privacy label change.

**Second step.** A direct Instagram Stories button, sending the card as a sticker over a solid background. It needs a Meta app registration but adds no SDK. Hide the button when Instagram is not installed.

**Later.** Snapchat only if users ask. TikTok only if the owner accepts an SDK.

Sources: [ShareLink](https://developer.apple.com/documentation/swiftui/sharelink), [Instagram Sharing to Stories](https://developers.facebook.com/docs/instagram-platform/sharing-to-stories), [Snap Creative Kit](https://developers.snap.com/snap-kit/creative-kit/overview) and [Creative Kit Lite](https://github.com/Snapchat/creative-kit), [TikTok OpenSDK](https://github.com/tiktok/tiktok-opensdk-ios), [X web intent](https://docs.x.com/x-for-websites/post-button/guides/web-intent). The TikTok developer site blocked fetching, so TikTok facts come from its official GitHub README.

### C. UX sketch

**Entry.** The Home toolbar share button opens a menu ("Post an image", "Live sharing"). "Post an image" opens a sheet at full height. (Round 2; the first version opened the sheet directly with a medium detent.)

**Sheet layout.**

1. Live preview of the card for the selected day.
2. Segmented picker for format: Story, Post, Square.
3. Segmented picker for detail: Rings, Macros, Full nutrition. Food names are never on the image in this phase.
4. Caption field with a Copy button.
5. Primary button "Share image" (system sheet). Optional "Instagram Story" button in step two.
6. (Superseded in round 2.) The person row moved out of the sheet into the "Live sharing" menu item, which shows "With N people" for Pro with sharing on.

**States.** Rendering (progress in the preview), render failed (retry, as the existing alert at `DashboardScreen.swift:135` does), empty day (allow, show zeros), Instagram not installed (button hidden), sharing off or not Pro (row leads to setup or the paywall).

**Other entry points.** A person screen should not offer image export: it would publish someone else's data. Insights could gain a weekly card later; leave it out now.

**Pro vs Free.** Image share stays free with no account. Person sharing keeps its current Pro rules.

**Accessibility.** Label each picker, give the preview an accessibility label that reads the numbers, keep 44 pt targets, support Dynamic Type in the sheet (the exported image keeps fixed sizes), and respect Reduce Motion.

**Liquid Glass.** System sheet, `Picker(.segmented)`, standard bordered buttons, `ShareLink`. No custom tints. Third-party logos must follow each platform's brand rules, so use a text label with an SF Symbol if unsure.

### D. Phases

**Phase 1: tidy shared code. No behavior change.**

- Failure modes: card pixels change by accident; widget target breaks because a moved file changes synchronized group membership; invite sharing regresses.
- Work: the four duplication items in section A.
- E2E: on a simulator, export the card before and after and compare images; create and share an invite.

**Phase 2: Share sheet with formats, detail, and caption.**

- Failure modes: `ImageRenderer` returns nil at larger sizes (today's code retries three times, `DashboardShareSupport.swift:80-91`); text clips in 9:16 or at large numbers; dark mode exports a transparent or wrong background; caption is dropped by the target app; the share warm-up (`App/AppWarmupCoordinator.swift:20-28`) or the review-prompt idle check (`App/AppRootView.swift:145`) stops matching the new flow; the dashboard tutorial step that opens Sharing breaks.
- Check first: I found no `NSPhotoLibraryAddUsageDescription` in the repo (`config/apple/Info-iOS.plist` has only `NSPhotoLibraryUsageDescription` at line 53). Confirm on a device that "Save Image" works today.
- E2E: XCUITest drives Home, opens the sheet, switches each format and detail, and writes the three PNGs as the artifact. Assert pixel sizes and that no food name appears.

**Phase 3: "Share with a person" row.**

- Failure modes: free users hit a dead end; the row shows stale counts when sharing is off; remote failure blocks the image path.
- E2E: free and Pro fixtures, sharing on and off, offline.

**Phase 4: Instagram Stories button.**

- Failure modes: missing or wrong App ID gives Instagram's "doesn't currently support sharing to Stories" error; pasteboard content lingers; `canOpenURL` false; Meta changes rules.
- E2E: the simulator has no Instagram, so automate only the hidden-button case. The real post needs a manual device check, recorded as such.

**Docs and privacy.**

- Phases 1 to 3: no privacy label change. Nothing leaves the device unless the user sends it. Update `changes-log.md` and the plans index.
- Phase 4: add one sentence to `web/src/pages/privacy.astro` saying the image goes to Instagram only when the user taps the button. The claim at line 61 ("no analytics SDK or advertising tracker") stays true. `PrivacyInfo.xcprivacy` and the App Store label should not change, since MACROS collects nothing new, but confirm against Apple's definitions before release.
- TikTok SDK, if ever added: the SDK ships its own privacy manifest, the privacy page must name it, and the label must be reviewed. Line 61 would need rewording.

### E. Open questions

1. Is registering a Meta developer app (and showing a Facebook App ID in the build) acceptable for the Instagram button?
2. Should food names ever be allowed on a public image, as an explicit opt-in?
3. Caption wording, and are hashtags wanted at all?
4. Should Home keep the swipe to Sharing once the menu has Live sharing? (Kept for now.)
5. Is a weekly Insights card worth a later phase?
6. Any appetite for the TikTok SDK, given the privacy position?
