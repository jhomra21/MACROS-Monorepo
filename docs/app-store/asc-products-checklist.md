# App Store Connect product checklist

Manual setup for WS9. Do not change the product IDs, prices, durations, or offer terms below.

## 1. Prerequisites

1. Sign in to App Store Connect with a role allowed to create products (Account Holder, Admin, App Manager, Developer, or Marketing).
2. Under **Business > Agreements**, confirm the **Paid Apps Agreement** is Active. The Account Holder must accept it; banking and tax details must also be provided.
3. Confirm the app record exists under **Apps**. Open the MACROS app record before starting.

Apple Help: [Sign and update agreements](https://developer.apple.com/help/app-store-connect/manage-agreements/sign-and-update-agreements); [Overview for configuring In-App Purchases](https://developer.apple.com/help/app-store-connect/configure-in-app-purchase-settings/overview-for-configuring-in-app-purchases)

## 2. Create the subscription group

1. In the app, open **Monetization > Subscriptions**.
2. Click **+**, enter reference name `MACROS Pro`, then click **Create**.
3. Add the en-US group localization: **Display Name** `MACROS Pro`. Leave the app display option at its intended default.
4. Add the yearly product first: open the group, click **Create** (or **+** if products already exist), and enter:
   - Reference Name: `MACROS Pro Yearly`
   - Product ID: `macros.pro.yearly`
5. Open the product, choose **Subscription Duration** `1 Year`, and save.
6. Add the monthly product in the same group:
   - Reference Name: `MACROS Pro Monthly`
   - Product ID: `macros.pro.monthly`
   - Subscription Duration: `1 Month`
7. Both plans provide the same MACROS Pro access. Set both to the same subscription level. If you keep separate levels, rank the plan with the most benefits at level 1; do not imply an upgrade or downgrade where none exists.

Apple Help: [Offer auto-renewable subscriptions](https://developer.apple.com/help/app-store-connect/manage-subscriptions/offer-auto-renewable-subscriptions); [Auto-renewable subscription information](https://developer.apple.com/help/app-store-connect/reference/in-app-purchases-and-subscriptions/auto-renewable-subscription-information)

## 3. Set subscription prices

For each subscription:

1. Open **Subscription Prices > Add Subscription Price**.
2. Set country or region to **United States** and select the matching base price:
   - Yearly: **$19.99 USD**
   - Monthly: **$2.99 USD**
3. Click **Next**. Keep Apple's comparable storefront prices unchanged so Apple generates/equalizes the other storefront prices based on taxes and exchange rates.
4. Review the prices and click **Confirm**.

Apple Help: [Manage pricing for auto-renewable subscriptions](https://developer.apple.com/help/app-store-connect/manage-subscriptions/manage-pricing-for-auto-renewable-subscriptions)

## 4. Configure the yearly introductory offer

1. Open `macros.pro.yearly` and go to **Subscription Prices > View all Subscription Pricing**.
2. Select **Set up Introductory Offer**.
3. Select **all available countries or regions**, then click **Next**.
4. Set the start date to the intended launch date and configure no end date, if App Store Connect offers that choice. Apple's current Help page instructs users to select both start and end dates but does not document a no-end-date option. If the form requires an end date, stop and escalate; do not invent a date or alter the locked offer term.
5. Choose **Free**, duration **1 Week**, then proceed.
6. Keep Apple's generated storefront prices unchanged. Confirm the offer.
7. Do not create an introductory offer for `macros.pro.monthly`.
8. Apple allows one introductory offer per person per subscription group, even when multiple products have offers. The yearly offer is for all new subscribers who are eligible under Apple's group rules.

Apple Help: [Set up introductory offers for auto-renewable subscriptions](https://developer.apple.com/help/app-store-connect/manage-subscriptions/set-up-introductory-offers-for-auto-renewable-subscriptions)

## 5. Enter subscription localizations

Use **Display Name and Description > Add**, select **English (U.S.) / en-US**, and add the specified text:

| Item | Display name | Description |
| --- | --- | --- |
| Group | `MACROS Pro` | — |
| Yearly | `MACROS Pro (Yearly)` | `Insights, weight trends, Apple Health sync, backup, custom colors, smart reminders.` |
| Monthly | `MACROS Pro (Monthly)` | `Insights, weight trends, Apple Health sync, backup, custom colors, smart reminders.` |

Apple's current Help reference specifies 2–30 characters for an In-App Purchase display name and 45 characters maximum for its description. The WS2 subscription description is longer than 45 characters; enter it as specified and follow the limit shown by the subscription localization form if it differs. Apple's subscription Help page does not publish separate character limits for these subscription localization fields. Do not silently rewrite the spec.

Apple Help: [Offer auto-renewable subscriptions](https://developer.apple.com/help/app-store-connect/manage-subscriptions/offer-auto-renewable-subscriptions); [In-App Purchase information](https://developer.apple.com/help/app-store-connect/reference/in-app-purchases-and-subscriptions/in-app-purchase-information); [Auto-renewable subscription information](https://developer.apple.com/help/app-store-connect/reference/in-app-purchases-and-subscriptions/auto-renewable-subscription-information)

## 6. Create lifetime non-consumable

1. In the app sidebar, open **Monetization > In-App Purchases** and click **+**.
2. Choose **Non-Consumable**.
3. Enter reference name `MACROS Pro Lifetime` and product ID `macros.pro.lifetime`; click **Create**.
4. In **Price Schedule**, click **Add Pricing**. Select **United States**, choose **$39.99 USD**, click **Next**, keep Apple's generated storefront prices unchanged, then confirm.
5. Add en-US localization with display name `MACROS Pro (Lifetime)`. The WS9 product spec does not provide a lifetime description; do not substitute invented marketing copy. If App Store Connect requires a description before save, get approved wording from the owner.
6. In **Family Sharing**, click **Turn On**, review the terms, and confirm. **This cannot be turned off later.**

Apple Help: [Create consumable or non-consumable In-App Purchases](https://developer.apple.com/help/app-store-connect/manage-in-app-purchases/create-consumable-or-non-consumable-in-app-purchases); [Set a price for an In-App Purchase](https://developer.apple.com/help/app-store-connect/manage-in-app-purchases/set-a-price-for-an-in-app-purchase); [Turn on Family Sharing for In-App Purchases](https://developer.apple.com/help/app-store-connect/configure-in-app-purchase-settings/turn-on-family-sharing-for-in-app-purchases); [In-App Purchase information](https://developer.apple.com/help/app-store-connect/reference/in-app-purchases-and-subscriptions/in-app-purchase-information)

## 7. Review information and first submission

1. For each of the three products, scroll to **Review Information**.
2. Upload the paywall screenshot produced by WS2 under `build/ws2-qa-<date>/` (use the actual paywall screenshot file from that QA artifact). Ensure it clearly shows the product/offer in the app.
3. Enter Review Notes with how to reach the paywall and select each plan; explain that the yearly plan presents the 1-week free trial only to eligible new subscribers. Include any review access instructions needed to reach the screen.
4. Save each product's review information.
5. For the first subscription submission, add the new app version, the `MACROS Pro` subscription group, and at least one subscription to the same draft submission before clicking **Submit for Review**. The group must be submitted with a subscription. Include the other products as appropriate in that submission.

Apple Help: [Offer auto-renewable subscriptions](https://developer.apple.com/help/app-store-connect/manage-subscriptions/offer-auto-renewable-subscriptions); [View and edit In-App Purchase information](https://developer.apple.com/help/app-store-connect/manage-in-app-purchases/view-and-edit-in-app-purchase-information); [Submit an In-App Purchase](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-in-app-purchase)

## 8. Create two Sandbox testers

1. At the top of App Store Connect, select **Users and Access**, then click **Sandbox**.
2. Click **+** (or **Create Test Accounts** on first use).
3. Create two separate testers with names, unique email addresses not already registered as Apple Accounts or used for store purchases, passwords, and storefronts. Use the United States for both unless testing another storefront.
4. Click **Create** for each tester. Record credentials securely for the owner; do not put them in the tracker or review notes.
5. On the test device, use the Sandbox sign-in option in Settings when testing in-app purchases. Do not sign out of the device's personal Apple Account just to test IAP.

Apple Help: [Create a Sandbox Apple Account](https://developer.apple.com/help/app-store-connect/test-in-app-purchases/create-a-sandbox-apple-account); [Manage Sandbox Apple Account settings](https://developer.apple.com/help/app-store-connect/test-in-app-purchases/manage-sandbox-apple-account-settings)

## 9. Final verification

| App Store Connect product | Expected `MACROSPro.storekit` identifier |
| --- | --- |
| Yearly subscription | `macros.pro.yearly` |
| Monthly subscription | `macros.pro.monthly` |
| Lifetime non-consumable | `macros.pro.lifetime` |

Confirm IDs, durations, prices, offer eligibility/period, localization, and lifetime Family Sharing match the table/spec above and the StoreKit configuration. Optionally, create a synced StoreKit configuration in Xcode by selecting **Sync this file with an app in App Store Connect**; use it as a cross-check, not as a replacement for this checklist or App Store Connect as the source of truth.

Apple Help: [Offer auto-renewable subscriptions](https://developer.apple.com/help/app-store-connect/manage-subscriptions/offer-auto-renewable-subscriptions); [Create consumable or non-consumable In-App Purchases](https://developer.apple.com/help/app-store-connect/manage-in-app-purchases/create-consumable-or-non-consumable-in-app-purchases); [Setting up StoreKit Testing in Xcode](https://developer.apple.com/documentation/xcode/setting-up-storekit-testing-in-xcode)
