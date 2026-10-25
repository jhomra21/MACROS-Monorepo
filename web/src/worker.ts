import { z } from 'zod';
import {
	getSupportRedirectPath,
	supportStatusMessages,
	validateSupportRequest,
} from './lib/support';
import { isJsonRequest, jsonResponse, parseRequest } from './lib/request';
import {
	validateWaitlistRequest,
	waitlistStatusMessages,
	type WaitlistRequestInput,
} from './lib/waitlist';

type AssetsBinding = {
	fetch(input: RequestInfo | URL, init?: RequestInit): Promise<Response>;
};

type SupportDatabase = {
	prepare(query: string): {
		bind(...values: (string | number)[]): PreparedStatement;
	};
	batch(statements: PreparedStatement[]): Promise<Array<{ meta: { changes?: number } }>>;
};

type PreparedStatement = {
	run(): Promise<{ meta: { changes?: number } }>;
};

const FORM_RETENTION_DAYS = 365;

const FORM_RETENTION_BATCH_SIZE = 500;

const FORM_RETENTION_MAX_ITERATIONS = 100;

const FORM_TABLES = ['support_requests', 'waitlist_entries'] as const;

function retentionCutoff(scheduledTime: number): string {
	const cutoff = new Date(scheduledTime);
	cutoff.setUTCDate(cutoff.getUTCDate() - FORM_RETENTION_DAYS);

	return cutoff.toISOString().slice(0, 19).replace('T', ' ');
}

async function purgeExpiredForms(database: SupportDatabase, scheduledTime: number): Promise<void> {
	const cutoff = retentionCutoff(scheduledTime);
	const counts = { support_requests: 0, waitlist_entries: 0 };
	let iterations = 0;
	let lastDeleted = 0;

	while (iterations < FORM_RETENTION_MAX_ITERATIONS) {
		const statements = FORM_TABLES.map((table) =>
			database.prepare(
				`DELETE FROM ${table} WHERE rowid IN (SELECT rowid FROM ${table} WHERE created_at < ? LIMIT ${FORM_RETENTION_BATCH_SIZE})`,
			).bind(cutoff),
		);

		const results = await database.batch(statements);
		iterations += 1;
		lastDeleted = 0;

		for (const [index, table] of FORM_TABLES.entries()) {
			const deleted = Number(results[index]?.meta.changes ?? 0);
			counts[table] += deleted;
			lastDeleted += deleted;
		}

		if (lastDeleted === 0) break;
	}

	console.log(JSON.stringify({
		event: 'form-retention-purge',
		supportRequests: counts.support_requests,
		waitlistEntries: counts.waitlist_entries,
		iterations,
		capped: iterations === FORM_RETENTION_MAX_ITERATIONS && lastDeleted > 0,
	}));
}

export type WorkerEnv = {
	ASSETS: AssetsBinding;
	SUPPORT_DB: SupportDatabase;
	SUPPORT_LIMITER?: { limit(options: { key: string }): Promise<{ success: boolean }> };
	WAITLIST_LIMITER?: { limit(options: { key: string }): Promise<{ success: boolean }> };
};

type WaitlistInsertResult = 'inserted' | 'existing';

function textResponse(status: number, message: string): Response {
	return new Response(message, {
		status,
		headers: {
			'content-type': 'text/plain; charset=utf-8',
		},
	});
}

function redirectResponse(request: Request, path: string): Response {
	return Response.redirect(new URL(path, request.url), 303);
}

async function insertSupportRequest(
	input: {
		name: string;
		email: string;
		message: string;
	},
	env: WorkerEnv,
): Promise<void> {
	await env.SUPPORT_DB.prepare(
		`INSERT INTO support_requests (name, email, message) VALUES (?, ?, ?)`,
	)
		.bind(input.name, input.email, input.message)
		.run();
}

async function insertWaitlistEntry(
	input: WaitlistRequestInput,
	env: WorkerEnv,
): Promise<WaitlistInsertResult> {
	const result = await env.SUPPORT_DB.prepare(
		`INSERT OR IGNORE INTO waitlist_entries (email) VALUES (?)`,
	)
		.bind(input.email)
		.run();

	return Number(result.meta.changes ?? 0) > 0 ? 'inserted' : 'existing';
}

