# Website Form Retention QA

Date: 2026-10-25

## Wrangler local scheduled-handler run

- Applied the existing support and waitlist D1 migrations to an isolated local D1 database under this artifact directory.
- Seeded support and waitlist rows at `datetime('now', '-366 days')` and `datetime('now')`.
- Started `wrangler dev --test-scheduled` with the isolated D1 persistence directory.
- Invoked `GET /__scheduled?cron=17+3+*+*+*`; Wrangler returned HTTP 200, `Ran scheduled event`.
- Queried D1 after the event: expired support and waitlist rows each had 0 remaining; recent support and waitlist rows each had 1 remaining.

## Miniflare integration

- `tools/runtime-qa/runtime-e2e.ts` dispatched the Worker scheduled handler against Miniflare D1 fixtures.
- The end-to-end suite passed: 129 loopback HTTP requests, 59 assertion groups. The scheduled purge removed one old row from each table and retained the recent waitlist entry.
