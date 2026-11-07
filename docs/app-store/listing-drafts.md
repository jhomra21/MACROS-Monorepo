# MACROS listing proposals

2026-11-03. **Owner approval required; nothing applied in ASC.** See [audit and field inventory](aso-and-review-notes.md) and [review history](rejection-log.md).

## Timing and shipping scope

- **NOW, no new build/version required by Apple's general guidance:** promotional text for existing features. Live ASC permissions remain unverified. No ASC change is authorized by this document.
- **NEXT EDITABLE VERSION, conservative plan:** name/subtitle, description, keywords, es-MX localization, default screenshots/previews, and privacy URL changes. Some text fields may still be editable in Waiting for Review; without live access we cannot classify them as locked or guarantee immediate editing. Owner can verify and approve earlier changes if allowed.
- **SCREENSHOT FIX BEFORE APPROVAL:** Apple explicitly blocks screenshot/preview edits while Waiting for Review. Owner may choose to withdraw/resubmit the same build to correct metadata, if eligible; no new binary is inherently necessary for an honest screenshot replacement. This requires separate authorization and may reset the review wait. Otherwise use the next version.
- **SHARING UPDATE:** publish v2-specific copy only with the version that ships and verifies those features. CPPs/events can have separate review without a binary update, but cannot advertise unavailable functionality.

Source baseline `origin/main` at `91f5b5f4c08f2822ab4d1c75a9dcbe74e480d1b1` has manual/saved-food and meal logging, online search, barcode/label scanning, goals, history, widgets, weight/Health integration, reminders, backup, and Pro gates. Cross-check: `PaidFeature.swift`, `ProPaywallSheet.swift`, `ProLegalLinks.swift`, `SettingsScreen.swift`, and feature folders. Main also contains newer food-sharing work. **The selected ASC 1.0 build is unknown**, so main cannot prove binary equivalence. The conservative description below omits remote-sharing claims, while retaining the existing daily image share card. Owner must compare against the selected build before use.

Counts include punctuation, spaces, and internal newlines, excluding code fences and any terminal newline. Keyword fields also report UTF-8 bytes because Apple's reference says 100 bytes. No competitor or trademark keywords. Search phrases are relevant hypotheses, not search-volume or ranking claims.

## (a) Description, 2082 / 4000 characters

**Timing: next editable version / earlier only after owner verifies live field permission.**
Reason: remove fixed prices and variable trial length, retain purchase disclosures, and avoid promising v2 sharing in 1.0.

```text
Log calories, protein, carbs, and fat without creating an account. MACROS: Nutrition Tracker helps you review what you eat and follow your daily goals.

LOG YOUR WAY
• Scan product barcodes or nutrition labels in one camera view.
• Search packaged foods online, or enter foods manually.
• Save foods and meals you use often.
• Review serving sizes and nutrition before adding an entry.

SEE YOUR DAY
• Follow daily calorie and macro rings, history, and a calendar.
• Add Home Screen and Lock Screen widgets.
• Set goals with the goal calculator and log your weight.
• Create a share card for your daily progress.

YOUR CHOICE
• Core food logging works without an account.
• MACROS stores your food log on your device.
• Packaged-food search and barcode lookup need an internet connection.
• Writing nutrition to Apple Health is free and requires your permission.

MACROS PRO
Pro requires an in-app purchase and adds Insights charts, weight trends, weight import from Apple Health, backup export and import, custom macro ring colors, custom widget color and photo backgrounds, and multiple or smart reminders.

Choose a monthly or yearly subscription, or a one-time lifetime purchase. Eligible new subscribers can get a free trial with the yearly plan. The purchase screen shows the current price and any available trial before you confirm.

Payment is charged to your Apple Account at confirmation, or when your free trial ends. Monthly and yearly subscriptions renew automatically unless canceled at least 24 hours before the current period ends. Your account is charged for renewal within 24 hours before the current period ends. Manage or cancel subscriptions in your Apple Account subscription settings. Lifetime access is a one-time purchase and does not renew.

Privacy Policy: https://macrosios.com/privacy/
Terms of Use: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

MACROS is a tracking tool, not medical advice. Nutrition information may be incomplete; review entries and consult a qualified health professional for health decisions.
```

These URLs match production source constants, not verified ASC fields. Confirm public reachability and policy accuracy before use. Verify yearly trial configuration/eligibility in ASC; if no introductory trial exists, remove that sentence. Actual localized price, offer duration, renewal terms, and benefits must appear before in-app purchase confirmation under 3.1.2; omitting description amounts does not waive that obligation.

