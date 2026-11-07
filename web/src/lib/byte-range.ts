// Workers static assets ignore Range and answer 200 with the whole file, and Safari plays MP4
// only after a 206 to its first-bytes probe, so /media/ responses are sliced here (RFC 9110 §14).
// Media files are about 1 MB, so reading the whole asset before slicing is cheap.
export async function withByteRange(request: Request, asset: Response): Promise<Response> {
	if (asset.status !== 200) return asset;

	const range = requestedRange(request, asset.headers.get('ETag'));

	if (range == null) {
		const whole = new Response(asset.body, asset);
		whole.headers.set('Accept-Ranges', 'bytes');

		return whole;
	}

	const body = await asset.arrayBuffer();
	const size = body.byteLength;
	const start = range.first === '' ? Math.max(0, size - Number(range.last)) : Number(range.first);
	const end = range.first === '' || range.last === '' ? size - 1 : Math.min(Number(range.last), size - 1);

	if (start > end) {
		return new Response(null, { status: 416, headers: { 'Content-Range': `bytes */${size}` } });
	}

	const headers = new Headers(asset.headers);
	headers.set('Accept-Ranges', 'bytes');
	headers.set('Content-Range', `bytes ${start}-${end}/${size}`);
	headers.set('Content-Length', String(end - start + 1));

	return new Response(body.slice(start, end + 1), { status: 206, headers });
}

// The single byte range to serve, or null to send the whole file.
function requestedRange(request: Request, etag: string | null): { first: string; last: string } | null {
	const ifRange = request.headers.get('If-Range');

	if (request.method !== 'GET' || (ifRange != null && ifRange !== etag)) return null;

	const match = /^bytes=(\d*)-(\d*)$/.exec(request.headers.get('Range')?.trim() ?? '');
	const first = match?.[1] ?? '';
	const last = match?.[2] ?? '';

	// No range, an empty one, or an end before the start: a server ignores the header.
	if (match == null || (first === '' && last === '')) return null;

	if (first !== '' && last !== '' && Number(last) < Number(first)) return null;

	return { first, last };
}
