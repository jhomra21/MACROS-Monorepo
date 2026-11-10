# Native app

Read [the Swift guide](../docs/development/swift.md) and [validation guide](../docs/development/validation.md).

- Use native SwiftUI, small feature-focused views, and composition rather than UIKit-style layers or a view model per view.
- Native iOS behavior comes first, design-skill advice second. Never remove or replace what iOS provides, and never add extra behavior (haptics, custom styling, spinners, press effects) on top of system menus, pickers, buttons, sheets, the keyboard, or the share sheet. Polish only the app's own views.
- Keep state close to its use. Prefer `@State`, `@Binding`, `@Observable`, and `@Environment`; share state only when callers need it.
- Organize new code by feature, not global Views/Models/ViewModels directories.
- Use async/await and lifecycle-aware tasks. Keep loading, errors, and editable fallbacks explicit.
- Keep primary data in SwiftData on device with iOS file/data protection. Store small secrets in Keychain.
- Preserve account-free import/export. HealthKit is optional OS permission, not an app login requirement.
- Keep persisted nutrition and log snapshots deterministic; root calculation/review rules also apply here.
- App, widget, and tests share selected source through synchronized Xcode groups. Review membership when adding non-source files.
- `AGENTS.md` and `CalMacroWidget/AGENTS.md` are explicitly excluded from app/widget resources. Keep that exclusion when changing groups.
- Migration fixtures, StoreKit catalogs used by tests, and other test resources belong in `cal-macro-trackerTests`, never the app bundle.
- Run simulator tests serially with 30-second default and 45-second maximum allowances, using the runbook's safe device selection and lock protocol.
- Never use the protected owner fixture for tests, reset it, or seed demo data on it.
- Swift 6 compiler availability is not Swift 6 language mode: project `SWIFT_VERSION` remains 5.0. Do not change concurrency/build settings as cleanup.
