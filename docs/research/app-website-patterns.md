# How iPhone app sites introduce themselves

Reviewed November 5, 2026, before rewriting MACROS. Thirteen sites, including seven nutrition or health apps. Each loaded in Playwright Chromium 156 at 390 × 844 and 1440 × 1000. Fresh desktop navigations confirmed the captures after the first resize-only pass. The mobile screenshots are real browser captures, not resized desktop screenshots. Reduced motion was requested. No account, purchase, or form was submitted.

## What showed up

Coordinates are CSS pixels from the top of the document at scroll position zero. "Both" means the headline and at least part of the product image appear within 844px. It does not mean the whole phone fits. Cookie banners remain in the captures, so some images are partly covered.

Headline and supporting-line counts use whitespace-separated words. Hyphenated words count as one. The prose column counts feature-led versus outcome-led words in the captured page's descriptive passages. These are editorial classifications, not a language-model score or a conversion study. Mixed passages take their dominant message. Navigation, legal text, cookies, reviews, article teasers, and repeated carousel copies are excluded. The counted passages have at least six words, so short labels are not included. These counts describe the longer copy, not every word in the HTML.

| Site and URL | First mobile screen | Headline, words | Supporting line, words | Primary CTA | First product image starts | Feature / outcome prose words | Tone |
| --- | --- | --- | --- | --- | --- | --- | --- |
| [MacroFactor](https://macrofactor.com/) | Both, text first; consent covers the lower image | Eat Smarter, 2 | MacroFactor Nutrition, 2 | Download | 320px | 0 / 0, landing page mostly routes to apps and articles | Direct and spare at the top, editorial below. |
| [Cal AI](https://www.calai.app/) | Both, text first; only the top of the phones appears | Meet Cal AI / Track your calories with just a picture, 10 | Yes, 27 | App Store badge | 733px | 206 / 0 | Sales-heavy, with a long explanation and lots of social proof. |
| [Lose It!](https://www.loseit.com/) | Both, text first | Say It. Snap It. Scan It., 6 | Yes, 7 | Sign Up for Free, sticky on mobile | 334px | 44 / 21 | Cheerful, quick verbs, then conventional weight-loss language. |
| [Cronometer](https://cronometer.com/) | Both, text first; consent covers much of the phone | Science-backed nutrition tracking at your fingertips., 6 | Yes, 26 | Sign Up For Free | 460px | 240 / 108 | Clinical and explanatory. |
| [Yazio](https://www.yazio.com/en) | Both, text first; mascot precedes the phones | Build healthy habits you'll love to keep, 7 | Get your custom plan in minutes, 6 | Try it now | 624px for the phone; mascot appears earlier | 63 / 15 | Friendly habit language above a feature list. |
| [Gentler Streak](https://gentler.app/) | Image first; the headline starts at 777px | Award-winning Health and Fitness Tracker, 5 | Yes, 31, below the fold | App Store badge, below the fold | 180px composite, actual screen at 187px | 385 / 392 | Encouraging, especially about rest and consistency. |
| [Bevel](https://www.bevel.health/) | Both, text first | Your Connected Health Coach, 4 | Yes, 14 | App Store badge; Download in the mobile banner | 454px phone, 308px decorative video | 185 / 94 | Reassuring coaching language followed by detailed metrics. |
| [Things](https://culturedcode.com/things/) | Large icon first, then title and text; product demo peeks in | Things, 1 | Yes, 23 | Watch Introduction Video | 697px demo, 138px icon | 0 / 83 | Calm, plain, focused on getting things off your mind. |
| [Flighty](https://flighty.com/) | Both, text first | Get the truth when you travel, 6 | Yes, 19 on mobile, 42 on desktop | Get the app in the header | 543px composite, 570px phone | 293 / 393 | Specific travel frustrations, with confident answers. |
| [Halide](https://halide.cam/) | Product art first, then headline | UNLOCK YOUR IPHONE CAMERA, 4 | The #1 App for Natural Photos., 6; then 24 explanatory words | Get it on the App Store, below the fold | About 180px, CSS background composite | 259 / 99 | Opinionated, visual, comfortable using camera terminology. |
| [Structured](https://structured.app/) | Full-screen product/lifestyle video first; no headline within 844px | your all in one day planner, 6 | Yes, 12, below the fold | Get started on mobile; Start planning for free on desktop | 0px video; first static phone at 1313px | 12 / 0 | Casual and visual; the opening asks you to scroll. |
| [Day One](https://dayoneapp.com/) | Both, text first; just the top of the product image | Your journal for life., 4 | The #1 journaling app., 4 | Download now / platform badges | 751px | 81 / 44 | Personal and warm, with concrete memory-making moments. |
| [Opal](https://opalapp.com/) | Text over decorative video, not a product screenshot | Attention on autopilot., 3 | Yes, 16 | App Store badge / Try for free | About 823px first product-demo tile; actual UI phone at 3523px | 81 / 95 | Emotional promise up front, followed by branded terms and statistics. |

Structured rotates between "day planner" and "to do list". Its headline can show both during a transition, giving nine words. Six is the stable headline shown in the contact-sheet capture. Halide uses background layers, so its product position is estimated from the rendered screenshot rather than an `img` rectangle. Opal's full-bleed opening video is decoration and does not count as the first product image. MacroFactor redirected from its old `macrofactorapp.com` address. The initial Lux Halide link returned a 404 and was replaced with `halide.cam`; the 404 is not part of the sample.

## Desktop is not a mobile recommendation

At 1440px, Cal AI and Lose It! use side-by-side text and phones. Gentler Streak also pairs its message with a phone over a background photo. Cronometer puts its headline beside a product collage. MacroFactor, Yazio, Bevel, Flighty, and Day One use centered messages with product art beneath. Things leads with its icon and a centered paragraph. Halide keeps its product art before the headline. Structured still opens with a full-screen video. Opal keeps text over a decorative background.

The desktop layouts have room for both. Shrinking them into one column can put the app much farther down. Flighty explicitly shortens its supporting copy on mobile. That is a better lesson for MACROS than copying any site's desktop composition.

## What I would borrow

Most sites give the visitor a short message before asking them to understand the app. Nine of thirteen show text before or over their opening visual. Eleven show both a headline and some product imagery in the first mobile screen, including Gentler Streak's headline at the bottom and the demo peeking into Things. The image may only peek in, as on Cal AI or Day One.

The strongest examples explain a recognizable moment. Flighty talks about finding out why your plane is late. Day One talks about returning to an old memory. Things talks about getting tasks off your mind. Those are more useful than a list of screens. Their pages can still be long, and the nutrition apps often use plenty of feature copy. Short copy is a choice for MACROS, not a claim that every successful app does it.

Image-first is not automatically better. Halide can sell the look of a camera before explaining it. Structured uses an entire screen before its headline. MACROS has neither that visual familiarity nor an App Store listing to fall back on. Its first line still needs to tell you what you can do.

## MACROS decision

Mobile order is headline, one short supporting line, the real food-diary screen, then the waitlist form and privacy note. Desktop keeps text and signup together on the left and the phone on the right. The DOM follows the mobile order. The screenshot is not interactive, so desktop keyboard order still goes from navigation to the form.

The headline is "Log your food. Get on with your day." The supporting line is "Your calories and macros, at a glance. No account needed."

At 390 × 844, the phone starts at 287px instead of 591px and ends at 794px. Its complete screen fits before the fold. The launch/waitlist line starts beneath it; the email form begins at 853px. That is an intentional tradeoff: see the app before being asked for an email. There is no evidence here that this order improves signups. The owner can judge that after launch.

The current branch's baseline differs from the owner's live screenshot. It already shows the upper part of the phone within 844px. The before image records that honestly rather than recreating the reported live layout.

The existing waitlist remains the CTA. The App Store launch flag stays false. Its official badge and Smart Banner remain flag-gated. There is no new client JavaScript, no new animation, and no deployment.

## Captures and repeatability

The [evidence report](../evidence/web-copy/README.md) includes an eight-site mobile contact sheet, before and after home captures, and the copy comparison. [Counted passages and their classifications](./app-website-copy-counts.json) preserve the word-count evidence, including excluded passages. Raw research captures and page text live locally in ignored `build/evidence/2026-11-05-web-copy/`. The page measurements were taken with `getBoundingClientRect()` at scroll position zero. Fresh desktop loads avoid counting an image that failed to load after only resizing a mobile page.

Repeat with Playwright Chromium, a clean browser context, `viewport: { width: 390, height: 844 }`, `deviceScaleFactor: 1`, and `reducedMotion: 'reduce'`. Navigate to each URL, wait for load and at most five seconds for network idle, record rendered text and element bounds, then capture the viewport. Repeat at 1440 × 1000 with a fresh navigation. Consent banners and changing carousels can change the visible result. This is a dated design review, not a claim about every visitor's experience.
