# App Store listing draft

Confirm the legal owner details before submission. Apple's limits: name 30 characters, subtitle 30, promotional text 170, keywords 100 (comma-separated, no name duplication).

## Listing

- **Name (25 of 30 characters):** MACROS: Nutrition Tracker
- **In-app brand:** MACROS
- **Subtitle (28 of 30 characters):** Calories, macros, no account
- **Promotional text (under 170 characters):** Scan barcodes or nutrition labels in one camera view and track calories and macros with no account. Your food log stays on your iPhone. Optional sharing and Pro tools.
- **Description:**

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
  • Sharing with a circle is optional and shares daily totals, not individual foods.
  • Writing nutrition to Apple Health is free.

  MACROS PRO
  Pro adds Insights charts with ranges from 7 days to All, weight trends, weight import from Apple Health, backup export and import, custom macro ring colors, custom widget color and photo backgrounds, and multiple or smart reminders.

  Choose a monthly subscription ($2.99), a yearly subscription ($19.99, including a 7-day free trial), or a $49.99 one-time lifetime purchase. Subscriptions renew automatically unless cancelled. Manage or cancel in your Apple Account subscription settings.

  MACROS is a tracking tool, not medical advice. Nutrition information may be incomplete; review entries and consult a qualified health professional for health decisions.

- **Keywords (under 100 characters, no words from the name or subtitle):** food diary,meal log,barcode,food journal,protein,carbs,fat,diet,weight,label scan,kcal,goal
- **What's New:** First release of MACROS: Nutrition Tracker. Log calories and macros with one camera view for barcodes and nutrition labels, Home Screen and Lock Screen widgets, daily rings, and optional sharing.
- **Support URL:** `https://<your-domain>/support` (replace with production domain)
- **Marketing URL:** `https://<your-domain>/` (replace with production domain)
- **Privacy policy URL:** `https://<your-domain>/privacy` (replace with production domain)
- **Terms of Use URL:** `https://<your-domain>/terms` (replace with production domain)

## App Review notes

- Food logging works without an account.
- Barcode and nutrition label scanning use the camera, so test them on a physical iPhone. The Simulator has no camera.
- To review sharing, install the app on two sandbox devices, enable Sharing on device A, create an invitation, then accept it on device B. Sharing is optional and sends daily totals rather than individual foods. Sharing needs two devices.
- Pro gates are visible in Settings. Review them without purchasing; paid products and subscription behavior are configured separately in App Store Connect.
- Apple Health requires user permission and a device with Health available. Writing nutrition is free; importing weight from Apple Health is a Pro feature. Reviewers can test the free path without purchasing.

## Age rating questionnaire draft

Confirm answers in App Store Connect against the final binary:

- **Infrequent/mild medical or treatment information:** No. The app is a nutrition log and does not provide medical advice or treatment.
- **Unrestricted web access, user-generated content, chat, or sharing with the public:** No. Sharing is limited to invited people; there is no public feed, user-posted content, or chat.
- **Advertising, gambling, violent, sexual, or substance-related content:** No.
- **Health or wellness topics:** Yes, nutrition and weight tracking.
