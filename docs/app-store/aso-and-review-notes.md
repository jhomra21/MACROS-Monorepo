# MACROS: ASO and App Review audit

Audit date: 2026-11-03. App ID: `6767565938`. Bundle: `juan-test.cal-macro-tracker`.
**Owner proposals only. No App Store Connect (ASC) changes, uploads, submissions, or removal from review.**

## Evidence and limits

**LIVE ASC UNVERIFIED.** The owner reports version 1.0 is Waiting for Review. This audit could not authenticate to ASC, identify the selected build, enumerate localizations, retrieve API attributes, or download submitted assets.

- `asc` was not on PATH. No `~/.appstoreconnect` or `~/.asc` directory, relevant environment variable names, or credential setup in repository scripts was found.
- Filename-only checks found no Apple `.p8` key in the checked standard key/configuration locations, Downloads, Desktop, `.local`, or `.t3` outside worktrees. No credentials or session tokens were extracted.
- Earlier Mac session records also report Xcode Apple ID account uploads, not an ASC API key. An Xcode upload session is not evidence of usable listing API access.
- The connector catalog offers no ASC connector. No write request was used to test permissions.
- Source baseline: `origin/main` at `91f5b5f4c08f2822ab4d1c75a9dcbe74e480d1b1`. Screenshot fallback: `origin/docs/asc-review-screenshots` at `174606fac59438a86e52f673c12217f7811b2285`. These commits are not proof of the submitted binary or metadata.

## Field inventory and editability

All values below come from `docs/app-store/listing.md` at the source baseline, **not ASC**. Its English draft does not identify a locale; en-US is an assumption, not a verified localization. No es-MX or other live localization inventory is available. Categories belong to app information, not separate per-locale category choices.

“Unknown” means no live permission/state attributes were available. Do not interpret it as a locked field. Apple says Waiting for Review permits editing **certain** information, but prohibits screenshot/preview edits. The fetched editable-property tables lost their checkmark icons, so this audit does not infer individual permissions from empty table cells.

| Field | Fallback value | While Waiting for Review |
| --- | --- | --- |
| Name | `MACROS: Nutrition Tracker` | Unknown for this app; status/version-dependent. Plan with next version unless owner verifies otherwise. |
| Subtitle | `Calories, macros, no account` | Unknown; Apple describes updates with a new version. |
| Promotional text | `Scan barcodes or nutrition labels in one camera view and track calories and macros with no account. Your food log stays on your iPhone. Optional sharing and Pro tools.` | Apple documents updates at any time without a new version; live role/field permission unverified. |
| Description | Exact fallback text below | Unknown for this app. Apple describes description updates with a new version; do not assume all text locks while waiting. |
| Keywords | `food diary,meal log,barcode,food journal,protein,carbs,fat,diet,weight,label scan,kcal,goal` | Unknown; plan for next editable version. |
| What's New | `First release of MACROS: Nutrition Tracker. Log calories and macros with one camera view for barcodes and nutrition labels, Home Screen and Lock Screen widgets, daily rings, and optional sharing.` | Apple says this field is unavailable for the first version. Draft text is not proof it exists in live 1.0. |
| Support URL | `https://<your-domain>/support` | Unknown for this app. Placeholder is not a verified live value. |
| Marketing URL | `https://<your-domain>/` | Unknown for this app. Placeholder is not a verified live value. |
| Privacy URL | `https://<your-domain>/privacy` | Unknown live permission. Apple says editable-status changes release with the next version. |
| Primary category | Not recorded | Unknown. Recommend Health & Fitness, subject to owner verification. |
| Secondary category | Not recorded | Unknown. Consider Food & Drink only if appropriate; optional. |
| Screenshots / previews | Uploaded sets and counts unknown | Apple explicitly prohibits uploading/editing them while Waiting for Review. |
| Other localizations | Unknown, not “none” | New locales require editable app status; verify before acting. |

The draft's name is **25** characters; subtitle **28**. The promo is **167**. The code's production URL candidates are `https://macros-web.jhonra121.workers.dev/`, `/support`, and `/privacy` (`web/src/data/site.ts`, `ProLegalLinks.swift`). Public GETs returned HTTP 200 for all three during this audit; this does not verify support-form delivery or ASC configuration. Do not copy placeholder URLs.

