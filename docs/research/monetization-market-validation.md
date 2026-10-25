# MACROS Monetization Market Validation

**Research date:** 2026-10-25
**Market:** United States iOS App Store
**Purpose:** Validate the existing monetization rationale, not revise the locked product decision.

## Executive summary

The locked offer is directionally consistent with the market: a useful free logging tier, an annual subscription with a short trial, a lower-priced monthly option, and an optional lifetime purchase. The evidence does not establish that this exact combination is dominant, that the selected prices are at the market's low end, that seven days is the best trial length, or that competitors commonly put Apple Health sync behind a paywall.

The strongest support is for retaining real value in the free tier and offering an annual plan. The largest market risk is not that the prices are too high: $19.99/year is below most established subscription competitors in the sample. Instead, the low annual price and a $39.99 lifetime option could limit long-term revenue, while gating Health sync may be conspicuous against several free-sync competitors. These are risks to monitor, not a recommendation to change locked decisions.

Competitor App Store pages expose multiple in-app purchase entries, sometimes for different durations, storefront price tiers, promotions, or legacy products. The listed prices below are observed entries, not a claim that every user sees that price or that it is the current paywall offer. Feature gates are marked unverified where the listing did not make them clear.

## Validation of the six claims

### 1. Freemium + subscription + lifetime is the dominant model

**Verdict: Partially validated.** Freemium logging with paid subscriptions is common among nutrition trackers in this sample, but the sample is not a market census and does not establish that the combined freemium/subscription/lifetime model is dominant. Most sampled established apps expose subscriptions; a lifetime purchase is visible for some products, including Lose It and Calory, but is not universal. RevenueCat reports that 35%+ of apps globally mix subscriptions with consumables or lifetime purchases, but that statistic does not isolate lifetime, nutrition, or a specific pricing model. Keep “common” rather than “dominant” as the defensible wording.

### 2. $19.99/year and $2.99/month are at or below the low end, with lifetime near 2x annual

**Verdict: Partially validated; “at the low end” is not supported as a blanket statement.** The selected monthly and annual prices are materially below many established competitors in the observed US listings. They are not below every competitor: the sample includes Josman Macros at $17.99/year, Calory at roughly $14.99–$17.99/year, and some other low-cost tiers. In the locked offer, $2.99 × 12 = $35.88, so $19.99/year is a 44.3% discount against twelve monthly payments; $39.99 lifetime is 2.00× the annual price. Calory's observed $34.99 lifetime against annual entries around $14.99–$17.99 is approximately 1.9–2.3× annual, a close example, but competitor lifetime-to-annual relationships vary. Public benchmark evidence reviewed here did not provide a comparable category median for monthly or annual prices; that benchmark is **unverified**.

### 3. A seven-day annual trial is standard and beats 3- or 14-day trials

**Verdict: Partially validated.** Seven days is within a commonly used 5–9-day trial band. RevenueCat's 2025 report says 52% of trials overall fall in that band, and Health & Fitness and Education have more than 80% of trials at five days or longer. This does not prove seven days is the exact most common configuration or that it outperforms three or fourteen days. RevenueCat's 2026 observational data shows annual-plan conversion rising from 24% for trials of four days or fewer to 33% for 5–9 days, 43% for 10–16 days, and 44.6% for 17–32 days overall. In Health & Fitness specifically, the reported 5–9-day conversion (46.8%) exceeded 10–16 days (40.4%). These are observational cohort comparisons, not randomized causal results, and longer-trial selection effects are acknowledged. They support “seven days is a familiar, plausible choice,” not “seven days wins.”

### 4. Free logging with paid advanced analytics/export is common; barcode paywalls are common

