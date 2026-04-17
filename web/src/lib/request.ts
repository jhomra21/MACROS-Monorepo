export async function parseRequest(request: Request): Promise<unknown> {
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

export function isJsonRequest(request: Request): boolean {
	const accept = request.headers.get('accept') ?? '';
	const contentType = request.headers.get('content-type') ?? '';

	return accept.includes('application/json') || contentType.includes('application/json');
}

export function jsonResponse(status: number, body: Record<string, unknown>): Response {
	return Response.json(body, { status });
}
