# Evidence policy

Raw run output goes to ignored `build/evidence/<date>-<task>/`. Keep a repeatable report, commands or exact UI steps, source commit/build, runtime/toolchain, isolated fixture, expected/observed outcomes, and blocked cases. Never include secrets or private owner data.

For each tracked task, keep a README plus at most five selected images totalling 2 MiB. Do not track videos, frame sequences, or xcresult bundles. A larger exception needs a stated reason in that task's README. The owner's general under-5-MB E2E artifact rule does not raise this repository's tracked limit. Keep raw logs/captures local; a local path is not a durable archive.

Reproducible scripts, small JSON, text reports, test fixtures, README screenshots in web/src/assets/app-images, and deliberate App Store assets have separate roles. Do not delete them by extension alone.

## Cleanup baseline

The 2026-11-05 cleanup removed old binary media from every evidence task except the shipped TestFlight build-33 features: weight-unit, search-row-polish, and insights-weight-card-width. Those three folders are retained unchanged as owner-approved historical exceptions to the five-image rule. README screenshots and docs/app-store were untouched.

Removed media remains in Git at main commit `074b10994f1b68d9d7a8d6c54ed7effb90d5f1f5`. Reports keep retrieval instructions with original paths. No uploads, LFS migration, or history rewriting occurred; ordinary deletion does not reduce old clone history.

Example, from the repository root:

```sh
git show 074b10994f1b68d9d7a8d6c54ed7effb90d5f1f5:docs/evidence/web-og/home.0eb2b274470d.png > build/recovered.png
```

Replace the example filename with the exact path in the report or `git ls-tree -r` at that commit. The ignored local cleanup manifest records every removed path, byte size, and SHA-256; it is a run artifact, not a new committed archive.
