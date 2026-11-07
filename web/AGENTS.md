# Website

- Use Bun and frozen lockfiles. See [setup](../docs/development/setup.md) and [validation](../docs/development/validation.md).
- Run `bun run check` for Wrangler types, Astro checks, and TypeScript. Oxlint does not validate Astro template semantics.
- Run `bun run build` on macOS when checking social-image output. The generator uses macOS Helvetica; Linux CI runs check, not build.
- Never run deploy as validation: it builds, applies remote D1 migrations, and publishes. Remote migrations and deployment require authorization.
- Keep wrangler.jsonc tooling for dev/deploy. Do not run cf init/dev/build/deploy while the cf Astro limitation remains.
- Long-form copy in guides, blog, and other pages always gets an unslop pass before shipping, without waiting to be asked.
- Cite primary sources for health/nutrition figures. App behavior claims must match current code.
- Illustrate guides with real app screenshots from `src/assets/app-images/` or authorized fresh media-simulator captures.
- Use static inline SVG or HTML/CSS diagrams, with no extra client JavaScript for illustrations.
- Prefer a visual explainer for numbers and math in blog posts and guides: a static HTML/CSS or inline SVG diagram placed with a `<!-- visual:... -->` marker as described in [SEO](SEO.md), rather than a bare table or long prose math.
- Follow [SEO](SEO.md); preserve support/waitlist privacy and retention behavior when changing forms.
- Keep README screenshots and `docs/app-store/` creative assets. Raw captures belong in ignored build/evidence; tracked evidence follows the root 2 MiB/five-image policy.