async function handleSupportRequest(request: Request, env: WorkerEnv): Promise<Response> {
	const body = await parseRequest(request);

	if (hasHoneypotValue(body)) {
		return isJsonRequest(request)
			? jsonResponse(200, { message: supportStatusMessages.submitted })
			: redirectResponse(request, getSupportRedirectPath('submitted'));
	}

	const parsed = validateSupportRequest(body);

	if (!parsed.success) {
		if (isJsonRequest(request)) {
			return jsonResponse(400, {
				message: parsed.message,
				fieldErrors: parsed.fieldErrors,
			});
		}

		return redirectResponse(request, getSupportRedirectPath('invalid'));
	}

	try {
		await insertSupportRequest(parsed.data, env);
	} catch {
		if (isJsonRequest(request)) {
			return jsonResponse(500, {
				message: supportStatusMessages.error,
			});
		}

		return redirectResponse(request, getSupportRedirectPath('error'));
	}

	if (isJsonRequest(request)) {
		return jsonResponse(200, {
			message: supportStatusMessages.submitted,
		});
	}

	return redirectResponse(request, getSupportRedirectPath('submitted'));
}

async function handleWaitlistRequest(request: Request, env: WorkerEnv): Promise<Response> {
	const body = await parseRequest(request);

	if (hasHoneypotValue(body)) {
		return isJsonRequest(request)
			? jsonResponse(200, { message: waitlistStatusMessages.submitted })
			: textResponse(200, waitlistStatusMessages.submitted);
	}

	const parsed = validateWaitlistRequest(body);

	if (!parsed.success) {
		if (isJsonRequest(request)) {
			return jsonResponse(400, {
				message: parsed.message,
				fieldErrors: parsed.fieldErrors,
			});
		}

		return textResponse(400, parsed.message);
	}

	try {
		const insertResult = await insertWaitlistEntry(parsed.data, env);

		const message =
			insertResult === 'inserted'
				? waitlistStatusMessages.submitted
				: waitlistStatusMessages.alreadyJoined;

		if (isJsonRequest(request)) {
			return jsonResponse(200, { message });
		}

		return textResponse(200, message);
	} catch {
		if (isJsonRequest(request)) {
			return jsonResponse(500, {
				message: waitlistStatusMessages.error,
			});
		}

		return textResponse(500, waitlistStatusMessages.error);
	}
}

export default {
	async fetch(request: Request, env: WorkerEnv): Promise<Response> {
		const url = new URL(request.url);

		if (request.method === 'POST' && url.pathname === '/api/support') {
			const limited = await enforceFormLimit(request, env.SUPPORT_LIMITER);

			if (limited != null) {
				return limited;
			}

			return handleSupportRequest(request, env);
		}

		if (request.method === 'POST' && url.pathname === '/api/waitlist') {
			const limited = await enforceFormLimit(request, env.WAITLIST_LIMITER);

			if (limited != null) {
				return limited;
			}

			return handleWaitlistRequest(request, env);
		}

		return env.ASSETS.fetch(request);
	},
	async scheduled(controller: Pick<ScheduledController, 'scheduledTime'>, env: WorkerEnv): Promise<void> {
		await purgeExpiredForms(env.SUPPORT_DB, controller.scheduledTime);
	},
};

function hasHoneypotValue(body: Awaited<ReturnType<typeof parseRequest>>): boolean {
	const parsed = honeypotSchema.safeParse(body);

	return parsed.success && (parsed.data.website?.trim().length ?? 0) > 0;
}

const honeypotSchema = z.object({ website: z.string().optional() }).loose();

async function enforceFormLimit(
	request: Request,
	limiter: WorkerEnv['SUPPORT_LIMITER'],
): Promise<Response | null> {
	if (limiter == null) return null;

	const ip = request.headers.get('cf-connecting-ip')?.trim() || 'unknown-client';
	const { success } = await limiter.limit({ key: ip });

	return success ? null : new Response(JSON.stringify({ message: 'Too many requests. Please try again in a minute.' }), {
		status: 429,
		headers: {
			'Cache-Control': 'no-store',
			'Content-Type': 'application/json; charset=utf-8',
			'Retry-After': '60',
		},
	});
}