## (b) English subtitle options

Keep name **`MACROS: Nutrition Tracker` (25 / 30 characters)**.
Reason: retain brand-first consistency and avoid an unnecessary rename.
**Timing for name/subtitles: next editable version / live field permission unknown.**

| Option | Exact subtitle | Characters | Reason |
| --- | --- | --- | --- |
| A, recommended | `Calorie Counter & Food Diary` | 28 / 30 | Two recognizable logging search phrases without repeating name words. |
| B | `Food Diary & Barcode Scanner` | 28 / 30 | Emphasize scanning as the distinguishing entry method. |
| C | `Calorie Counter & Meal Log` | 26 / 30 | Target calorie and meal logging without name duplication. |

Choose one, not all. Check relevance and conversion after release; these drafts do not establish demand.

## (c) English keywords for subtitle A

**84 / 100 characters; 84 / 100 UTF-8 bytes. Timing: next editable version / live field permission unknown.**
Reason: use remaining space for actual scanning, nutrients, goals, weight, widget, reminder, and backup features.

```text
barcode,label,scan,protein,carbs,fat,weight,meal,journal,goal,widget,reminder,backup
```

No words from `MACROS: Nutrition Tracker` or `Calorie Counter & Food Diary`, nor their plurals. No spaces after commas. Pro features are valid targets but must be disclosed as paid where featured. This field intentionally omits new-sharing keywords until the shipping release is known. If choosing subtitle B or C, revise keywords first: B duplicates `barcode`; C duplicates `meal`. Do not paste this field unchanged with those alternatives.

## (d) Spanish (Mexico), es-MX

**Timing: next editable version; live locale existence/permission unknown.** Metadata localization does not localize the app's UI. Do not imply Spanish in-app support without checking the binary.

| Field | Exact proposal | Characters / limit | UTF-8 bytes | Reason |
| --- | --- | --- | --- | --- |
| Name | `MACROS: Diario de alimentos` | 27 / 30 | 27 | Keep brand first and describe a food diary in natural Spanish. |
| Subtitle | `Cuenta calorías y peso` | 22 / 30 | 23 | State calorie counting and weight logging without repeating name words. |
| Keywords | `proteína,carbohidratos,grasa,comida,etiqueta,escáner,porción,meta,recordatorio` | 78 / 100 | 81 / 100 | Add relevant nutrition, scan, serving, goal, and reminder terms without title/subtitle duplication. |

Do not replace natural Spanish with English keyword stuffing to exploit an assumed US indexing map. The es-MX/US crossover is a practitioner observation, not a guaranteed Apple rule. Before adding the locale, prepare the required localized description, screenshots, and support/privacy destinations; this proposal covers only the requested name/subtitle/keyword fields.

## (e) Promotional text

### Existing features, 136 / 170 characters

**Timing: NOW under Apple's general rules, no new version; live permission unverified.**
Reason: emphasize scan review and account-free logging without an absolute privacy or sharing promise.

```text
Scan barcodes or nutrition labels, review each entry, and track calories, protein, carbs, and fat. Log food without creating an account.
```

### Sharing update, 127 / 170 characters

**Timing: SHARING UPDATE ONLY, after the feature ships; no binary needed just to change this field then.**
Reason: explain per-person scope and the invite purchase requirement without implying sharing is compulsory.

```text
Choose what to share with each person: today’s macros or macros plus foods. Sharing is optional. Creating invites requires Pro.
```

Before release, verify server enforcement, current-day limits, consent, and connection rules. Include “A connection works while either person has Pro” and optional upload details in the update's description/help, not just a short promo.

## (f) Screenshot correction plan

The fallback `07-paywall.png` shows prices. Its public-upload status is **unverified**. `review-lifetime.png`, `review-monthly.png`, `review-yearly.png`, and the six plan-selected review candidates also show prices; keep private IAP review evidence separate from public marketing assets.

