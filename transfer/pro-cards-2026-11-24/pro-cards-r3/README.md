# Pro feature card evidence

Captured on iPhone 17 (iOS 27.0) at 9:41. Screenshots are JPEGs resized to
1300 px high. The temporary XCUITest used the project StoreKit configuration
and verified the yearly plan displayed `$19.99`.

| Screenshot | State | Paired card background bounds (inclusive JPEG y pixels) |
| --- | --- | --- |
| [general-top.jpg](general-top.jpg) | Settings → Pro, light | Sharing / Shared widgets: 632–863; Weight / More reminders: 882–1142 |
| [reminders-context-top.jpg](reminders-context-top.jpg) | Multiple reminders contextual paywall | Sharing / Shared widgets: 882–1112 |
| [dark-general-top.jpg](dark-general-top.jpg) | Settings → Pro, dark | Sharing / Shared widgets: 632–863; Weight / More reminders: 882–1142 |
| [ax-xxxl-top.jpg](ax-xxxl-top.jpg) | Settings → Pro, Accessibility XXXL | Single-column layout, no paired rows; the visible first card scrolls normally |

Edges are inclusive y-pixel rows of the opaque card fill measured at interior
x coordinates in the 1300-pixel-high JPEGs. The rounded-corner antialias fringe
is excluded; its visible transition is within one pixel of these bounds.
Paired fills have matching top and bottom rows. Wide contextual cards and the
AX single-column card retain content-sized heights; scrolling continues to
the plan rows.