### Exact fallback description

```text
Log calories, protein, carbs, and fat without creating an account. MACROS: Nutrition Tracker keeps daily food logging fast and your data on your device.

LOG YOUR WAY
• Scan product barcodes or nutrition labels in one camera view.
• Search packaged foods online, or enter foods manually.
• Save foods and meals you use often.
• Review serving sizes and nutrition before each entry is added.

SEE YOUR DAY
• Daily calorie and macro rings, plus history and a calendar.
• Small and medium Home Screen widgets and a Lock Screen widget.
• Set goals with the goal calculator and log your weight.
• Create a share card for your daily progress.

YOUR CHOICE
• No account required.
• Food logs are stored on your device.
• Packaged-food search and barcode lookup use an internet connection.
• Sharing is optional and off by default. Choose Nothing, Macros, or Macros + Foods separately for each person.
• Writing nutrition to Apple Health is free.

MACROS PRO
Pro adds Insights charts with ranges from 7 days to All, weight trends, weight import from Apple Health, backup export and import, custom macro ring colors, custom widget color and photo backgrounds, and multiple or smart reminders.

Choose a monthly subscription ($2.99), a yearly subscription ($19.99, including a 7-day free trial), or a $49.99 one-time lifetime purchase. Subscriptions renew automatically unless cancelled. Manage or cancel in your Apple Account subscription settings.

MACROS is a tracking tool, not medical advice. Nutrition information may be incomplete; review entries and consult a qualified health professional for health decisions.
```

## Screenshot inventory, fallback only

No submitted ASC set was downloaded. Branch images were extracted into ignored `build/asc-audit/fallback-6.9/` and `build/asc-audit/fallback-review/` and each of the 21 images was opened and visually inspected. These are candidates, **not a list of uploaded screenshots**.

| Branch directory / display label | Candidate count | ASC display type / uploaded count |
| --- | --- | --- |
| `docs/app-store/media/6.9/` | 15 PNGs: 12 feature captures, 3 review captures | 6.9-inch directory label only; API display type and count unknown |
| `docs/app-store/review-screenshots/` | 6 PNGs, plan-selected light/dark variants | Private IAP review candidates, not a public display set |
| 6.5-inch and other sizes/localizations | No set found in these app-store branch paths | Unknown; absence here does not prove absence in ASC |

The 15 files: `01-onboarding.png`, `02-dashboard.png`, `03-add-food.png`, `04-history.png`, `04-scan-result.png`, `04-scan-review.png`, `05-insights-30d.png`, `06-sharing.png`, `07-paywall.png`, `08-settings.png`, `08b-settings-sharing.png`, `09-widgets.png`, `review-lifetime.png`, `review-monthly.png`, `review-yearly.png`.

The six separate review candidates: `paywall-lifetime-selected-dark.png`, `paywall-lifetime-selected-light.png`, `paywall-monthly-selected-dark.png`, `paywall-monthly-selected-light.png`, `paywall-yearly-selected-dark.png`, `paywall-yearly-selected-light.png`.

The extracted PNGs use 1320×2868 or 1206×2622 pixels. Directory labels alone are not display-size validation. Local `build/asc-audit/image-manifest.json` records each file's dimensions and SHA-256; `verify-docs.py` and `validation.txt` preserve repeatable character/byte counts, keyword checks, verbatim fallback-description comparison, and link/credential-pattern checks. These ignored artifacts are not part of the docs-only commit.

## Compliance findings