1. Owner verifies actual uploaded filenames/order across every localization/display set and preview. Do not assume seven planned shots equal seven uploaded shots.
2. Replace public slot 7 with an authentic Pro widget-background editor and resulting widget, without a purchase screen or price. Use synthetic data and a feature present in the selected binary. Caption: **`Personalize your widgets with Pro` (33 characters)**. Reason: show a paid benefit without displaying prices or doctoring a paywall.
3. Label paid Insights imagery: **`Nutrition trends with Pro` (25 characters)**. Reason: disclose the purchase requirement without a price.
4. If a sharing-invite image ships in the approved build, use **`Create sharing invites with Pro` (31 characters)**. Reason: disclose the Pro gate. Show totals-only UI for an older build; use food-sharing UI only for the update.
5. Avoid price, strikethrough, percentage savings, trial-duration, “free” badges, and unverifiable superlatives in public captures/captions. Preserve real in-app purchase prices and terms; do not modify the app's paywall merely to make public marketing art.
6. Keep actual paywall screenshots in private IAP review information. Match current products/eligibility and include review instructions; do not sanitize private review evidence to hide pricing.
7. Verify exported dimensions against Apple's display specifications, inspect every image at full size, check the 4+ audience requirement and fictional data, and preserve filename/hash/order evidence before the owner uploads.

**Timing:** cannot replace default screenshots while Waiting for Review. Owner chooses withdrawal/resubmission (if appropriate) or the next editable version. No removal or upload occurred in this audit.

## (g) Sharing-update release checklist

All items are proposals, not ASC operations or scheduled tasks.

- [ ] **At least 21 days before release:** owner submits an App Enhancements featuring nomination for per-person sharing control. Include target date, regions, privacy/consent story, TestFlight evidence, and accurate paid-feature disclosures. [Apple recommends three weeks minimum](https://developer.apple.com/help/app-store-connect/manage-featuring-nominations/nominate-your-app-for-featuring/). If nominated November 3, plan release no earlier than November 24, 2026 to meet this lead time. Featuring is not guaranteed.
- [ ] **Before submission:** compare release binary with current 1.0, verify two-device invite/revoke/pause/food-sharing paths, and update privacy disclosures and reviewer instructions. Explain changes specifically in Notes for Review; do not relabel an old feature as new.
- [ ] **Metadata:** publish sharing promo only with availability; revise description to explain Nothing / Macros / Macros + Foods, today-only data, optional uploads, invite Pro gate, and either-person-Pro connection rule. Recheck screenshots, no prices, and Terms/privacy links.
- [ ] **Phased release:** enable the update's seven-day automatic-update rollout after owner approval; monitor crashes, invite failures, consent/revocation, and entitlement behavior. Define a pause decision owner. Apple permits pauses totaling 30 days; manual downloads/updates bypass phasing. This applies to a version update, not a first-launch audience throttle. [Apple guide](https://developer.apple.com/help/app-store-connect/update-your-app/release-a-version-update-in-phases/).
- [ ] **In-App Event idea:** a limited launch window for the significant per-person sharing release, using a **Major Update** badge if Apple considers it substantial. Event concept: “Your Sharing Circle” (19 characters). Demonstrate the new controls, select actual dates, provide a tested deep link to that experience, and state paid participation requirements. Do not claim a challenge/reward system the app lacks or use a generic daily-logging promotion. Events need separate approval; no event or deep link is implemented here. [Apple rules](https://developer.apple.com/app-store/in-app-events/).
- [ ] **CPP ideas:** (1) scanning page, led by barcode/label review; (2) weight-and-Insights page, visibly Pro; (3) private sharing page for the update, with consent and invite gate. Assign relevant keywords from the **latest approved app version**, not an invented CPP keyword field. Current proposed keyword field supports scanning and weight; sharing terms require a deliberate later keyword revision. Use unique combinations and validated deep links only where supported. Apple currently allows up to 70 CPPs and requires approval, independent of a new binary. Current help requires at least one Ready for Distribution country before creation. [CPP help](https://developer.apple.com/help/app-store-connect/create-custom-product-pages/configure-multiple-product-page-versions/).
- [ ] **PPO:** after enough traffic exists, test one scanning-first versus dashboard-first screenshot sequence. Do not change the subtitle at the same time or claim low-volume noise is a win. Up to three treatments; screenshot/preview-only tests can get independent review, but alternate icons must exist in the published binary. [PPO guidance](https://developer.apple.com/app-store/product-page-optimization/).
- [ ] **Retention:** assess peer benchmarks only with sufficient comparable data; check Retention Messaging and win-back eligibility/configuration with the owner before enabling anything. Never promise an offer to ineligible subscribers or change data collection without a privacy review.
- [ ] **Archive evidence:** preserve the owner-approved copy, submitted screenshots, build/source SHA, full review messages/attachments, and release outcome in [the rejection log](rejection-log.md).

Apple's [product-page guide](https://developer.apple.com/app-store/product-page/) supports the field limits, no-description-price recommendation, keyword hygiene, and non-indexed promotional text. The [audit](aso-and-review-notes.md) separates Apple-confirmed guidance from the owner's practitioner research.
