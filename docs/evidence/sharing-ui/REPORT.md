# Sharing UI and ring polish (build 25 owner bugs)

Branch `fix/sharing-ui-ring-polish` (base `origin/main` 9761515). iPhone 17 simulator, iOS 27.0, Xcode 27.0 (`Xcode-26.4.1.app`).

## How the screens were checked

- **Rings (bug 4):** the real app, live, on the simulator, with the empty dashboard. Dark and light.
- **Sharing list, person screen, + menu (bugs 1 to 3):** the real app, live, but fed by a **temporary in-process mock sharing backend** (`-sharingUIHarness` launch argument, four people: Alex with goals and 2 foods, Sam paused, Jordan not sharing, Kai without goals). It was not committed. **The dev Convex backend (energized-pigeon-822) and the two-device pairing were not used**, so none of these screens ran against real server data. The mock also forced Pro on for the invite-share-sheet capture only.

## Bug 4: ring seam line

Root cause (confirmed): `.glassEffect(in: Circle().stroke(style:))` makes glass from a stroked path. It draws a glass edge highlight along the inside of the band and at every ring seam. Wrapping the three tracks in one `GlassEffectContainer` did not remove it. A glass disc masked to the band also did not, until the glass frame was sized to the ring plus one line width.

Fix: glass the filled `Circle()` (sized `diameter + lineWidth`) and mask it to the stroked band. Same tint, same animatable diameter, no extra layers.

- Zoom, collapsed: `seam-zoom-before.png` / `seam-zoom-after.png`
- Zoom, mid-transition (video frame): `seam-zoom-mid-before.png` (line through the middle of the track) / `seam-zoom-mid-after.png` (one smooth band)
- Collapsed / mid / expanded, dark: `rings-before-*-dark.png`, `rings-after-*-dark.png`
- Collapsed / expanded, light (after only): `rings-after-collapsed-light.png`, `rings-after-expanded-light.png`
- Rings with `usesGlassEffect: false` (list row, person screen) use a different code path and look clean in the screenshots below.

Not captured: a before shot in light mode, and Reduce Motion.

## Bug 1: person screen

Cause (confirmed): the "Today" section had the rings and legend as two List rows, so the List drew a separator between them.

Fix: one row, rings above the legend, reusing the dashboard's `.dashboardCard` legend style (`of N g`). Rings are a little larger (180). System insetGrouped sections, segmented picker, and destructive Remove are unchanged. No custom glass cards.

- Before: `person-before-dark.png`, `person-before-light.png`
- After: `person-after-dark.png`, `person-after-light.png`
- No goals (empty rings, P/C/F text): `person-after-no-goals-dark.png`
- Paused: `person-after-paused-dark.png`

Not captured: the not-shared state after the change (it was only seen before), and the "no macros today" state.

## Bug 2: blue text in the sharing list

Cause (confirmed): `NavigationLink` rows inside a `ScrollView` / `LazyVStack` take the accent tint. Fix: a standard `List` (chevrons and separators) with primary name, secondary totals and status, orange for paused. Small rings kept.

- `sharing-list-before-dark.png`, `sharing-list-after-dark.png`

## Bug 3: + button menu

`+` is now a `Menu` with the same `appTopBarIconStyle()` label. Gear still opens settings.

- **Create Invite:** reuses `SharingSyncService.createInvite()` and presents the invite link in the system share sheet. Pro-gated like the Settings flow: free users get the Pro paywall, and if sharing is off on the device it opens Sharing settings.
- **Accept Invite:** opens the existing Sharing settings screen, which already has the "Invite token or link" field and confirmation. No invite logic was duplicated.
- Backup's private share sheet became a shared `URLShareSheet` (in `App/`, not `Shared/`, which is also compiled into the widget).

Evidence: `plus-menu-after-dark.png`, `create-invite-share-sheet-pro-dark.png`, `create-invite-free-paywall-dark.png`.

Not verified: a real invite creation against the dev backend, and accepting an invite from this menu end to end. The mock backend returns a fixed token.

## Validation

- `make quality-format-check`: clean.
- `make quality-build`: succeeded. The remaining warnings are in files this branch does not touch.
- Full suite on iPad `E91B597B`, serial, AGENTS.md time limits, skipping `PurchaseStoreStoreKitTests`: **217 tests, 0 failures**.
- No unit tests were added.
