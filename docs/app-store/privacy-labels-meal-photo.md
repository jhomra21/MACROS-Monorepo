# App Store privacy labels: meal photo scanning

This is a planned mapping for optional meal photo scanning, available to MACROS Pro subscribers and with a 5-scan trial for non-Pro users. Confirm it against the final app binary, request implementation, vendor terms, and current App Store Connect questionnaire before saving the privacy answers. **Owner confirmation in App Store Connect is pending when this feature ships.**

## Planned flow

When the user starts a scan, the app sends a downscaled JPEG image of about 1024 pixels and a fixed prompt through a MACROS server to Google's paid Gemini API as a processor. The response contains suggested food names and gram estimates only. The user reviews and can edit those suggestions; the app calculates nutrition and calories from its food data.

MACROS relays the request and does not store the photo or model result. It may retain a per-device daily request count without content. Google does not use prompts or outputs from its paid API to train or improve products, but retains them for 55 days for abuse monitoring and legal requirements under its data processing terms.

## Working App Privacy mapping

| Data sent | Likely Apple data type | Purpose | Linked to you | Tracking |
| --- | --- | --- | --- | --- |
| Meal photo | User Content → Photos or Videos | App Functionality | Confirm against the final request and linkage details before selecting | No |
| Fixed prompt | Not user-added text; no separate Other User Content entry expected | App Functionality | Not applicable | No |
| Suggested food names and gram estimates returned by Gemini | Not sent by the app to the service as new user content; the result is transient and MACROS does not store it | App Functionality | Not applicable | No |
| Per-device daily request count retained by MACROS without content | Confirm the exact identifier and retention behavior before deciding whether this is reportable data | App Functionality | Confirm before selecting | No |

Do not add **User Content → Other User Content** for the fixed prompt alone. Reassess if the app begins sending user-entered text, such as a user-written description or note. Do not claim the image is not linked to identity without checking whether the final request or service logs retain an IP address, device identifier, or other linkable metadata. The planned feature is not used for tracking.

Apple's guidance says data transmitted off device and retained in a form accessible to the developer or third-party partner beyond servicing the request is collected. The photo is sent to a third party and Google retains prompts and outputs for 55 days, so assess the photo under the corresponding data type even though the feature does not store it in MACROS. Select **App Functionality**, not analytics or advertising.

Google reference: [Gemini API usage policies](https://ai.google.dev/gemini-api/docs/usage-policies).

Apple reference: [App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/).
