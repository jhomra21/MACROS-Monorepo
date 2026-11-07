/// <reference types="bun" />
import { describe, expect, it, spyOn } from 'bun:test';
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

// Custom-domain failure list: an old workers.dev or www link must not serve duplicate
// content; the redirect must keep the path and query; form POSTs on an old host must not
// be downgraded to GET or write anything; the canonical host and local dev hosts must
// reach assets untouched.
describe('canonical host redirects', () => {
	function hostEnv() {
		const db = fakeDatabase();
		let assetCalls = 0;

		const env = {
			ASSETS: {
				fetch: async () => {
					assetCalls += 1;

					return new Response('asset');
				},
			},
			SUPPORT_DB: db,
		};

		return { env, db, get assetCalls() { return assetCalls; } };
	}

	it('permanently redirects the workers.dev host, keeping path and query', async () => {
		const ctx = hostEnv();
		const response = await worker.fetch(new Request('https://macros-web.jhonra121.workers.dev/guides/how-to-set-macro-goals/?ref=ig'), ctx.env);

		expect(response.status).toBe(301);
		expect(response.headers.get('location')).toBe('https://macrosios.com/guides/how-to-set-macro-goals/?ref=ig');
		expect(ctx.assetCalls).toBe(0);
	});

	it('permanently redirects www to the apex host', async () => {
		const ctx = hostEnv();
		const response = await worker.fetch(new Request('https://www.macrosios.com/'), ctx.env);

		expect(response.status).toBe(301);
		expect(response.headers.get('location')).toBe('https://macrosios.com/');
	});

	it('uses 308 for form posts on an old host and writes nothing', async () => {
		const ctx = hostEnv();

		const response = await worker.fetch(new Request('https://macros-web.jhonra121.workers.dev/api/waitlist', {
			method: 'POST',
			headers: { 'content-type': 'application/json', accept: 'application/json' },
			body: JSON.stringify({ email: 'test@example.com' }),
		}), ctx.env);

		expect(response.status).toBe(308);
		expect(response.headers.get('location')).toBe('https://macrosios.com/api/waitlist');
		expect(ctx.db.writes).toBe(0);
	});

	it('serves the canonical host and local dev hosts from assets', async () => {
		for (const url of ['https://macrosios.com/guides/', 'http://localhost:8787/', 'https://example.test/about/']) {
			const ctx = hostEnv();
			const response = await worker.fetch(new Request(url), ctx.env);

			expect(response.status).toBe(200);
			expect(ctx.assetCalls).toBe(1);
		}
	});
});

// Byte-range failure list for /media/ (Safari plays MP4 only after a 206 to its bytes=0-1 probe):
// - Window: first-bytes, middle, open-ended, suffix, clamped, and single-byte ranges return exactly
//   those bytes with Content-Range, whatever the upstream chunk size (one byte, mid-window, larger than the file).
// - Streaming: the file is never buffered; the upstream is read only up to the range end and then
//   cancelled, and cancelling the response cancels the upstream.
// - 416 with bytes */size for a start at or past the end, bytes=-0, and any range on an empty file.
// - Whole file as 200 for multi-range, malformed, or end-before-start Range headers.
// - The static-assets binding sends no Content-Length (checked in wrangler dev), so a missing, non-numeric,
//   or negative one makes the file be measured by reading it, up to 8 MiB; a bigger file is sent whole as 200.
// - If-Range (RFC 9110 §13.1.5): a strong ETag must match a strong asset ETag; weak tags on either side,
//   a missing asset ETag, or an unknown validator mean 200. A date matches only when it equals
//   Last-Modified exactly and that Last-Modified is at least a second older than now (tested at
//   -5 s, 0, 999, and 1000 ms with a stubbed clock); a missing, mismatched, or malformed date means 200.
// - HEAD is never sliced; 304 and 404 pass through; Content-Type, Cache-Control, and ETag survive;
//   non-media paths keep the plain asset response.