**Verdict: Partially validated.** Many products preserve some free food logging and reserve richer analytics, exports, or planning features for paid tiers, but free feature boundaries vary substantially. Barcode gating is not consistent across the category: MyFitnessPal and Lose It place barcode scanning in Premium, while Cronometer, MyNetDiary, Foodnoms, Carb Manager, Nutritionix Track, and others advertise free barcode logging. Therefore, the decision to keep barcode/label OCR/online search in MACROS Free is a meaningful free-tier differentiator, not an industry-standard paywall pattern. “Advanced analytics/export” also needs to remain feature-specific rather than a universal competitor rule.

### 5. Gating Apple Health sync is normal

**Verdict: Not validated; evidence suggests it may be an outlier in this sample.** MyNetDiary, Cronometer, Foodnoms, FatSecret, Lifesum, Nutritionix Track, and Calory advertise some Apple Health connectivity, and their retrieved listings do not consistently show it as a paid-only feature. Lose It presents sync among Premium features. Other products' integration access or gates were unclear. This sample cannot prove market-wide prevalence, but it does not support calling a Health-sync paywall “normal.” Treat this as a potential trust/review risk, especially if free logging remains otherwise broad. Exact competitor gate status is **unverified** where noted in the matrix.

### 6. Lifetime Family Sharing is common among indie trackers

**Verdict: Partially validated.** Apple supports Family Sharing for eligible non-consumables and subscriptions when enabled in App Store Connect, for up to five additional family members. Foodnoms explicitly advertises family options and Family Sharing; Calory's listing indicates Family Sharing support. These examples demonstrate feasibility, not prevalence among indie trackers, nor proof that each listing's lifetime purchase is the item shared. No reliable category denominator was found, so “common” is **unverified**. The locked lifetime entitlement and Family Sharing setup should be checked directly in App Store Connect before release.

## Competitor comparison

Prices are US App Store listing entries captured on 2026-10-25. Multiple entries can be alternate offers or product tiers; where purchase term or paywall mapping is unclear, the table says so. “Trial unverified” means the retrieved App Store listing did not establish its duration.