Sources: [current App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) (page reports updated October 16, 2026) and [Apple's product-page guidance](https://developer.apple.com/app-store/product-page/). **No finding below establishes what Apple currently has in the submission.**

1. **Public paywall screenshot risk, 2.3.7.** Apple: “Metadata such as app names, subtitles, screenshots, and previews should not include prices”. Candidate `docs/app-store/media/6.9/07-paywall.png` shows **“$19.99/year”**, **“$2.99/month”**, **“$49.99 once”**, and **“7 days free · Best value”**. If submitted publicly, replace it; accurate prices still do not belong in public screenshots. `review-lifetime.png`, `review-monthly.png`, and `review-yearly.png` in the same directory also show those three price rows. They must not leak into the public set.
2. **Private review screenshots are different.** All six `docs/app-store/review-screenshots/paywall-{lifetime,monthly,yearly}-selected-{dark,light}.png` show “$19.99/year”, “$2.99/month”, and “$49.99 once”. The lifetime variants also say **“Buy lifetime for $49.99”**; monthly variants **“Subscribe for $2.99/month”**. These are useful private IAP review evidence, not inherently a public-metadata violation. The yearly variants show **“7 days free · Best value”** / **“Start 7-day free trial”**; monthly/lifetime variants show **“1 week free · Best value”**. Verify the real StoreKit offer and eligibility, not just the screenshot.
3. **Description prices, stale regional/trial claims.** Both baseline and evidence-branch `docs/app-store/listing.md` say: **“Choose a monthly subscription ($2.99), a yearly subscription ($19.99, including a 7-day free trial), or a $49.99 one-time lifetime purchase.”** Apple explicitly advises avoiding specific description prices because they may be inaccurate across regions. Remove amounts; qualify trial eligibility and avoid a fixed duration when it can vary. This is a documented metadata risk, not proof of false pricing.
4. **False prices / strikethrough, 2.3.1(a).** No invented crossed-out price or discount percentage was observed in the inspected candidates. Current production prices, price history, and introductory offers remain unverified. Do not certify “Best value” or trial availability from the mock StoreKit catalog. Apple prohibits promoting a false price “whether within or outside of the App Store”; retain genuine prior-price evidence before making any comparison claim.
5. **Paid-feature labeling, 2.3.2.** `screenshots.md` proposes **“Spot your nutrition trends.”** and **“Choose what each person can see.”** Neither caption itself explains the Pro requirement. A screenshot showing paid charts or invite creation should visibly say Pro / in-app purchase required. `05-insights-30d.png` and `06-sharing.png` are the relevant candidates. The main description identifies most Pro benefits but omits the invite-creation purchase requirement from its sharing paragraph. Keep prices out while disclosing the paid features.
6. **Shipping-binary mismatch, 2.3 / 2.3.1(a).** Main's listing says **“Choose Nothing, Macros, or Macros + Foods separately for each person.”** Main now implements this in `SharingScreen.swift`. The older evidence-branch listing instead says **“Sharing with a circle is optional and shares daily totals, not individual foods.”** `implementation-trackers/sharing-v2-plan.md` records build 23's earlier totals-only behavior. Selected ASC build unknown: do not promote per-person food sharing as a 1.0 shipping feature until the owner checks it. `06-sharing.png` and `08b-settings-sharing.png` are older sharing UI evidence, not proof of v2. Proposed 1.0 copy omits remote-sharing promises.
7. **Privacy scope.** Main's promo says **“Your food log stays on your iPhone.”** That needs qualification when optional food sharing uploads selected food data. Main `SharingScreen.swift` explicitly describes this upload. Prefer “Core food logging works without an account” / “MACROS stores your food log on your device”; document optional uploads with the sharing release. Do not imply nothing ever leaves the phone.
8. **Placeholder URLs, 2.1 / 5.1.1.** `listing.md` contains **“https://<your-domain>/support”**, **“https://<your-domain>/”**, and **“https://<your-domain>/privacy”**. They are draft placeholders; if present in ASC, replace them with verified production destinations. Draft description also lacks a Terms link; the proposed copy includes privacy and standard EULA links.
9. **Subscriptions, 3.1.2(c).** Existing copy says **“Subscriptions renew automatically unless cancelled. Manage or cancel in your Apple Account subscription settings.”** Preserve and expand the renewal/cancellation disclosure, plan periods, benefits, eligible trial conversion, and lifetime distinction. Actual price and offer terms still belong on the in-app purchase screen before confirmation. Main `ProPaywallSheet.swift` loads StoreKit prices/trial duration and has a legal footer; screenshot framing alone cannot prove all disclosures are visible before purchase in the submitted binary.
10. **Name consistency and audience, 2.3.8.** “MACROS: Nutrition Tracker” starts with in-app “MACROS” (`AppBrand.swift`). No “For Kids”/“For Children” claim or age-inappropriate content was identified in this fallback audit. Apple requires similar app names/icons, not a literal universal “must start with” formula. Brand-first is a conservative proposal, not a quoted Apple rule.
11. **Competitors, trademarks, other platforms, 2.3.7 / 2.3.10 / 5.2.** No competing-app names or other-mobile-platform marketing were identified in the fallback listing or inspected screenshots. “Apple Health”, “Home Screen”, and “Lock Screen” describe actual supported Apple features; they are not keyword targets or endorsement claims. “MACROS” trademark clearance and any third-party food/package artwork rights remain unverified. No unsupported medical-accuracy, AI-logging, iCloud-sync, or Apple Watch promise should be added.

## Owner's X research, with evidence levels

These posts are practitioner reports, not Apple policy or controlled ranking experiments. The linked posts were read for this audit.

| Topic and source | Practical conclusion / qualification |
| --- | --- |
| Terminations after older rejections: [Phillip Shoemaker](https://x.com/pbsIdentity/status/2116271984803983393), [Vladyslav](https://x.com/Zeil_Zeil/status/2117270386756702423), [Stacy](https://x.com/stacy_siz/status/2115505304460840960) | Authors describe account risks tied to past review disputes and incomplete old records. These are allegations, not findings about MACROS or proof of Apple's reasoning. 3.2(f) here refers to the Developer Program License Agreement, not guideline 3.2. Keep the full rejection, attachments, replies, fix rationale, and outcome locally even after approval. |
| False/struck-through prices: [Marco](https://x.com/maxzrco/status/2115475931124892054) | Do not invent a former price or imply a fake discount. Apple's 2.3.1(a) supports the false-price warning. The author's blanket “no -50% in ads” is broader than the rule; genuine offers still need truthful, eligible terms. |
| Description prices: [Chad](https://x.com/ChadAppDev/status/2115459559296819485) | Omit fixed amounts; keep plan/benefit and renewal disclosure. Apple's product-page guide independently recommends avoiding specific prices. |
| Subtitle indexing: [Zach](https://x.com/zzwitz/status/2057690739891462607) | Use a descriptive search phrase rather than a slogan. Apple confirms subtitle searchability; the claim that it converts better than screenshots is not established here. |
| Names, es-MX, duplication, CPPs: [Luka Shaw](https://x.com/vovalukashov/status/2116880073080893842) | Keep brand first, test real phrases, avoid wasting field space on name/subtitle words and their plurals. US indexing of es-MX and ranking examples are practitioner observations, not an Apple-confirmed storefront map. Apple's current CPP help says select keywords from the latest approved version; don't treat CPPs as unlimited new keyword fields. |
| Duplication disagreement: [Philip Carlson](https://x.com/phlpcrlsn/status/2117257859666706484) | Author argues variants such as “habit tracker” / “habit tracking” can work and key terms may be needed for CPP selection. No Apple-confirmed change in duplicate penalties was found. Our drafts follow the owner's no-duplication requirement; reserve only relevant keyword-field terms for planned CPPs. |
| Promo, events, CPPs, localization: [Pablo](https://x.com/pfernan95dev/status/2104133952114204927) | Promo is 170 characters, editable without a version, and not indexed (Apple confirms). Events and localized metadata add discovery surfaces. The post's 35-CPP limit is stale: Apple now documents **70**. |
| PPO, events, win-back, rollout, featuring: [Pablo](https://x.com/pfernan95dev/status/2115269824880201859) | Test one screenshot hypothesis before adding treatments; consider a real sharing-launch event, not a price promotion. Evaluate win-back offers for eligible former subscribers. Plan nomination at least three weeks ahead and phased automatic updates; manual downloads bypass phasing. |
| Retention Messaging and benchmarks: [Pablo](https://x.com/pfernan95dev/status/2109449219639845363) | Evaluate retention offers/messages and peer benchmarks after launch; availability, eligibility, sufficient analytics volume, and configuration need verification in the owner's account. This audit did not enable either. Avoid adding analytics/collection just to chase a benchmark. |
| **UNVERIFIED, not Apple-confirmed:** [intent search since June 2026](https://x.com/kedytcom/status/2068634197124685880) | The post supplies no primary evidence that keyword indexing was replaced. Do not discard Apple's keyword guidance. |
| **UNVERIFIED, not Apple-confirmed:** [screenshot captions indexed since June 2025](https://x.com/zzwitz/status/2064339732092330299) | Do not keyword-stuff captions or promise ranking gains. Design captions for legibility and honest conversion. |
| 2025 review statistics: [Pablo](https://x.com/pfernan95dev/status/2116634062076965299) | Verified against [Apple's 2025 Transparency Report](https://www.apple.com/legal/app-store/transparency/2025/): 9,100,620 submissions reviewed; 2,093,244 rejected; 1,354,418 Performance citations; 387,087 approved after rejection. Submissions can repeat and rejection categories overlap; these are not unique-app probabilities. Prioritize completeness and real-device review paths. |

Apple references for execution later: [searchable fields](https://developer.apple.com/help/app-store-connect/create-an-app-record/view-and-edit-app-information/), [product page](https://developer.apple.com/app-store/product-page/), [localization](https://developer.apple.com/help/app-store-connect/manage-app-information/localize-app-information/), [CPP setup and approved-version keywords](https://developer.apple.com/help/app-store-connect/create-custom-product-pages/configure-multiple-product-page-versions/), [PPO](https://developer.apple.com/app-store/product-page-optimization/), [events](https://developer.apple.com/app-store/in-app-events/), [phased release](https://developer.apple.com/help/app-store-connect/update-your-app/release-a-version-update-in-phases/), [featuring nominations: minimum three-week recommendation](https://developer.apple.com/help/app-store-connect/manage-featuring-nominations/nominate-your-app-for-featuring/).

## Ratings and reviews: Apple's rules

- Use StoreKit's [RequestReviewAction / requestReview](https://developer.apple.com/documentation/storekit/requestreviewaction), not a custom star prompt. [Guideline 5.6.1](https://developer.apple.com/app-store/review/guidelines/#developer-code-of-conduct) requires the provided API.
- Follow the [HIG ratings page](https://developer.apple.com/design/human-interface-guidelines/ratings-and-reviews): ask after meaningful engagement, at a natural break; not first launch, onboarding, or during food entry. Allow time and further engagement before asking again.
- StoreKit controls display; at most three prompts in 365 days for an unrated app on the device. Do not assume a prompt appears, call it from a “Rate us” button, or gate benefits on reviews. RequestReviewAction does nothing in TestFlight.
- A deliberate Settings “Write a review” action can instead open the persistent link: `https://apps.apple.com/app/id6767565938?action=write-review`. Apple documents appending `action=write-review`; this audit did not verify the unreleased product page is publicly reachable.
- Do not pre-screen users into positive/negative review paths, incentivize ratings, or promise a rating improves access.

## Owner verification before any ASC edit

1. Read the selected 1.0 build, state, app-info and version localization records, category relationships, and all screenshot/preview sets; save a timestamped export.
2. Fetch every submitted 6.9-inch asset, map API filename/display type/order to the local candidates, and inspect previews for paywall pricing too. Branch filenames cannot establish uploaded identity.
3. Read `appStoreVersionSubmissions`, review submissions/items, and any accessible review messages/attachments. Record access errors and pagination. A submission status is not the full Resolution Center conversation.
4. Read field editability/state information where exposed. Keep “unknown” where the API does not expose a capability. Never PATCH to probe permissions.
5. Ask the owner which allowed metadata changes to apply now. For a public paywall screenshot, owner must choose whether to interrupt review to fix it or defer; this audit did neither.

Editability sources: [app/submission statuses](https://developer.apple.com/help/app-store-connect/reference/app-information/app-and-submission-statuses/), [app info](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information/), [platform info](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/), [editable-property reference](https://developer.apple.com/help/app-store-connect/reference/app-information/required-localizable-and-editable-properties/), [privacy URL release timing](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/).
