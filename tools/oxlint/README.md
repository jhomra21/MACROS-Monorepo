# JavaScript and TypeScript lint

This private Bun package pins Oxlint and its plugin SDK together. Swift quality commands remain separate.

From the repository root:

```sh
cd tools/oxlint
bun install --frozen-lockfile
bun run typecheck
bun run smoke
cd ../..
make lint-js
```

The root `.oxlintrc.json` enables all 18 generic anti-slop rules, native `oxc/no-accumulating-spread`, and classic `eslint/complexity` at error with maximum 20. Generated, installed, vendored, and agent assets are excluded; owned application and QA source remain included.

Oxlint checks supported JavaScript/TypeScript, including supported script regions in Astro inputs. It does not validate Astro template semantics or Swift. Native default rules may also report warnings.

`make lint-js` passes with zero errors and warnings. Cleanup uses schema-validated boundary parsing and owner-derived types, not lint suppressions or unsafe casts. Re-run the repository lint command after changes; its rules and coverage remain unchanged. The smoke command separately proves plugin loading, controlled positive/negative examples, and the complexity 20/21 boundary.

The vendored source is unchanged. See [`anti-slop/UPSTREAM.md`](anti-slop/UPSTREAM.md) for its exact preserved snapshot, checksum manifest, unknown generic upstream revision, and nested license.
