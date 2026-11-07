# AI search and blog plan for macrosios.com

Research date: November 7, 2026. Prepared for Juan. Research only: no settings changed, nothing submitted, posted, liked, bookmarked, committed, or deployed.

## Summary

1. There is no separate "AI SEO." Google, Bing, OpenAI and Perplexity all say the same thing. Be crawlable and indexed, write useful pages, and back claims with evidence. Google calls llms.txt, "chunking," and special markup things you can ignore. ([Google AI optimization guide][G-AIO])
2. Our technical base is good. robots.txt allows every bot, and Cloudflare blocks none. Cloudflare's AI Crawl Control showed GPTBot, OAI-SearchBot, ChatGPT-User, ClaudeBot, Claude-SearchBot, PerplexityBot, Applebot and Googlebot all allowed with 0 failed requests in the last 7 days. Bot Fight Mode is off. Google has indexed the site. Search Console's "Search generative AI" control is set to **Include**.
3. The biggest gap is **Bing**. `site:macrosios.com` on Bing returned unrelated results, so the site is probably not in Bing's index yet. Bing feeds Copilot and is one likely discovery path for ChatGPT. Add the site to Bing Webmaster Tools and add IndexNow.
4. The live site is behind the repo. The live guide and sitemap still say "Updated November 4"; the repo says November 6. Deploy before the next indexing push (owner authorization needed).
5. The clearest content opening is honest, dated comparison pages. Google AI Overviews and Perplexity already cite small indie apps (KiloTrack, Calory, Calorix, Foodnoms, Amy Food Journal, Callie) for "calorie counter no account" queries. Those pages show what they checked and when.
6. Generic nutrition questions (protein per day, reading labels) are cited from NIH, FDA, Examine and hospital sites. We will not beat them by restating them. We win with app-specific, first-hand pages: real screenshots, our own label-vs-database checks, and exact math.
7. Publish about two posts a month, all written and checked by you. Measure with Search Console's Generative AI report, Bing's AI Performance report, referrers, and a fixed monthly prompt check.

## 1. What drives inclusion today

### Google AI Overviews and AI Mode

**Strong evidence: Google's own documentation.**

- Eligibility is plain indexing. "To be eligible to be shown as a supporting link in AI Overviews or AI Mode, a page must be indexed and eligible to be shown in Google Search with a snippet... There are no additional technical requirements." ([AI features and your website][G-AIF])
- Since August 31, 2026, there is also a per-property control. A site "must be included in Search generative AI features in Search Console to be eligible." Include is the default. ([Search generative AI control][G-CTRL]) Ours is set to Include (checked November 7).
- The systems are the same ranking systems. Google says the features are "rooted in our core Search ranking and quality systems," use retrieval from the Search index, and use "query fan-out," meaning several related searches per question. ([Google AI optimization guide][G-AIO])
- What Google says matters most is "valuable, non-commodity content." Its example of commodity content is "7 Tips for First-Time Homebuyers." Its advice: "Don't just recycle what others on the internet have already said, or could easily be produced by a generative AI model." ([Google AI optimization guide][G-AIO])
- What Google says to ignore: llms.txt and "special" markup, "chunking," rewriting for AI, "inauthentic mentions," and "overfocusing on structured data." ([Google AI optimization guide][G-AIO])
- Making pages for every fan-out variation "primarily to manipulate rankings or generative AI responses... violates Google's scaled content abuse spam policy." ([Google AI optimization guide][G-AIO]) Spam policies explicitly apply to AI responses. ([Search Central changelog][G-UPD])
- Authorship counts. Google asks whether bylines "lead to further information about the author" and calls fake authors or credentials deception. ([Helpful content][G-HELP])
- FAQ rich results are gone. Google stopped showing them on May 7, 2026, and removed the docs. ([Search Central changelog][G-UPD])

**Moderate evidence: third-party studies with large samples.**

| Finding | Source and sample | How to read it |
| --- | --- | --- |
| Only 38% of AI Overview citations also rank in the top 10 for the same query. 18% of non-ranking citations are YouTube. | [Ahrefs, March 2026][S-AH38]: 863K keyword SERPs, 4M AI Overview URLs | Ranking still helps, but fan-out pulls pages from related searches. A focused page can be cited without ranking first for the head term. Vendor study. |
| Searchers clicked a result in 8% of visits with an AI summary, versus 15% without. They clicked a link inside the summary in 1% of visits. | [Pew Research, July 2025][S-PEW]: browsing data from 900 US adults, March 2025 | Independent and methodical, but older and US-only. Expect fewer clicks per impression. |
| Organic CTR on AI Overview queries fell through 2025 and partly recovered in early 2026. Brands cited in an AI Overview got more clicks than uncited brands on the same queries. | [Seer Interactive, April 2026][S-SEER]: 53 brands, 5.47M queries, 2.43B impressions | Agency client data, not a random sample. Supports "being cited beats just ranking." |
| Wikipedia, YouTube and Reddit are the most-cited sources across AI answers. Reddit's share in ChatGPT swung from about 60% to about 10% of responses in weeks. | [Semrush, Nov 2025][S-SEMR] (100M+ citations); [Pew][S-PEW] | Citation sources are volatile. Off-site presence (Reddit, YouTube, roundups) matters, but no single channel is stable. |

### ChatGPT search

**Strong evidence (OpenAI docs):**

- OAI-SearchBot is the search crawler. "Sites that are opted out of OAI-SearchBot will not be shown in ChatGPT search answers." GPTBot is for training and is separate: "a webmaster can allow OAI-SearchBot... while disallowing GPTBot." ChatGPT-User fetches pages when a user asks. ([OpenAI crawlers][O-BOTS])
- "Any public website can appear in ChatGPT search." ChatGPT may also get URLs "from a third-party search provider." Referral links carry `utm_source=chatgpt.com`. ([OpenAI publisher FAQ, archived Oct 4, 2026][O-FAQ]; the live URL redirected to an unrelated page on November 7)

**Weak or unconfirmed:** OpenAI does not name Bing in its current docs. The "ChatGPT uses Bing's index" claim comes from 2024 launch coverage and SEO writers. Treat Bing as one likely source, not the only one. A ChatGPT "search console" is unannounced; the only report is one observer relayed by Search Engine Roundtable ([seroundtable][S-SER]).

### Bing and Copilot

**Strong evidence (Microsoft docs):**

- Bing's guidelines now cover "Bing search experiences, Copilot, and grounding API results." "SEO best practices... also support eligibility for AI-generated experiences, grounding results, and citations." ([Bing Webmaster Guidelines][B-GUIDE])
- Bing explicitly asks for IndexNow: "Use IndexNow to notify Bing when URLs are added... updated... removed," with sitemaps carrying "accurate lastmod values." ([Bing Webmaster Guidelines][B-GUIDE])
- Content rules that read like a checklist for us: "Surface key information early," "Focus each URL on a single topic," "Ensure content can be verified independently," "Define entities clearly and consistently." ([Bing Webmaster Guidelines][B-GUIDE])
- `NOARCHIVE` "prevents content from being used in Copilot responses." `NOCACHE` limits Copilot to URL, title and snippet. We use neither. ([Bing Webmaster Guidelines][B-GUIDE])
- Bing Webmaster Tools has an **AI Performance** report: total citations, cited pages, and "grounding queries" across Copilot and partners. ([Bing blog, Feb 2026][B-AIPERF])

### Claude

