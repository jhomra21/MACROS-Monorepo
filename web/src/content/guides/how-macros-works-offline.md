---
title: "Does MACROS work offline?"
description: "MACROS can log food, search saved and bundled foods, and read nutrition labels offline. Online food search and barcode lookup need a connection."
published: 2026-11-18
updated: 2026-11-23
draft: false
image: ../../assets/app-images/app-add-food.png
imageAlt: "MACROS food search showing on-device matches and online search results"
imageCaption: "The search screen separates foods saved on the device from online results."
related:
  - guides/calorie-counter-no-account
  - guides/how-label-scanning-works
  - guides/how-to-set-macro-goals
  - blog/serving-size-vs-whole-package
---

MACROS can log food without a network connection, search foods saved on the iPhone, and recognize text on a nutrition label. Online food search and barcode lookup need the network, so manual entry remains available when those requests cannot run.

MACROS: Nutrition Tracker is an iPhone app for iOS 26 or later.

## What can I do without a connection?

You can log food by entering it manually, add a saved food or meal, and search the on-device food list. The app also includes a bundled list of common foods. These actions do not require a MACROS account or an internet connection.

You can point the camera at a nutrition label and have Apple Vision recognize its text on the iPhone. The label image is not sent for recognition. Review the result and edit any value before logging.

## Which lookups need the network?

Online food search sends the search term to the MACROS Cloudflare Worker. The Worker requests matching foods from USDA FoodData Central. Barcode lookup sends the barcode number to that Worker, which requests the product from Open Food Facts. Both requests include standard network metadata such as your IP address. The app does not send your food diary with either lookup.

If a search or lookup cannot reach the service, use a saved or bundled food, enter the food yourself, or scan the nutrition label and check the recognized values.

## Does offline use require an account?

No. Tracking does not require an account. Optional sharing is a separate feature. It uses a device-generated sharing profile, requires a network connection, and sends only the details you choose to share with each person. The [privacy policy](/privacy/#optional-sharing-circle) explains what each sharing choice sends.

## Can I export food logs offline?

Backup export, CSV log export, and backup import are MACROS Pro features. When you export, the app creates a file that you can save or share using iOS. See [what is free and what Pro adds](/#plans).

Read [what is MACROS?](/what-is-macros/) for the full product facts, including data sources and availability.
