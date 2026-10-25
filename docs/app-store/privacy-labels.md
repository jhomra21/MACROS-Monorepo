# App Store privacy labels: working mapping

This draft reflects the described app and website flows. Confirm against the final binary, third-party SDK inventory, and current App Store Connect questionnaire before submitting.

## App

| Data | Apple category | Collected by developer? | Purpose / linked to identity | Tracking? | Basis |
| --- | --- | --- | --- | --- | --- |
| Food logs, foods, meals, goals, body profile, weight entries | None for developer collection | No | Stored in the app's protected on-device container; not transmitted to our servers | No | On-device storage |
| Search text or barcode; request IP and standard request metadata | Search History; Identifiers / Other Data as applicable to Apple's current choices | Processed by the Worker and upstream food providers | App functionality; no account identifier is sent. Request metadata may be visible to service operators, so verify vendor handling before final declaration | No | Optional packaged-food search and barcode lookup |
| Display name, random profile key, daily calories/protein/carbs/fat, entry count, day and time zone | Health & Fitness | Yes, only when the user enables sharing | App functionality; no real-name account required; the profile key is pseudonymous, but a user-selected display name may identify a person. Assess linked-to-identity based on final implementation | No | Optional sharing circle. Individual foods are not uploaded |
| Sharing secret verifier, invite token hashes, status/expiry, profile/relationship references, sharing scope and interval timestamps | Identifiers / Other Data as applicable | Yes, only for sharing | App functionality; associated with the pseudonymous sharing profile | No | Convex backend records needed to authorize invitations and access |
| Apple Health nutrition and weight values | Health & Fitness | No, by the developer | Written to or read from Apple Health on device; not transmitted to our servers | No | Optional Apple Health sync |
| Purchase entitlement status | Purchases | No direct collection by developer beyond entitlement state provided by Apple | App functionality; Apple handles billing | No | StoreKit |
| Reminder schedule and notification content | None for developer collection | No | Scheduled locally | No | Local notifications |

### App label reasoning

- There is no analytics SDK, advertising SDK, or cross-app/site tracking.
- The sharing service stores nutrition totals, which fall under Health & Fitness. Sharing is off by default and opt-in. Do not label all local nutrition records as collected by the developer.
- Search requests are relayed by the developer's Worker and queried against Open Food Facts and USDA FoodData Central. Confirm provider retention and any identifiers included by the final request implementation.
- Apple Health data is used only for app functionality and is not transmitted to the developer.
- Do not state that sharing data is not linked to identity without reconciling the optional display name and the actual App Store Connect definition. The random key is pseudonymous, not anonymous.

## Website

| Data | Apple category if applicable | Purpose | Retention |
| --- | --- | --- | --- |
| Waitlist email | Contact Info: Email Address | Waitlist updates | 12 months in Cloudflare D1 |
| Support name, email, message | Contact Info: Name, Email Address; User Content: Other User Content | Responding to support requests | 12 months in Cloudflare D1 |
| IP address and standard request/browser metadata | Other Data / Diagnostics as applicable | Cloudflare site delivery and security logs | Cloudflare operational/security log retention; confirm current account settings |

Website contact details are not collected by the iOS app. No analytics SDK or advertising tracker is used on the site.
