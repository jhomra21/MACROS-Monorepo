# MACROS search measurement

## Search tools

Both are already set up. Check current state in the tool before changing anything.

- **Google Search Console:** domain property verified by the `google-site-verification` TXT record in Cloudflare. Search Console read the sitemap on Nov 6, 2026. Keep the TXT record.
- **Bing Webmaster Tools:** site added and `https://macrosios.com/sitemap.xml` submitted and read on Nov 7, 2026 (7 URLs then).
- **After each deploy that adds pages:** resubmit the sitemap in both tools so the new URLs are read, then use URL Inspection on the new pages. Submission does not guarantee indexing.
## Check AI answers every two weeks

Ask the same prompts in ChatGPT, Perplexity, Google AI Mode, and Copilot. Use a private window where possible. Record whether the assistant names MACROS, cites `macrosios.com`, and which other domains it cites. Keep dated raw notes in ignored `build/evidence/<date>-ai-answers/`.

| # | Prompt | ChatGPT | Perplexity | Google AI Mode | Copilot |
| --- | --- | --- | --- | --- | --- |
| 1 | What is the MACROS nutrition tracker app for iPhone (macrosios.com)? | | | | |
| 2 | Is there a calorie counter for iPhone that doesn't require an account? | | | | |
| 3 | Which calorie tracking apps keep my food diary on my phone instead of the cloud? | | | | |
| 4 | What calorie tracker works offline on iPhone? | | | | |
| 5 | Which iPhone apps can scan a nutrition label, not just a barcode, to log calories? | | | | |
| 6 | Are there calorie trackers with a one-time purchase instead of a subscription? | | | | |
| 7 | What is a good MyFitnessPal alternative with no account and no ads? | | | | |
| 8 | Why don't the macros on a label add up to the calories? | | | | |
| 9 | How do I log half a package when the label is per serving? | | | | |
| 10 | Does the MACROS app for iPhone sell or upload my food data? | | | | |

For each cell, note `named / cited / other cited domains`, or `not named / not cited / other cited domains`. Prompts 1 and 10 check whether assistants confuse MACROS with a different app.

## Success signals

| Timing | Signals to check |
| --- | --- |
| 30 days | The fact page, privacy page, offline guide, and home page plans section are indexed in Google and Bing. Assistants describe MACROS correctly for prompt 1 when given the domain. Search Console shows impressions for at least five non-brand target queries. The comparison page is drafted and its sources are checked. |
| 60 days | If launch has happened, the App Store listing and comparison page are live. At least two third-party roundups or directories list MACROS. The brand query "macros ios" or "macrosios" returns the site first on Google and Bing. At least 20 non-brand queries have impressions, and one prompt from 2 through 7 names or cites MACROS in at least one assistant. |
| 90 days | At least three long-tail target queries average a top-10 position. At least three prompts from 2 through 7 name MACROS on two assistants. Assistant referral visits are measurable. Waitlist or install attribution shows the site contributes visits, and the label-versus-database data post has a link from at least one external page. |

If the app has not launched by day 60, shift launch-dependent signals to 30 and 60 days after launch. Treat these as indicators, not guarantees of ranking or citation.
