import { jsonValueSchema, type JsonObject, type ParsedRequestBody } from './json';

export async function parseRequest(request: Request): Promise<ParsedRequestBody> {
	const contentType = request.headers.get('content-type') ?? '';

	try {
		if (contentType.includes('application/json')) {
			const parsed = jsonValueSchema.safeParse(await request.json());

			return parsed.success ? parsed.data : null;
		}

		const formData = await request.formData();

		return Object.fromEntries(formData.entries());
	} catch {
		return null;
	}
}

export function isJsonRequest(request: Request): boolean {
	const accept = request.headers.get('accept') ?? '';
	const contentType = request.headers.get('content-type') ?? '';

	return accept.includes('application/json') || contentType.includes('application/json');
}

export function jsonResponse(status: number, body: JsonObject): Response {
	return Response.json(body, { status });
}