- Three Anthropic bots: ClaudeBot (training), Claude-SearchBot (search index), Claude-User (fetches on a user's request). Blocking Claude-SearchBot "may reduce your site's visibility and accuracy in user search results." ([Anthropic crawler help][A-BOTS])
- Claude's web search used Brave Search as of March 2025, per Anthropic's subprocessor list ([Simon Willison][S-SW]; [TechCrunch][S-TC]). Not re-confirmed for 2026. If true, Brave's index matters too. We can't submit to Brave, so normal crawlability is the only lever.

### Perplexity

- PerplexityBot "is designed to surface and link websites in search results." Perplexity-User fetches on a user's request and "generally ignores robots.txt rules." ([Perplexity crawlers][P-BOTS])
- Perplexity warns that Cloudflare **Bot Fight Mode** "can't be skipped with WAF custom rules" and "can still challenge Perplexity bots." ([Perplexity crawlers][P-BOTS])

### Gemini and Apple

- `Google-Extended` does **not** affect Google Search. It controls Gemini training **and grounding in Gemini Apps**. "Google-Extended does not impact a site's inclusion in Google Search nor is it used as a ranking signal." ([Google crawlers][G-CRAWL]) Blocking it would likely remove us from Gemini app answers. Do not block it.
- Applebot powers Spotlight, Siri and Safari search, and its data can "provide additional context... when AI models are used to generate output." Applebot-Extended only controls training. If robots.txt doesn't name Applebot but names Googlebot, Applebot follows the Googlebot rules. ([Apple][AP-BOT])

### llms.txt

**Do not build it.** Google says it doesn't use it ([Google AI optimization guide][G-AIO]). Ahrefs checked 137,210 domains with traffic in May 2026: 97% of llms.txt files got no requests. Among files that were fetched, the top AI fetchers were GPTBot (training) and Claude Code, not search bots. AI bots never requested a missing llms.txt. ([Ahrefs llms.txt study][S-AHLLM]) It is cheap, but it does nothing measurable for discovery today. Revisit only if a search provider documents using it.

### What practitioners on X report

Details are in Appendix A. Useful patterns, with evidence strength:

- **Keep search and answer bots allowed; block only scrapers.** [@illyism][X-ILLY1] says he analyzed 10M requests across 22 sites. Self-reported log data; the allow list matches the vendor docs above.
- **Cited AI links get few clicks but still matter.** [@CyrusShepard][X-CYRUS] opted a site out of Google AI features: AI citations had about 1% CTR, yet the opt-out affected over 20% of traffic and citations also lifted regular clicks. One site, self-reported, from a well-known SEO.
- **ChatGPT referrals convert well for apps.** [@0xbono][X-BONO] cites 94 ChatGPT views to 59 downloads; [@nomalex_][X-NOMALEX] reports a download jump he attributes to ChatGPT. Both anecdotes, no screenshots checked.
- **Measure prompts, diagnose missing vs. weak pages, then fix one thing.** [@wespreadjam on Granola][X-JAM]. The 4,600% figure is unverified and promotional; the workflow is sound.
- **Programmatic calculator pages can grow impressions fast.** [@junead_kh][X-JUNEAD] claims 780 to 66,000 daily impressions in 6 weeks with 150+ tax calculators. Impressions, not users. This is exactly the scaled-page pattern Google warns about; it works in finance tools with real per-state data, not for us.

## 2. Technical checklist for macrosios.com

### Current state (checked November 7, 2026)

| Item | State | Evidence |
| --- | --- | --- |
| robots.txt | `User-agent: * / Allow: / / Sitemap:` | Live fetch. No Cloudflare-managed block in the file. |
| AI bot access | No crawler blocked. Allowed requests, last 7 days: archive.org_bot 209, Googlebot 73, GPTBot 36, Applebot 14, BingBot 1, ChatGPT-User 1, Claude-SearchBot 1, ClaudeBot 1, OAI-SearchBot 1, PerplexityBot 1. 0 unsuccessful for all. | Cloudflare AI Crawl Control > Security, checked in the owner's dashboard on November 7. Also `200` for spoofed AI user agents with `curl.exe`. |
| Cloudflare security settings | Bot Fight Mode off. AI Labyrinth off. Browser Integrity Check on. Email Address Obfuscation on. Hotlink protection off. Managed robots.txt not in use. | Owner's dashboard, November 7. |
| Email obfuscation in practice | All 7 sitemap pages served a plain `mailto:` link (footer and support page) and no `email-decode` script. | `curl.exe` with default and Chrome user agents, November 7. The rewrite does not appear to apply to these Worker-served pages. |
| Google index | 6+ pages show for `site:macrosios.com` | Google search in the logged-in preview profile. |
| Bing index | No macrosios.com results for `site:macrosios.com` | Bing search. Likely not indexed. |
| Search Console | Sitemap read Nov 6, 7 pages, Success. Performance, Page indexing and Generative AI reports: "Processing data." Breadcrumbs: 5 valid, 0 invalid. HTTPS: 6 pages. Core Web Vitals: no data. Search generative AI control: **Include**. | Read-only visit. |
| Deployed vs repo | Live guide `dateModified` and sitemap `lastmod` are 2026-11-04. Repo frontmatter says `updated: 2026-11-06`. | Live HTML and sitemap vs `web/src/content/guides/how-to-set-macro-goals.md`. |
| llms.txt | 404 | Live fetch. Fine. |

### robots.txt

Keep the current file. It already allows everything, which is what we want for search and answer bots.

Rules if you ever edit it:

- A group that names a bot replaces the `*` group for that bot. If you add `User-agent: GPTBot`, that group must contain every rule GPTBot should follow.
- **Training is your decision.** Allowing GPTBot, ClaudeBot and Applebot-Extended may help future models know MACROS. No study shows this causes citations; it is opinion ([@illyism][X-ILLY1]). Blocking them does not affect search visibility per each vendor's docs. My recommendation: keep allowing them while the brand is unknown.
- **Never block** Googlebot, bingbot, Applebot, OAI-SearchBot, ChatGPT-User, Claude-SearchBot, Claude-User, PerplexityBot, Perplexity-User, or Google-Extended (Gemini app grounding).
- Optional: block pure scrapers like `Bytespider` and `meta-externalagent`. They send no traffic back. Low priority; our site is small.

### Cloudflare settings

Verified in the dashboard on November 7. Keep these as they are:

1. **AI Crawl Control** shows no blocked crawler and 0 failed requests for every AI bot over 7 days. ([AI Crawl Control][CF-ACC]) Keep any AI Crawler and Agent access policies on **Allow**. ([Cloudflare AI policies][CF-AI])
2. **Managed robots.txt** is not in use. The live file is our own three lines. Leave Bot Preference Sync off unless you decide to disallow training. ([Cloudflare managed robots.txt][CF-ROBOTS])
3. **Bot Fight Mode is off.** Keep it off. Perplexity warns it can challenge their bots and can't be skipped with WAF rules. ([Perplexity crawlers][P-BOTS])
4. **AI Labyrinth is off.** Keep it off. It serves decoy pages to crawlers that ignore robots.txt. We gain nothing from it.
5. **Browser Integrity Check is on.** It challenges requests with suspicious headers. The 7-day data shows no failed AI-bot requests, so it isn't hurting crawling. Recheck if a bot starts failing.
6. **Email Address Obfuscation is on.** When it applies, Cloudflare rewrites email addresses in HTML and injects a deferred `email-decode.min.js` script. ([Cloudflare email obfuscation][CF-EMAIL]) On November 7, none of our 7 pages showed the rewrite: the footer and support page served a plain `mailto:` link and no script. It may not apply to Worker-served pages. Either way it's harmless for SEO: the script is deferred, and Google can still read a `mailto:` link. Optional: turn it off to keep pages free of injected script, and recheck the support page in a browser's network panel.
7. **Crawler Hints** (Caching > Configuration) sends IndexNow pings based on cache misses ([Cloudflare Crawler Hints][CF-HINTS]). Our pages are Worker static assets with `run_worker_first`, so it's unclear whether those cache signals fire. Prefer the explicit IndexNow step below.

Check AI Crawl Control monthly. Today it shows that crawlers visit but rarely. Only one OAI-SearchBot, PerplexityBot and Claude-SearchBot request each, and one BingBot request in 7 days. That fits the Bing indexing gap below.

### Bing Webmaster Tools and IndexNow

- **Add the site to Bing Webmaster Tools now.** Import from Search Console is the fastest route. Submit `https://macrosios.com/sitemap.xml`. Then use URL Inspection and the AI Performance report. ([Bing blog][B-AIPERF])
- **Add IndexNow to the release routine.** Yes, worth it. Bing asks for it by name. The protocol takes a key file at the site root and a POST of changed URLs (up to 10,000 per request). ([IndexNow docs][IDX])
  - Put a key file in `web/public/<key>.txt`. The key is not secret; it proves host ownership.
  - Add a small Bun script in `web/` that runs **after** an authorized deploy. It reads the built sitemap, diffs `lastmod` against the previous deploy (or takes explicit URLs), and POSTs to `https://api.indexnow.org/indexnow`.
  - Keep it out of `bun run check`. Validation must never ping search engines.
  - A `200` only means "received," not "indexed."

### Sitemap and lastmod

- The sitemap is correct in design: canonical URLs only, article `lastmod` from `updated`. Keep `updated` truthful. Google lists changing dates without real changes as a warning sign. ([Helpful content][G-HELP])
- Static pages (home, about, privacy, terms, support) have no `lastmod`. That's fine. Add one only if you can derive it truthfully (for example, a manual date in `pages`).
- Deploy so the live site matches the repo's November 6 guide update.

### Structured data

| Type | Today | Change |
| --- | --- | --- |
| FAQPage (home) | Present, matches visible FAQ | Keep. No Google rich result since May 2026, but it matches visible text, costs nothing, and Bing says structured data "may support clearer grounding." ([Bing guidelines][B-GUIDE]) Update `web/SEO.md`, which still says FAQ results are restricted rather than discontinued. |
| MobileApplication | name, OS, category, free offer | Keep. Google's app rich result requires a rating or review, which we don't have and must not invent. ([Google software app][G-SW]) At launch, add `installUrl`/`downloadUrl` (App Store URL), `screenshot`, and `sameAs` to the App Store listing. |
| Organization | name, url, founder | Add `logo` (a square PNG), and `sameAs`: `https://www.instagram.com/macrosios/`, plus the App Store URL at launch and any other real profiles. ([Google Organization][G-ORG]) |
| Person (author) | Only inside Article: name + `/about/` | Add a Person node with a stable `@id` (for example `https://macrosios.com/about/#juan`) on the About page, with `sameAs` to your real public profiles (X, GitHub, LinkedIn if you want them public). Reference that `@id` from every Article `author`. Google recommends `url` or `sameAs` on authors. ([Google Article][G-ART]) |
| Article | headline, dates, author, image | Add `publisher: { "@id": ".../#organization" }`. Keep `dateModified` truthful. |
| BreadcrumbList | Inner pages; 5 valid in Search Console | Keep. |

Do not add Review, AggregateRating or HowTo markup we can't back with visible, real data.

### About page and E-E-A-T

The About page has one sentence about you. Google's "Who" questions ask that bylines lead to background on the author. ([Helpful content][G-HELP]) Add:

- Who you are and what you do, in a few sentences. Your own photo if you're comfortable.
- Why you built MACROS, and your own experience tracking food or training.
- How posts are made: you write them, you check app claims against the current build, you cite primary sources, and you date each check. If AI tools help draft or edit, say so in one line. Google suggests disclosing automation "where someone might think 'How was this created?'" ([Helpful content][G-HELP])
- What you are not: not a dietitian or doctor. The guide already says this well.
- A corrections line with the support email.
- Optional, worth considering for health posts: a paid review by a registered dietitian, credited by name only if real.

### Internal linking

- Every post links to 2-3 related posts and the matching guide, using descriptive anchor text. Bing asks for crawlable `<a href>` links with "relevant anchor text." ([Bing guidelines][B-GUIDE])
- Replace the generic related row (`More guides · Get help · privacy`) with a short "Related" list from frontmatter (a `related` slug array).
- Link from the home FAQ and feature sections to the posts that explain them (for example, "Check the portion" to the serving-size post).
- When the blog launches, add it to navigation as already planned.

### Page speed

The site is prerendered Astro with no client framework and responsive AVIF/WebP images. Lab performance is not a risk. Core Web Vitals field data will appear in Search Console after traffic grows; check it then. Keep illustrations as static SVG/HTML as `web/AGENTS.md` requires.

### Search Console actions

1. Leave Search generative AI on **Include**.
2. After each publish and deploy, inspect the new URL and request indexing once.
3. Check Page indexing in a week, once processing finishes. Any "Discovered, not indexed" or "Crawled, not indexed" means the page needs more value or more internal links.
4. Watch the **Generative AI performance report** (impressions by page, country, device). It shows impressions only, not clicks. ([Generative AI report][G-GENREP])
5. In Performance, filter queries containing "app," "no account," "free," "vs," "alternative" to see buying-intent queries. (This idea comes from [@hridoyreh][X-HRIDOY]; it's a filter, not a tactic.)

## 3. Content strategy

### Who we write for

From the slideshow research ([marketing-slideshows.md](marketing-slideshows.md), [viral-posts-analysis.md](viral-posts-analysis.md)):

- **Gym-goers who check protein.** They read labels, care about grams, and want fast logging.
- **People tracking calories** who are tired of sign-ups, ads, or paywalls on basic features.
- **Privacy-minded iPhone users** who don't want a cloud food diary.

They search two kinds of things:

1. **Method questions**: "how many grams of protein," "how to read a serving size," "how to count macros." Answer engines cite NIH, FDA, Examine, hospitals and big apps here. We earn a place only with something they lack: our real screens, worked examples, and our own data.
2. **App-choice questions**: "calorie counter app no account," "barcode scanner calorie app free," "MyFitnessPal alternative without subscription." Here small indie sites already get cited. On November 7, Google's AI Overviews cited kilotrack.app, calory.app, calorix.ai, foodnoms.com and amyfoodjournal.com, and Perplexity cited Amy Food Journal, Calorix and Callie. (Searches ran in your logged-in profile, so personalization is possible.)

### How a quotable post is built

Patterns from the cited indie pages ([Calorix comparison][C-CALORIX], [Amy Food Journal comparison][C-AMY]) and from Bing's guidelines:

- **Answer in the first two sentences.** Calorix opens with a bold one-paragraph answer naming which apps include a free barcode scanner. Bing: "Avoid long introductions." ([Bing guidelines][B-GUIDE])
- **Date the check.** "Checked on each app's own pages, October 23, 2026." Add a short change log. This is honest and makes the page safe to quote.
- **Tables for comparisons and numbers.** One row per item, units in headers.
- **Say how you checked.** A "How we checked" section with sources and limits. This is Google's "How" question.
- **Disclose that it's our app.** Both comparison pages have an "Our app" section after the neutral comparison. Do the same.
- **Primary-source citations inline,** next to the number, not only in a list at the end.
- **One topic per URL.** ([Bing guidelines][B-GUIDE])
- **Real screenshots with useful alt text.** Bing says images should support the text, not replace it.
- **Original data where we can.** Our own label-vs-database checks, our own serving-math examples. This is what "non-commodity" means for us.
- **A short FAQ section** with real follow-up questions is fine for readers. Don't expect a rich result.

### What not to do

- No AI-generated filler or posts written to a word count. Google: "Are you writing to a particular word count...? (No, we don't.)" ([Helpful content][G-HELP])
- No thin programmatic pages ("protein in [food]" × 5,000) or a page per fan-out query. That is the scaled content abuse pattern. ([Google AI optimization guide][G-AIO])
- No doorway pages ("best calorie app for [city/diet]") that funnel to the same CTA.
- No fake reviews, testimonials, ratings, or "inauthentic mentions." No buying links or listicle placements.
- No unsupported competitor claims. Every competitor fact needs a dated link to the competitor's own page.
- No date bumps without real changes.

### Health accuracy rules

The topic is health-adjacent, so accuracy is the brand.

- Cite primary sources: National Academies DRIs, FDA (21 CFR 101.9, the Nutrition Facts pages), USDA FoodData Central, NIH, and peer-reviewed papers via PubMed. Avoid citing blogs or other apps for health numbers.
- Distinguish reference values from targets. The RDA of 0.8 g/kg is a minimum for most healthy adults, not a sports target. The current guide already does this well.
- State who the advice is for (healthy adults) and when to see a professional.
- No weight-loss promises, no disease claims, no "burn fat" language.
- App-behaviour claims must match the current build (`web/AGENTS.md`). Recheck at each app release.
- Every post gets the unslop pass before shipping (`web/AGENTS.md`).

### Off-site work (where answers come from)

AI answers lean on Reddit, YouTube and roundup articles ([Pew][S-PEW], [Semrush][S-SEMR], [Ahrefs][S-AH38]). Google warns that seeking inauthentic mentions doesn't help. Honest versions:

- After launch, email authors of roundups that are already cited (Amy Food Journal, Calorix, Garage Gym Reviews, Eat This Much) with plain, checkable facts: free features, no account, price, App Store link. Ask nothing more than accuracy.
- Answer relevant Reddit questions as yourself, disclosing that you build MACROS, only where the question is genuinely about no-account or privacy-first tracking.
- For the top 3 posts, record a 30-60 second screen recording and post it to YouTube and Instagram (@macrosios), embedding it on the post. Video is heavily cited in AI Overviews ([Ahrefs][S-AH38]).
- Use the same one-line description everywhere: site, App Store subtitle, Instagram bio, roundup pitches. Bing asks for consistent entity naming. ([Bing guidelines][B-GUIDE])

## 4. Editorial plan

Ranked by expected value: query demand we observed, how often small sites are cited for it, how credibly we can answer, and how close the reader is to installing. "Pre-launch" means it can ship before App Store approval.

### 1. Free calorie counter apps with no account (checked [date])

- **Target:** "calorie counter app no account," "best calorie counter app without account," "calorie tracker no sign up." Choosing an app.
- **Why us:** We are a no-account app. AI Overviews and Perplexity already cite indie comparison pages for these exact queries.
- **Outline:** One-paragraph answer. Table: app, account required to log, free barcode scan, free label scan, ads, data stored where, price, source link, date checked. Sections: what "no account" can mean (none, optional, required for sync). How we checked. Our app: MACROS, clearly labeled. Change log.
- **Sources:** Each app's own pricing, privacy and App Store pages, dated. Apple App Privacy labels.
- **Links:** Privacy page, home features, launch post.
- **Screenshots:** Yes, MACROS first-run screen with no sign-up.
- **Timing:** Draft now. Publish at App Store approval, so "download" is true. Re-check quarterly.

### 2. Serving size vs. the whole package: how to log what you actually ate

- **Target:** "how to read a nutrition label serving size," "calories per serving vs per container." Method.
- **Why us:** Portion review is a core MACROS feature ("Half the pack? Make it half"). AI Overviews cite FDA here, so we cite FDA too and add the logging step they don't cover.
- **Outline:** Answer: calories on the label are per serving; multiply by servings eaten. Worked examples from 3 real packages (photos of labels you own). Dual-column labels. Grams vs household measures. How to log half a pack in MACROS.
- **Sources:** [FDA, How to Understand and Use the Nutrition Facts Label](https://www.fda.gov/food/nutrition-facts-label/how-understand-and-use-nutrition-facts-label); FDA, Serving Size on the Nutrition Facts Label; 21 CFR 101.9 and 101.12 (reference amounts).
- **Links:** Macro goals guide, home "portion" feature.
- **Screenshots:** Yes, scan review with the Servings stepper.
- **Timing:** Pre-launch.

### 3. Why your label scan and the food database disagree (our data)

- **Target:** "why are calories different on MyFitnessPal and the label," "food database wrong calories." Trust.
- **Why us:** Original data. MACROS searches USDA FoodData Central and Open Food Facts (`worker/usda-proxy`) and reads labels on device with Apple Vision. You can compare 20-30 real products: label vs each database entry.
- **Outline:** Answer and headline number from your sample. Table of products with differences. Causes: reformulation, regional versions, crowd entry errors, rounding. Method and limits (small, non-random sample). What MACROS does: review before logging, every value editable.
- **Sources:** USDA FoodData Central docs; Open Food Facts docs; 21 CFR 101.9 rounding rules.
- **Links:** Post 2, post 4, privacy (what leaves the phone for search).
- **Screenshots:** Yes, a scan with an edited value.
- **Timing:** Pre-launch. The highest "non-commodity" value on this list.

### 4. Why label calories don't add up to 4-4-9

- **Target:** "macros don't add up to calories," "why calories don't match macros." Method.
- **Why us:** The guide already explains 4/4/9. Users will see mismatches in the app.
- **Outline:** Answer: rounding rules, fiber, sugar alcohols, and permitted calculation methods. Three worked label examples with the math. When to trust the label total.
- **Sources:** 21 CFR 101.9(c)(1) calorie methods and (c) rounding rules; FDA labeling guide.
- **Links:** Macro goals guide, post 3.
- **Screenshots:** Optional.
- **Timing:** Pre-launch.

### 5. How much protein per day to build muscle, and where the numbers come from

- **Target:** "how many grams of protein per day to build muscle." Method. Very high demand; NIH is cited.
- **Why us:** Not authority. We add exact unit math, a weight table, and how to hit it in a logging day. Keep it modest.
- **Outline:** Answer: RDA 0.8 g/kg is a floor for healthy adults; studies of resistance-trained adults point higher, around 1.6 g/kg with an upper confidence bound near 2.2. Table in kg and lb. Per-meal split. How to set a protein goal in MACROS.
- **Sources:** National Academies DRI (as in the guide); Morton et al. 2018, *Br J Sports Med* meta-analysis (PubMed 28698222); Jäger et al. 2017, ISSN position stand (PubMed 28642676). Verify each figure against the paper before citing.
- **Links:** Macro goals guide, post 8.
- **Screenshots:** Yes, Daily Goals.
- **Timing:** Pre-launch.

### 6. MACROS 1.0 launch post

- **Target:** Brand queries, "MACROS app."
- **Why us:** It's ours. Draft exists.
- **Outline:** Existing draft, plus what's free, privacy in one paragraph, and links to posts 1-3.
- **Sources:** App Store listing.
- **Screenshots:** Yes.
- **Timing:** On approval, per `web/SEO.md`.

### 7. What stays on your iPhone: a calorie tracker without a cloud account

- **Target:** "calorie tracker privacy," "food diary app that doesn't share data," "offline calorie counter." Choosing an app.
- **Why us:** First-hand and verifiable against the privacy policy and code.
- **Outline:** Answer: the log stays on device; search terms and barcodes go to our food-search service; sharing is opt-in. Table: data, where it lives, when it leaves. Offline behaviour. Backup export (Pro). Apple Health.
- **Sources:** Our privacy page; Apple's App Privacy label documentation.
- **Links:** Privacy page, post 1.
- **Screenshots:** Yes, Settings and sharing controls.
- **Timing:** Pre-launch.

### 8. Protein per 100 calories: a table of common foods

- **Target:** "high protein foods per calorie," "protein per 100 calories." Method, list.
- **Why us:** A computed, citable data table from USDA FoodData Central with the method shown. Assistants like quotable tables.
- **Outline:** Answer: the top foods by grams of protein per 100 kcal. One table, about 40 common foods, with FDC IDs. Method and caveats. No "good/bad food" language.
- **Sources:** USDA FoodData Central, each row linked by FDC ID.
- **Links:** Post 5, macro goals guide.
- **Screenshots:** No.
- **Timing:** Pre-launch. Keep it to one honest page, not a page per food.

### 9. How to count macros: a day of logging, step by step

- **Target:** "how to count macros," "how to track macros for beginners." Method. AI Overviews cite MyFitnessPal's blog and calculator.net.
- **Why us:** A real day logged in the app, with every number shown.
- **Outline:** Answer in 3 steps (set goals, log with weights or servings, check totals). A full example day with a table. Common mistakes: unlogged oils, wrong serving, mixing raw and cooked weights.
- **Sources:** USDA FoodData Central entries for each food; FDA label pages.
- **Links:** Macro goals guide, posts 2, 4, 10.
- **Screenshots:** Yes, the home dashboard and History.
- **Timing:** Pre-launch with TestFlight screens. Recheck at launch.

### 10. Logging cups and tablespoons: why we won't guess grams

- **Target:** "cups to grams calories," "how to log food by volume." Method.
- **Why us:** A product rule ("never invent grams for a volume-only serving") with a real reason: density varies.
- **Outline:** Answer. A table of the same volume weighing differently (flour, oats, rice, peanut butter). What MACROS asks you to confirm. When a kitchen scale matters.
- **Sources:** USDA FoodData Central household-measure portions.
- **Links:** Posts 2, 9.
- **Screenshots:** Yes, if the current build has a clear screen for it. Confirm behaviour in code first.
- **Timing:** Pre-launch.

### 11. Free barcode scanner calorie apps: what each one charges for (checked [date])

- **Target:** "barcode scanner calorie app free," "MyFitnessPal alternative without subscription." Choosing an app. AI Overviews cite Cronometer, FatSecret, Foodnoms, Amy, Lifehacker.
- **Why us:** Barcode and label scans are free in MACROS.
- **Outline:** Same format as post 1, focused on scanning and paywalls. Fair notes on who each app suits better.
- **Sources:** Each app's own pricing page, dated.
- **Links:** Post 1, launch post.
- **Screenshots:** Yes, a scan.
- **Timing:** After launch. Overlaps with post 1; publish only if Search Console shows separate demand.

### 12. How accurate are nutrition labels?

- **Target:** "are nutrition labels accurate," "calorie label tolerance FDA." Trust.
- **Why us:** Pairs with post 3's data.
- **Outline:** Answer: FDA compliance rules allow some variance and treat calories as a nutrient that must not be significantly overstated or understated (check exact wording in 101.9(g)). What studies found. What that means for daily tracking.
- **Sources:** 21 CFR 101.9(g); Urban et al. 2010, *J Am Diet Assoc* (verify the PubMed record before citing).
- **Links:** Posts 3, 4.
- **Screenshots:** No.
- **Timing:** Pre-launch.

### 13. Track your macros from the Home Screen and Lock Screen

- **Target:** "calorie tracker widget iPhone," "macro widget lock screen." Feature, choosing an app.
- **Why us:** Real widgets, free personal sizes.
- **Outline:** Answer: which widgets exist and what's free. How to add one (iOS steps). Shared-person widgets with Pro.
- **Sources:** Apple's support page on adding widgets.
- **Links:** Home widgets section, launch post.
- **Screenshots:** Yes, widgets.
- **Timing:** At launch.

### 14. Logging a restaurant meal or home recipe with no barcode

- **Target:** "how to log restaurant food calories," "how to log homemade food." Method.
- **Why us:** Manual entry and saved meals are free, and the review step is core to the app.
- **Outline:** Answer. Three approaches: restaurant nutrition pages, building from ingredients, honest estimates. When estimating is fine.
- **Sources:** FDA menu labeling rule (21 CFR 101.11); USDA FoodData Central.
- **Links:** Posts 9, 10.
- **Screenshots:** Yes, manual entry and saved meals.
- **Timing:** Pre-launch.

### 15. A calorie deficit, explained without the 3,500-calorie myth

- **Target:** "how big a calorie deficit to lose weight." Method. Highest health risk on the list.
- **Why us:** The calculator uses fixed 250/500/750 kcal steps. We can explain exactly what that setting does and doesn't promise.
- **Outline:** Answer. Why the old 3,500 kcal per pound rule overestimates long-term loss. What the MACROS setting does. When to see a professional.
- **Sources:** Hall et al. 2011, *The Lancet* (PubMed 21872751); NIH Body Weight Planner.
- **Links:** Macro goals guide.
- **Screenshots:** Yes, activity and goal screens.
- **Timing:** Last. Consider a dietitian review first.

## 5. Cadence and measurement

### Cadence

- About **two posts a month**, plus one refresh of an older post. Google: "improving old pages" is fine when the change is real, and [@arthuryuzbashev][X-ARTHUR] reports that improving old pages scaled faster than new ones (self-reported).
- Re-check comparison posts (1, 11) every quarter and after any competitor pricing news. Update the "checked" date only after a real re-check.
- Recheck app-behaviour posts at every app release.

### Measurement

| What | Where | How often |
| --- | --- | --- |
| Queries, impressions, clicks, CTR by page | Search Console > Performance | Weekly once data exists |
| AI Overview and AI Mode impressions by page | Search Console > Generative AI report | Monthly |
| Indexing problems | Search Console > Page indexing; URL Inspection | After each publish |
| Copilot and Bing AI citations, grounding queries | Bing Webmaster Tools > AI Performance | Monthly, after adding the site |
| Which AI crawlers visit, and any blocks | Cloudflare AI Crawl Control | Monthly |
| Referrals from chatgpt.com, perplexity.ai, gemini.google.com, copilot.microsoft.com, claude.ai | Cloudflare analytics or Worker logs (see note) | Monthly |
| Waitlist signups, then App Store downloads by source | Waitlist data; App Store Connect sources | Monthly |
| Manual AI answer check | Fixed prompt list, logged out/private window | Monthly |

**Referrer note:** Zone analytics may not show referrers on the current plan, and Cloudflare Web Analytics needs a client script. A lighter option: log only the `Referer` **hostname** for HTML page requests in the Worker's existing observability. No paths, no IPs. That needs your decision since it touches logging. ChatGPT adds `utm_source=chatgpt.com` to links. ([OpenAI publisher FAQ][O-FAQ])

**Monthly prompt check:** Keep the list fixed so months compare. Ask ChatGPT, Perplexity, Gemini, Copilot, Claude and Google (AI Mode) the same 10 questions, for example "best calorie counter iPhone no account," "free barcode scanner calorie app," "how to log half a pack of food." Record whether MACROS appears and which domains are cited. Save raw notes in ignored `build/evidence/<date>-ai-answers/`, per the evidence policy.

## 6. First sprint

In order:

1. **You:** Decide whether to keep Email Address Obfuscation on (optional, low impact). The other Cloudflare settings are already right.
2. **You:** Add macrosios.com to Bing Webmaster Tools (import from Search Console) and submit the sitemap.
3. **You:** Authorize a deploy so the live site matches the repo's November 6 guide.
4. **Build:** Organization `logo` and `sameAs` (Instagram), Person node with `@id`, Article `publisher`. Update `web/SEO.md` about FAQ rich results ending.
5. **Build:** IndexNow key file and a post-deploy Bun script, kept out of validation.
6. **Write:** Expand the About page (bio, how posts are made, AI disclosure, corrections).
7. **Write and publish:** Post 2 (serving size) and post 3 (label vs database, with your own data). Both are pre-launch and need no App Store link.
8. **Prepare:** Draft post 1 (no-account comparison) and the launch post, ready for approval day.
9. **Start the monthly prompt check** and record the baseline: today MACROS appears nowhere.

## Appendix A: X posts

Bookmarks: I scrolled `/i/bookmarks` (redirects to History > Bookmarks) to the end: 860 posts, newest November 6, 2026, oldest April 2023. The table lists every relevant one. Engagement numbers were read on November 7. "Evidence" means the post shows data or a screenshot; "self-reported" means numbers without verifiable proof; "opinion" means advice without data.

### From the owner's bookmarks

| Author | Date | Post | Claim | Type |
| --- | --- | --- | --- | --- |
| @illyism | 2026-11-01 | [link][X-ILLY1] | Robots.txt for AI SEO after 10M requests across 22 sites: keep search and answer bots (Googlebot, bingbot, Applebot, OAI-SearchBot, ChatGPT-User, Claude-SearchBot, Claude-User, PerplexityBot, Perplexity-User, DuckAssistBot, etc.), keep GPTBot and ClaudeBot, block scrapers. 1,320 bookmarks. | Self-reported data. Allow list matches vendor docs. |
| @NicholasDulait | 2026-11-06 | [link](https://x.com/NicholasDulait/status/2118680853836452101) | Quotes @VengeonsP's article "The Google Algorithm Explained, In Depth" written from the leak by an AI. | Opinion. Leak interpretations aren't Google guidance. |
| @arthuryuzbashev | 2026-11-02 | [link][X-ARTHUR] | $9k/mo from SEO. Metadata matters; length depends on competition; improving old pages scales faster than new ones. | Self-reported. |
| @arthuryuzbashev | 2026-10-20 | [link](https://x.com/arthuryuzbashev/status/2112604754312360344) | One Reddit post took a product from $1k to $10k/month. | Self-reported. |
| @tyd3n_ | 2026-11-03 | [link](https://x.com/tyd3n_/status/2117694233301725635) | ASO guide: match search intent, legible screenshots, measure downloads. Author sells an ASO tool. | Opinion. |
| @phlpcrlsn | 2026-11-02 | [link](https://x.com/phlpcrlsn/status/2117257859666706484) | Custom product pages per keyword; App Store no longer punishes keyword duplicates. | Opinion, unverified. |
| @miloshjokic | 2026-11-05 | [link](https://x.com/miloshjokic/status/2118347071505715357) | Offers App Store listing reviews; says most of 900+ listings make the same mistakes. | Self-reported. |
| @wespreadjam | 2026-10-28 | [link][X-JAM] | Granola grew AI-search new users 4,600% in 7 months: map buyer questions, diagnose missing vs. weak pages, study cited third-party sources, measure Google and AI separately. 565K views. | Promotional, unverified figure. Workflow is useful. |
| @junead_kh | 2026-10-28 | [link][X-JUNEAD] | 150+ calculator pages took Google impressions from 780 to 66,000/day in 6 weeks. | Self-reported. Impressions only. |
| @hridoyreh | 2026-10-21 | [link][X-HRIDOY] | Filter GSC queries by buying-intent regex, then optimize for them. 14,500 visitors. | Self-reported. |
| @illyism | 2026-10-20 | [link](https://x.com/illyism/status/2112377329284730977) | To get recommended by ChatGPT, find "best X" listicles linking to competitors and pitch them. | Opinion. Fine only as honest outreach. |
| @borjafat | 2026-10-27 | [link](https://x.com/borjafat/status/2116164330014007296) | 69 backlink tactics behind "133k AI mentions": editorial links, roundups, original statistics, journalist requests. | Self-reported; promotes own product. Statistics and roundup items are useful. |
| @kalashvasaniya | 2026-10-24 | [link](https://x.com/kalashvasaniya/status/2114433628419879152) | Run a prompt that creates a .md file for every page for SEO/AEO/GEO/ASO. | Opinion. Contradicted by Google and Ahrefs data. |
| @devmelv | 2026-10-08 | [link](https://x.com/devmelv/status/2112632240593158297) | Distribution beats product; sell outcomes; one post a day. | Opinion. |
| @Shpigford | 2026-09-25 | [link](https://x.com/Shpigford/status/2103602736310992919) | AI SEO service: keyword map, 12 articles/month, vs/alternatives pages, free calculators, AEO tracking. | Service offer. Shows what an "AI SEO system" produces; volume is the risk. |
| @BuildingWaves | 2026-10-31 | [link](https://x.com/BuildingWaves/status/2116477686189084794) | A Chrome extension gives 50 downloads/day and a high-authority backlink. | Self-reported. Not relevant to an iPhone app. |
| @openseo | 2026-10-15 | [link](https://x.com/openseo/status/2110871613474545932) | Shares an AI-generated site audit. | Product promo. |
| @illyism | 2025-09-29 | [link](https://x.com/illyism/status/1972482471985099107) | Find app ideas from "alternative" keywords with CPC > $1 in Ahrefs. | Opinion. |
| @illyism | 2025-02-03 | [link](https://x.com/illyism/status/1886448017248559162) | Public SEO audits of levelsio's sites. | Opinion. |
| @jackfriks | 2024-11-11 | [link](https://x.com/jackfriks/status/1856013303169847470) | 30,000 downloads/month from short videos. | Self-reported. Social, not search. |
| @huntabyte | 2025-03-04 | [link](https://x.com/huntabyte/status/1896785774382829778) | Added llms.txt to Bits UI docs for coding agents. | Use case is coding agents, not search. |

### From X search (recent, not bookmarked)

| Author | Date | Post | Claim | Type |
| --- | --- | --- | --- | --- |
| @CyrusShepard | 2026-11-05 | [link][X-CYRUS] | Opted a site out of Google AI features: AI citations ~1% CTR, but the opt-out affected 20%+ of traffic; citations also raised regular clicks. | Experiment, self-reported. Strongest practitioner data found. |
| @alexgroberman | 2026-09-25 | [link](https://x.com/alexgroberman/status/2103513741686083916) | Explains the GSC Generative AI report: impressions, not clicks. Promotes services. | Accurate on the report; confirmed by Google docs. |
| @naveenkio | 2026-11-04 | [link](https://x.com/naveenkio/status/2118031587418001888) | Summarizes a DataForSEO study (190M keywords): AIO on 61% of results; YouTube most cited. His own product: 6 of 1,419 cited sources were his site. | Secondhand study plus own small sample. Unverified. |
| @AlDev0 | 2026-10-31 | [link](https://x.com/AlDev0/status/2116678887614874022) | SE Ranking data via Planable: YouTube in 49.48% of AI Overview answers. | Secondhand. |
| @craigcampbell03 | 2026-11-06 | [link](https://x.com/craigcampbell03/status/2118620893161390285) | Relays Lily Ray: answer AIO queries with YouTube videos, not more blog posts. | Opinion. |
| @0xbono | 2026-10-27 | [link][X-BONO] | ChatGPT sent 94 views and 59 app downloads. Tips: one clear sentence everywhere, honest comparison pages, use-case pages, "how did you hear" survey. | Self-reported. Advice consistent with docs. |
| @nomalex_ | 2026-11-07 | [link][X-NOMALEX] | One of his apps has a big download increase mainly from ChatGPT recommendations. | Anecdote. |
| @alg0_slayer | 2026-11-07 | [link](https://x.com/alg0_slayer/status/2119006202323439621) | A ChatGPT "search console" is in testing; says plainly OpenAI hasn't announced it. Works for an SEO vendor. | Rumor, honestly labeled. |
| @nateberkopec | 2026-10-15 | [link](https://x.com/nateberkopec/status/2110583475300692344) | Regrets shipping llms.txt and Markdown content negotiation. | Opinion. |
| @chris_nectiv | 2026-05-20 | [link](https://x.com/chris_nectiv/status/2057054481200619596) | Google's Chrome Lighthouse added an llms.txt audit for agents. | Accurate; Ahrefs measured those fetches at ~1 in 1,000. |
| @isbkch | 2026-10-23 | [link](https://x.com/isbkch/status/2113598191182422311) | Prompt to turn an app into 50+ pages that rank for problems. | Opinion. Scaled-content risk. |
| @RobHoffman_ | 2026-11-04 | [link](https://x.com/RobHoffman_/status/2118075314836590607) | Improve "striking distance" pages ranking 4-20. | Opinion; standard practice. |

## Appendix B: Competitor and live-answer checks (November 7, 2026)

Google searches in the logged-in Default profile (personalization possible), `hl=en&gl=us`. Every query showed an AI Overview.

| Query | AI Overview cited | Top organic |
| --- | --- | --- |
| how many grams of protein per day to build muscle | nih.gov | hartfordhealthcare.org, examine.com, pmc.ncbi.nlm.nih.gov, uclahealth.org, goldsgym.com |
| how to read a nutrition label serving size | fda.gov, gafoods.com, youtube.com, facebook.com | fda.gov, diabetes.org, heart.org, illinois.edu |
| how to count macros | calculator.net, ratioyogurt.com, functional-bodybuilding.com, healthline.com, blog.myfitnesspal.com, youtube.com, weightwatchers.com | calculator.net, ratioyogurt.com, rudisbakery.com, goodrx.com |
| best calorie counter app without account | amyfoodjournal.com, kilotrack.app, quora.com | amyfoodjournal.com, reddit.com, mynetdiary.com, garagegymreviews.com |
| barcode scanner calorie app free | cronometer.com, fatsecret.com, apps.apple.com, amyfoodjournal.com, lifehacker.com | cronometer.com, apps.apple.com (MyNetDiary), reddit.com |
| calorie counter app no account | kilotrack.app, calory.app, quora.com | amyfoodjournal.com, reddit.com, mynetdiary.com, kilotrack.app, calorix.ai |
| myfitnesspal alternative without subscription | foodnoms.com, amyfoodjournal.com, reddit.com | reddit.com, mynetdiary.com, blog.eatthismuch.com, foodnoms.com, platelens.app |
| how many calories in a serving vs per container | marshallcountyhealthdepartment.com, fda.gov, foodhero.org | fda.gov, heart.org, uabmedicine.org |

Perplexity, "best calorie counter app for iPhone without an account": answer named MyNetDiary and Foodnoms. Sources: mynetdiary.com, amyfoodjournal.com (two posts), calorix.ai, mycallie.app, appstoretracker.com, autonomous.ai, blog.eatthismuch.com, inapp.pro.

What the big apps publish:

- **MacroFactor**: long article series (nutrition fundamentals, bulking and cutting, BMR, micronutrients). Evidence-heavy.
- **Cronometer**: science posts and a podcast with dietitians.
- **Lose It**: RD-reviewed recipes and weight-loss tips, member stories.
- **MyFitnessPal**: GLP-1 content, recipes, restaurant guides, a macro calculator page that AI Overviews cite.

What cited indie pages have in common: a direct answer at the top, a dated "checked on" line, a comparison table, "how we checked," a change log, their own app disclosed in a separate section, and a FAQ. KiloTrack's home page is cited from its title alone: "AI Calorie Counter & Offline Food Diary | No Sign-Up."

## Appendix C: Sources

Google
- [G-AIF]: https://developers.google.com/search/docs/appearance/ai-features
- [G-AIO]: https://developers.google.com/search/docs/fundamentals/ai-optimization-guide (last updated 2026-07-10)
- [G-CTRL]: https://support.google.com/webmasters/answer/16908024
- [G-GENREP]: https://support.google.com/webmasters/answer/16984139
- [G-HELP]: https://developers.google.com/search/docs/fundamentals/creating-helpful-content
- Generative AI content guidance: https://developers.google.com/search/docs/fundamentals/using-gen-ai-content
- Spam policies: https://developers.google.com/search/docs/essentials/spam-policies
- [G-UPD]: https://developers.google.com/search/updates (FAQ deprecation May 8, 2026; spam policies apply to AI responses; AI Mode counted in Search Console)
- [G-ART]: https://developers.google.com/search/docs/appearance/structured-data/article
- [G-SW]: https://developers.google.com/search/docs/appearance/structured-data/software-app
- [G-ORG]: https://developers.google.com/search/docs/appearance/structured-data/organization
- [G-CRAWL]: https://developers.google.com/crawling/docs/crawlers-fetchers/google-common-crawlers

Microsoft
- [B-GUIDE]: https://www.bing.com/webmasters/help/webmaster-guidelines-30fba23a
- [B-AIPERF]: https://blogs.bing.com/webmaster/2026/2/Introducing-AI-Performance-in-Bing-Webmaster-Tools-Public-Preview/
- [IDX]: https://www.indexnow.org/documentation

AI providers
- [O-BOTS]: https://platform.openai.com/docs/bots (now https://developers.openai.com/api/docs/bots)
- [O-FAQ]: https://web.archive.org/web/20261004224023/https://help.openai.com/en/articles/12627856-publishers-and-developers-faq
- [A-BOTS]: https://support.claude.com/en/articles/8896518-does-anthropic-crawl-data-from-the-web-and-how-can-site-owners-block-the-crawler
- [P-BOTS]: https://docs.perplexity.ai/guides/bots
- [AP-BOT]: https://support.apple.com/en-us/119829

Cloudflare
- [CF-AI]: https://developers.cloudflare.com/bots/additional-configurations/block-ai-bots/
- [CF-ROBOTS]: https://developers.cloudflare.com/bots/additional-configurations/managed-robots-txt/
- [CF-ACC]: https://developers.cloudflare.com/ai-crawl-control/
- [CF-HINTS]: https://developers.cloudflare.com/cache/advanced-configuration/crawler-hints/
- [CF-EMAIL]: https://developers.cloudflare.com/waf/tools/scrape-shield/email-address-obfuscation/
- Owner's Cloudflare dashboard, macrosios.com zone, AI Crawl Control and Security settings, read November 7, 2026.

Studies and reporting
- [S-AH38]: https://ahrefs.com/blog/ai-overview-citations-top-10/ (863K SERPs, 4M citations; vendor)
- Ahrefs earlier study, 76% from top 10: https://ahrefs.com/blog/search-rankings-ai-citations/ (1.9M citations; superseded)
- [S-AHLLM]: https://ahrefs.com/blog/llmstxt-study/ (137,210 domains; vendor)
- [S-PEW]: https://www.pewresearch.org/short-reads/2025/07/22/google-users-are-less-likely-to-click-on-links-when-an-ai-summary-appears-in-the-results/ (900 adults; independent)
- [S-SEER]: https://www.seerinteractive.com/insights/aio-impact-on-google-ctr-2026-update (53 brands; agency)
- [S-SEMR]: https://www.semrush.com/blog/most-cited-domains-ai/ (100M+ citations; vendor)
- [S-SER]: https://www.seroundtable.com/chatgpt-tools-for-business-42476.html (rumor of ChatGPT business tools)
- [S-SW]: https://simonwillison.net/2025/Mar/21/anthropic-use-brave/
- [S-TC]: https://techcrunch.com/2025/03/21/anthropic-appears-to-be-using-brave-to-power-web-searches-for-its-claude-chatbot/
- Weaker, not relied on: 5W citation audit press release (synthesis of vendor data), DataForSEO study via X summary, SE Ranking YouTube figure via X summary.

Competitor pages
- [C-CALORIX]: https://calorix.ai/compare/free-calorie-counter-apps/
- [C-AMY]: https://www.amyfoodjournal.com/blog/free-calorie-tracking-apps-no-subscription
- https://kilotrack.app/, https://foodnoms.com/, https://macrofactor.com/articles/, https://cronometer.com/blog/, https://www.loseit.com/articles/, https://blog.myfitnesspal.com/

X posts cited in the text
- [X-ILLY1]: https://x.com/illyism/status/2116793959041368471
- [X-CYRUS]: https://x.com/CyrusShepard/status/2118413771416969380
- [X-BONO]: https://x.com/0xbono/status/2118002106145571115
- [X-NOMALEX]: https://x.com/nomalex_/status/2118957350409101331
- [X-JAM]: https://x.com/wespreadjam/status/2115568290307469548
- [X-JUNEAD]: https://x.com/junead_kh/status/2115518966852399219
- [X-HRIDOY]: https://x.com/hridoyreh/status/2112916239605760037
- [X-ARTHUR]: https://x.com/arthuryuzbashev/status/2117297479561474448

Repo files read: `web/SEO.md`, `web/AGENTS.md`, `web/src/data/site.ts`, `web/src/lib/seo.ts`, `web/src/content.config.ts`, `web/src/pages/robots.txt.ts`, `web/src/pages/sitemap.xml.ts`, `web/src/pages/about.astro`, `web/src/pages/[section]/[...slug].astro`, `web/src/layouts/SiteLayout.astro`, `web/wrangler.jsonc`, the macro goals guide, the launch draft, and the two research docs linked above.

[G-AIF]: https://developers.google.com/search/docs/appearance/ai-features
[G-AIO]: https://developers.google.com/search/docs/fundamentals/ai-optimization-guide
[G-CTRL]: https://support.google.com/webmasters/answer/16908024
[G-GENREP]: https://support.google.com/webmasters/answer/16984139
[G-HELP]: https://developers.google.com/search/docs/fundamentals/creating-helpful-content
[G-UPD]: https://developers.google.com/search/updates
[G-ART]: https://developers.google.com/search/docs/appearance/structured-data/article
[G-SW]: https://developers.google.com/search/docs/appearance/structured-data/software-app
[G-ORG]: https://developers.google.com/search/docs/appearance/structured-data/organization
[G-CRAWL]: https://developers.google.com/crawling/docs/crawlers-fetchers/google-common-crawlers
[B-GUIDE]: https://www.bing.com/webmasters/help/webmaster-guidelines-30fba23a
[B-AIPERF]: https://blogs.bing.com/webmaster/2026/2/Introducing-AI-Performance-in-Bing-Webmaster-Tools-Public-Preview/
[IDX]: https://www.indexnow.org/documentation
[O-BOTS]: https://platform.openai.com/docs/bots
[O-FAQ]: https://web.archive.org/web/20261004224023/https://help.openai.com/en/articles/12627856-publishers-and-developers-faq
[A-BOTS]: https://support.claude.com/en/articles/8896518-does-anthropic-crawl-data-from-the-web-and-how-can-site-owners-block-the-crawler
[P-BOTS]: https://docs.perplexity.ai/guides/bots
[AP-BOT]: https://support.apple.com/en-us/119829
[CF-AI]: https://developers.cloudflare.com/bots/additional-configurations/block-ai-bots/
[CF-ROBOTS]: https://developers.cloudflare.com/bots/additional-configurations/managed-robots-txt/
[CF-ACC]: https://developers.cloudflare.com/ai-crawl-control/
[CF-HINTS]: https://developers.cloudflare.com/cache/advanced-configuration/crawler-hints/
[CF-EMAIL]: https://developers.cloudflare.com/waf/tools/scrape-shield/email-address-obfuscation/
[S-AH38]: https://ahrefs.com/blog/ai-overview-citations-top-10/
[S-AHLLM]: https://ahrefs.com/blog/llmstxt-study/
[S-PEW]: https://www.pewresearch.org/short-reads/2025/07/22/google-users-are-less-likely-to-click-on-links-when-an-ai-summary-appears-in-the-results/
[S-SEER]: https://www.seerinteractive.com/insights/aio-impact-on-google-ctr-2026-update
[S-SEMR]: https://www.semrush.com/blog/most-cited-domains-ai/
[S-SER]: https://www.seroundtable.com/chatgpt-tools-for-business-42476.html
[S-SW]: https://simonwillison.net/2025/Mar/21/anthropic-use-brave/
[S-TC]: https://techcrunch.com/2025/03/21/anthropic-appears-to-be-using-brave-to-power-web-searches-for-its-claude-chatbot/
[C-CALORIX]: https://calorix.ai/compare/free-calorie-counter-apps/
[C-AMY]: https://www.amyfoodjournal.com/blog/free-calorie-tracking-apps-no-subscription
[X-ILLY1]: https://x.com/illyism/status/2116793959041368471
[X-CYRUS]: https://x.com/CyrusShepard/status/2118413771416969380
[X-BONO]: https://x.com/0xbono/status/2118002106145571115
[X-NOMALEX]: https://x.com/nomalex_/status/2118957350409101331
[X-JAM]: https://x.com/wespreadjam/status/2115568290307469548
[X-JUNEAD]: https://x.com/junead_kh/status/2115518966852399219
[X-HRIDOY]: https://x.com/hridoyreh/status/2112916239605760037
[X-ARTHUR]: https://x.com/arthuryuzbashev/status/2117297479561474448
