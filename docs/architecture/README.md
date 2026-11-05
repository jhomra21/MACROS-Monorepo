# Architecture

MACROS keeps primary tracking local. Supporting packages are separate install and validation units, not an Xcode build dependency chain.

## Native app and persistence

[The app entry](../../cal-macro-tracker/cal_macro_trackerApp.swift) creates the local services and SwiftUI scene. [AppRootView](../../cal-macro-tracker/App/AppRootView.swift) owns root navigation; Features contains AddFood, Scan, Dashboard, History, Insights, Settings, Purchases, Sharing, Weight, Health, Reminders, Backup, and Onboarding.

[AppModelContainerFactory](../../cal-macro-tracker/Data/Services/AppModelContainerFactory.swift) delegates persistent storage to [SharedModelContainerFactory](../../cal-macro-tracker/Shared/SharedModelContainerFactory.swift). SwiftData models include goals, body profile, foods, meals/components, log snapshots, and weights. The shared app-group store disables CloudKit, applies file protection, and migrates a legacy store with SQLite backup and staged publication. Data/Services repositories own local persistence; views do not need an account to log food.

Shared contains nutrition snapshots, app-group configuration, formatting, and widget storage used by selected targets. Xcode's synchronized groups determine membership; directory proximity alone does not mean every file belongs to both targets.

## Widgets and purchases

[CalMacroWidgetBundle](../../cal-macro-tracker/CalMacroWidget/CalMacroWidgetBundle.swift) registers personal and shared-person widgets. Providers read local snapshots or fetch authorized shared data, rather than driving app navigation or local logging. Shared-person credentials/cache/control records live behind Shared types. Privacy and revocation checks must survive app closure.

[PurchaseStore](../../cal-macro-tracker/Features/Purchases/PurchaseStore.swift) owns StoreKit Pro plans and legacy lifetime support. The `config/apple/MACROSPro.storekit` catalog serves local testing; it is not the production product catalog. Backend Pro verification is separate from local Debug/Xcode entitlements.

## Optional sharing

[SharingSyncService](../../cal-macro-tracker/Features/Sharing/SharingSyncService.swift) coordinates optional uploads, live dashboard subscription, identity generations, and widget control. Remote failures must not block local logging or delete SwiftData data.

[worker/auth](../../worker/auth/) exchanges sharing identity for auth tokens and redirects invites. [convex-backend/convex](../../convex-backend/convex/) owns profiles, invites, relationships, grant intervals, daily snapshots, optional food days, quotas, and verified Pro state ([schema](../../convex-backend/convex/schema.ts)). The app and extension enforce privacy in addition to server authorization. Generated backend instructions and APIs keep their current ownership.

## Food search and website

[worker/usda-proxy](../../worker/usda-proxy/) owns food-provider adapters, normalization, cache, deadlines, rate limiting, and the shared USDA Durable Object budget. The app consumes its contracts and reviews uncertain nutrition before persistence.

[web](../../web/) uses Astro pages/components for public content and a separate Worker entry for support/waitlist APIs with D1 migrations and retention. Social images generate at build time using macOS Helvetica. Web publication and remote D1 migration are explicit operations, not checks.

## Validation boundaries

[cal-macro-trackerTests](../../cal-macro-trackerTests/) holds native fixtures and XCTest. [Runtime QA](../../tools/runtime-qa/README.md) runs original Worker entries under loopback Miniflare with mocked upstreams; convex-test provides registered in-memory backend integration coverage. Neither replaces device, account, or production release checks. See [validation](../development/validation.md) and [plans](../plans/README.md).
