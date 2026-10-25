# App Store Connect Products Tracker (WS9)

Branch `launch/ws9-asc-products`. Manual App Store Connect setup selected 2026-10-25; the API script path is dropped. See the [click-by-click product checklist](../docs/app-store/asc-products-checklist.md).

## Products to create (must match WS2 exactly)

- Subscription group: reference name `MACROS Pro`.
  - `macros.pro.yearly`: reference name "MACROS Pro Yearly", duration 1 year, US price $19.99 (choose the matching price point; let Apple equalize other storefronts), introductory offer: free trial, 1 week, all new subscribers, no end date. Localization en-US: display name "MACROS Pro (Yearly)", description "Insights, weight trends, weight import from Apple Health, backup, custom colors, smart reminders."
  - `macros.pro.monthly`: reference name "MACROS Pro Monthly", 1 month, US $2.99, same localization pattern, no intro offer.
  - Subscription group localization en-US: "MACROS Pro".
- Non-consumable `macros.pro.lifetime`: reference name "MACROS Pro Lifetime", US $49.99, Family Sharing on, localization "MACROS Pro (Lifetime)".
- Each product needs a review screenshot (use the paywall screenshot from WS2's QA artifact) and review notes before submission. The first subscription must be submitted together with a new app version.

## Decision (2026-10-25)

- Manual App Store Connect setup is the chosen path. The API script path is dropped; no API key or API automation is needed.
- Follow [docs/app-store/asc-products-checklist.md](../docs/app-store/asc-products-checklist.md) for verified navigation, fields, pricing, localization, review, sandbox, and final product-ID checks.
