export const prerender = false;

import type { APIRoute } from 'astro';
import { env } from 'cloudflare:workers';

import { isJsonRequest, jsonResponse, parseRequest } from '../../lib/request';
import {
	validateWaitlistRequest,
	waitlistStatusMessages,
	type WaitlistRequestInput,
} from '../../lib/waitlist';

type WaitlistInsertResult = 'inserted' | 'existing';

async function insertWaitlistEntry(input: WaitlistRequestInput): Promise<WaitlistInsertResult> {
	const result = await env.SUPPORT_DB.prepare(
		`INSERT OR IGNORE INTO waitlist_entries (email) VALUES (?)`,
	)
		.bind(input.email)
		.run();

	return Number(result.meta.changes ?? 0) > 0 ? 'inserted' : 'existing';
}

function textResponse(status: number, message: string): Response {
	return new Response(message, {
		status,
		headers: {
			'content-type': 'text/plain; charset=utf-8',
		},
	});
}

export const POST: APIRoute = async ({ request }) => {
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
		const insertResult = await insertWaitlistEntry(parsed.data);
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
};
