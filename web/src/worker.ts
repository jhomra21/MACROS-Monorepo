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

type Env = {
	ASSETS: AssetsBinding;
	SUPPORT_DB: D1Database;
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
	env: Env,
): Promise<void> {
	await env.SUPPORT_DB.prepare(
		`INSERT INTO support_requests (name, email, message) VALUES (?, ?, ?)`,
	)
		.bind(input.name, input.email, input.message)
		.run();
}

async function insertWaitlistEntry(
	input: WaitlistRequestInput,
	env: Env,
): Promise<WaitlistInsertResult> {
	const result = await env.SUPPORT_DB.prepare(
		`INSERT OR IGNORE INTO waitlist_entries (email) VALUES (?)`,
	)
		.bind(input.email)
		.run();

	return Number(result.meta.changes ?? 0) > 0 ? 'inserted' : 'existing';
}

async function handleSupportRequest(request: Request, env: Env): Promise<Response> {
	const parsed = validateSupportRequest(await parseRequest(request));

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

async function handleWaitlistRequest(request: Request, env: Env): Promise<Response> {
	const parsed = validateWaitlistRequest(await parseRequest(request));

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
	async fetch(request: Request, env: Env): Promise<Response> {
		const url = new URL(request.url);

		if (request.method === 'POST' && url.pathname === '/api/support') {
			return handleSupportRequest(request, env);
		}

		if (request.method === 'POST' && url.pathname === '/api/waitlist') {
			return handleWaitlistRequest(request, env);
		}

		return env.ASSETS.fetch(request);
	},
};
