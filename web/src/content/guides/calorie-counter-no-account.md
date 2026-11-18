---
title: "Calorie counter with no account: what that means in MACROS"
description: "MACROS needs no account to track food. See what stays on your iPhone, what the app sends for food lookups, and how optional export works."
published: 2026-11-18
updated: 2026-11-18
draft: false
image: ../../assets/app-images/app-home.png
imageAlt: "MACROS food diary with daily calorie and macro totals above the logged foods"
imageCaption: "Your daily food log is stored on the iPhone."
related:
  - guides/how-macros-works-offline
  - guides/how-label-scanning-works
  - guides/how-to-set-macro-goals
  - blog/serving-size-vs-whole-package
---

MACROS: Nutrition Tracker is an iPhone calorie counter that does not require an account. Your food log stays in the app on your device; online searches and barcode lookups send only the query or barcode to MACROS's food-search service.

## Does MACROS require an account to track?

No. You can log food without creating an account or signing in. The food diary, saved foods and meals, goals, body profile, and weight entries stay in the app's protected container on the iPhone.

Optional sharing is separate from tracking and starts off. When you turn it on, the app creates a device-generated sharing profile. You choose whether each connected person sees no details, daily totals, or daily totals and today's foods. Sharing needs a network connection. The [privacy policy](/privacy/#optional-sharing-circle) lists the fields sent and how to stop sharing.

## What information leaves the iPhone for food lookups?

When you search online, the app sends the search term to the MACROS Cloudflare Worker, which requests food results from USDA FoodData Central. A barcode lookup sends the barcode number to the Worker, which requests product data from Open Food Facts. These requests include standard network metadata, including your IP address. The food diary is not sent with a lookup.

The app also searches saved foods and a bundled common-food list on the device. Nutrition-label text recognition runs on the iPhone with Apple Vision; the label image is not uploaded for recognition. Read [what works offline](/guides/how-macros-works-offline/) for which actions need a connection.

## Can I export the food diary?

Backup export, CSV log export, and backup import require MACROS Pro. The app creates a file that you choose to save or share through iOS. Export is not an automatic upload to a MACROS account.

The iPhone app is coming soon. [Join the waitlist](/#waitlist) for an email when it is available, and see [the full MACROS product facts](/what-is-macros/).
