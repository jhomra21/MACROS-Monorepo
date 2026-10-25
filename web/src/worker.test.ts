/// <reference types="bun" />
import { describe, expect, it } from 'bun:test';
import worker from './worker';
import type { WorkerEnv } from './worker';

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