| App | Observed IAP examples | Free vs paid, as advertised | Trial / Health / lifetime notes |
|---|---|---|---|
| MyFitnessPal | Premium monthly $19.99; annual $79.99; other $9.99 monthly / $49.99 annual entries | Basic manual logging and Health connectivity described; barcode, photo/voice logging, custom goals, insights and ad-free experience are Premium | Trial duration unverified; Health gate unclear; no lifetime identified. [Listing](https://apps.apple.com/us/app/myfitnesspal-calorie-counter/id341232718) |
| Lose It | Annual $79.99; other $9.99–$29.99 subscription entries; lifetime $49.99/$59.99 | Free calorie tracking/basic goals; Premium includes barcode, photo/voice, advanced tracking and sync including HealthKit | Trial duration unverified; lifetime listed. [Listing](https://apps.apple.com/us/app/lose-it-calorie-counter/id297368629) |
| Cronometer | Gold $10.99 monthly / $59.99 annual | Free logging, barcode, search, Apple Health/Watch sync, charts/trends; Gold adds photo/voice, fasting, deeper insights/customization and ad-free use | Trial duration unverified; no lifetime apparent. [Listing](https://apps.apple.com/us/app/cronometer-calorie-counter/id1145935738) |
| MacroFactor | $11.99 monthly; $71.99 annual; $47.99 six-month | Subscription required after trial; barcode, logging, insights, weight trends and subscription features | Seven-day trial advertised; Health details/gate unclear; no lifetime. [Listing](https://apps.apple.com/us/app/macrofactor-macro-tracker/id1553503471) |
| Carbon | $11.99 monthly; $99.99 annual; $59.99 six-month | Subscription required overall; food logging/barcode, charts and Apple Health body-weight/body-fat reading described | Trial duration unverified; no lifetime. [Listing](https://apps.apple.com/us/app/carbon-smart-diet-coach/id1437820611) |
| Lifesum | Examples: $7.49 monthly, $14.99/3 months, $49.99 annual; other higher entries also present | Limited free logging; full feature and scan gates unclear; Health import/export advertised, gate unclear | Trial duration unverified; prices appear tier-/offer-dependent; no lifetime identified. [Listing](https://apps.apple.com/us/app/lifesum-ai-calorie-counter/id286906691) |
| YAZIO | Examples: $11.90 monthly, $23.90/$47.90 annual, plus other terms/tiers | Free calorie logging; PRO includes long-term trends, integrations and premium insights; barcode availability/gate unclear | Trial duration unverified; Health/Watch gate unclear; no lifetime listed. [Listing](https://apps.apple.com/us/app/ai-calorie-tracker-by-yazio/id946099227) |
| Noom | IAP entries from $44.99 through $199.99; terms not clear from listing | Coaching/behavior-change program; free logging access and feature boundaries unclear | Trial, Health gate and duration/term mapping unverified; no lifetime identified. [Listing](https://apps.apple.com/us/app/noom-weight-loss-food-tracker/id634598719) |
| FatSecret | Examples: $10.49/$14.99 monthly; $19.99–$28.99 quarterly; $38.99/$59.99 annual | Free logging, barcode/photo, Health, reports/macros and reminders advertised; Premium includes meal plans and advanced planning | Trial duration unverified; no lifetime listed. [Listing](https://apps.apple.com/us/app/calorie-counter-by-fatsecret/id347184248) |
| MyNetDiary | $8.99 monthly; annual entries $29.99–$59.99; Plus $14.99 | Free logging/barcode, charts/reports, Health, widgets, reminders and macros; Premium adds meal scan, adaptive analysis, fasting and integrations | Trial duration unverified; generic Family Sharing indicator, specific IAP eligibility unclear. [Listing](https://apps.apple.com/us/app/calorie-counter-mynetdiary/id287529757) |
| Cal AI | IAP entries $2.99–$29.99 and others; terms/product mapping unclear | Food scan analysis requires subscription per listing; other free-tier boundaries unclear | Trial duration unverified in App Store listing; Health write not shown; no lifetime identified. Distinct from Calory. [Listing](https://apps.apple.com/us/app/cal-ai-calorie-tracker/id6480417616) |
| Foodnoms | $5.99 monthly / $39.99 annual; family $9.99 monthly / $69.99 annual; alternate tiers | Free unlimited logging, barcode, recipes/meals, Health export, basic reminders and CSV export; Plus adds Health import, charts, insights, more reminders/nutrients and AI | Trial duration unverified; Family Sharing explicitly supported. [Listing](https://apps.apple.com/us/app/foodnoms-nutrition-tracker/id1479461686), [feature comparison](https://foodnoms.com/plus) |
| Macros by JosmanTek | $3.99 monthly; $8.99/3 months; $12.99/6 months; $17.99 annual | Free food logging, barcode and basic macro/calorie tracking; Plus adds detailed goals, micronutrients, graphs, PDF export, sync and calorie cycling | Trial duration unverified; Health gate unclear; no lifetime listed. [Listing](https://apps.apple.com/us/app/macros-calorie-counter/id1216666985) |
| Carb Manager | $8.49 monthly; $16.49 quarterly; annual entries $24.99–$49.99 | Free barcode, basic logging/net carbs and weight charts; Premium adds advanced reports, micronutrients, integrations, fasting and meal planning | Trial duration unverified; Health gate unclear; no lifetime listed. [Listing](https://apps.apple.com/us/app/carb-manager-keto-macro-log/id410089731) |
| Calory (Funn Media) | $2.99/$4.99 monthly; $14.99–$17.99 annual; $34.99 lifetime; Plus tiers also listed | Logging, barcode, Health read/write, widgets, charts, reminders and color options advertised; exact free/subscription/one-time split unclear | Trial advertised, duration unverified; Family Sharing marker present but exact item eligibility unclear. Distinct from Cal AI. [Listing](https://apps.apple.com/us/app/calorie-counter-calory-ai/id1441252752) |
| Ate/AteMate | $9.99 monthly; $49.99 annual; $19.99 quarterly; Coach $19.99 monthly | Food journal/photos and limited AI; paid tiers add coaching/insights | Listing says every plan has seven-day trial; Health details/gates unclear. Adjacent food-journal product, not a direct macro-tracker comparator. [Listing](https://apps.apple.com/us/app/atemate-food-journal-coach/id1164976477) |
| Fitia | $19.99 monthly; annual $53.99–$59.99; family annual $89.99; other terms | Tracker available; meal planning, AI coach and advanced features are Premium; barcode free status unclear | Trial duration unverified; Health integration advertised, gate unclear; family plan marketed for up to six. [Listing](https://apps.apple.com/us/app/fitia-calorie-counter-diet/id1448277011) |
| Nutritionix Track | $5.99 monthly; $28.99 annual | Free logging, barcode, stats, spreadsheet export, Health push/pull and reminders | Two-month Pro trial listed for coach portal/log sharing; this is not necessarily a trial of a comparable full app subscription. No lifetime. [Listing](https://apps.apple.com/us/app/nutritionix-track/id1061691342) |

### Reading the comparison

- “Macros” by JosmanTek and MACROS are separate apps.
- Cal AI and Calory are separate apps.
- Storefront IAP menus often list several price points at once. They do not reveal which offer is currently shown to a given user, whether a price is promotional, or which product identifier maps to a feature gate.
- Competitor feature-gate statements above reflect listing copy and cited official help pages where available. They are not a full hands-on audit of every paywall.
- MyFitnessPal's official support article says barcode scanning moved to Premium on October 1, 2022: [barcode scanner support](https://support.myfitnesspal.com/hc/en-us/articles/360032271672-The-barcode-scanner-is-not-working-in-the-iOS-app).

## Market benchmarks

| Source / date | Finding | Relevance and limits |
|---|---|---|
| RevenueCat, *State of Subscription Apps 2025* | Dataset: 75,000+ apps and $10B+ revenue. Health & Fitness median trial-to-paid conversion 39.9%; 90th percentile 68.3%. 52% of trials overall are 5–9 days; Health & Fitness and Education have over 80% of trials at five days or longer. | Supports seven days as a common duration band, not as the optimal exact length. Cross-app observational benchmark. [Source](https://www.revenuecat.com/state-of-subscription-apps-2025) |
| RevenueCat, *Subscription App Trends 2026*, published 2026-03-19 | 17–32-day trial conversion 42.5% versus 25.5% for trials under four days; 46.5% of apps moved to four-day-or-shorter trials. | Cross-category and observational; does not show seven days outperforming three or fourteen, nor isolate annual H&F plans. [Source](https://www.revenuecat.com/blog/growth/subscription-app-trends-benchmarks-2026) |
| RevenueCat, *Free trial length*, published 2026-09-28 | Across annual plans, median conversion: <=4 days 24%; 5–9 days 33%; 10–16 days 43%; 17–32 days 44.6%. Health & Fitness: 5–9 days 46.8%, 10–16 days 40.4%. Renewal tends to increase with duration. | Period August 2025–July 2026, 17,000+ apps. Observational medians; not randomized causal evidence. Longer-trial cohort selection effects are noted. [Source](https://www.revenuecat.com/blog/growth/free-trial-length) |
| Adapty, *Health & Fitness app subscription benchmarks 2026*, published 2026-03-27 | Source describes 16,000 apps / $3B. Annual plan share in H&F rose from 51% to 61% over 2023–25. H&F annual high-vs-low price LTV reported as $70 vs $17; annual-plan trial lifts LTV. | Directional support for annual plans, not evidence for MACROS' exact price or a universal price target. The reported weekly-funnel trial conversion is not directly comparable to annual trial conversion. [Source](https://adapty.io/blog/health-fitness-app-subscription-benchmarks/) |
| RevenueCat 2025 lifetime/mixed monetization | 35%+ of apps mix subscriptions with consumables or lifetime purchases. | Global, not H&F-specific; statistic does not isolate lifetime prevalence or prove a freemium + subscription + lifetime model is dominant. |

The reviewed public sources did not establish median US monthly/annual nutrition-app prices, annual-versus-monthly revenue share across the full competitor market, or lifetime-purchase prevalence among indie trackers. These are **unverified**, not assumed to be zero or uncommon.

## Locked offer arithmetic and risks

| Locked offer | Implication |
|---|---|
| $2.99 monthly | $35.88 if paid for twelve months. |
| $19.99 annual with seven-day trial | 44.3% below twelve monthly payments. Strongly affordable relative to many observed competitors, but could under-monetize compared with higher-priced category peers. |
| $39.99 lifetime | 2.00× the annual list price. A lifetime buyer crosses the annual gross-revenue equivalent after roughly two annual purchases, before fees, taxes, churn, or discounting; lifetime can also displace renewals. |
| Legacy `fullunlock001` remains a recognized lifetime entitlement | Preserves existing buyers but may anchor expectations around a one-time unlock. The old purchase price and cohort economics were not established in this market research. |

**Risks to monitor, without changing the locked decision:**

1. **Underpricing / revenue ceiling:** The annual price is below most observed established-app entries, though not the entire sample. Validate conversion and retention against MACROS' own funnel before treating competitor prices as a target.
2. **Lifetime cannibalization:** A $39.99 lifetime purchase is roughly two annual payments. Monitor the share of buyers selecting lifetime and renewal revenue displaced.
3. **Health sync backlash:** Several sampled competitors advertise Health connectivity without an evident paid gate. If Health sync is Pro-only, explain the boundary plainly and watch conversion, support contacts, and review themes.
4. **Free-tier differentiation and expectations:** Keeping barcode/label OCR/online search free is favorable against apps that paywall scanning. Avoid implying that all competitors paywall barcode.
5. **Legacy entitlement anchoring:** `fullunlock001` recognition may shape user expectations. Existing entitlement compatibility and future naming/positioning should be communicated consistently; no product rename or SKU change is proposed here.
6. **Family Sharing setup:** Apple supports eligible products, but this must be enabled for the specific IAP in App Store Connect. Confirm configuration and test purchase sharing rather than relying on a generic listing marker.

## Options to consider later (not decisions)

- Keep the locked prices and trial, then evaluate actual install-to-trial, trial-to-paid, annual renewal, monthly retention, lifetime mix, and refund/support data after launch.
- If trial tuning is later authorized, compare durations with a controlled test and measure retained paid value, not only trial conversion. Current benchmarks do not select a causal winner.
- If Health sync remains Pro-only, test clear paywall copy and observe feedback; this report does not recommend changing its gate.
- Verify Family Sharing for the exact lifetime non-consumable in App Store Connect and in a family sandbox scenario.

No product identifiers, prices, trial duration, or feature gates are changed by this research.

## Sources and method

- Competitor evidence: linked US Apple App Store product pages, accessed 2026-10-25. Apple listings can be dynamic and may show multiple IAP prices or tiers; they are point-in-time observations, not a normalized price survey.
- Family Sharing: [Apple StoreKit documentation](https://developer.apple.com/documentation/storekit/supporting-family-sharing-in-your-app) and [App Store Connect help](https://developer.apple.com/help/app-store-connect/configure-in-app-purchase-settings/turn-on-family-sharing-for-in-app-purchases/), accessed 2026-10-25. Apple documentation describes eligible purchase types and sharing limits, not category prevalence.
- Trial and subscription benchmarks: RevenueCat and Adapty reports linked above. Their cohorts are observational and should not be interpreted as causal experiments or exact forecasts for MACROS.
- Unclear price terms, current user-facing offers, and feature gates are labeled **unverified** rather than inferred from unrelated IAP entries.
