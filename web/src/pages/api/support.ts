export const prerender = false;

import type { APIRoute } from 'astro';
import { env } from 'cloudflare:workers';

import { isJsonRequest, jsonResponse, parseRequest } from '../../lib/request';
import {
	getSupportRedirectPath,
	supportStatusMessages,
	validateSupportRequest,
} from '../../lib/support';

async function insertSupportRequest(input: {
	name: string;
	email: string;
	message: string;
}): Promise<void> {
	await env.SUPPORT_DB.prepare(
		`INSERT INTO support_requests (name, email, message) VALUES (?, ?, ?)`,
	)
		.bind(input.name, input.email, input.message)
		.run();
}

export const POST: APIRoute = async ({ request, redirect }) => {
	const parsed = validateSupportRequest(await parseRequest(request));

	if (!parsed.success) {
		if (isJsonRequest(request)) {
			return jsonResponse(400, {
				message: parsed.message,
				fieldErrors: parsed.fieldErrors,
			});
		}

		return redirect(getSupportRedirectPath('invalid'), 303);
	}

	try {
		await insertSupportRequest(parsed.data);
	} catch {
		if (isJsonRequest(request)) {
			return jsonResponse(500, {
				message: supportStatusMessages.error,
			});
		}

		return redirect(getSupportRedirectPath('error'), 303);
	}

	if (isJsonRequest(request)) {
		return jsonResponse(200, {
			message: supportStatusMessages.submitted,
		});
	}

	return redirect(getSupportRedirectPath('submitted'), 303);
};
