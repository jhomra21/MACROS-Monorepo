# Widget extension

Native and root rules apply. Use the repository's [WidgetKit review skill](../../.factory/skills/apple-widget-design-review/SKILL.md) for widget design and review.

- Keep WidgetKit entry/provider work separate from app UI. Share nutrition snapshots and app-group storage through existing Shared types.
- Preserve privacy, authorization, revocation, freshness, and per-person selection behavior. Do not treat a preview as proof of live timeline or Lock Screen behavior.
- Report unsupported or blocked device/family checks explicitly. Do not claim simulator previews cover physical-device behavior.
- Keep instruction Markdown excluded from both app and extension synchronized-group resources.
- Use isolated fixtures and the root simulator lock/budget policy. Never reset or seed the owner's fixture for widget verification.
