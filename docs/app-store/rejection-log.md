# MACROS rejection and review-message log

App ID `6767565938`, bundle `juan-test.cal-macro-tracker`. Audit: 2026-11-03.

## Findings and access limits

**No past App Review rejection or Resolution Center message was found in the inspected repository records. ASC history is unavailable, not verified empty.**

This Mac had no usable ASC API key/configuration or `asc` CLI in the checked locations. No authenticated request to app-store-version submissions, review-submission items, or Resolution Center messages was possible. We cannot establish that ASC has no rejections, quote any Apple review message, or enumerate its attachment names. Version 1.0 “Waiting for Review” comes from the owner and does not imply a clean prior history.

Read-only searches covered:

- `changes-log.md`, `docs/app-store/`, and implementation trackers at `91f5b5f4c08f2822ab4d1c75a9dcbe74e480d1b1`, plus the app-store evidence branch `174606fac59438a86e52f673c12217f7811b2285`.
- All fetched git commit subjects for rejection/Resolution Center/App Review/guideline terms and diffs in the history of those documentation paths for explicit guideline/review-rejection text.
- Repository “rejected” mentions. Most concern code reviews, input validation, or local StoreKit errors, not Apple App Review.

Do not turn these local events into rejection entries:

| Event | Evidence | Classification |
| --- | --- | --- |
| Duplicate build 7 blocked during build 8 upload | `implementation-trackers/testflight-release-tracker.md`, 2026-10-26 | Upload/build-number failure; no full Apple message or attachment names recorded. Not App Review rejection. |
| `SKInternalErrorDomain Code=3`, `WS2.StoreKitSetup Code=1`, `OctaneSaveConfigurationRequest` errors | `changes-log.md`, `implementation-trackers/pro-subscription-storekit-tracker.md` | Local simulator StoreKit setup failures, not a Resolution Center conversation. |
| TestFlight processing/upload reports | `implementation-trackers/testflight-release-tracker.md` | Upload/processing or beta-group evidence, not a rejection or proof of App Store approval. |

**Recovered full Apple review messages: 0. Recovered Apple review attachment filenames: 0.** This reports recovery results only. Ask the owner to export all ASC messages and attached files when access is available; preserve the full conversation, including information requests and approvals, not just formal rejections. Do not fabricate missing text from memory or a commit summary.

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
