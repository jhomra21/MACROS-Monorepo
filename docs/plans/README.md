# Plans

Status as of 2026-11-05. Moving a tracker does not close a check. Dated build numbers, machine assignments, failures, and results remain historical; source currently configures version 1.0/build 33, not proof of release approval.

## Active and blocked

Release owner owns App Store/account/device gates; native maintainer owns app checks; service maintainer owns backend checks. Completion requires a dated report with the exact source/build and observed result, not a build pass or an archived screenshot.

| Plan | Status | Next verification |
| --- | --- | --- |
| [TestFlight release](active/testflight-release-tracker.md) | Blocked on owner/device | Retain all three open checkboxes, reconcile old build-8/group wording against current App Store Connect, record device results and complete submission metadata |
| [Pro/StoreKit](active/pro-subscription-storekit-tracker.md) | Blocked on device/account | Sandbox all plans/trial/cancel/manage/redeem, second-device restore, lifetime Family Sharing, legacy purchase; reconcile dated simulator failures with a new bounded run |
| [App Store products](active/app-store-connect-products-tracker.md) | Blocked on owner | Verify products, prices/localizations, trial, review screenshots and submission in App Store Connect |
| [Shared widget implementation](active/shared-person-widget-implementation.md) | Implemented, release blocked | 1.0 approval/cutover, distribution entitlements and hardware first-unlock protection; no production authorization implied |
| [Unified sharing](active/unified-sharing.md) | Active, phases 1 to 3 built; phases 2 and 3 await owner review | Phases 1 to 3 approved: shared code cleanup, Share screen with sizes, detail choice and auto-copied caption, and a Share with a person row. Instagram Stories, Snapchat and TikTok deferred |
| [Sharing v2](active/sharing-v2-plan.md) | Implemented in part, release blocked | Owner approves release sequence, notification URLs, real Sandbox verification and Pro enforcement timing |
| [Sharing v2 backend validation](active/sharing-v2-backend-validation.md) | Local checks complete, live blocked | Authorized deployed Node/runtime check, valid real Sandbox transaction, subscription transport and notifications |
| [Sharing](active/sharing-implementation-tracker.md) | Active, optional polish | Valid-invite name confirmation checkbox, domain/universal-link decision; exact subscription counts, rollover, network retry, invalid/expired/replayed invites |
| [Meals](active/meals-implementation-tracker.md) | Active, optional polish | Decide whether saved-meal Settings management is needed; retain its open checkbox |
| [Unified camera](active/unified-camera-tracker.md) | Active/device blocked | Unknown-product dismissal/recovery checkbox; live camera/torch/OCR, Add Food morph, Reduce Motion, exact swipe landing and Home Screen Quick Action |
| [Retention](active/retention-polish-tracker.md) | Implemented, device check blocked | Barcode 429 non-retryable/Retry-After feedback on TestFlight with camera |
| [Weight/Health/reminders](active/weight-health-reminders-tracker.md) | Implemented, hardware checks blocked | Health authorization/write/readback, delivered notification cold/background taps, multiple/smart firing times |
| [Bundled foods](active/bundled-food-database-tracker.md) | Implemented, device checks open | Saved barcode digits, brand prefix and mixed meal/food ordering |
| [Typed quantity entry](active/typed-quantity-entry.md) | Proposed, not started | Owner request 2026-11-07: tap Servings/Grams to type an exact amount; settle validation rules, then E2E |
| [Website/legal](active/website-legal-metadata-tracker.md) | Implemented, submission open | Release owner reconciles listing placeholders, privacy mapping, screenshots, review notes/URLs and age rating |

## Completed implementation records

These records retain limitations. Their outstanding checks also appear in [release follow-ups](active/release-follow-ups.md).

- [Architecture refactor](archive/architecture-refactor-implementation-tracker.md): implemented; old claim that CLI tests are undocumented is superseded by the validation guide.
- [Insights](archive/insights-implementation-tracker.md): V1 implementation complete.
- [Backup/import/export](archive/backup-export-import-tracker.md): implementation/simulator E2E complete; device Files round-trip remains.
- [Camera inline details](archive/camera-inline-details-plan.md): implemented/simulator-validated, not full device sign-off.
- [Insights long ranges](archive/insights-long-ranges-tracker.md): implemented; macro panning and exhaustive combinations remain unverified.
- [Packaged food reliability](archive/packaged-food-search-reliability-tracker.md): implemented; deferred stale-cache strategy/UI affordances are not promised work.
- [State-machine F2/F3](archive/state-machine-fixes.md): implemented; F1/F4 and 11 suspects are separate work.
- [Goal calculator/onboarding](archive/goal-calculator-onboarding-tracker.md): implemented and validated as recorded.
- [Services hardening](archive/services-hardening-tracker.md): implemented; 429 device feedback remains under retention.
- [Dependency update](archive/dependency-update-tracker.md): completed dated upgrade; codegen/toolchain caveats remain historical, not release sign-off.

## Superseded planning

- [Launch program](archive/launch-program-tracker.md): dated coordination, build numbers and machine roles, not current root instructions. Unclosed checks move forward below.
- [Original shared-widget plan](archive/shared-person-widget-plan.md) and [review](archive/shared-person-widget-plan-review.md): implementation is recorded in the active widget tracker; release and negative-case limitations remain open.

## Before/after obligation audit

All 26 source trackers moved, none deleted. Six unchecked boxes remain six: TestFlight 3, meals 1, sharing 1, unified camera 1. No checkbox was checked by cleanup.

[Release follow-ups](active/release-follow-ups.md) assigns owners and closure evidence. [Obligation inventory](active/obligation-inventory.md) enumerates every pre-move unchecked box and prose candidate, including historical/resolved statements for conservative review. The local before/after comparison checks those original lines survive in their moved source. A candidate's inclusion is not a claim it is still a product defect. Never close an item without reconciling later evidence explicitly.
