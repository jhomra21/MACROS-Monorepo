/// <reference types="bun" />
import { describe, expect, it } from 'bun:test';
import worker from './worker';
import type { WorkerEnv } from './worker';

// Retention failure list: exact-boundary rows must remain, newer rows must remain,
// empty tables must terminate, multi-batch deletion must stop on zero changes, and
// a permanently nonempty batch sequence must stop at the hard iteration cap.

function fakeDatabase() {
	let writes = 0;

	const database = {
		get writes() { return writes; },

		prepare() {
			return {
				bind() {
					return {
						async run() {
							writes += 1;

							return { meta: { changes: 1 } };
						},
					};
				},
			};
		},
		async batch() {
			return [{ meta: { changes: 0 } }, { meta: { changes: 0 } }];
		},
	};

	return database satisfies WorkerEnv['SUPPORT_DB'] & { readonly writes: number };
}

describe('website form hardening', () => {
	it('returns 429 with Retry-After without writing when support quota is exhausted', async () => {
		const db = fakeDatabase();

		const response = await worker.fetch(new Request('https://example.test/api/support', {
			method: 'POST',
			headers: {
				'cf-connecting-ip': '203.0.113.8',
				'content-type': 'application/json',
				accept: 'application/json',
			},
			body: JSON.stringify({ name: 'Test User', email: 'test@example.com', message: 'A detailed message.' }),
		}), {
			ASSETS: { fetch: async () => new Response() },
			SUPPORT_DB: db,
			SUPPORT_LIMITER: { limit: async () => ({ success: false }) },
		});

		expect(response.status).toBe(429);
		expect(response.headers.get('retry-after')).toBe('60');
		expect(db.writes).toBe(0);
	});
});

type FormRow = { created_at: string };

type DatabaseStatement = ReturnType<ReturnType<WorkerEnv['SUPPORT_DB']['prepare']>['bind']>;

function retentionDatabase(rows: { support_requests: FormRow[]; waitlist_entries: FormRow[] }, alwaysDelete = false) {
	let batches = 0;

	const statementMetadata = new WeakMap<DatabaseStatement, {
		table: 'support_requests' | 'waitlist_entries';
		cutoff: string;
	}>();

	const database = {
		get batches() { return batches; },
		rows,

		prepare(query: string) {
			const table = query.includes('support_requests') ? 'support_requests' : 'waitlist_entries';

			return {
				bind(cutoff: string) {
					const statement: DatabaseStatement = {
						async run() {
							return { meta: { changes: 0 } };
						},
					};

					statementMetadata.set(statement, { table, cutoff });

					return statement;
				},
			};
		},

		async batch(statements: DatabaseStatement[]) {
			batches += 1;

			return statements.map((statement) => {
				const metadata = statementMetadata.get(statement);

				if (metadata == null) throw new Error('Missing retention statement metadata.');

				const { table, cutoff } = metadata;

				if (alwaysDelete) return { meta: { changes: 1 } };

				const expired = rows[table].filter((row) => row.created_at < cutoff).slice(0, 500);

				rows[table] = rows[table].filter((row) => !expired.includes(row));

				return { meta: { changes: expired.length } };
			});
		},
	};

	return database satisfies WorkerEnv['SUPPORT_DB'] & { readonly batches: number; rows: typeof rows };
}

async function purgeAt(rows: { support_requests: FormRow[]; waitlist_entries: FormRow[] }, alwaysDelete = false) {
	const database = retentionDatabase(rows, alwaysDelete);

	await worker.scheduled({ scheduledTime: Date.UTC(2026, 9, 25, 3, 17) }, {
		ASSETS: { fetch: async () => new Response() },
		SUPPORT_DB: database,
	});

	return database;
}

describe('website form retention', () => {
	it('preserves rows exactly at the 365-day boundary and newer', async () => {
		const boundary = '2025-10-25 03:17:00';
		const newer = '2025-10-25 03:17:01';

		const rows = {
			support_requests: [
				{ created_at: '2025-10-25 03:16:59' },
				{ created_at: boundary },
				{ created_at: newer },
			],
			waitlist_entries: [
				{ created_at: '2025-10-25 03:16:59' },
				{ created_at: boundary },
				{ created_at: newer },
			],
		};

		await purgeAt(rows);

		expect(rows.support_requests).toEqual([{ created_at: boundary }, { created_at: newer }]);
		expect(rows.waitlist_entries).toEqual([{ created_at: boundary }, { created_at: newer }]);
	});

	it('terminates cleanly for empty tables', async () => {
		const database = await purgeAt({ support_requests: [], waitlist_entries: [] });

		expect(database.batches).toBe(1);
	});

	it('loops over bounded batches until a batch deletes no rows', async () => {
		const old = { created_at: '2020-01-01 00:00:00' };

		const rows = {
			support_requests: Array.from({ length: 501 }, () => ({ ...old })),
			waitlist_entries: [],
		};

		const database = await purgeAt(rows);

		expect(database.batches).toBe(3);
		expect(rows.support_requests).toHaveLength(0);
	});

	it('stops when the hard iteration cap is reached', async () => {
		const database = await purgeAt({ support_requests: [], waitlist_entries: [] }, true);

		expect(database.batches).toBe(100);
	});
});
