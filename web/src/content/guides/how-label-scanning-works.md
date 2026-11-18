---
title: "How label scanning works in MACROS"
description: "MACROS reads nutrition-label text on your iPhone, then lets you review the values and serving amount before logging."
published: 2026-11-18
updated: 2026-11-18
draft: false
image: ../../assets/app-images/app-scan-details.png
imageAlt: "MACROS label-scan editor with nutrition values, serving size, and editable food details"
imageCaption: "Check the scan and correct any values that do not match the package."
related:
  - guides/calorie-counter-no-account
  - guides/how-macros-works-offline
  - guides/how-to-set-macro-goals
  - blog/label-calories-4-4-9
---

MACROS uses Apple Vision on the iPhone to recognize text on a nutrition label. It turns that text into a reviewable food entry, not an automatic log. Check the name, serving size, calories, and nutrients, edit any mistake, then choose how much you ate.

MACROS: Nutrition Tracker is an iPhone calorie and macro tracker that needs no account. The app is coming soon, and the waitlist is open.

## Does the label photo leave the iPhone?

No. The app passes the camera image to Apple's Vision text-recognition framework on the device. The app code does not send that image to the food-search service for label recognition. Barcode lookup and online food search are separate network actions.

## What should I check after a scan?

Compare the scanned food name, serving description, calories, and nutrient values with the package. OCR can misread small print, symbols, or a faint image. MACROS leaves the result open for review, and you can edit the food name, serving size, calories, and nutrient values before logging.

<!-- visual:scan-review -->

If a number is wrong, open Edit details and correct it from the package. MACROS records the values you approve. It does not fill in an unrecognized value by guessing.

## How does MACROS scale the numbers to my portion?

If the label values describe one serving, MACROS multiplies those per-serving values by the number of servings you say you ate. For gram entry, it scales the same per-serving values by grams eaten divided by the confirmed grams in one serving. When a barcode result provides nutrition per 100 g, the app uses the known serving weight to convert those values to a serving basis before logging.

For example, one and a half servings multiplies each per-serving value by 1.5. If you enter 60 g for a serving that the label defines as 40 g, the multiplier is 60 divided by 40, or 1.5. A source value of 200 calories per 100 g for a confirmed 40 g serving becomes 80 calories per serving.

<!-- visual:serving-ruler -->

<!-- visual:quantity-steps -->

The app does not invent a gram weight for a volume-only serving. Grams stays unavailable until you enter a serving weight in grams. You can still log the food by servings.

## When should I use a barcode instead?

Use a barcode when you want to look up a packaged product in Open Food Facts. That lookup needs a network connection. Label recognition does not need one, and can work when the product is missing from the online database. Read [what works offline](/guides/how-macros-works-offline/) for the limits of offline use.

The [privacy policy](/privacy/#food-search-and-barcode-lookup) explains what gets sent for online search and barcode requests. [Join the waitlist](/#waitlist) for an email when MACROS is available.