const mediaBytes = Uint8Array.from({ length: 1000 }, (_, index) => index % 251);

type UpstreamProbe = { pulled: number; cancelled: boolean };

type MediaOptions = {
	status?: number;
	headers?: Record<string, string>;
	omitLength?: boolean;
	chunkSize?: number;
	bytes?: Uint8Array<ArrayBuffer>;
	probe?: UpstreamProbe;
};

function chunkedBody(bytes: Uint8Array, chunkSize: number, probe: UpstreamProbe) {
	let offset = 0;

	return new ReadableStream<Uint8Array>({
		pull(controller) {
			if (offset >= bytes.length) return controller.close();

			controller.enqueue(bytes.slice(offset, offset + chunkSize));
			offset += chunkSize;
			probe.pulled += 1;
		},
		cancel() {
			probe.cancelled = true;
		},
	});
}

function mediaEnv({ status = 200, headers: extra = {}, omitLength = false, chunkSize, bytes = mediaBytes, probe }: MediaOptions = {}) {
	return {
		ASSETS: {
			async fetch(input: RequestInfo | URL, init?: RequestInit) {
				const request = new Request(input, init);

				const headers = new Headers({
					'Content-Type': 'video/mp4',
					'Cache-Control': 'public, max-age=31536000, immutable',
					ETag: '"abc"',
					'Content-Length': String(bytes.length),
					...extra,
				});

				if (omitLength) headers.delete('Content-Length');

				if (status !== 200) return new Response(null, { status, headers });

				if (request.method === 'HEAD') return new Response(null, { headers });

				return new Response(chunkSize == null ? bytes : chunkedBody(bytes, chunkSize, probe ?? { pulled: 0, cancelled: false }), { headers });
			},
		},
		SUPPORT_DB: fakeDatabase(),
	};
}

function mediaRequest(headers: Record<string, string> = {}, path = '/media/demo.mp4', method = 'GET') {
	return new Request(`http://localhost${path}`, { method, headers });
}

async function bodyBytes(response: Response) {
	return new Uint8Array(await response.arrayBuffer());
}

