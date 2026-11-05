# Development setup

Run commands from the active worktree, not a fixed owner checkout. There is no root package.json or JS workspace install.

## Native app

Use macOS and Xcode 26+ with the iOS SDK. The app targets iOS 26; a Swift 6 compiler builds Swift 5 language mode (`SWIFT_VERSION = 5.0`). Check the selected toolchain with `xcode-select -p` and `xcodebuild -version`; application folder names can be misleading.

```sh
xcodebuild -list -project cal-macro-tracker.xcodeproj
make quality-storekit
make quality-build
```

The shared schemes are `cal-macro-tracker` and `CalMacroWidget`. The app scheme runs `cal-macro-trackerTests`. Its StoreKit reference is `../../config/apple/MACROSPro.storekit`; the catalog also belongs to the test bundle. Pro plans are yearly, monthly, and lifetime, with legacy `fullunlock001` support. Catalog validation is not purchase-test evidence.

Install official swift-format (`brew install swift-format`) for formatting checks. Periphery is optional for `make quality-dead`. Read the [simulator runbook](simulator-runbook.md) before any device use. macOS builds are deferred.

## Support packages

Use Bun 1.4.4 and each package's frozen lockfile. The website requires Node >=22.23.4; runtime QA requires Node 22.18+ for native TypeScript. Install only the packages you need:

```sh
cd web && bun install --frozen-lockfile
# In a fresh shell from the repository root:
cd worker/auth && bun install --frozen-lockfile
# Repeat for worker/usda-proxy, convex-backend, tools/runtime-qa, tools/oxlint.
```

`worker/usda-proxy` dev uses port 8787; auth uses 8788. The Debug simulator app's packaged-food URL is loopback port 8787. Copy the proxy's `.dev.vars.example` to ignored `.dev.vars` only when live USDA development needs a key; do not commit it. Optional sharing development needs a configured Convex dev deployment, but offline validation does not.

Web `bun run dev` starts the Astro and API processes. Use `bun run check` for Linux-compatible checks. Social-image builds require macOS Helvetica. Deployment scripts are not validation: web deploy also applies remote D1 migrations. No setup command authorizes a deploy.

See [validation](validation.md) for check commands and [architecture](../architecture/README.md) for ownership.
