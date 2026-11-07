// Workers static assets ignore Range and answer 200 with the whole file, and Safari plays MP4
// only after a 206 to its first-bytes probe, so /media/ responses are sliced here (RFC 9110 §14).
//
// The asset body is a stream with no seek. When the asset reports its Content-Length, the window
// is cut out of the stream chunk by chunk: bytes before the range are skipped and the upstream is
// cancelled once the range end has been sent. The static-assets binding does not send a
// Content-Length (checked in wrangler dev), so otherwise the file is measured by reading a clone
// of it, up to MAX_MEASURED_BYTES; a bigger file is sent whole.
const MAX_MEASURED_BYTES = 8 * 1024 * 1024;

export async function withByteRange(request: Request, asset: Response): Promise<Response> {
	if (asset.status !== 200) return asset;

	const range = requestedRange(request, asset.headers);

	if (range == null) {
		const whole = new Response(asset.body, asset);
		whole.headers.set('Accept-Ranges', 'bytes');

		return whole;
	}

	const length = contentLength(asset);
	const measured = length == null ? await readUpTo(asset.clone(), MAX_MEASURED_BYTES) : null;
	const size = length ?? measured?.byteLength;

	if (size == null) return asset;

	const start = range.first === '' ? Math.max(0, size - Number(range.last)) : Number(range.first);
	const end = range.first === '' || range.last === '' ? size - 1 : Math.min(Number(range.last), size - 1);

	if (start > end) {
		await asset.body?.cancel();

		return new Response(null, { status: 416, headers: { 'Content-Range': `bytes */${size}` } });
	}

	const headers = new Headers(asset.headers);
	headers.set('Accept-Ranges', 'bytes');
	headers.set('Content-Range', `bytes ${start}-${end}/${size}`);
	headers.set('Content-Length', String(end - start + 1));

	if (measured != null) {
		await asset.body?.cancel();

		return new Response(measured.slice(start, end + 1), { status: 206, headers });
	}

	// A body-less response with a nonzero Content-Length cannot be sliced.
	if (asset.body == null) return asset;

	return new Response(window(asset.body, start, end), { status: 206, headers });
}

function contentLength(asset: Response): number | null {
	const value = asset.headers.get('Content-Length');

	return value != null && /^\d+$/.test(value) ? Number(value) : null;
}

// The whole body, or null (after cancelling the read) once it exceeds `limit` bytes.
async function readUpTo(response: Response, limit: number): Promise<Uint8Array | null> {
	const reader = response.body?.getReader();
	const chunks: Uint8Array[] = [];
	let total = 0;

	while (reader != null) {
		const { done, value } = await reader.read();

		if (done) break;

		total += value.byteLength;

		if (total > limit) {
			await reader.cancel();

			return null;
		}

		chunks.push(value);
	}

	const bytes = new Uint8Array(total);
	let offset = 0;

	for (const chunk of chunks) {
		bytes.set(chunk, offset);
		offset += chunk.byteLength;
	}

	return bytes;
}

// The bytes from `start` through `end` (inclusive) of a stream, pulled only as the consumer reads.
function window(source: ReadableStream<Uint8Array>, start: number, end: number): ReadableStream<Uint8Array> {
	const reader = source.getReader();
	let offset = 0;

	return new ReadableStream<Uint8Array>({
		async pull(controller) {
			for (;;) {
				const { done, value } = await reader.read();

				if (done) return controller.close();

				const chunkStart = offset;
				offset += value.byteLength;

				if (offset <= start) continue;

				controller.enqueue(value.subarray(Math.max(0, start - chunkStart), Math.min(value.byteLength, end + 1 - chunkStart)));

				if (offset > end) {
					controller.close();
					await reader.cancel();
				}

				return;
			}
		},
		cancel: (reason) => reader.cancel(reason),
	});
}

// The single byte range to serve, or null to send the whole file.
function requestedRange(request: Request, assetHeaders: Headers): { first: string; last: string } | null {
	if (request.method !== 'GET' || !ifRangeAllows(request.headers.get('If-Range'), assetHeaders)) return null;

	const match = /^bytes=(\d*)-(\d*)$/.exec(request.headers.get('Range')?.trim() ?? '');
	const first = match?.[1] ?? '';
	const last = match?.[2] ?? '';

	// No range, an empty one, or an end before the start: a server ignores the header.
	if (match == null || (first === '' && last === '')) return null;

	if (first !== '' && last !== '' && Number(last) < Number(first)) return null;

	return { first, last };
}

// RFC 9110 §13.1.5: If-Range holds an entity-tag or an HTTP-date, and the range applies only
// when that validator still matches strongly. Anything else means the whole file.
function ifRangeAllows(value: string | null, assetHeaders: Headers): boolean {
	const ifRange = value?.trim();

	if (ifRange == null) return true;

	if (ifRange.startsWith('"') || ifRange.startsWith('W/')) {
		return !ifRange.startsWith('W/') && ifRange === assetHeaders.get('ETag');
	}

	// A date matches only exactly, and Last-Modified is strong only if the file is at least a second older than now.
	const lastModified = assetHeaders.get('Last-Modified');

	return ifRange === lastModified && Date.now() - Date.parse(lastModified ?? '') >= 1000;
}