describe('media byte ranges', () => {
	it('answers the first-bytes probe with exactly those bytes', async () => {
		const response = await worker.fetch(mediaRequest({ Range: 'bytes=0-1' }), mediaEnv());

		expect(response.status).toBe(206);
		expect(response.headers.get('content-range')).toBe('bytes 0-1/1000');
		expect(response.headers.get('content-length')).toBe('2');
		expect(response.headers.get('accept-ranges')).toBe('bytes');
		expect(response.headers.get('content-type')).toBe('video/mp4');
		expect(response.headers.get('cache-control')).toBe('public, max-age=31536000, immutable');
		expect(response.headers.get('etag')).toBe('"abc"');
		expect([...(await bodyBytes(response))]).toEqual([0, 1]);
	});

	it('serves open-ended, clamped, and suffix ranges', async () => {
		const cases = [
			['bytes=990-', 'bytes 990-999/1000', 990, 1000],
			['bytes=995-5000', 'bytes 995-999/1000', 995, 1000],
			['bytes=-10', 'bytes 990-999/1000', 990, 1000],
			['bytes=-5000', 'bytes 0-999/1000', 0, 1000],
		] as const;

		for (const [range, contentRange, start, end] of cases) {
			const response = await worker.fetch(mediaRequest({ Range: range }), mediaEnv());

			expect(response.status).toBe(206);
			expect(response.headers.get('content-range')).toBe(contentRange);
			expect(await bodyBytes(response)).toEqual(mediaBytes.slice(start, end));
		}
	});

	it('slices the same window from any upstream chunking', async () => {
		const windows = [[0, 0], [0, 9], [5, 20], [395, 405], [499, 500], [990, 999], [999, 999], [0, 999]] as const;

		for (const chunkSize of [1, 7, 64, 400, 1000, 5000]) {
			for (const [start, end] of windows) {
				const response = await worker.fetch(mediaRequest({ Range: `bytes=${start}-${end}` }), mediaEnv({ chunkSize }));

				expect(response.status).toBe(206);
				expect(response.headers.get('content-length')).toBe(String(end - start + 1));
				expect(await bodyBytes(response)).toEqual(mediaBytes.slice(start, end + 1));
			}

			const tail = await worker.fetch(mediaRequest({ Range: 'bytes=-10' }), mediaEnv({ chunkSize }));

			expect(await bodyBytes(tail)).toEqual(mediaBytes.slice(990));
		}
	});

	it('stops reading and cancels the upstream after the range end', async () => {
		const probe = { pulled: 0, cancelled: false };
		const response = await worker.fetch(mediaRequest({ Range: 'bytes=0-9' }), mediaEnv({ chunkSize: 100, probe }));

		expect(await bodyBytes(response)).toEqual(mediaBytes.slice(0, 10));
		expect(probe.cancelled).toBe(true);
		expect(probe.pulled).toBeLessThanOrEqual(2);
	});

	it('cancels the upstream when the client cancels, without buffering ahead', async () => {
		const probe = { pulled: 0, cancelled: false };
		const response = await worker.fetch(mediaRequest({ Range: 'bytes=0-899' }), mediaEnv({ chunkSize: 100, probe }));
		const reader = response.body!.getReader();

		expect((await reader.read()).value?.byteLength).toBe(100);
		expect(probe.pulled).toBeLessThanOrEqual(4);

		await reader.cancel();

		expect(probe.cancelled).toBe(true);
		expect(probe.pulled).toBeLessThan(9);
	});

	it('rejects unsatisfiable ranges with 416', async () => {
		for (const range of ['bytes=1000-', 'bytes=2000-3000', 'bytes=-0']) {
			const response = await worker.fetch(mediaRequest({ Range: range }), mediaEnv());

			expect(response.status).toBe(416);
			expect(response.headers.get('content-range')).toBe('bytes */1000');
		}

		const empty = await worker.fetch(mediaRequest({ Range: 'bytes=0-' }), mediaEnv({ bytes: new Uint8Array(0) }));

		expect(empty.status).toBe(416);
		expect(empty.headers.get('content-range')).toBe('bytes */0');
	});

	it('returns the whole file for multi-range, malformed, or absent Range headers', async () => {
		const wholeFileHeaders: Record<string, string>[] = [{ Range: 'bytes=0-1,5-6' }, { Range: 'items=0-1' }, { Range: 'bytes=5-2' }, {}];

		for (const headers of wholeFileHeaders) {
			const response = await worker.fetch(mediaRequest(headers), mediaEnv());

			expect(response.status).toBe(200);
			expect(response.headers.get('accept-ranges')).toBe('bytes');
			expect((await response.arrayBuffer()).byteLength).toBe(1000);
		}
	});

	it('measures the file itself when the asset sends no usable Content-Length', async () => {
		const unusable = [{ omitLength: true }, { headers: { 'Content-Length': 'abc' } }, { headers: { 'Content-Length': '-5' } }];

		for (const options of unusable) {
			for (const [range, status, contentRange, expected] of [
				['bytes=995-', 206, 'bytes 995-999/1000', mediaBytes.slice(995)],
				['bytes=-10', 206, 'bytes 990-999/1000', mediaBytes.slice(990)],
				['bytes=1000-', 416, 'bytes */1000', new Uint8Array(0)],
			] as const) {
				const response = await worker.fetch(mediaRequest({ Range: range }), mediaEnv({ ...options, chunkSize: 100 }));

				expect(response.status).toBe(status);
				expect(response.headers.get('content-range')).toBe(contentRange);
				expect(await bodyBytes(response)).toEqual(expected);
			}
		}

		const empty = await worker.fetch(mediaRequest({ Range: 'bytes=0-' }), mediaEnv({ omitLength: true, bytes: new Uint8Array(0) }));

		expect(empty.status).toBe(416);
		expect(empty.headers.get('content-range')).toBe('bytes */0');
	});

	it('sends the whole file when it is too large to measure without a Content-Length', async () => {
		const large = new Uint8Array(8 * 1024 * 1024 + 1);
		const response = await worker.fetch(mediaRequest({ Range: 'bytes=0-1' }), mediaEnv({ omitLength: true, bytes: large, chunkSize: 1024 * 1024 }));

		expect(response.status).toBe(200);
		expect(response.headers.get('content-range')).toBeNull();
		expect((await response.arrayBuffer()).byteLength).toBe(large.length);
	});

	it('honours If-Range only for a matching strong ETag', async () => {
		const cases: [string, Record<string, string>, number][] = [
			['"abc"', {}, 206],
			['"old"', {}, 200],
			['W/"abc"', {}, 200],
			['"abc"', { ETag: 'W/"abc"' }, 200],
			['W/"abc"', { ETag: 'W/"abc"' }, 200],
			['"abc"', { ETag: '' }, 200],
		];

		for (const [ifRange, assetHeaders, status] of cases) {
			const response = await worker.fetch(mediaRequest({ Range: 'bytes=0-1', 'If-Range': ifRange }), mediaEnv({ headers: assetHeaders }));

			expect(response.status).toBe(status);
			expect((await response.arrayBuffer()).byteLength).toBe(status === 206 ? 2 : 1000);
		}
	});

	it('honours an If-Range date only when it equals a strong Last-Modified', async () => {
		const old = 'Wed, 21 Oct 2015 07:28:00 GMT';

		const cases: [string, Record<string, string>, number][] = [
			[old, { 'Last-Modified': old }, 206],
			[old, { 'Last-Modified': 'Thu, 22 Oct 2015 07:28:00 GMT' }, 200],
			[old, {}, 200],
			['not a date', { 'Last-Modified': old }, 200],
			['not a date', { 'Last-Modified': 'not a date' }, 200],
			['', { 'Last-Modified': old }, 200],
		];

		for (const [ifRange, assetHeaders, status] of cases) {
			const response = await worker.fetch(
				mediaRequest({ Range: 'bytes=0-1', 'If-Range': ifRange }),
				mediaEnv({ headers: { ETag: '', ...assetHeaders } }),
			);

			expect(response.status).toBe(status);
		}
	});

	it('treats Last-Modified as strong only from one second before now', async () => {
		const modified = 'Wed, 21 Oct 2015 07:28:00 GMT';
		const clock = spyOn(Date, 'now');

		try {
			for (const [elapsed, status] of [[-5000, 200], [0, 200], [999, 200], [1000, 206]] as const) {
				clock.mockReturnValue(Date.parse(modified) + elapsed);

				const response = await worker.fetch(
					mediaRequest({ Range: 'bytes=0-1', 'If-Range': modified }),
					mediaEnv({ headers: { ETag: '', 'Last-Modified': modified } }),
				);

				expect(response.status).toBe(status);
			}
		} finally {
			clock.mockRestore();
		}
	});

	it('never slices HEAD and passes 304 and 404 through', async () => {
		const head = await worker.fetch(mediaRequest({ Range: 'bytes=0-1' }, '/media/demo.mp4', 'HEAD'), mediaEnv());

		expect(head.status).toBe(200);
		expect(head.headers.get('accept-ranges')).toBe('bytes');

		for (const status of [304, 404]) {
			const response = await worker.fetch(mediaRequest({ Range: 'bytes=0-1' }), mediaEnv({ status }));

			expect(response.status).toBe(status);
			expect(response.headers.get('content-range')).toBeNull();
		}
	});

	it('leaves non-media assets alone', async () => {
		const response = await worker.fetch(mediaRequest({ Range: 'bytes=0-1' }, '/favicon.ico'), mediaEnv());

		expect(response.status).toBe(200);
		expect(response.headers.get('accept-ranges')).toBeNull();
		expect((await response.arrayBuffer()).byteLength).toBe(1000);
	});
});
