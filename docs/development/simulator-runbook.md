# Simulator runbook

## Safety and ownership

Never erase, reset, or seed `9843E820-3A2A-4599-9206-D224B3035A47`, the owner's iPhone 18 Pro fixture. Do not use it for tests. Keep at most four devices booted and at most one stock. Never shut down a reserved, unknown, or actively claimed device to meet this budget.

Keep exactly one simulator per device model per iOS version. Reuse existing devices; do not create a simulator for QA or tests. Creation is only for an owner-approved new model/runtime replacing an old device. Clean-install checks use the iPad runner or an available empty iPhone, not private owner state. Authorized tasks may erase/reinstall/change settings/seed those disposable fixtures and must leave them usable.

Acquire `/tmp/macros-sim-locks/<UDID>` with atomic `mkdir` before device use. An existing lock means claimed, not stale by assumption. Record task ownership, do not steal locks, and release only your own lock with `rmdir` after cleanup. If no suitable device is free, report the blocker. Do not use shutdown-all, erase-all, or runtime removal as troubleshooting shortcuts.

The media iPhone 18 Pro Max and owner fixture stay stock. The iPad runner, iPhone 17, 17e, and Air use simslim with [macros-slim.json](../../tools/sim/macros-slim.json). Verify a booted device with `simslim verify <UDID> --profile tools/sim/macros-slim.json`; authorized repair uses `simslim on` with the same profile. Install with `brew install mobai-app/tap/simslim` if needed. Do not boot just to update documentation.

Historical measurement (2026-10-30, 180 seconds settled): about 7.4 GB slim iPhone 17 versus 10.6 GB stock media iPhone. These are not current memory measurements or proof of current slimming state.

## Discover first

```sh
xcode-select -p
xcodebuild -version
xcrun simctl runtime list
xcrun simctl list devices
```

Observed 2026-11-05, read-only: active `/Applications/Xcode-26.4.1.app/Contents/Developer` reports Xcode 27.0 (27A266a). `/Applications/Xcode.app` reports Xcode 26.4 (17E192). Select per command with DEVELOPER_DIR rather than changing the system default.

Live runtime disk images were both Ready: iOS 27.0 (24A434), image `9BCFD3EA-65E8-4996-BD4E-218799C1F30F`; iOS 26.5 (23F77), image `EC37288C-B4E6-4240-8230-27CBD3BE073D`. Total: 2 images, 15.4G. This conflicts with the owner's 26.5 removal note; do not resolve that conflict by deleting anything. There were no 26.5 devices.

All observed devices below were Shutdown on iOS 27.0. Rediscover before use.

| Device | UDID | Role |
| --- | --- | --- |
| iPhone 18 Pro | 9843E820-3A2A-4599-9206-D224B3035A47 | Protected owner fixture |
| MACROS-iPhone-18-Pro-Max-2026-10-30 | D16C3D35-889F-404F-BDD4-C640A6DBC4EF | App Store demo media, 9:41 status bar |
| iPhone 17e | F976E800-DA1F-4F20-B755-DFD964E33975 | Disposable QA |
| iPhone Air | 844B72D7-D128-4607-AB2E-6C14B024618F | Disposable QA |
| iPhone 17 | 918D29B9-97D3-42C0-9C47-00605E01E8DB | Disposable QA |
| MACROS-iPad-Air-11-2026-10-29 | E91B597B-CE57-4C0B-A8A4-51CBDC3386AB | Serial tests, iPhone compatibility mode |

## StoreKit compatibility evidence

The 2026-10-26 probe activated the catalog on Xcode 26.4 (17E192) with iOS 27.0. It reported 18/18 entitlement tests, but only 11/14 StoreKit tests plus a separate Ask to Buy timeout. iOS 26.4 rejected activation with SKInternalErrorDomain Code=3; Xcode 27.0 hung that older probe. These are dated results, not a blanket current pass or prohibition.

For the known-good toolchain use `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` explicitly with the serial [test command](validation.md). Rerun PurchaseStoreStoreKitTests before promoting another toolchain. Simulator results cannot close sandbox purchase, second-device restore, Family Sharing, or legacy real-account checks. See [active plans](../plans/README.md). No payment tests or device changes were made for this runbook.
