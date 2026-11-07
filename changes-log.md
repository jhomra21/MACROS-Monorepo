# Changes Log

Current history. Older records retain their original wording and dated limitations.

See the [app archive index](docs/history/app/README.md) for every archived heading. See [plans](docs/plans/README.md) for current obligations.

## 2026-11-06 Website feature screenshots

Replaced the six home feature glyphs with deterministic app screenshot crops and responsive AVIF/WebP images, preserving copy and motion. Personal widget crops exclude shared data. Web checks, nine Worker tests, build, lint, and six viewport/theme captures pass; desktop images total 58 KB at 1×. See [crop rectangles and visual evidence](docs/evidence/web-feature-images/README.md).

## 2026-11-05 StoreKit test timing

Stabilized StoreKit test delivery/reset ordering, moved Ask to Buy test IPC off the main actor, and retained cold legacy-refresh coverage without changing app entitlement behavior. Legacy publication timing reproduced; the historical Ask to Buy timeout's blocking site remains unproven. Validation: ten independent 15/15 StoreKit passes, 262/262 remaining tests, formatting, build, and catalog checks pass. See [evidence and same-process stress limitation](docs/evidence/storekit-test-timing/README.md).

## 2026-11-05 Apple configuration paths

Moved the three Info plists and StoreKit catalog to `config/apple/`, updating Xcode, the shared scheme, validation tooling, and active docs without changing configuration contents or source. Validation: build, plist/settings, StoreKit config, lint, formatting, links, bundle parity and 262 tests pass; Xcode 26.4 StoreKit tests execute zero tests because the iPad destination is unavailable, reproduced on unchanged `a12f579`.

## 2026-11-05 Repository cleanup

Corrected tooling/purchase docs, split scoped instructions, moved development guides and status-indexed plans, and archived old history. Removed approved old evidence media while retaining build-33 captures and text reports; untracked personal scheme metadata. Linux-only quality CI and the rule migration checklist are in the [cleanup record](docs/repo-cleanup-plan.md). Native/web and offline checks pass; no release/device gate was closed.
