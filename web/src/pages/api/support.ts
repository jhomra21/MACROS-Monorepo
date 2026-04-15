export const prerender = false;

import type { APIRoute } from 'astro';
import { env } from 'cloudflare:workers';

import {
	getSupportRedirectPath,
	supportStatusMessages,
	validateSupportRequest,
} from '../../lib/support';

async function parseRequest(request: Request): Promise<unknown> {
	const contentType = request.headers.get('content-type') ?? '';

	try {
		if (contentType.includes('application/json')) {
			return await request.json();
		}

		const formData = await request.formData();

		return Object.fromEntries(formData.entries());
	} catch {
		return null;
	}
}

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

function isJsonRequest(request: Request): boolean {
	const accept = request.headers.get('accept') ?? '';
	const contentType = request.headers.get('content-type') ?? '';

	return accept.includes('application/json') || contentType.includes('application/json');
}

function jsonResponse(status: number, body: Record<string, unknown>): Response {
	return Response.json(body, { status });
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
