# App Store Connect Products Tracker (WS9)

Branch `launch/ws9-asc-products` (only if the API script is written). Mac. Consequential external action: run only in dry-run first, then live with the owner's explicit go-ahead.

## Products to create (must match WS2 exactly)

- Subscription group: reference name `MACROS Pro`.
  - `macros.pro.yearly`: reference name "MACROS Pro Yearly", duration 1 year, US price $19.99 (choose the matching price point; let Apple equalize other storefronts), introductory offer: free trial, 1 week, all new subscribers, no end date. Localization en-US: display name "MACROS Pro (Yearly)", description "Insights, weight trends, Apple Health sync, backup, custom colors, smart reminders."
  - `macros.pro.monthly`: reference name "MACROS Pro Monthly", 1 month, US $2.99, same localization pattern, no intro offer.
  - Subscription group localization en-US: "MACROS Pro".
- Non-consumable `macros.pro.lifetime`: reference name "MACROS Pro Lifetime", US $39.99, Family Sharing on, localization "MACROS Pro (Lifetime)".
- Each product needs a review screenshot (use the paywall screenshot from WS2's QA artifact) and review notes before submission. The first subscription must be submitted together with a new app version.

## Manual path (15 minutes, no code)

App Store Connect > Apps > MACROS > Monetization > Subscriptions > Create Subscription Group > add the two subscriptions, set prices (Subscription Pricing > Add Subscription Price), add the yearly introductory offer (Subscription Prices > Introductory Offers), add localizations. Then In-App Purchases > Create > Non-Consumable for lifetime, price, localization, Family Sharing. Finally App Privacy and the product review information.

## API path (optional)

- Prerequisite from the owner: an App Store Connect API key with the App Manager role: Key ID, Issuer ID, and the `.p8` file placed at `~/.private_keys/AuthKey_<KEYID>.p8` on the Mac. Never commit or print the key.
- `tools/asc/` (Bun + TypeScript, isolated package): ES256 JWT (20-minute expiry) and a thin client; verify every endpoint against the official OpenAPI spec downloaded from Apple's App Store Connect API page at run time. Expected resources: `apps` (filter by bundle id), `subscriptionGroups`, `subscriptions`, `subscriptionPricePoints`, `subscriptionPrices`, `subscriptionIntroductoryOffers`, `subscriptionLocalizations`, `subscriptionGroupLocalizations`, `inAppPurchases` (v2), `inAppPurchasePriceSchedules`, `inAppPurchaseLocalizations`.
- Idempotent: look up existing resources by product id before creating; `--dry-run` prints the plan; `--apply` executes and prints resulting ids. Report everything created.
