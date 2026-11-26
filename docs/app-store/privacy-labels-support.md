# App Store privacy label: in-app support

Update the MACROS App Privacy answers in App Store Connect when the in-app support endpoint is live. Apple says data sent off device and retained in readable form beyond servicing the request is collected. The support service sends requests to the support mailbox and uses them only to answer support.

| Apple data type | Purpose | Linked to you | Tracking |
| --- | --- | --- | --- |
| Contact Info → Email Address (only when the optional email is provided) | App Functionality → Customer Support | Not linked to you, per the owner’s requested classification | Not used for tracking |
| User Content → Customer Support (category and message) | App Functionality → Customer Support | Not linked to you, per the owner’s requested classification | Not used for tracking |
| Diagnostics → Other Diagnostic Data (app version/build, iOS version, and device model, included to diagnose support reports) | App Functionality → Customer Support | Not linked to you, per the owner’s requested classification | Not used for tracking |
| Other Data → Other Data Types (request IP used only for rate limiting; retained in an IP-keyed counter for up to one hour and not emailed) | App Functionality | Not linked to you, per the owner’s requested classification | Not used for tracking |

These selections follow Apple’s data type names and purposes: [App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/). Apple classifies “Customer Support” under User Content and “Other Diagnostic Data” as technical diagnostics. The app sends no name, user ID, food data, Pro status, or other locale/device details.

Confirm the linkage answers against the final retention and mailbox workflow before saving: Apple considers data linked when it can be tied to a person via an account, device, or other details. This feature intentionally sends no account or device identifier, but an optional email address and the network IP deserve particular review under that definition.
