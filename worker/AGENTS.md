# Workers

- auth owns sharing identity/tokens and invite redirects; usda-proxy owns provider lookup and food-search normalization.
- Use Bun, frozen lockfiles, and each package's existing scripts. Run `bun run check` in each affected package.
- auth check includes Bun tests. usda-proxy runtime contracts run through [runtime QA](../tools/runtime-qa/README.md), not a nonexistent package test script.
- Run `make qa-network` from the root after installing runtime-QA and Convex dependencies; it uses isolated loopback/mock services, not production credentials.
- Do not deploy or modify production services/secrets as validation. Keep credentials out of logs and reports.
- Keep wrangler.jsonc dev/deploy commands. Use cf only for authorized account/resource work; no cf init/dev/build/deploy migration during the Astro limitation.
- Preserve rate limits, upstream budgets/deadlines, degraded/no-store responses, and editable offline fallbacks.
