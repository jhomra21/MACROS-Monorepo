# MACROS rejection and review-message log

App ID `6767565938`, bundle `juan-test.cal-macro-tracker`. Audit: 2026-11-03.

## 2026-05-11 to 2026-05-13: version 1.0, builds 3 and 5, submission 2bf4dd23

Source: ASC > App Review > Submissions, read in the owner's signed-in session on 2026-11-03. The text below is copied from ASC. Attachment not downloaded yet.

| Field | Record |
| --- | --- |
| Submission ID | `2bf4dd23-de4c-4d3c-84c6-406a2dccf3c6`, submitted 2026-05-12 10:09 AM, final status **Removed** |
| First rejection | 2026-05-11 1:00 PM, version 1.0 (3), iPad Air 11-inch (M3), iPadOS 26.4.2. Guidelines **2.1(a) App Completeness** ("the top right button was unresponsive") and **2.2 Beta Testing** ("features that are intended to support beta testing") |
| Attachment | `Screenshot-0511-105910.png` (Apple's attachment; download it from ASC and keep it in owner storage) |
| Our replies | 2026-05-11 9:36 PM, 2026-05-12 9:09 AM, 2026-05-12 10:04 AM (full text below). We said the app was not production-ready and asked how to test IAP in TestFlight |
| Second rejection | 2026-05-13 10:28 AM, version 1.0 (5), iPhone 17 Pro Max. Guideline **2.2**: "Your app appears to be a pre-release, test, or trial version with a limited feature set." |
| What changed since | iPad compact navigation fix; the app was finished before resubmitting; Sandbox testing used for IAP instead of App Review; app renamed from "MACROS-beta" to "MACROS: Nutrition Tracker" |
| Resubmission | Submission `01487b42-af8f-4113-8091-012d7374080b`, 2026-10-31 3:13 PM, version 1.0 (23) plus the MACROS Pro group, Monthly, Yearly, Lifetime. Review notes open with "RESUBMISSION: build 5 was rejected in May 2026 under 2.2." Status on 2026-11-03: Waiting for Review |
| Outcome | Pending |

Lesson: never submit to App Review only to unlock IAP testing. Sandbox purchases in TestFlight do not need an approved app. Test on iPad too (the app runs there in compatibility mode).

### Full thread

```text
--- Apple, 2026-05-11 1:00 PM ---
Hello, 

Thank you for submitting the new app, MACROS-beta, for review. We noticed some issues that require your attention. Please see below for additional information.

If you have any questions, we are here to help. Reply to this message in App Store Connect and let us know.

Review Environment
Submission ID: 2bf4dd23-de4c-4d3c-84c6-406a2dccf3c6
Review date: May 11, 2026
Review Device: iPad Air 11-inch (M3)
Version reviewed: 1.0 (3)

Guideline 2.2 - Performance - Beta Testing

Issue Description

Your app includes features that are intended to support beta testing. Since you are submitting a production version of your app, features intended to support beta testing are not appropriate.

Next Steps

To resolve this issue, revise the app and remove features that are intended to support beta testing. Since you are submitting a production version of your app, features intended to support beta testing are not appropriate.

Resources

- Learn more about beta testing requirements in guideline 2.2.
- Test apps and invite users to provide feedback with TestFlight Beta Testing.

Guideline 2.1(a) - Performance - App Completeness
Issue Description

The app exhibited one or more bugs that would negatively impact users.

Bug description: the top right button was unresponsive. 

Review device details:

- Device type: iPad Air 11-inch (M3) 
- OS version: iPadOS 26.4.2
- Internet Connection: Active

Next Steps

Test the app on supported devices to identify and resolve bugs and stability issues before submitting for review.

If the bug cannot be reproduced, try the following:

- For new apps, uninstall all previous versions of the app from a device, then install and follow the steps to reproduce.
- For app updates, install the new version as an update to the previous version, then follow the steps to reproduce.

Note that users expect apps they download to function on all the devices where they are available. For example, apps that may be downloaded onto iPad devices should function as expected for iPad users. 

Resources

- For information about testing apps and preparing them for review, see Testing a Release Build.
- To learn about troubleshooting networking issues, see Networking Overview.

Support
- Reply to this message in your preferred language if you need assistance. If you need additional support, use the Contact Us module.
- Consult with fellow developers and Apple engineers on the Apple Developer Forums.
- Provide feedback on this message and your review experience by completing a short survey.

iOS App 1.0App Version
Rejection Reasons:

2.1.0 Performance: App Completeness

2.2.0 Performance: Beta Testing

Rejection Attachments:
Screenshot-0511-105910.png

--- Juan Martinez, 2026-05-11 9:36 PM ---
Hello, thanks for the review and information. I have already fixed the three button bug in all devices. It was a problem with navigation compacting to that on smaller screens, which is something I forgot to test initially, but I found out testing it during the weekend and already fixed it in one of the newer versions, which I will be publishing, actually it might already be published up there. But for the other point, this is not intended for production. I did this flow because it's what I understood from the In-App Purchases, since I wanted to be able to test that via test flight, and from all the stuff I read in the documentation and the little messages there that I have to go through the review process through this, and doing the submission for reviewing the app to get the IAP in the flow. 
But all I wanted to do is test it on test flight and make sure everything's working. This is not intended to be full production. I'm sorry if this is the wrong flow for that. That's what I just understood it was. This is obviously not ready, of course. So could you please advise as to what to do for the beta point? How can I be able to test the In-App Purchases in test flight, which is just one purchase item. I would like some help on this, because I'm a little confused.

--- Juan Martinez, 2026-05-12 9:09 AM ---
I just read more about the sandbox account, and I was definitely in the wrong trying to submit this app review! I am so sorry, I was trying to just test the purchases flow and permissions in the app. Not sure if I should leave this open and open another review when I am done.

--- Juan Martinez, 2026-05-12 10:04 AM ---
I actually read more and I'm a little bit more confused. So I did have to submit the app for review to get the IAP purchase thing online or enabled so that I can use my sandbox account, which I enabled on my phone and I was trying to use to do the purchase, but it's not recognizing the purchase. And I'm continuing testing everything else, and everything else is being fixed, but this is what's getting me stuck is that I don't know if I should do another app submission for review. There's no beta features on the app right now. Everything that's on the app is going to be in the final version. It's just that the app obviously isn't fully finished, fully tested, because I need to test the IAP. And I can't do that without doing the submission, so I'm gonna do it again because from rereading everything, I think I do need to clear a submission so that the IAP purchase is registered to the app or linked to the app in Test Flight in the sandbox, so that the test flight app picks up the purchase ID or something, or the entitlement. I'd like to test this to even consider putting it out in production. Like I said in the previous message, I'd like to test this and I'm just a little confused. I think I've found the answers I needed, but I'm still not 100% sure if what I'm reading and what I'm understanding is what I should do to be able to test this purchase.

--- Apple, 2026-05-13 10:28 AM ---
Hello,

Thank you for your efforts to follow our guidelines. There are some outstanding issues that still need your attention.

If you have any questions, we are here to help. Reply to this message in App Store Connect and let us know.

Review Environment
Submission ID: 2bf4dd23-de4c-4d3c-84c6-406a2dccf3c6
Review date: May 13, 2026
Review Device: iPhone 17 Pro Max
Version reviewed: 1.0 (5)

Guideline 2.2 - Performance - Beta Testing

Issue Description

Your app appears to be a pre-release, test, or trial version with a limited feature set. Apps that are created for test or trial purposes are not appropriate for the App Store.

Next Steps

To resolve this issue, please complete, remove, or fully configure any partially implemented features. If the app is not ready for public distribution, use TestFlight to test the app.

Resources

- Learn more about beta testing requirements in guideline 2.2.
- Test apps and invite users to provide feedback with TestFlight Beta Testing.

Support
- Reply to this message in your preferred language if you need assistance. If you need additional support, use the Contact Us module.
- Consult with fellow developers and Apple engineers on the Apple Developer Forums.
- Provide feedback on this message and your review experience by completing a short survey.
```
## 2026-11-11: version 1.0, build 23, submission 01487b42

| Field | Record |
| --- | --- |
| Date received | 2026-11-11 7:17 AM (ASC time), read in the owner's signed-in session the same day |
| Version / build / device | 1.0 (23), iPhone 17 Pro Max, iOS 27.2, internet active |
| Submission ID | `01487b42-af8f-4113-8091-012d7374080b`, submitted 2026-10-31 3:13 PM with the MACROS Pro group, Monthly, Yearly and Lifetime |
| Message type | Rejection; the app version is Rejected and the four purchase items are back to Ready for Review |
| Guideline cited | **2.1(a) Performance: App Completeness**, "In-App purchases are unavailable in the app." |
| Attachment | `Screenshot-1111-130937.png` (downloaded; kept outside the repository). It shows the Pro paywall with Yearly, Monthly and Lifetime all "Unavailable", "Some purchase options are unavailable. Please try again.", Retry, and a disabled "Purchase Unavailable" button. StoreKit returned no products without an error. |
| Checked in ASC and the developer portal (2026-11-11) | Product IDs `macros.pro.yearly`, `macros.pro.monthly`, `macros.pro.lifetime` match the code; each has a price, an en-US name and description, and all 175 regions; the group has an en-US display name; Paid Apps Agreement (Oct 25, 2026 to May 7, 2027), bank account and W-9 are active; App ID `juan-test.cal-macro-tracker` has In-App Purchase enabled. Every item in Apple's TN3186 checklist passes. The legacy `fullunlock001` sits separately in Waiting for Review. |
| What we are changing | Products load at launch and again on foreground, with bounded automatic retries, merged partial results and StoreKit diagnostics in the log (branch `app/iap-load-hardening`), then build 37 |
| Our reply / resubmission | Pending, owner approved resubmitting with build 37 |
| Outcome | Pending |

### Exact Apple message

```text
Hello,

Thank you for your resubmission. Upon further review, we identified additional issues that need your attention. See below for more information.

If you have any questions, we are here to help. Reply to this message in App Store Connect and let us know.

Review Environment
Submission ID: 01487b42-af8f-4113-8091-012d7374080b
Review date: November 11, 2026
Review Device: iPhone 17 Pro Max
Version reviewed: 1.0 (23)

App Version
Guideline 2.1(a) - Performance - App Completeness
Issue Description

The app exhibited one or more bugs that would negatively impact users.

In-App purchases are unavailable in the app.

Review device details:

- Device type: iPhone 17 Pro Max
- OS version: iOS 27.2
- Internet Connection: Active

Next Steps

Test the app on supported devices to identify and resolve bugs and stability issues before submitting for review.

If the bug cannot be reproduced, try the following:

- For new apps, uninstall all previous versions of the app from a device, then install and follow the steps to reproduce.
- For app updates, install the new version as an update to the previous version, then follow the steps to reproduce.

Note that users expect apps they download to function on all the devices where they are available. For example, apps that may be downloaded onto iPad devices should function as expected for iPad users.
```

## Entry template

Copy this section for each rejection or review-message thread. Preserve verbatim wording and original file names; redact credentials and personal contact details only in the Git copy. Keep the unredacted original in owner-controlled secure storage.

### YYYY-MM-DD: version / build, thread reference

| Field | Record |
| --- | --- |
| Date received, time, timezone | |
| Version / build / platform / localization | |
| ASC submission ID / review item ID / thread reference | |
| Message type | Rejection / metadata rejection / information request / reply / approval / other |
| Guideline cited (exact) | |
| Exact Apple message | Paste full text below; no paraphrase |
| Attached files | Exact original file names; local evidence paths; SHA-256 if available; “none” only after checking |
| What we changed | Specific metadata/code/config change; commit SHA and affected files |
| Why | How the change addresses the cited issue; remaining disagreement or ambiguity |
| Our exact reply | Paste below or link a preserved transcript |
| Resubmission date, time, timezone | |
| Resubmitted version/build and submission ID | |
| Outcome and date | Pending / approved / rejected again / appeal; full follow-up text |
| Evidence source and export date | ASC API/UI export, email, attachment; pagination/access gaps |
| Owner approval | Decision, date; never infer authorization from a draft |

#### Exact Apple message

```text
[Paste the entire message. This is a template, not a recovered message.]
```

#### Exact reply / subsequent messages

```text
[Paste the full exchange in chronological order.]
```

## Preservation procedure

1. Export the complete text and take screenshots of the ASC conversation. Download all attachments before resubmitting; retain original filenames.
2. Keep each version/build under an owner-controlled evidence folder, with a text record of the issue, fix, reason, reply, and outcome. Store credentials outside the repository.
3. Record approved fixes as well as disputes. Approval is an outcome, not evidence that future enforcement cannot revisit earlier conduct.
4. On a new rejection, compare the full cited message with the previous fix before changing metadata or resubmitting. Escalate ambiguity to the owner rather than guessing.

Rationale: developer reports from [Shoemaker](https://x.com/pbsIdentity/status/2116271984803983393), [Vladyslav](https://x.com/Zeil_Zeil/status/2117270386756702423), and [Stacy](https://x.com/stacy_siz/status/2115505304460840960) describe problems reconstructing older rejection histories. They do not establish a rejection history for MACROS. [Apple's review guidance](https://developer.apple.com/app-store/review/guidelines/#after-you-submit) recommends communicating with App Review about specific issues.
