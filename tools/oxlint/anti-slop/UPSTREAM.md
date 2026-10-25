# Vendored anti-slop provenance

- Source repository: unknown. These assets were supplied in the installed `install-anti-slop` skill at `/Users/juan/.factory/skills/install-anti-slop/assets/anti-slop`; the skill bundle does not identify a repository revision for the generic plugin.
- Source commit: unknown. Do not infer the generic plugin revision from the nested ESLint Stylistic source.
- Installed paths: `tools/oxlint/anti-slop/index.ts` and its relative `rules/`, `shared/`, `effect/`, and `vendor/eslint-stylistic/` modules.
- Recovery and verification: `anti-slop-pristine-snapshot.tar.gz` preserves the exact original skill asset tree. `SHA256SUMS` records each original file hash; compare after extracting the snapshot to verify the installed copy. The snapshot hash is `3301b003a0225e1ab00d36ea1b22fe1982ca9c1bdde98c47f31e48d78f8a4216`.
- The archive has a top-level `anti-slop/` directory and macOS AppleDouble `._*` metadata entries. `SHA256SUMS` covers the 38 actual source/license/provenance files, not those metadata entries.
- Nested vendored rule: `vendor/eslint-stylistic/UPSTREAM.md` identifies the padding-line rule's exact source files and ESLint Stylistic commit `435c3ea0fd26a5fef9042c4b36b6e165fbbf8d08`; its adjacent MIT license is retained. That commit identifies only the nested rule, not the generic anti-slop plugin.
- Deviations: none to the copied plugin source. Generic rules are enabled by the root `.oxlintrc.json`; the optional Effect plugin files are vendored but not registered because no package directly depends on Effect.
